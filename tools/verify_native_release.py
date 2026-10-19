"""Native CI acceptance; uses disposable userdata and never publishes releases."""
import json
from pathlib import Path
import platform
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
VOICE = tuple('voice/' + name + '_checks.gd' for name in (
    'voice', 'voice_udp', 'voice_playback',
    'voice_device', 'voice_text_focus'))
SOURCE = (
    'network/wr_storage_codec_checks.gd', 'network/wr_snapshot_codec_checks.gd',
    'network/wr_store_worker_checks.gd', 'network/wr_native_session_checks.gd',
    'network/wr_store_lock_checks.gd',
    'network/wr_actor_parity_checks.gd', 'network/wr_floor_runtime_checks.gd',
    'network/wr_online_input_checks.gd',
    'network/wr_transaction_checks.gd', 'network/wr_client_hurt_checks.gd',
    'network/wr_progression_migration_checks.gd',
    'world_rise_progression_fixture.gd', 'world_rise_practice_checks.gd',
    'wr_third_person_checks.gd', 'blood_feedback_checks.gd',
    'wr_body_grip_checks.gd', 'wr_wrist_regression_checks.gd',
)


def voice_transport(engine, exported=False):
    """The transport fixture requires a server plus two actual client processes."""
    from runtime_paths import isolated_environment
    jobs = []
    summaries = []
    started = time.monotonic()
    with tempfile.TemporaryDirectory(prefix='wr-native-voice-') as temporary:
        root = Path(temporary)
        try:
            def spawn(name, server=False):
                folder = root / name
                folder.mkdir()
                log = folder / 'process.log'
                stream = log.open('w', encoding='utf-8')
                env = isolated_environment(folder / 'userdata')
                env['WORLD_RISE_DURABLE_HELPER'] = str(ROOT / 'tools/network/durable_replace.py')
                env['WORLD_RISE_PYTHON'] = sys.executable
                args = [str(engine), '--headless']
                if not exported:
                    args += ['--path', str(ROOT / 'game')]
                args += ['--script', 'res://scripts/voice/voice_transport_checks.gd', '--',
                         '--peers', '2', '--port', '25483']
                if server:
                    args.append('--server')
                process = subprocess.Popen(args, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, env=env)
                jobs.append((process, stream, log))
                return process, folder

            server, server_folder = spawn('server', True)
            deadline = time.monotonic() + 20
            while time.monotonic() < deadline and server.poll() is None:
                if any(server_folder.rglob('ready.json')):
                    break
                time.sleep(.1)
            else:
                raise RuntimeError('Native voice server did not establish readiness')
            spawn('client-one')
            spawn('client-two')
            deadline = time.monotonic() + 35
            while time.monotonic() < deadline and any(p.poll() is None for p, _, _ in jobs):
                time.sleep(.1)
            for process, stream, log in jobs:
                stream.flush()
                output = log.read_text(encoding='utf-8', errors='replace')
                marker = 'VOICE TRANSPORT SERVER PASS' if log.parent.name == 'server' else 'VOICE TRANSPORT PASS'
                if process.poll() != 0 or marker not in output or any(line.startswith(('ERROR:', 'SCRIPT ERROR:')) for line in output.splitlines()):
                    raise RuntimeError('Native voice transport failed: ' + log.parent.name)
                summaries.extend(line for line in output.splitlines() if line.startswith('VOICE TRANSPORT'))
            return {'kind': 'exported-release' if exported else 'source', 'script': 'voice/voice_transport_checks.gd',
                    'passed': True, 'peers': 2, 'seconds': round(time.monotonic() - started, 3), 'summary': summaries}
        except Exception:
            retained = ROOT / 'output/verification' / ('native-export-voice-transport.log' if exported else 'native-source-voice-transport.log')
            retained.parent.mkdir(parents=True, exist_ok=True)
            for process, _, _ in jobs:
                if process.poll() is None:
                    process.terminate()
            for process, _, _ in jobs:
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            retained.write_text('\n'.join(log.parent.name + '\n' + log.read_text(encoding='utf-8', errors='replace') for _, _, log in jobs))
            raise
        finally:
            for process, stream, _ in reversed(jobs):
                if process.poll() is None:
                    process.kill()
                    process.wait()
                stream.close()


def main():
    from platform_cli import GAME, import_game, package_fingerprints, run_process, toolchain, validate, write
    from client_export import export_client
    from server_export import export_server
    started = time.monotonic()
    report = {'host': platform.platform(), 'machine': platform.machine(),
              'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'passed': False, 'checks': [], 'scope': 'Native automated fixtures; physical microphone/listening, GPU play and notarization are separate acceptance.'}
    report['platform_exclusions'] = ['voice_native_checks.gd loads the macOS-only capture extension; verify separately on macOS.']
    destination = ROOT / 'output/verification/native-release-current.json'
    try:
        validate()
        import_game()
        engine = toolchain(('godot',))['godot']
        fingerprint = package_fingerprints()
        for script in (*SOURCE, *VOICE):
            output = run_process([engine, '--headless', '--path', str(GAME), '--script', 'res://scripts/' + script],
                                 timeout=240, log='native-source-' + Path(script).stem + '.log', isolated=True)
            report['checks'].append({'kind': 'source', 'script': script, 'passed': True,
                                     'summary': [line for line in output.splitlines() if any(word in line for word in ('CHECKS', 'PASS', 'RESULT', 'VERIFICATION_'))][-4:]})
        report['checks'].append(voice_transport(engine))
        run_process([sys.executable, 'tools/verify_network_progression_hop.py', '--godot', engine], timeout=300,
                    log='native-progression-hop.log', isolated=True)
        hop = json.loads((destination.parent / 'network-progression-hop-current.json').read_text())
        report['checks'].append({'kind': 'source-real-enet', 'script': 'verify_network_progression_hop.py',
                                 'passed': bool(hop.get('passed')), 'topology': hop.get('topology'),
                                 'exits': hop.get('exits'), 'source_unchanged': hop.get('source_unchanged')})
        if not hop.get('passed'):
            raise RuntimeError('Real progression A-B-A hop report did not pass')
        run_process([sys.executable, 'tools/verify_blood_online.py', '--godot', engine], timeout=300,
                    log='native-blood-online.log', isolated=True)
        blood = json.loads((destination.parent / 'blood-online-current.json').read_text())
        report['checks'].append({'kind': 'source-real-enet-main', 'script': 'verify_blood_online.py',
                                 'passed': bool(blood.get('passed')), 'topology': blood.get('topology'),
                                 'client_exit': blood.get('client_exit'),
                                 'checks': len((blood.get('result') or {}).get('checks', []))})
        if not blood.get('passed'):
            raise RuntimeError('Real online Main blood report did not pass')
        run_process([sys.executable, 'tools/test_hosting.py'], log='native-hosting-python.log', isolated=True)
        run_process([sys.executable, 'tools/network/verify_world_lock.py'], log='native-writer-lock-python.log', isolated=True)
        run_process([sys.executable, 'tools/test_release_downloads.py'], log='native-release-bundle-python.log', isolated=True)
        if sys.platform == 'win32':
            package = export_client('windows')
        elif sys.platform == 'linux':
            folder = export_server()
            package = folder / 'world-rise-server.x86_64'
        else:
            raise ValueError('This CI gate targets native Windows and Linux only')
        exported = (*VOICE, 'network/wr_storage_codec_checks.gd', 'network/wr_native_session_checks.gd',
                    'network/wr_progression_migration_checks.gd', 'network/wr_transaction_checks.gd',
                    'network/wr_store_worker_checks.gd', 'network/wr_store_lock_checks.gd')
        if sys.platform == 'win32':
            exported += ('world_rise_progression_fixture.gd', 'world_rise_practice_checks.gd',
                         'wr_third_person_checks.gd', 'blood_feedback_checks.gd',
                         'wr_body_grip_checks.gd', 'wr_wrist_regression_checks.gd',
                         'network/wr_client_hurt_checks.gd', 'network/wr_actor_parity_checks.gd',
                         'network/wr_export_title_checks.gd')
        for script in exported:
            output = run_process([str(package), '--headless', '--script', 'res://scripts/' + script], timeout=240,
                        log='native-export-' + Path(script).stem + '.log', isolated=True)
            report['checks'].append({'kind': 'exported-release', 'script': script, 'passed': True,
                                     'summary': [line for line in output.splitlines() if any(word in line for word in ('CHECKS', 'PASS', 'RESULT', 'VERIFICATION_'))][-4:]})
        if sys.platform == 'win32':
            output = run_process([str(package), '--headless', '--script', 'res://scripts/world_rise_ui_checks.gd',
                                  '--', '--exported-host-gate'], timeout=240,
                                 log='native-export-host-gate.log', isolated=True)
            report['checks'].append({'kind': 'exported-release', 'script': 'world_rise_ui_checks.gd --exported-host-gate',
                                     'passed': True, 'summary': [line for line in output.splitlines() if 'CHECKS' in line or 'PASS' in line][-4:]})
        report['checks'].append(voice_transport(package, exported=True))
        # Prove the release-template assertions execute and can fail, rather
        # than accepting stripped assert() calls as passing voice coverage.
        try:
            run_process([str(package), '--headless', '--script', 'res://scripts/voice/voice_checks.gd',
                         '--', '--voice-fixture-force-failure'], log='native-export-negative-control.log', isolated=True)
        except RuntimeError:
            negative = json.loads((destination.parent / 'native-export-negative-control.result.json').read_text())
            failure_log = (destination.parent / 'native-export-negative-control.log').read_text()
            if negative['passed'] or 'VOICE FIXTURE FAIL' not in failure_log:
                raise RuntimeError('Negative control did not reach the always-active voice check')
            report['checks'].append({'kind': 'exported-negative-control', 'passed': True})
        else:
            raise RuntimeError('Exported voice negative control did not fail')
        if sys.platform == 'linux':
            # Native x86_64 source host: functional/load evidence, not a
            # universal hardware performance guarantee or Docker evidence.
            run_process([sys.executable, 'tools/verify_network_processes.py', '--godot', engine,
                         '--clients', '8', '--seconds', '45', '--gameplay'], timeout=240,
                        log='native-linux-eight-player.log', isolated=True)
            from network.summarize_performance import summarize
            report['native_linux_load'] = summarize(json.loads((destination.parent / 'network-process-latest.json').read_text()))
            report['checks'].append({'kind': 'native-linux-eight-player-source', 'passed': True})
        if fingerprint != package_fingerprints():
            raise RuntimeError('Runtime sources changed during native verification')
        report.update(passed=True, runtime_source=fingerprint)
    except Exception as error:
        report['error'] = str(error)
        raise
    finally:
        report['seconds'] = round(time.monotonic() - started, 3)
        write(destination, report)
        print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
