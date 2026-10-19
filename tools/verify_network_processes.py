"""Launch a separate authority and real ENet client processes in disposable storage."""
import argparse
from collections import Counter
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from runtime_paths import isolated_environment
from udp_condition_proxy import UDPConditionProxy

ROOT = Path(__file__).resolve().parents[1]


def scenario(engine, clients, duration, external_port=None, password_file=None, rtt_ms=0, jitter_ms=0, loss=0, gameplay=False, scenario_registry=None, prediction=False, client_fps="", state_file=None):
    from platform_cli import package_fingerprints
    source_before = package_fingerprints()
    processes = []
    proxies = []
    with tempfile.TemporaryDirectory(prefix='world-rise-net-probe-') as temporary:
        scratch = Path(temporary)
        port = external_port or 24780 + clients
        def spawn(name, arguments):
            folder = scratch / name
            folder.mkdir()
            log = folder / 'process.log'
            env = isolated_environment(folder / 'userdata')
            env['WORLD_RISE_DURABLE_HELPER'] = str(ROOT / 'tools/network/durable_replace.py')
            env['WORLD_RISE_PYTHON'] = os.sys.executable
            stream = log.open('w')
            process = subprocess.Popen([engine, '--headless', '--path', str(ROOT / 'game')] + arguments,
                                       stdout=stream, stderr=subprocess.STDOUT, env=env)
            processes.append((process, stream, log))
            return process, log
        registry = None
        if scenario_registry:
            registry = json.loads(Path(scenario_registry).read_text())
        elif gameplay:
            setup, setup_log = spawn('scenario-setup', ['--script', 'res://scripts/network/wr_network_scenario_setup.gd', '--',
                                     f'--scenario-root={scratch / "authored-scenario"}'])
            setup.wait(timeout=60)
            if setup.returncode != 0 or 'ERROR' in setup_log.read_text():
                raise AssertionError('Authored scenario setup failed: ' + setup_log.read_text()[-4000:])
            registry = json.loads((scratch / 'authored-scenario/scenario.json').read_text())
        if external_port:
            server = None
            server_log = scratch / 'external-server.log'
            server_log.write_text('')
        else:
            server, server_log = spawn('server', ['res://scenes/world_rise_server.tscn', '--',
                                      f'--port={port}', f'--data-dir={registry["server"] if registry else scratch / "world"}', '--bind=127.0.0.1'])
        try:
            deadline = time.monotonic() + 100
            while not external_port and time.monotonic() < deadline and server.poll() is None:
                if 'WORLD_RISE_SERVER_READY' in server_log.read_text():
                    break
                time.sleep(.1)
            else:
                if not external_port:
                    raise AssertionError('Server did not become ready: ' + server_log.read_text()[-4000:])
            jobs = []
            for index in range(clients):
                entry = registry['clients'][index] if registry else {}
                fps_values = client_fps.split(',') if client_fps else ['60'] * clients
                client_frame_cap = fps_values[index % len(fps_values)]
                checkpoint = entry.get('checkpoint', scratch / f'client{index}' / 'character.json')
                destination_port = port
                if rtt_ms or jitter_ms or loss:
                    proxy = UDPConditionProxy(port, rtt_ms, jitter_ms, loss, 18481 + index)
                    proxies.append(proxy)
                    destination_port = proxy.port
                client_script = 'wr_prediction_process_probe.gd' if prediction else 'wr_process_probe.gd'
                process, log = spawn(f'client{index}', ['--script', f'res://scripts/network/{client_script}', '--',
                                     f'--port={destination_port}', f'--checkpoint={checkpoint}', f'--seconds={duration}', f'--expected={sum(1 for candidate in registry["clients"][:clients] if candidate["floor"] == entry["floor"]) if registry else clients}', f'--password-file={password_file or ""}',
                                     f'--role={entry.get("role", "baseline")}', f'--purchase={entry.get("purchase_item", "")}', f'--fps={client_frame_cap}'])
                jobs.append((process, log))
            ready = Path(registry['server']) / 'ready.json' if registry else scratch / 'world/ready.json'
            if state_file:
                Path(state_file).write_text(json.dumps({'server_pid': server.pid if server else None,
                    'scratch': str(scratch), 'ready_path': str(ready),
                    'client_pids': [job[0].pid for job in jobs]}) + '\n')
            samples = []
            sample_start = time.monotonic()
            while any(process.poll() is None for process, _ in jobs):
                if time.monotonic() - sample_start > duration + 45:
                    raise TimeoutError('Network clients exceeded bounded departure deadline')
                sample = {'wall_elapsed_seconds': round(time.monotonic() - sample_start, 3), 'expected_players': clients}
                try:
                    sample['health'] = json.loads(ready.read_text())
                except (OSError, json.JSONDecodeError):
                    sample['health'] = {}
                if server is not None and os.name != 'nt':
                    measure = subprocess.run(['ps', '-p', str(server.pid), '-o', 'rss=,%cpu='], capture_output=True, text=True)
                    columns = measure.stdout.split()
                    if len(columns) == 2:
                        sample.update({'rss_kib': int(columns[0]), 'cpu_percent': float(columns[1])})
                samples.append(sample)
                time.sleep(.5)
            results = []
            for process, log in jobs:
                process.wait(timeout=1)
                contents = log.read_text()
                tag = 'PREDICTION_PROBE_RESULT ' if prediction else 'PROBE_RESULT '
                lines = [line.removeprefix(tag) for line in contents.splitlines() if line.startswith(tag)]
                results.append({'exit': process.returncode, 'result': json.loads(lines[-1]) if lines else None,
                                'errors': list(dict.fromkeys(line for line in contents.splitlines() if 'ERROR' in line)),
                                'error_counts': dict(Counter(line for line in contents.splitlines() if 'ERROR' in line))})
            acceptance_failures = []
            if prediction and client_fps:
                requested_caps = [int(value) for value in client_fps.split(',')]
                for index, item in enumerate(results):
                    actual_cap = (item.get('result') or {}).get('render_fps_cap')
                    if actual_cap != requested_caps[index % len(requested_caps)]:
                        acceptance_failures.append(f'Client {index} cap {actual_cap} differs from requested cap')
            if registry and registry.get('progression_tree_version') == 5:
                for index, item in enumerate(results):
                    if (item.get('result') or {}).get('progression_tree_version') != 5:
                        acceptance_failures.append(f'Client {index} did not durably export current tree5 progression')
            ready = Path(registry['server']) / 'ready.json' if registry else scratch / 'world/ready.json'
            health = json.loads(ready.read_text()) if ready.exists() else {}
            source_after = package_fingerprints()
            if source_before != source_after:
                acceptance_failures.append('Runtime sources changed during this scenario')
            outcome = {'clients': clients, 'requested_client_seconds': duration, 'external_server': bool(external_port), 'passed': all(r['exit'] == 0 and not r['errors'] for r in results) and 'ERROR' not in server_log.read_text() and not acceptance_failures,
                       'source_before': source_before, 'source_after': source_after, 'source_unchanged': source_before == source_after,
                       'acceptance_failures': acceptance_failures,
                       'server_samples': samples, 'server_health': health, 'prediction_clients': prediction, 'client_fps': client_fps or '60', 'authored_gameplay': registry is not None, 'scenario_progression_tree_version': registry.get('progression_tree_version') if registry else None, 'scenario_content_digest': registry.get('content_digest') if registry else None, 'conditions': {'rtt_ms': rtt_ms, 'jitter_ms': jitter_ms, 'loss': loss},
                       'proxy_metrics': [proxy.stats for proxy in proxies],
                       'server_peak_rss_kib': max((s['rss_kib'] for s in samples if 'rss_kib' in s), default=None),
                       'server_peak_cpu_percent': max((s['cpu_percent'] for s in samples if 'cpu_percent' in s), default=None),
                       'elapsed_seconds': round(time.monotonic() - sample_start, 2), 'results': results,
                       'server_errors': list(dict.fromkeys(line for line in server_log.read_text().splitlines() if 'ERROR' in line)),
                       'server_error_counts': dict(Counter(line for line in server_log.read_text().splitlines() if 'ERROR' in line))}
            evidence = ROOT / 'output/verification/network-process-latest.json'
            evidence.parent.mkdir(parents=True, exist_ok=True)
            evidence.write_text(json.dumps(outcome, indent=2) + '\n')
            matrix_path = evidence.parent / 'network-integration-current.json'
            matrix = json.loads(matrix_path.read_text()) if matrix_path.exists() else {}
            category = f'authored-{clients}' if registry else f'prediction-{clients}' if prediction else f'transport-{clients}'
            matrix[category] = outcome
            matrix_path.write_text(json.dumps(matrix, indent=2) + '\n')
            print(json.dumps({"passed": outcome["passed"], "clients": clients, "elapsed_seconds": outcome.get("elapsed_seconds"), "evidence": str(evidence), "acceptance_failures": outcome.get("acceptance_failures", []), "error": outcome.get("error")}), flush=True)
            return outcome
        except Exception as error:
            outcome = {'passed': False, 'clients': clients, 'requested_client_seconds': duration,
                       'authored_gameplay': registry is not None, 'prediction_clients': prediction,
                       'error': str(error),
                       'process_logs': {log.parent.name: log.read_text()[-12000:] for _, _, log in processes}}
            evidence = ROOT / 'output/verification/network-process-latest.json'
            evidence.parent.mkdir(parents=True, exist_ok=True)
            evidence.write_text(json.dumps(outcome, indent=2) + '\n')
            print(json.dumps({"passed": outcome["passed"], "clients": clients, "elapsed_seconds": outcome.get("elapsed_seconds"), "evidence": str(evidence), "acceptance_failures": outcome.get("acceptance_failures", []), "error": outcome.get("error")}), flush=True)
            return outcome
        finally:
            if state_file:
                Path(state_file).unlink(missing_ok=True)
            for proxy in proxies:
                proxy.close()
            for process, stream, _ in reversed(processes):
                if process.poll() is None:
                    process.terminate()
                    try: process.wait(timeout=5)
                    except subprocess.TimeoutExpired: process.kill(); process.wait()
                stream.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--clients', type=int, choices=[2, 8], required=True)
    parser.add_argument('--seconds', type=int, default=12)
    parser.add_argument('--external-port', type=int)
    parser.add_argument('--password-file')
    parser.add_argument('--rtt-ms', type=int, default=0)
    parser.add_argument('--jitter-ms', type=int, default=0)
    parser.add_argument('--loss', type=float, default=0)
    parser.add_argument('--gameplay', action='store_true')
    parser.add_argument('--scenario-registry')
    parser.add_argument('--prediction', action='store_true')
    parser.add_argument('--client-fps', default='')
    parser.add_argument('--state-file', type=Path, help='Ephemeral process IDs and ready path for external profiling; removed on exit')
    args = parser.parse_args()
    if args.prediction and args.clients > 2:
        parser.error('Actual main prediction probes are bounded to two clients on this workstation')
    result = scenario(args.godot, args.clients, args.seconds, args.external_port, args.password_file, args.rtt_ms, args.jitter_ms, args.loss, args.gameplay, args.scenario_registry, args.prediction, args.client_fps, args.state_file)
    raise SystemExit(0 if result['passed'] else 1)


if __name__ == '__main__':
    main()
