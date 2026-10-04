"""Fetch pinned portable authoring tools into a local cache, never global PATH."""
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
CACHE = Path(os.environ['USERPROFILE']) / '.cache' / 'comic-art-platform'
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
    CACHE.mkdir(parents=True, exist_ok=True)
    release = fetch_json(f'https://api.github.com/repos/godotengine/godot-builds/releases/tags/{GODOT_VERSION}-stable')
    names = [f'Godot_v{GODOT_VERSION}-stable_win64.exe.zip', f'Godot_v{GODOT_VERSION}-stable_export_templates.tpz']
    assets = {asset['name']: asset for asset in release['assets']}
    jobs = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        for name in names:
            asset = assets[name]
            digest = asset.get('digest') or ''
            jobs.append(pool.submit(download, asset['browser_download_url'], name, digest.removeprefix('sha256:') or None))
        blender_name = f'blender-{BLENDER_VERSION}-windows-x64.zip'
        jobs.append(pool.submit(download, f'https://mirrors.ocf.berkeley.edu/blender/release/Blender4.5/{blender_name}', blender_name))
        archives = [job.result() for job in jobs]
    godot_dir = CACHE / f'godot-{GODOT_VERSION}'
    godot_dir.mkdir(exist_ok=True)
    with zipfile.ZipFile(archives[0]) as archive:
        archive.extractall(godot_dir)
    template_dir = CACHE / f'templates-{GODOT_VERSION}'
    template_dir.mkdir(exist_ok=True)
    with zipfile.ZipFile(archives[1]) as archive:
        for name in ['templates/windows_release_x86_64.exe', 'templates/windows_debug_x86_64.exe']:
            archive.extract(name, template_dir)
    blender_dir = CACHE / f'blender-{BLENDER_VERSION}-windows-x64'
    if not (blender_dir / 'blender.exe').exists():
        with zipfile.ZipFile(archives[2]) as archive:
            archive.extractall(CACHE)
    record = {
        'godot_version': GODOT_VERSION,
        'blender_version': BLENDER_VERSION,
        'godot': str(godot_dir / f'Godot_v{GODOT_VERSION}-stable_win64_console.exe'),
        'blender': str(blender_dir / 'blender.exe'),
        'windows_release_template': str(template_dir / 'templates/windows_release_x86_64.exe'),
        'windows_debug_template': str(template_dir / 'templates/windows_debug_x86_64.exe'),
        'archive_sha256': {path.name: sha256(path) for path in archives},
        'blender_download_source': f'https://mirrors.ocf.berkeley.edu/blender/release/Blender4.5/{blender_name}',
    }
    (ROOT / 'tools' / 'toolchain.local.json').write_text(json.dumps(record, indent=2) + '\n')
    subprocess.run([sys.executable,'-m','pip','install','--disable-pip-version-check','--quiet','--target',str(CACHE/'python'),'jsonschema==4.25.1'],check=True)
    print('Portable toolchain ready; paths saved in tools/toolchain.local.json.', flush=True)


if __name__ == '__main__':
    main()
