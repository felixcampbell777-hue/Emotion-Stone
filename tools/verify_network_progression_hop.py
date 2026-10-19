"""Real current-protocol legacy migration A -> fresh B -> A, isolated from player saves."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
from runtime_paths import isolated_environment

ROOT = Path(__file__).resolve().parents[1]
PROBE = 'res://scripts/network/wr_progression_hop_probe.gd'


def fingerprint():
    paths = sorted(list((ROOT / 'game/scripts').rglob('*.gd')) +
                   list((ROOT / 'game/content').rglob('*.json')) +
                   [ROOT / 'game/project.godot', ROOT / 'tools/network/durable_replace.py'])
    digest = hashlib.sha256()
    for path in paths:
        digest.update(path.relative_to(ROOT).as_posix().encode() + b'\0' + path.read_bytes())
    return {'sha256': digest.hexdigest(), 'files': len(paths)}


def file_sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def scenario(engine, port_a, port_b, exported=False, durable_helper=None):
    children = []
    engine = str(Path(engine).resolve())
    adjacent = Path(engine).parent / 'durable_replace.py'
    helper = Path(durable_helper).resolve() if durable_helper else adjacent if exported and adjacent.is_file() else ROOT / 'tools/network/durable_replace.py'
    if not helper.is_file():
        raise RuntimeError('Trusted fixture persistence helper is missing')
    def capture():
        if not exported:
            return fingerprint()
        return {'scope': 'embedded executable and trusted external helper',
                'executable_sha256': file_sha(Path(engine)),
                'durable_helper_sha256': file_sha(helper)}
    before = capture()
    with tempfile.TemporaryDirectory(prefix='wr-progression-live-hop-') as temporary:
        scratch = Path(temporary)
        data = scratch / 'scenario'

        def spawn(name, arguments):
            folder = scratch / name
            folder.mkdir()
            log = folder / 'process.log'
            stream = log.open('w')
            env = isolated_environment(folder / 'userdata')
            # A fixture owns its loopback ports and empty test membership secret.
            # Never inherit a real host's password, bind, data or voice settings.
            for key in ('WORLD_RISE_PASSWORD_FILE', 'WORLD_RISE_PRIVATE_VPN', 'WORLD_RISE_PORT',
                        'WORLD_RISE_VOICE_PORT', 'WORLD_RISE_DATA_DIR', 'WORLD_RISE_BIND_ADDRESS'):
                env.pop(key, None)
            env.update(WORLD_RISE_DURABLE_HELPER=str(helper),
                       WORLD_RISE_PYTHON=sys.executable)
            process = subprocess.Popen([engine, '--headless'] + ([] if exported else ['--path', str(ROOT / 'game')]) + arguments,
                                       stdout=stream, stderr=subprocess.STDOUT, env=env)
            children.append((process, stream, log))
            return process, log

        def server(name, port, world):
            process, log = spawn(name, ['res://scenes/world_rise_server.tscn', '--',
                                f'--port={port}', f'--data-dir={data / world}', '--bind=127.0.0.1'])
            deadline = time.monotonic() + 45
            health = {}
            while process.poll() is None and time.monotonic() < deadline:
                try:
                    health = json.loads((data / world / 'ready.json').read_text())
                except (OSError, ValueError):
                    health = {}
                # Release-template stdout is buffered when redirected. Use the
                # real production readiness record, then count startup markers
                # after clean exits have flushed the logs.
                if health.get('ready') and health.get('voice_ready') and not health.get('storage_error'):
                    return process, log
                time.sleep(.1)
            raise RuntimeError(f'Server startup failed ({name}, exit={process.poll()}, deadline=45s, health={health}): ' + log.read_text()[-4000:])

        try:
            setup, setup_log = spawn('setup', ['--script', PROBE, '--', '--mode=seed', f'--scenario={data}'])
            setup.wait(timeout=25)
            if setup.returncode or 'ERROR' in setup_log.read_text():
                raise RuntimeError('Disposable legacy seed failed: ' + setup_log.read_text()[-4000:])
            server('serverA', port_a, 'a')
            client, client_log = spawn('client', ['--script', PROBE, '--', f'--scenario={data}',
                                      f'--port-a={port_a}', f'--port-b={port_b}'])
            started_b = False
            deadline = time.monotonic() + 160
            while client.poll() is None and time.monotonic() < deadline:
                if not started_b and (data / 'start-b.request').is_file():
                    server('serverB', port_b, 'b')
                    (data / 'b-started').write_text('ready')
                    started_b = True
                time.sleep(.1)
            if client.poll() is None:
                raise TimeoutError('Live migration timed out: ' + client_log.read_text()[-5000:])
            for world in ('a', 'b'):
                (data / world / 'stop.request').write_text('clean verification shutdown')
            for process, _, log in children:
                if log.parent.name.startswith('server'):
                    process.wait(timeout=12)
            reports = [line.removeprefix('PROGRESSION_HOP_RESULT ') for line in client_log.read_text().splitlines()
                       if line.startswith('PROGRESSION_HOP_RESULT ')]
            result = json.loads(reports[-1]) if reports else None
            reopened = None
            if result and result.get('passed'):
                (data / 'client-result.json').write_text(json.dumps(result))
                verification, verification_log = spawn('reopen', ['--script', PROBE, '--',
                                                      '--mode=reopen', f'--scenario={data}'])
                verification.wait(timeout=25)
                lines = [line.removeprefix('PROGRESSION_HOP_REOPEN ') for line in verification_log.read_text().splitlines()
                         if line.startswith('PROGRESSION_HOP_REOPEN ')]
                reopened = json.loads(lines[-1]) if lines else None
            errors = {}
            for _, _, log in children:
                rows = [line for line in log.read_text().splitlines() if 'ERROR' in line or 'WARNING:' in line]
                errors[log.parent.name] = dict(Counter(rows))
            exits = {log.parent.name: process.returncode for process, _, log in children}
            ready_counts = {log.parent.name: sum(line.startswith('WORLD_RISE_SERVER_READY') for line in log.read_text().splitlines())
                            for _, _, log in children if log.parent.name.startswith('server')}
            ready_once = set(ready_counts) == {'serverA', 'serverB'} and all(count == 1 for count in ready_counts.values())
            after = capture()
            passed = bool(result and result.get('passed') and reopened and reopened.get('passed')) and not any(errors.values()) \
                and all(code == 0 for code in exits.values()) and ready_once and before == after
            return {'passed': passed,
                    'engine': 'Godot 4.5.1', 'execution_scope': 'embedded export; no source path override' if exported else 'source project',
                    'fixture_helper_scope': 'adjacent packaged helper' if helper == adjacent else 'explicit checkout fixture support; no installed-client hosting claim', 'topology': 'Separate dedicated A/B and one reused real ENet Session client',
                    'result': result, 'durable_server_reopen': reopened, 'exits': exits, 'errors': errors,
                    'server_ready_counts': ready_counts, 'servers_started_exactly_once': ready_once,
                    'source_before': before, 'source_after': after, 'source_unchanged': before == after,
                    'failure_logs': {} if passed else {log.parent.name: log.read_text()[-6000:] for _, _, log in children}}
        finally:
            for process, stream, _ in reversed(children):
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
                stream.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--exported', action='store_true', help='Execute the embedded export without a source --path override')
    parser.add_argument('--durable-helper', type=Path, help='Trusted external fixture helper when not shipped beside the executable')
    parser.add_argument('--port-a', type=int, default=25091)
    parser.add_argument('--port-b', type=int, default=25093)
    parser.add_argument('--output', type=Path, default=ROOT / 'output/verification/network-progression-hop-current.json')
    args = parser.parse_args()
    if not (1024 <= args.port_a <= 65534 and 1024 <= args.port_b <= 65534) or abs(args.port_a - args.port_b) < 2:
        parser.error('Use two nonoverlapping game/voice port pairs')
    try:
        result = scenario(args.godot, args.port_a, args.port_b, args.exported, args.durable_helper)
    except (RuntimeError, TimeoutError, subprocess.TimeoutExpired) as error:
        result = {'passed': False, 'error': str(error)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
