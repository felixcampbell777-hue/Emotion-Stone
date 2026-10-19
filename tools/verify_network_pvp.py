"""Real dedicated authority plus two authenticated Session peers, one in the actual game."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from runtime_paths import isolated_environment

ROOT = Path(__file__).resolve().parents[1]


def run(engine, control_only=False, mode="full"):
    children = []
    with tempfile.TemporaryDirectory(prefix='world-rise-pvp-') as temporary:
        scratch = Path(temporary)
        def spawn(name, arguments):
            directory = scratch / name
            directory.mkdir()
            env = isolated_environment(directory / 'userdata')
            env['WORLD_RISE_DURABLE_HELPER'] = str(ROOT / 'tools/network/durable_replace.py')
            env['WORLD_RISE_PYTHON'] = os.sys.executable
            path = directory / 'process.log'
            stream = path.open('w')
            process = subprocess.Popen([engine, '--headless', '--path', str(ROOT / 'game'), *arguments],
                                       stdout=stream, stderr=subprocess.STDOUT, env=env)
            children.append((process, stream, path))
            return process, path
        try:
            setup, setup_log = spawn('setup', ['--script', 'res://scripts/network/wr_network_scenario_setup.gd', '--',
                '--scenario-kind=pvp-arrow-wall', f'--scenario-root={scratch / "scenario"}'])
            setup.wait(timeout=60)
            if setup.returncode or 'ERROR' in setup_log.read_text():
                raise RuntimeError(setup_log.read_text()[-6000:])
            server, server_log = spawn('server', ['res://scenes/world_rise_server.tscn', '--', '--port=24931',
                '--bind=127.0.0.1', f'--data-dir={scratch / "scenario/server"}'])
            deadline = time.monotonic() + 60
            while 'WORLD_RISE_SERVER_READY' not in server_log.read_text():
                if server.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError('Server not ready: ' + server_log.read_text()[-6000:])
                time.sleep(.1)
            client, client_log = spawn('clients', ['--script', 'res://scripts/network/wr_pvp_process_probe.gd', '--',
                '--port=24931', f'--registry={scratch / "scenario/scenario.json"}', f'--health={scratch / "scenario/server/ready.json"}', f'--control-only={str(control_only).lower()}', f'--mode={mode}'])
            client.wait(timeout=360)
            text = client_log.read_text()
            reports = [line.removeprefix('PVP_PROBE_RESULT ') for line in text.splitlines() if line.startswith('PVP_PROBE_RESULT ')]
            errors = list(dict.fromkeys(line for _, _, path in children for line in path.read_text().splitlines()
                if 'ERROR' in line or 'WARNING:' in line))
            result = json.loads(reports[-1]) if reports else None
            outcome = {'passed': client.returncode == 0 and bool(result and result.get('passed')) and not errors,
                       'engine': 'Godot 4.5.1', 'platform': 'macOS source', 'client_exit': client.returncode,
                       'fixture_mode': mode,
                       'topology': 'One separate dedicated server; two independent authenticated Session peers; one actual main scene',
                       'result': result, 'errors': errors,
                       'server_health': json.loads((scratch / 'scenario/server/ready.json').read_text())}
            if not outcome['passed']:
                outcome['failure_log_tail'] = text[-16000:]
            destination = ROOT / ('output/verification/network-pvp-diagnostic-current.json' if control_only else 'output/verification/network-pvp-repair-current.json' if mode != 'full' else 'output/verification/network-pvp-current.json')
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(json.dumps(outcome, indent=2) + '\n')
            print(json.dumps({"passed": outcome["passed"], "checks": len((outcome.get("result") or {}).get("checks", [])), "failures": (outcome.get("result") or {}).get("failures", []), "error": outcome.get("error"), "evidence": str(destination)}), flush=True)
            return outcome
        except Exception as error:
            outcome = {'passed': False, 'error': str(error),
                       'process_logs': {path.parent.name: path.read_text()[-12000:] for _, _, path in children}}
            destination = ROOT / ('output/verification/network-pvp-diagnostic-current.json' if control_only else 'output/verification/network-pvp-repair-current.json' if mode != 'full' else 'output/verification/network-pvp-current.json')
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(json.dumps(outcome, indent=2) + '\n')
            print(json.dumps({"passed": outcome["passed"], "checks": len((outcome.get("result") or {}).get("checks", [])), "failures": (outcome.get("result") or {}).get("failures", []), "error": outcome.get("error"), "evidence": str(destination)}), flush=True)
            return outcome
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


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--control-only', action='store_true')
    parser.add_argument('--mode', choices=['full', 'repair'], default='full')
    args = parser.parse_args()
    raise SystemExit(0 if run(args.godot, args.control_only, args.mode)['passed'] else 1)
