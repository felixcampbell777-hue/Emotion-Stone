"""Fetch pinned portable authoring tools into a local cache, never global PATH."""
import argparse
import platform
import shutil
import tarfile
import concurrent.futures
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
from runtime_paths import cache_dir
CACHE = cache_dir()
GODOT_VERSION = '4.5.1'
BLENDER_VERSION = '4.5.3'


def fetch_json(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'ComicArtPlatform/1.0'})
    with urllib.request.urlopen(req, timeout=60) as response:
        return json.load(response)


def download(url, filename, expected=None):
    target = CACHE / filename
    if target.exists() and (not expected or sha256(target) == expected):
        print(f'Cached: {filename}', flush=True)
        return target
    partial = target.with_suffix(target.suffix + '.partial')
    print(f'Downloading: {filename}', flush=True)
    req = urllib.request.Request(url, headers={'User-Agent': 'ComicArtPlatform/1.0'})
    with urllib.request.urlopen(req, timeout=120) as response, partial.open('wb') as output:
        while chunk := response.read(4 * 1024 * 1024):
            output.write(chunk)
    if expected and sha256(partial) != expected:
        raise RuntimeError(f'Checksum mismatch: {filename}')
    partial.replace(target)
    print(f'Downloaded: {filename}', flush=True)
    return target


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        while chunk := stream.read(4 * 1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--with-blender', action='store_true', help='Install pinned Blender authoring tools (optional outside Windows)')
    parser.add_argument('--skip-templates', action='store_true', help='Only install the editor, not export templates')
    args = parser.parse_args()
    CACHE.mkdir(parents=True, exist_ok=True)
    release = fetch_json(f'https://api.github.com/repos/godotengine/godot-builds/releases/tags/{GODOT_VERSION}-stable')
    host = 'win64.exe' if sys.platform == 'win32' else 'macos.universal' if sys.platform == 'darwin' else 'linux.arm64' if platform.machine() in ('aarch64', 'arm64') else 'linux.x86_64'
    names = [f'Godot_v{GODOT_VERSION}-stable_{host}.zip']
    if not args.skip_templates:
        names.append(f'Godot_v{GODOT_VERSION}-stable_export_templates.tpz')
    assets = {asset['name']: asset for asset in release['assets']}
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        jobs = []
        for name in names:
            asset = assets[name]
            digest = asset.get('digest') or ''
            jobs.append(pool.submit(download, asset['browser_download_url'], name, digest.removeprefix('sha256:') or None))
        archives = [job.result() for job in jobs]
    godot_dir = CACHE / f'godot-{GODOT_VERSION}-{host}'
    godot_dir.mkdir(exist_ok=True)
    engine = godot_dir / ('Godot.app/Contents/MacOS/Godot' if sys.platform == 'darwin' else f'Godot_v{GODOT_VERSION}-stable_win64_console.exe' if sys.platform == 'win32' else f'Godot_v{GODOT_VERSION}-stable_{host}')
    # Never overwrite a running signed macOS executable in place (AMFI caches its inode).
    if not engine.exists():
        with zipfile.ZipFile(archives[0]) as archive:
            archive.extractall(godot_dir)
    if sys.platform != 'win32':
        engine.chmod(0o755)
    version_check = subprocess.run([str(engine), '--headless', '--version'], capture_output=True, text=True, timeout=30)
    if version_check.returncode or not version_check.stdout.strip().startswith(GODOT_VERSION + '.'):
        hint = ' Check that the tool cache filesystem allows execution (not noexec).' if sys.platform.startswith('linux') else ''
        raise RuntimeError(f'Pinned Godot could not start (exit {version_check.returncode}): ' + (version_check.stdout + version_check.stderr).strip() + hint)
    record_path = ROOT / 'tools' / 'toolchain.local.json'
    record = json.loads(record_path.read_text()) if record_path.exists() else {}
    record.update({'godot_version': GODOT_VERSION, 'godot': str(engine), 'python': sys.executable, 'python_version': platform.python_version()})
    if not args.skip_templates:
        template_dir = CACHE / f'templates-{GODOT_VERSION}'
        template_dir.mkdir(exist_ok=True)
        with zipfile.ZipFile(archives[1]) as archive:
            for name in ['windows_release_x86_64.exe', 'windows_debug_x86_64.exe', 'linux_release.x86_64', 'linux_debug.x86_64', 'macos.zip']:
                archive.extract('templates/' + name, template_dir)
        record['macos_template'] = str(template_dir / 'templates/macos.zip')
        for target in ('windows', 'linux'):
            for mode in ('release', 'debug'):
                name = f'windows_{mode}_x86_64.exe' if target == 'windows' else f'linux_{mode}.x86_64'
                record[f'{target}_{mode}_template'] = str(template_dir / 'templates' / name)
    if args.with_blender or sys.platform == 'win32':
        system = 'windows-x64.zip' if sys.platform == 'win32' else ('macos-arm64.dmg' if platform.machine() == 'arm64' else 'macos-x64.dmg') if sys.platform == 'darwin' else 'linux-x64.tar.xz'
        blender_name = f'blender-{BLENDER_VERSION}-{system}'
        base = 'https://mirrors.ocf.berkeley.edu/blender/release/Blender4.5/'
        with urllib.request.urlopen(base + f'blender-{BLENDER_VERSION}.sha256', timeout=60) as response:
            checksums = dict((line.split()[1].lstrip('*'), line.split()[0]) for line in response.read().decode().splitlines() if line.strip())
        blender_archive = download(base + blender_name, blender_name, checksums[blender_name])
        archives.append(blender_archive)
        blender_dir = CACHE / f'blender-{BLENDER_VERSION}-{system.removesuffix(".zip").removesuffix(".dmg").removesuffix(".tar.xz")}'
        engine_blender = blender_dir / ('Blender.app/Contents/MacOS/Blender' if sys.platform == 'darwin' else 'blender.exe' if sys.platform == 'win32' else 'blender')
        if not engine_blender.exists():
            if sys.platform == 'darwin':
                mount = CACHE / 'blender-install-mount'
                mount.mkdir(exist_ok=True)
                subprocess.run(['hdiutil', 'attach', str(blender_archive), '-nobrowse', '-readonly', '-mountpoint', str(mount)], check=True)
                try:
                    shutil.copytree(mount / 'Blender.app', blender_dir / 'Blender.app', dirs_exist_ok=True)
                finally:
                    subprocess.run(['hdiutil', 'detach', str(mount)], check=True)
            elif sys.platform == 'win32':
                with zipfile.ZipFile(blender_archive) as archive:
                    archive.extractall(CACHE)
            else:
                with tarfile.open(blender_archive) as archive:
                    archive.extractall(CACHE, filter='data')
        record.update({'blender_version': BLENDER_VERSION, 'blender': str(engine_blender), 'blender_download_source': base + blender_name})
    record.setdefault('archive_sha256', {}).update({path.name: sha256(path) for path in archives})
    (ROOT / 'tools' / 'toolchain.local.json').write_text(json.dumps(record, indent=2) + '\n')
    subprocess.run([sys.executable,'-m','pip','install','--disable-pip-version-check','--quiet','--upgrade','--target',str(CACHE/'python'),'--requirement',str(ROOT/'tools/requirements-runtime.txt')],check=True)
    print('Portable toolchain ready; paths saved in tools/toolchain.local.json.', flush=True)


if __name__ == '__main__':
    main()
