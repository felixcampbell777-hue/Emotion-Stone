"""Consistent offline backups. Stop the server before snapshot or restore."""
import argparse
from contextlib import contextmanager
import hashlib
import fnmatch
import io
import json
import os
from pathlib import Path
import tarfile
import tempfile
import time

TRANSIENT = {'ready.json', 'stop.request', '.write-probe', '.admin.lock', 'admin.request.json', 'admin.result.json', 'world.json.request.json', 'world.json.request.json.pending', 'world.json.pending', 'world.json.previous.pending', 'world.writer.lock'}


def transient(name):
    name = Path(name).name
    return name in TRANSIENT or any(fnmatch.fnmatchcase(name, pattern) for pattern in (
        'world.json.pending.*', 'world.json.request.*.json', 'world.json.request.*.json.pending'))


def ensure_stopped(data):
    if (data / 'ready.json').exists():
        raise ValueError('Server readiness file exists; stop cleanly before backup/restore. After a forced kill, start/recover/stop first.')


@contextmanager
def offline_world(data):
    ensure_stopped(data)
    lock_path = data / 'world.writer.lock'
    if not lock_path.is_file():
        raise ValueError('World writer lock is missing; start/recover/stop the matching server before backup')
    # Hold the kernel lock through the entire snapshot, including the interval
    # before a starting server creates ready.json. Never unlink this inode.
    with lock_path.open('r+b' if os.name == 'nt' else 'rb') as lock:
        try:
            if os.name == 'nt':
                import msvcrt
                msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as error:
            raise ValueError('World has an active writer; stop it cleanly before backup') from error
        ensure_stopped(data)
        yield


def backup(data, destination, retain):
    with offline_world(data):
        return _snapshot(data, destination, retain)


def _snapshot(data, destination, retain):
    ensure_stopped(data)
    if destination.resolve().is_relative_to(data.resolve()):
        raise ValueError('Backup destination must be outside data')
    destination.mkdir(parents=True, exist_ok=True)
    files = sorted(p for p in data.rglob('*') if p.is_file() and not transient(p.name))
    if any(p.is_symlink() for p in data.rglob('*')):
        raise ValueError('Data must not contain symlinks')
    manifest = {'format': 1, 'created_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), 'files': {p.relative_to(data).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}}
    name = time.strftime('world-rise-%Y%m%dT%H%M%SZ', time.gmtime()) + '-' + str(time.time_ns() % 1000000) + '.tar.gz'
    output = destination / name
    temporary = output.with_suffix('.partial')
    try:
        with tarfile.open(temporary, 'w:gz') as archive:
            for path in files:
                archive.add(path, arcname='data/' + path.relative_to(data).as_posix(), recursive=False)
            raw = json.dumps(manifest, sort_keys=True).encode()
            entry = tarfile.TarInfo('backup-manifest.json')
            entry.size = len(raw)
            archive.addfile(entry, io.BytesIO(raw))
        with temporary.open('rb') as stream:
            os.fsync(stream.fileno())
        temporary.replace(output)
        for obsolete in sorted(destination.glob('world-rise-*.tar.gz'), key=lambda p: p.stat().st_mtime, reverse=True)[retain:]:
            obsolete.unlink()
    finally:
        temporary.unlink(missing_ok=True)
    print(output)
    return output


def restore(source, data):
    ensure_stopped(data)
    if data.exists() and any(data.iterdir()):
        raise ValueError('Restore requires an empty target; retain the old volume for rollback')
    with tarfile.open(source, 'r:gz') as archive:
        entries = archive.getmembers()
        if any(not m.isfile() or m.name.startswith('/') or '..' in Path(m.name).parts for m in entries):
            raise ValueError('Backup contains unsafe paths or non-file entries')
        names = [m.name for m in entries]
        if len(names) != len(set(names)):
            raise ValueError('Backup contains duplicate paths')
        manifest = json.load(archive.extractfile('backup-manifest.json'))
        if manifest.get('format') != 1:
            raise ValueError('Incompatible backup format')
        if any(Path(name).is_absolute() or '..' in Path(name).parts or not name or transient(name) for name in manifest['files']):
            raise ValueError('Unsafe path in backup manifest')
        expected = {'data/' + name for name in manifest['files']} | {'backup-manifest.json'}
        if set(names) != expected:
            raise ValueError('Backup manifest/file mismatch')
        # Verify every hash before installing any file.
        for name, digest in manifest['files'].items():
            if hashlib.sha256(archive.extractfile('data/' + name).read()).hexdigest() != digest:
                raise ValueError('Backup checksum mismatch: ' + name)
        data.mkdir(parents=True, exist_ok=True)
        for name in manifest['files']:
            target = data / name
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open('xb') as stream:
                stream.write(archive.extractfile('data/' + name).read())
                stream.flush()
                os.fsync(stream.fileno())
    print('RESTORED: verified hashes; start matching server version to validate checkpoint schema')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    create = commands.add_parser('backup')
    create.add_argument('data', type=Path)
    create.add_argument('destination', type=Path)
    create.add_argument('--retain', type=int, default=7)
    load = commands.add_parser('restore')
    load.add_argument('archive', type=Path)
    load.add_argument('data', type=Path)
    args = parser.parse_args()
    if args.command == 'backup':
        if args.retain < 1:
            parser.error('--retain must be positive')
        backup(args.data, args.destination, args.retain)
    else:
        restore(args.archive, args.data)


if __name__ == '__main__':
    main()
