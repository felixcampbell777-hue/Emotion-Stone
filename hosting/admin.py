"""Local container administration. No network listener or remote filesystem input."""
import argparse
import json
import os
from pathlib import Path
import re
import sys
import tempfile
import time
import uuid


def request(data, operation, timeout=12):
    import fcntl  # This CLI runs in the Linux server image (also works on macOS).
    data = Path(data)
    with (data / '.admin.lock').open('a') as lock:
        deadline = time.monotonic() + timeout
        while True:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() > deadline:
                    raise TimeoutError('Another administrator request is still pending')
                time.sleep(.1)
        operation = {**operation, 'id': uuid.uuid4().hex}
        raw = json.dumps(operation).encode()
        if len(raw) > 8192:
            raise ValueError('Administrator request exceeds 8192 bytes')
        target = data / 'admin.request.json'
        if target.exists():
            raise ValueError('A previous request remains pending; check server health before retrying')
        with tempfile.NamedTemporaryFile(prefix='.admin-', suffix='.tmp', dir=data, delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())
        try:
            temporary.replace(target)
            while time.monotonic() < deadline:
                try:
                    result = json.loads((data / 'admin.result.json').read_text())
                except (OSError, ValueError):
                    result = {}
                if result.get('id') == operation['id']:
                    return result
                time.sleep(.1)
            raise TimeoutError('Server did not acknowledge; check health and storage. Do not assume mutation succeeded.')
        finally:
            temporary.unlink(missing_ok=True)


def identifier(value):
    if not re.fullmatch('[0-9a-f]{32}', value):
        raise argparse.ArgumentTypeError('Character ID must be 32 lowercase hexadecimal characters')
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data', type=Path, default=Path(os.environ.get('WORLD_RISE_DATA_DIR', '/data')))
    commands = parser.add_subparsers(dest='op', required=True)
    for operation in ('status','save','restart'):
        commands.add_parser(operation)
    for operation in ('kick','ban'):
        command = commands.add_parser(operation)
        command.add_argument('character', type=identifier)
    whitelist = commands.add_parser('whitelist')
    toggle = whitelist.add_mutually_exclusive_group(required=True)
    toggle.add_argument('--enable', action='store_true')
    toggle.add_argument('--disable', action='store_true')
    whitelist.add_argument('characters', nargs='*', type=identifier)
    args = parser.parse_args()
    operation = {'op':args.op}
    if args.op in ('kick','ban'):
        operation['character'] = args.character
    if args.op == 'whitelist':
        operation.update(enabled=args.enable, characters=args.characters)
    result = request(args.data, operation)
    print(json.dumps(result, indent=2))
    return 0 if result.get('ok') else 1


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, ValueError, TimeoutError) as error:
        print('ADMIN ERROR: ' + str(error), file=sys.stderr)
        raise SystemExit(1)
