"""Assemble verified downloadable game/server bundles; never push or publish."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def progression_contract():
    catalog = json.loads((ROOT / 'game/content/world_rise/skills.json').read_text())
    attributes = [item['id'] for item in catalog['attributes']]
    if attributes != ['strength', 'agility', 'greatsword']:
        raise ValueError('Current World Rise release requires Strength, Agility and Greatsword categories')
    version = catalog['tree_version']
    if type(version) is not int or version < 1:
        raise ValueError('Current progression tree version must be explicit')
    return {'tree_version': version, 'attributes': attributes}


def verified_package(folder, current, version):
    manifest = json.loads((folder / 'manifest.json').read_text())
    if manifest['game_version'] != version or not manifest.get('source_stable_during_export'):
        raise ValueError('Wrong version or unstable export: ' + str(folder))
    if not (manifest.get('content_validated') or manifest.get('validated_content')):
        raise ValueError('Content validation was skipped: ' + str(folder))
    for phase in ('source_before', 'source_after'):
        if any(manifest[phase].get(key) != digest for key, digest in current.items()):
            raise ValueError('Stale runtime fingerprint: ' + str(folder))
    helper = manifest['source_after'].get('durable_helper')
    if helper and helper != sha(ROOT / 'tools/network/durable_replace.py'):
        raise ValueError('Stale durable helper: ' + str(folder))
    paths = [folder / 'manifest.json']
    for name, expected in manifest['files'].items():
        relative = Path(name)
        if relative.is_absolute() or '..' in relative.parts:
            raise ValueError('Unsafe manifest member')
        member = folder / relative
        if member.is_symlink() or not member.is_file() or sha(member) != expected:
            raise ValueError('Package checksum mismatch: ' + name)
        paths.append(member)
    return paths


def archive(destination, files):
    """Stable member ordering/timestamps/modes, with only explicit file inputs."""
    with zipfile.ZipFile(destination, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as output:
        for name, source in sorted(files, key=lambda item: item[0]):
            item = zipfile.ZipInfo(name, (2026, 10, 18, 0, 0, 0))
            item.create_system = 3
            executable = source.suffix in ('.sh', '.x86_64')
            item.external_attr = (0o100755 if executable else 0o100644) << 16
            item.compress_type = zipfile.ZIP_DEFLATED
            with source.open('rb') as incoming, output.open(item, 'w', force_zip64=True) as outgoing:
                shutil.copyfileobj(incoming, outgoing, 1024 * 1024)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native-report', type=Path, action='append', required=True,
                        help='Matching passed native Windows and Linux CI report (repeat twice)')
    args = parser.parse_args()
    from platform_cli import package_fingerprints
    current = package_fingerprints()
    progression = progression_contract()
    version = json.loads((ROOT / 'game/content/release.json').read_text())['version']
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('A semantic release version is required')
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    if subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip():
        raise ValueError('Commit the final source/tooling before assembling immutable release downloads')
    systems = set()
    native = {}
    for path in args.native_report:
        report = json.loads(path.read_text())
        if not report.get('passed') or report.get('commit') != commit or report.get('runtime_source') != current:
            raise ValueError('Native gate must pass on this exact commit/runtime: ' + str(path))
        system = report['host'].split('-')[0]
        systems.add(system)
        native[system] = report
    if not {'Windows', 'Linux'} <= systems:
        raise ValueError('Both native Windows and Linux reports are required')
    mac = ROOT / 'output/clients/macos' / ('v' + version)
    win = ROOT / 'output/clients/windows' / ('v' + version)
    server = ROOT / 'output/linux-server' / ('v' + version)
    macfiles = verified_package(mac, current, version)
    winfiles = verified_package(win, current, version)
    serverfiles = verified_package(server, current, version)
    if not (mac / 'WorldRise.zip') in macfiles or not (win / 'WorldRise.exe') in winfiles:
        raise ValueError('Required client executable/archive missing')
    if not (server / 'world-rise-server.x86_64') in serverfiles:
        raise ValueError('Required server executable missing')
    for system, folder, binary in [('Windows', win, win / 'WorldRise.exe'),
                                   ('Linux', server, server / 'world-rise-server.x86_64')]:
        proof = native[system].get('exported_package', {})
        if proof.get('manifest_sha256') != sha(folder / 'manifest.json') or proof.get('binary_sha256') != sha(binary):
            raise ValueError('Download must be the exact native-tested artifact: ' + system)
    local = json.loads((ROOT / 'output/verification/local-release-current.json').read_text())
    if not local.get('passed') or not local.get('source_unchanged') or local.get('commit') != commit or local.get('runtime_source') != current:
        raise ValueError('Current exact-commit Mac/Docker package acceptance is required')
    for name, folder in [('macos', mac), ('windows', win), ('linux', server)]:
        if local.get('packages', {}).get(name, {}).get('manifest_sha256') != sha(folder / 'manifest.json'):
            raise ValueError('Package changed after local acceptance: ' + name)
    if local.get('macos', {}).get('package_sha256') != sha(mac / 'WorldRise.zip') or not local.get('docker', {}).get('passed'):
        raise ValueError('Actual Mac and Docker package guards must pass')

    if f'SERVER_VERSION: {version}' not in (ROOT / 'hosting/compose.yaml').read_text():
        raise ValueError('Compose build version must match release')
    destination = ROOT / 'output/releases' / ('v' + version)
    if destination.exists():
        raise ValueError('Refusing to replace an existing release bundle: ' + str(destination))
    game = destination / 'game'
    host = destination / 'server'
    game.mkdir(parents=True)
    host.mkdir()
    shutil.copy2(mac / 'WorldRise.zip', game / f'WorldRise-macOS-v{version}.zip')
    archive(game / f'WorldRise-Windows-x86_64-v{version}.zip',
            [(p.relative_to(win).as_posix(), p) for p in winfiles])
    hosting_names = ('Dockerfile', 'compose.yaml', 'supervise.py', 'admin.py', 'backup.py', 'README.md')
    support = [(f'hosting/{name}', ROOT / 'hosting' / name) for name in hosting_names]
    support.append(('.dockerignore', ROOT / '.dockerignore'))
    support += [(f'docs/{name}', ROOT / 'docs' / name) for name in ('DEDICATED-SERVER.md', 'PORTABLE-TOOLS.md')]
    support += [('tools/measure_hosting.py', ROOT / 'tools/measure_hosting.py')]
    server_readme = host / 'README.txt'
    server_readme.write_text(f'''World Rise dedicated server v{version} — Linux x86_64

This download includes the ready-to-run server and its Docker build inputs.
Install Docker Engine with Compose on a native Linux x86_64 host. Extract the
ZIP into a fresh folder, open that folder, and run:

  mkdir -p hosting/secrets
  python3 -c 'import secrets; from pathlib import Path; p=Path("hosting/secrets/server_password"); p.exists() or p.write_text(secrets.token_urlsafe(32)+"\\n"); p.chmod(0o600)'
  sudo chown 10001:10001 hosting/secrets/server_password
  docker compose -f hosting/compose.yaml build
  docker compose -f hosting/compose.yaml up -d
  docker compose -f hosting/compose.yaml ps

Do not run the source build/bootstrap commands in docs: the exported server is
already included. No Godot editor, Blender, Git LFS or full source clone is
needed to host this download. Docker downloads the pinned Python base image.

The default binds game UDP 24571 and authenticated voice UDP 24572 to loopback.
Set WORLD_RISE_BIND_ADDRESS to your trusted private VPN/LAN interface address
before starting remote play. Allow both ports on that interface and share the
membership password out of band. Clients need the separate game download.
This version requires a trusted private VPN for remote use; public encrypted
transport is not implemented. Linux ARM64 is not a supported server target.

See docs/DEDICATED-SERVER.md for administration, backup/restore and shutdown.
Keep hosting/secrets and the persistent data volume private. Stop cleanly
before backup. Keep the previous image and a pre-upgrade backup when upgrading.
''')
    support.append(('README.txt', server_readme))
    archive(host / f'WorldRise-Server-Linux-x86_64-v{version}.zip',
            [(f'output/linux-server/v{version}/' + p.relative_to(server).as_posix(), p) for p in serverfiles] + support)
    (game / 'README.txt').write_text(f'''World Rise game v{version}

Windows: extract the Windows ZIP fully and open WorldRise.exe. Keep its DLLs
and third-party-notices folder with it. macOS: extract the macOS ZIP and open
the app. This macOS prerelease is ad-hoc signed and is not notarized; macOS
may block launch until you explicitly allow it in Privacy & Security.

World Rise — Floor 1 is selected on the title screen. Choose Start New Game
for offline play, or use the connection screen for a compatible dedicated server. Clients
need no Docker. The game and server use the same version/content protocol.

I opens inventory, P opens Level Up, Escape closes overlays before pausing.
Read the in-game settings and controls for camera, combat and voice options.
Online overlays stop local input while the shared world continues running.

Windows GPU/device play and real microphone/listening still require human
acceptance. Native automated headless checks are recorded in the manifest.
''')
    limits = ['Windows GPU/device play and real microphone/listening remain human acceptance.',
              'macOS is ad-hoc signed and not notarized.',
              'Dedicated hosting requires a trusted private VPN; public encrypted transport is unsupported.',
              'Native CI load measurements describe that host only; uniform 60Hz is not guaranteed.']
    for folder, tag in ((game, 'v' + version), (host, 'server-v' + version)):
        record = {'version': version, 'tag': tag, 'commit': commit, 'runtime_source': current,
                  'native_gates': [json.loads(p.read_text()) for p in args.native_report],
                  'progression_contract': progression,
                  'distribution': 'prerelease', 'remaining_acceptance': limits}
        (folder / 'RELEASE-MANIFEST.json').write_text(json.dumps(record, indent=2) + '\n')
        members = sorted(p for p in folder.iterdir() if p.is_file())
        (folder / 'SHA256SUMS.txt').write_text(''.join(f'{sha(p)}  {p.name}\n' for p in members))
    print(destination)


if __name__ == '__main__':
    main()
