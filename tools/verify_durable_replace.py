"""Exercise actual checkpoint replacement and failed-write recovery in disposable storage."""
import base64
import hashlib
import json
import struct
from pathlib import Path
import subprocess
import sys
import tempfile

HELPER = Path(__file__).resolve().parent / 'network' / 'durable_replace.py'


def variant(value):
    """Independent minimal Godot Variant encoder for opaque atomic-I/O fixtures."""
    if isinstance(value, dict):
        return struct.pack('<II', 27, len(value)) + b''.join(variant(k) + variant(v) for k, v in value.items())
    if isinstance(value, str):
        encoded = value.encode('utf-8')
        return struct.pack('<II', 4, len(encoded)) + encoded + b'\0' * (-len(encoded) % 4)
    if isinstance(value, int):
        return struct.pack('<Ii', 2, value)
    raise TypeError(type(value))


def envelope(value):
    raw = variant(value)
    return {'world_rise_storage': 1, 'kind': 'world', 'encoding': 'godot-variant-no-objects-v1',
            'raw_size': len(raw), 'sha256': hashlib.sha256(raw).hexdigest(),
            'payload': base64.b64encode(raw).decode('ascii')}


def run():
    outcomes = []
    with tempfile.TemporaryDirectory(prefix='world-rise-durability-') as directory:
        target = Path(directory) / 'world.json'
        pending = Path(str(target) + '.pending')
        previous = Path(str(target) + '.previous')
        first = envelope({'sequence': 1, 'copper': 11, 'padding': 'x' * 8192})
        second = envelope({'sequence': 2, 'copper': 37})
        pending.write_text(json.dumps(first))
        result = subprocess.run([sys.executable, str(HELPER), str(target)], capture_output=True)
        assert result.returncode == 0 and json.loads(target.read_text()) == first
        outcomes.append('first durable checkpoint installed')
        pending.write_text(json.dumps(second))
        result = subprocess.run([sys.executable, str(HELPER), str(target)], capture_output=True)
        assert result.returncode == 0 and json.loads(target.read_text()) == second
        assert json.loads(previous.read_text()) == first
        outcomes.append('replacement preserves complete prior checkpoint')
        pending.write_text('{broken')
        result = subprocess.run([sys.executable, str(HELPER), str(target)], capture_output=True)
        assert result.returncode != 0 and json.loads(target.read_text()) == second
        outcomes.append('malformed proposed checkpoint cannot replace accepted data')
        if sys.platform != 'win32':
            # Limit backup writes in the child: a concrete write failure must not
            # acknowledge or install the pending economy state.
            import resource
            target.write_text(json.dumps(first))
            pending.write_text(json.dumps(second))
            accepted_backup = previous.read_bytes()
            def limit_file_writes():
                resource.setrlimit(resource.RLIMIT_FSIZE, (128, 128))
            result = subprocess.run([sys.executable, str(HELPER), str(target)],
                                    capture_output=True, preexec_fn=limit_file_writes)
            assert result.returncode != 0 and json.loads(target.read_text()) == first
            assert json.loads(pending.read_text()) == second
            assert previous.read_bytes() == accepted_backup
            outcomes.append('actual child write failure preserves accepted checkpoint and prior backup')
    print(json.dumps({'checks': len(outcomes), 'passed': outcomes}, indent=2))


if __name__ == '__main__':
    run()
