"""Container lifecycle: local files only, no public administration listener."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

DATA = Path(os.environ.get('WORLD_RISE_DATA_DIR', '/data'))
READY = DATA / 'ready.json'
STOP = DATA / 'stop.request'


def health():
    try:
        status = json.loads(READY.read_text())
        return status.get('ready') is True and not status.get('storage_error') and time.time() - READY.stat().st_mtime < 15
    except (OSError, ValueError):
        return False


def configured_ports(environment):
    port = int(environment.get('WORLD_RISE_PORT', '24571'))
    if not 1024 <= port <= 65535:
        raise ValueError('WORLD_RISE_PORT must be 1024..65535')
    voice_port = int(environment.get('WORLD_RISE_VOICE_PORT', str(port + 1)))
    if not 1024 <= voice_port <= 65535 or voice_port == port:
        raise ValueError('Voice UDP port must be distinct, 1024..65535; configure it explicitly when game port is 65535')
    return port, voice_port


def main():
    if '--health' in sys.argv:
        return 0 if health() else 1
    DATA.mkdir(parents=True, exist_ok=True)
    # Fail before opening a socket when persistent storage is unavailable.
    probe = DATA / '.write-probe'
    with probe.open('w') as stream:
        stream.write('write-test\n')
        stream.flush()
        os.fsync(stream.fileno())
    probe.unlink()
    READY.unlink(missing_ok=True)
    STOP.unlink(missing_ok=True)
    port, voice_port = configured_ports(os.environ)
    command = ['/app/world-rise-server.x86_64', '--headless', '--path', '/app', 'res://scenes/world_rise_server.tscn', '--', '--port=' + str(port), '--data-dir=' + str(DATA), '--voice-port=' + str(voice_port)]
    child = subprocess.Popen(command)
    stopping = None
    def stop(_signum, _frame):
        nonlocal stopping
        if stopping is None:
            stopping = time.monotonic()
            STOP.touch()
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    while child.poll() is None:
        if STOP.exists() and stopping is None:
            stopping = time.monotonic()
        if stopping is not None and time.monotonic() - stopping > 25:
            print('ERROR: graceful save deadline exceeded; terminating child', flush=True)
            child.terminate()
            try:
                child.wait(timeout=3)
            except subprocess.TimeoutExpired:
                child.kill()
            return 1
        time.sleep(0.1)
    READY.unlink(missing_ok=True)
    return child.returncode


if __name__ == '__main__':
    raise SystemExit(main())
