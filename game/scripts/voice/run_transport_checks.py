"""Run real ENet-authenticated sessions and their dedicated HMAC voice UDP clients.
No microphone is opened: clients inject a synthetic Opus tone into the normal voice UDP transport.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools'))
from udp_condition_proxy import UDPConditionProxy
import platform_cli
from runtime_paths import isolated_environment


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--peers', type=int, choices=[2, 8], default=2)
    parser.add_argument('--port', type=int, default=25483)
    parser.add_argument('--crossfloor', action='store_true')
    parser.add_argument('--conditioned', action='store_true', help='150ms RTT, ±20ms per-leg jitter, 2%% loss per leg on gameplay and voice')
    args = parser.parse_args()
    processes, temporary, proxies = [], [], []
    results = []
    try:
        for index in range(args.peers + 1):
            scratch = tempfile.TemporaryDirectory(prefix='world-rise-voice-')
            temporary.append(scratch)
            env = isolated_environment(scratch.name)
            client_port = args.port
            if index > 0 and args.conditioned:
                game_proxy = UDPConditionProxy(args.port, jitter_ms=20, seed=31000 + index)
                voice_proxy = UDPConditionProxy(args.port + 1, jitter_ms=20, seed=41000 + index)
                proxies.extend([game_proxy, voice_proxy])
                client_port = game_proxy.port
                env['WORLD_RISE_TEST_VOICE_PORT'] = str(voice_proxy.port)
            command = [platform_cli.toolchain()['godot'], '--headless', '--verbose', '--path', str(ROOT / 'game'), '--script', 'res://scripts/voice/voice_transport_checks.gd', '--', '--peers', str(args.peers), '--port', str(client_port)]
            if index == 0:
                command.append('--server')
            if args.crossfloor:
                command.append('--crossfloor')
            processes.append(subprocess.Popen(command, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True))
            time.sleep(.2 if index == 0 else .05)
        for index, process in enumerate(processes):
            try:
                out, err = process.communicate(timeout=32)
            except subprocess.TimeoutExpired:
                process.kill()
                out, err = process.communicate()
                err += '\nFixture process timed out'
            outcome = {'process': index, 'exit': process.returncode,
                       'outcome': [line for line in out.splitlines() if line.startswith('VOICE TRANSPORT')],
                       'errors': list(dict.fromkeys(err.strip().splitlines()))[:20], 'leaks': [line for line in out.splitlines() if any(term in line for term in ['Leaked instance', 'Orphan StringName', 'still in use at exit'])][:20]}
            results.append(outcome)
            print(json.dumps(outcome))
        passed = all(result['exit'] == 0 and not result['errors'] for result in results)
        scenario = f"{'conditioned' if args.conditioned else 'local'}-{'crossfloor-' if args.crossfloor else ''}{args.peers}"
        target = ROOT / f'output/verification/voice-transport-{scenario}.json'
        target.parent.mkdir(parents=True, exist_ok=True)
        report = json.dumps({'passed': passed, 'peers': args.peers, 'crossfloor': args.crossfloor, 'conditioned': args.conditioned,
                             'proxy_stats': [dict(proxy.stats) for proxy in proxies], 'processes': results}, indent=2) + '\n'
        target.write_text(report)
        (target.parent / 'voice-transport.json').write_text(report)
        return 0 if passed else 1
    finally:
        for process in processes:
            if process.poll() is None:
                process.kill()
                process.wait()
        for proxy in proxies:
            proxy.close()
        for scratch in temporary:
            scratch.cleanup()


if __name__ == '__main__':
    raise SystemExit(main())
