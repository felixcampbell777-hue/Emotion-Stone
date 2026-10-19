"""Durable replacement used only by the trusted local dedicated server.

One-shot: durable_replace.py /data/world.json
Persistent private pipe: durable_replace.py --worker /data/world.json
The worker's target is fixed at startup; commands cannot supply filesystem paths.
"""
import json
import base64
import hashlib
import os
from pathlib import Path
import sys
import time


MAX_WORLD_BYTES = 64 * 1024 * 1024
MAX_JSON_BYTES = 2 * ((MAX_WORLD_BYTES + 2) // 3) * 4 + 4096


def validate_envelope(value):
    fields = {'world_rise_storage', 'kind', 'encoding', 'raw_size', 'sha256', 'payload'}
    if not isinstance(value, dict) or set(value) != fields:
        raise ValueError('Unsupported legacy or malformed network checkpoint envelope')
    if type(value['world_rise_storage']) is not int or value['world_rise_storage'] != 1 or value['kind'] != 'world' or value['encoding'] != 'godot-variant-no-objects-v1':
        raise ValueError('Unsupported network checkpoint version/kind/encoding')
    count, payload, checksum = value['raw_size'], value['payload'], value['sha256']
    if type(count) is not int or not 8 <= count <= MAX_WORLD_BYTES:
        raise ValueError('Network checkpoint payload size exceeds its bound')
    if not isinstance(payload, str) or not 12 <= len(payload) <= ((MAX_WORLD_BYTES + 2) // 3) * 4 or len(payload) % 4:
        raise ValueError('Network checkpoint base64 exceeds its bound')
    if not isinstance(checksum, str) or len(checksum) != 64 or any(c not in '0123456789abcdef' for c in checksum):
        raise ValueError('Invalid network checkpoint checksum')
    raw = base64.b64decode(payload, validate=True)
    if len(raw) != count or hashlib.sha256(raw).hexdigest() != checksum:
        raise ValueError('Network checkpoint checksum/size does not match')
    if raw[:4] != bytes((27, 0, 0, 0)):
        raise ValueError('Network checkpoint root must be a no-object dictionary')


def commit_target(target, proposal=None):
    started = time.perf_counter_ns()
    target = Path(target).resolve()
    temporary = Path(proposal) if proposal is not None else Path(str(target) + '.pending')
    if not 2 <= temporary.stat().st_size <= MAX_JSON_BYTES:
        raise ValueError('Network checkpoint file exceeds its size bound')
    with temporary.open('r+b') as stream:
        validate_envelope(json.load(stream))
        validated = time.perf_counter_ns()
        stream.flush()
        os.fsync(stream.fileno())
    pending_synced = time.perf_counter_ns()
    if target.exists():
        backup = Path(str(target) + '.previous')
        backup_pending = Path(str(backup) + '.pending')
        with target.open('rb') as source, backup_pending.open('wb') as destination:
            destination.write(source.read())
            destination.flush()
            os.fsync(destination.fileno())
        os.replace(backup_pending, backup)
    backup_synced = time.perf_counter_ns()
    os.replace(temporary, target)
    if os.name != 'nt':
        descriptor = os.open(target.parent, os.O_RDONLY | getattr(os, 'O_DIRECTORY', 0))
        try:
            os.fsync(descriptor)
        finally:
            os.close(descriptor)
    ended = time.perf_counter_ns()
    return {"validate_us": (validated-started)//1000, "pending_fsync_us": (pending_synced-validated)//1000, "backup_fsync_us": (backup_synced-pending_synced)//1000, "replace_directory_fsync_us": (ended-backup_synced)//1000, "total_us": (ended-started)//1000}


def world_lock(target):
    """An open OS lock, never a PID sentinel, owns this fixed world directory."""
    lock = open(Path(target).parent / 'world.writer.lock', 'a+b')
    try:
        if os.name == 'nt':
            import msvcrt
            lock.seek(0)
            if not lock.read(1):
                lock.write(b'0')
                lock.flush()
            lock.seek(0)
            msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        lock.close()
        raise OSError('World directory already has an active writer')
    return lock


def parent_monitor(parent_pid):
    if parent_pid is None:
        return lambda: True
    if os.name != 'nt':
        return lambda: os.getppid() == parent_pid
    # A persistent kernel process handle detects exit even if Windows retains or
    # recycles the numeric parent PID. It requires no kill/admin privileges.
    import ctypes
    from ctypes import wintypes
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel.OpenProcess.restype = wintypes.HANDLE
    kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
    kernel.WaitForSingleObject.restype = wintypes.DWORD
    handle = kernel.OpenProcess(0x00100000, False, parent_pid)
    if not handle:
        raise OSError('Cannot monitor the world writer parent process')
    return lambda: kernel.WaitForSingleObject(handle, 0) == 258


def take_request(request_path, retry_seconds=1.0):
    """Remove one private request before processing it; retry only Windows sharing locks.

    A scanner or a still-closing native file handle can transiently deny access.
    No checkpoint operation has started here, so rereading after a failed removal
    cannot replay an acknowledged commit. All other failures remain fatal.
    """
    deadline = time.monotonic() + retry_seconds
    while True:
        try:
            line = request_path.read_text()
            request_path.unlink()
            return line
        except FileNotFoundError:
            return None
        except OSError as exc:
            if getattr(exc, 'winerror', None) not in (32, 33) or time.monotonic() >= deadline:
                raise
            time.sleep(0.001)


def worker(target, parent_pid=None, namespace=None):
    if namespace is not None and (len(namespace) != 32 or any(c not in "0123456789abcdef" for c in namespace)):
        raise ValueError("invalid private worker namespace")
    proposal = str(target) + ".pending." + namespace if namespace else None
    request_path = Path(str(target) + ".request." + namespace + ".json") if namespace else Path(str(target) + ".request.json")
    try:
        parent_alive = parent_monitor(parent_pid)
        ownership = world_lock(target)
    except OSError as exc:
        print(json.dumps({'ready': False, 'error': str(exc)}), flush=True)
        return 1
    # Ownership exists before the parent reads mutable world state or creates a
    # proposal/request. Kernel ownership disappears on any process termination.
    request_path.unlink(missing_ok=True)
    print(json.dumps({'ready': True, 'namespace': namespace}), flush=True)
    # Line requests and responses remain tiny. Only the parent owns these pipes;
    # there is no listener, network port, shell, or remotely supplied filename.
    def requests():
        if parent_pid is None:
            yield from sys.stdin
            return
        while parent_alive():
            try:
                line = take_request(request_path)
            except OSError as exc:
                # Preserve the first read/remove failure instead of silently
                # terminating the worker and leaving only downstream timeouts.
                print(json.dumps({'id': -1, 'ok': False, 'error': 'Private request read/remove failed: ' + str(exc)[:512]}), flush=True)
                return
            if line is None:
                time.sleep(0.0001)
            else:
                yield line
    for line in requests():
        request_id = -1
        try:
            if len(line) > 1024:
                raise ValueError('oversized worker request')
            request = json.loads(line)
            request_id = request['id']
            if not isinstance(request_id, int) or request['op'] not in ('commit', 'stop'):
                raise ValueError('invalid worker command')
            if request['op'] == 'stop':
                print(json.dumps({'id': request_id, 'ok': True}), flush=True)
                return 0
            stages = commit_target(target, proposal)
            result = {'id': request_id, 'ok': True, 'stages': stages}
        except (OSError, ValueError, KeyError, TypeError) as exc:
            result = {'id': request_id, 'ok': False, 'error': str(exc)[:512]}
        print(json.dumps(result, separators=(',', ':')), flush=True)
    ownership.close()
    return 0  # Parent exit/pipe closure cannot leave an orphan worker running.


def main():
    if len(sys.argv) in (3, 4, 5) and sys.argv[1] == '--worker':
        return worker(sys.argv[2], int(sys.argv[3]) if len(sys.argv) >= 4 else None, sys.argv[4] if len(sys.argv) == 5 else None)
    ownership = world_lock(sys.argv[1])
    commit_target(sys.argv[1])
    ownership.close()
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, ValueError, IndexError) as exc:
        print(f'durable checkpoint failed: {exc}', file=sys.stderr)
        raise SystemExit(1)
