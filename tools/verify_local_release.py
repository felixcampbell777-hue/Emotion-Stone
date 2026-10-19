"""Inspect real Mac packages and optional disposable packaged-client/Docker sessions."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import time

from prepare_release_downloads import sha, verified_package, progression_contract
from runtime_paths import isolated_environment

ROOT = Path(__file__).resolve().parents[1]


def command(args, timeout=120, env=None, expected=0):
    result = subprocess.run(args, cwd=ROOT, env=env, capture_output=True, text=True,
                            encoding='utf-8', errors='replace', timeout=timeout)
    if result.returncode != expected:
        raise RuntimeError('Command failed: ' + str(args[0]) + '\n' + (result.stdout + result.stderr)[-10000:])
    return result


def fixture(executable, script, args=(), native=False, expect_failure=False):
    with tempfile.TemporaryDirectory(prefix='wr-installed-gate-') as temporary:
        env = isolated_environment(Path(temporary) / 'userdata')
        env['WORLD_RISE_PYTHON'] = sys.executable
        result = subprocess.run([str(executable), *([] if native else ['--headless']), '--script', 'res://scripts/' + script,
                                 *(['--', *args] if args else [])], cwd=temporary, env=env,
                                capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=120)
        output = result.stdout + result.stderr
        if expect_failure:
            passed = result.returncode != 0 and 'VOICE FIXTURE FAIL' in output
        else:
            passed = result.returncode == 0 and not any(line.startswith(('ERROR:', 'SCRIPT ERROR:')) for line in output.splitlines())
        record = {'script': script, 'native': native, 'expected_failure': expect_failure,
                  'passed': passed, 'exit': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr}
        if not passed:
            raise RuntimeError(json.dumps(record))
        return record


def clients(executable, scratch, password, port, voice=False, returning=False):
    expected_tree = progression_contract()['tree_version']
    jobs = []
    try:
        for index in range(2):
            folder = scratch / (('voice-' if voice else 'player-') + str(index))
            folder.mkdir(exist_ok=True)
            env = isolated_environment(folder / 'userdata')
            env['WORLD_RISE_PYTHON'] = sys.executable
            log = folder / 'process.log'
            stream = log.open('w', encoding='utf-8')
            if voice:
                arguments = ['--script', 'res://scripts/voice/voice_transport_checks.gd', '--',
                             '--peers', '2', '--port', str(port), '--password-file', str(password)]
            else:
                profile = folder / 'checkpoint/portable.json'
                arguments = ['--script', 'res://scripts/network/wr_process_probe.gd', '--',
                             '--port=' + str(port), '--seconds=10', '--expected=2',
                             '--checkpoint=' + str(profile), '--password-file=' + str(password), '--role=baseline']
                if returning and not profile.is_file():
                    raise RuntimeError('Returning client checkpoint is missing')
            process = subprocess.Popen([str(executable), '--headless', *arguments], cwd=folder,
                                       env=env, stdout=stream, stderr=subprocess.STDOUT)
            jobs.append((process, stream, log))
        deadline = time.monotonic() + 75
        while any(p.poll() is None for p, _, _ in jobs) and time.monotonic() < deadline:
            time.sleep(.1)
        reports = []
        for process, stream, log in jobs:
            stream.flush()
            output = log.read_text(encoding='utf-8', errors='replace')
            errors = [line for line in output.splitlines() if line.startswith(('ERROR:', 'SCRIPT ERROR:'))]
            if voice:
                parsed = [line for line in output.splitlines() if line.startswith('VOICE TRANSPORT PASS')]
                valid = bool(parsed)
            else:
                parsed = [json.loads(line.removeprefix('PROBE_RESULT ')) for line in output.splitlines() if line.startswith('PROBE_RESULT ')]
                valid = bool(parsed and parsed[-1].get('hash_roundtrip_stable') and parsed[-1].get('departed') and parsed[-1].get('progression_tree_version') == expected_tree)
            if process.poll() != 0 or errors or not valid:
                raise RuntimeError('Packaged client failed: ' + log.parent.name + '\n' + output[-12000:])
            reports.append({'exit': process.returncode, 'passed': True, 'result': parsed[-1]})
        return reports
    finally:
        for process, stream, _ in reversed(jobs):
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill(); process.wait()
            stream.close()


def docker_smoke(executable, version, report=None):
    project = 'wr-hosting-fixture-release' + version.replace('.', '')
    if command(['docker', 'ps', '-aq', '--filter', 'label=com.docker.compose.project=' + project]).stdout.strip() or command(['docker', 'volume', 'ls', '-q', '--filter', 'label=com.docker.compose.project=' + project]).stdout.strip():
        raise RuntimeError('Refusing to reuse existing fixture containers/volumes')
    report = report if report is not None else {}
    report['scope'] = 'Current packaged Mac embedded-PCK clients and Linux Docker export; amd64 emulation on Apple arm64, not native Linux performance.'
    with tempfile.TemporaryDirectory(prefix='wr-packaged-docker-') as temporary:
        scratch = Path(temporary)
        password = scratch / 'server_password'
        import secrets
        password.write_text(secrets.token_urlsafe(32) + '\n')
        password.chmod(0o600)
        override = scratch / 'override.json'
        override.write_text(json.dumps({'secrets': {'server_password': {'file': str(password)}}}))
        env = dict(os.environ, WORLD_RISE_PORT='24891', WORLD_RISE_VOICE_PORT='24892', WORLD_RISE_BIND_ADDRESS='127.0.0.1')
        compose = ['docker', 'compose', '-p', project, '-f', 'hosting/compose.yaml', '-f', str(override)]
        def run(args, timeout=120, expected=0):
            return command([*compose, *args], timeout=timeout, env=env, expected=expected)
        def ready(players=None):
            deadline = time.monotonic() + 45
            last = ''
            while time.monotonic() < deadline:
                result = subprocess.run([*compose, 'exec', '-T', 'world-rise', 'cat', '/data/ready.json'], cwd=ROOT, env=env, capture_output=True, text=True, timeout=10)
                last = result.stdout
                try:
                    status = json.loads(last)
                    if status.get('ready') and status.get('voice_ready') and not status.get('storage_error') and (players is None or status.get('players') == players):
                        return status
                except ValueError:
                    pass
                time.sleep(.2)
            raise RuntimeError('Docker readiness deadline exceeded: ' + last)
        try:
            run(['build'], timeout=600)
            run(['run', '--rm', '--no-deps', '--entrypoint', 'python3', 'world-rise', '-c',
                 'from pathlib import Path; import os; assert os.geteuid()==10001; assert Path("/run/secrets/server_password").read_bytes().strip()'])
            report['secret_readable_by_service_uid'] = True
            run(['up', '-d'], timeout=120)
            report['initial_health'] = ready(0)
            identifier = run(['ps', '-q', 'world-rise']).stdout.strip()
            configuration = json.loads(command(['docker', 'inspect', identifier]).stdout)[0]
            report['image_id'] = configuration['Image']
            report['limits'] = {'memory_bytes': configuration['HostConfig']['Memory'],
                                'nano_cpus': configuration['HostConfig']['NanoCpus'],
                                'read_only': configuration['HostConfig']['ReadonlyRootfs'],
                                'user': configuration['Config']['User']}
            report['guards'] = []
            for script, negative in [('voice/voice_udp_checks.gd', False), ('voice/voice_checks.gd', False),
                                     ('network/wr_session_teardown_checks.gd', False), ('network/wr_session_reuse_checks.gd', False),
                                     ('voice/voice_udp_checks.gd', True)]:
                result = run(['run', '--rm', '--no-deps', '--entrypoint', '/app/world-rise-server.x86_64', 'world-rise',
                              '--headless', '--script', 'res://scripts/' + script,
                              *(['--', '--voice-fixture-force-failure'] if negative else [])], expected=1 if negative else 0)
                text = result.stdout + result.stderr
                if negative and 'VOICE FIXTURE FAIL' not in text:
                    raise RuntimeError('Linux exported negative control did not reach active checks')
                if not negative and any(line.startswith(('ERROR:', 'SCRIPT ERROR:')) for line in text.splitlines()):
                    raise RuntimeError(text[-10000:])
                report['guards'].append({'script': script, 'expected_failure': negative, 'expected_outcome_met': True, 'stdout': result.stdout, 'stderr': result.stderr})
            # Reuse the exact strict native-CI transport harness against the
            # embedded Linux export, including its actual Session teardown.
            support = scratch / 'transport-harness'
            support.mkdir(mode=0o755)
            for name in ('verify_native_release.py', 'verify_network_progression_hop.py', 'runtime_paths.py'):
                shutil.copy2(ROOT / 'tools' / name, support / name)
            transport_code = """import sys,json
from pathlib import Path
sys.path.insert(0,'/fixture-tools')
import verify_native_release as gate
gate.ROOT=Path('/tmp/transport-root')
gate.ROOT.mkdir()
try:
    print(json.dumps(gate.voice_transport(Path('/app/world-rise-server.x86_64'),exported=True)))
except Exception:
    for retained in gate.ROOT.glob('output/verification/*.log'):
        print(retained.read_text(),flush=True)
    raise
"""
            retained = ROOT / 'output/verification/local-export-voice-transport.log'
            try:
                transport = subprocess.run([*compose, 'run', '--rm', '--no-deps', '--volume', str(support) + ':/fixture-tools:ro',
                                            '--entrypoint', 'python3', 'world-rise', '-c', transport_code],
                                           cwd=ROOT, env=env, capture_output=True, text=True, timeout=120)
            except subprocess.TimeoutExpired as error:
                def captured(value):
                    return value.decode('utf-8', 'replace') if isinstance(value, bytes) else value or ''
                retained.write_text(captured(error.stdout) + captured(error.stderr) + '\nTransport exceeded120s outer deadline.\n')
                raise RuntimeError('Exported Linux voice transport timed out; see ' + str(retained)) from error
            if transport.returncode:
                retained.write_text(transport.stdout + transport.stderr)
                raise RuntimeError('Exported Linux voice transport failed; see ' + str(retained))
            report['exported_voice_transport'] = json.loads(transport.stdout.splitlines()[-1])
            hop_code = ("import sys,json; sys.path.insert(0,'/fixture-tools'); import verify_network_progression_hop as hop; "
                        "result=hop.scenario('/app/world-rise-server.x86_64',25091,25093,exported=True); "
                        "print(json.dumps(result)); sys.exit(0 if result['passed'] else 1)")
            hop = subprocess.run([*compose, 'run', '--rm', '--no-deps', '--volume', str(support) + ':/fixture-tools:ro',
                                  '--entrypoint', 'python3', 'world-rise', '-c', hop_code],
                                 cwd=ROOT, env=env, capture_output=True, text=True, timeout=300)
            hop_log = ROOT / 'output/verification/local-export-progression-hop.log'
            if hop.returncode:
                hop_log.write_text(hop.stdout + hop.stderr)
                raise RuntimeError('Embedded export same-Session rejoin failed; see ' + str(hop_log))
            report['exported_progression_hop'] = json.loads(hop.stdout.splitlines()[-1])
            report['packaged_voice_clients'] = clients(executable, scratch, password, 24891, voice=True)
            print('LOCAL_RELEASE_DOCKER_VOICE_PASS', flush=True)
            ready(0)
            report['first_clients'] = clients(executable, scratch, password, 24891)
            print('LOCAL_RELEASE_DOCKER_FIRST_CLIENTS_PASS', flush=True)
            ready(0)
            before = json.loads(run(['exec', '-T', 'world-rise', 'python3', '/app/admin.py', 'status']).stdout)
            run(['restart', 'world-rise'])
            ready(0)
            after = json.loads(run(['exec', '-T', 'world-rise', 'python3', '/app/admin.py', 'status']).stdout)
            if before.get('world_id') != after.get('world_id') or not before.get('world_id'):
                raise RuntimeError('Restart changed the durable world identity')
            report['restart_world_id_preserved'] = True
            report['returning_clients'] = clients(executable, scratch, password, 24891, returning=True)
            print('LOCAL_RELEASE_DOCKER_RETURNING_CLIENTS_PASS', flush=True)
            ready(0)
            run(['stop', 'world-rise'])
            stopped = json.loads(command(['docker', 'inspect', identifier]).stdout)[0]['State']
            if stopped['ExitCode'] != 0 or stopped['OOMKilled']:
                raise RuntimeError('Container did not stop cleanly')
            report['graceful_stop'] = {'exit': stopped['ExitCode'], 'oom_killed': stopped['OOMKilled']}
            report['passed'] = True
        finally:
            preserving_failure = sys.exc_info()[0] is not None
            try:
                run(['down', '--volumes', '--remove-orphans'], timeout=120)
                report['cleanup'] = {'containers_remaining': command(['docker', 'ps', '-aq', '--filter', 'label=com.docker.compose.project=' + project]).stdout.split(),
                                     'volumes_remaining': command(['docker', 'volume', 'ls', '-q', '--filter', 'label=com.docker.compose.project=' + project]).stdout.split()}
                if any(report['cleanup'].values()):
                    raise RuntimeError('Fixture resources were not removed')
            except Exception as cleanup_error:
                report['cleanup_error'] = str(cleanup_error)
                if not preserving_failure:
                    raise
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--docker', action='store_true')
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('This local package gate runs on macOS; native Windows/Linux use CI')
    from platform_cli import GAME, package_fingerprints, write
    version = json.loads((GAME / 'content/release.json').read_text())['version']
    current = package_fingerprints()
    report = {'version': version, 'commit': command(['git', 'rev-parse', 'HEAD']).stdout.strip(), 'runtime_source': current, 'passed': False}
    try:
        report['packages'] = {}
        for name, folder in [('macos', ROOT / 'output/clients/macos' / ('v' + version)), ('windows', ROOT / 'output/clients/windows' / ('v' + version)), ('linux', ROOT / 'output/linux-server' / ('v' + version))]:
            verified_package(folder, current, version)
            report['packages'][name] = {'manifest_sha256': sha(folder / 'manifest.json')}
        folder = ROOT / 'output/clients/macos' / ('v' + version)
        expanded = folder / 'probe-expanded'
        if expanded.exists():
            shutil.rmtree(expanded)
        command(['ditto', '-x', '-k', str(folder / 'WorldRise.zip'), str(expanded)])
        apps = list(expanded.glob('*.app'))
        if len(apps) != 1:
            raise RuntimeError('Expected exactly one exported app')
        app = apps[0]
        info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
        if info.get('CFBundleShortVersionString') != version or not info.get('NSMicrophoneUsageDescription'):
            raise RuntimeError('Mac version/microphone usage metadata missing')
        command(['codesign', '--verify', '--deep', '--strict', str(app)])
        executable = app / 'Contents/MacOS' / info['CFBundleExecutable']
        report['macos'] = {'package_sha256': sha(folder / 'WorldRise.zip'), 'codesign_deep_strict': True, 'notarized': False,
                          'fixtures': [fixture(executable, 'network/wr_export_title_checks.gd'),
                                       fixture(executable, 'world_rise_ui_checks.gd', ['--exported-host-gate']),
                                       fixture(executable, 'voice/voice_native_checks.gd', native=True),
                                       fixture(executable, 'voice/voice_checks.gd'),
                                       fixture(executable, 'voice/voice_playback_checks.gd')]}
        print('LOCAL_RELEASE_MAC_PASS', flush=True)
        if args.docker:
            report['docker'] = {}
            docker_smoke(executable, version, report['docker'])
        if current != package_fingerprints():
            raise RuntimeError('Runtime source changed during package acceptance')
        report['source_unchanged'] = True
        report['passed'] = True
    except Exception as error:
        report['error'] = str(error)
        raise
    finally:
        write(ROOT / 'output/verification/local-release-current.json', report)
        print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
