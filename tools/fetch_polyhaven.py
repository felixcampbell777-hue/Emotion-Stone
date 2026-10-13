"""Fetch verified data files from the official Poly Haven API (CC0)."""
import concurrent.futures
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art/environment/source/polyhaven_cc0'
ASSETS = ROOT / 'game/assets/environment/polyhaven_cc0'
MODELS = ['fir_tree_01', 'fir_sapling', 'rock_moss_set_01', 'fern_02', 'tree_stump_01', 'grass_medium_01']
SURFACES = ['forest_ground_04', 'rocky_trail', 'cobblestone_floor_08', 'pine_bark', 'brown_planks_05', 'forest_leaves_02', 'leafy_grass']

def fetch_file(job):
    path, info = job
    if not info['url'].startswith('https://dl.polyhaven.org/file/ph-assets/'):
        raise ValueError('Untrusted asset host')
    if path.suffix.lower() not in {'.gltf', '.bin', '.jpg', '.png'}:
        raise ValueError('Non-data asset rejected')
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists() or hashlib.md5(path.read_bytes()).hexdigest() != info['md5']:
        if "'" in info['url'] or "'" in str(path):
            raise ValueError('Invalid quoted path')
        subprocess.run(['powershell', '-NoProfile', '-Command',
                        "Invoke-WebRequest -Uri '" + info['url'] + "' -OutFile '" + str(path) + "' -TimeoutSec 180"], check=True, capture_output=True)
    if hashlib.md5(path.read_bytes()).hexdigest() != info['md5']:
        raise ValueError('Asset checksum mismatch: ' + str(path))
    return {'path': str(path.relative_to(SOURCE)), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'url': info['url']}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--group', choices=['all', 'textures', 'small'], default='all')
    args = parser.parse_args()
    SOURCE.mkdir(parents=True, exist_ok=True)
    manifest = []
    selected = SURFACES if args.group == 'textures' else MODELS[1:] if args.group == 'small' else MODELS + SURFACES
    for asset in selected:
        metadata = json.loads((ROOT / 'art/environment' / (asset + '-files.json')).read_text(encoding='utf-8-sig'))
        (SOURCE / (asset + '-files.json')).write_text(json.dumps(metadata, indent=2))
        jobs = []
        if asset in MODELS:
            scene = metadata['gltf']['2k' if asset in ['fir_sapling', 'rock_moss_set_01'] else '1k']['gltf']
            jobs.append((SOURCE / asset / Path(scene['url']).name, scene))
            for name, info in scene['include'].items():
                if '..' in Path(name).parts or Path(name).is_absolute():
                    raise ValueError('Unsafe asset path')
                jobs.append((SOURCE / asset / name, info))
        else:
            for kind, name in [('Diffuse', 'albedo'), ('nor_gl', 'normal'), ('Rough', 'roughness')]:
                info = metadata[kind]['2k']['jpg']
                jobs.append((SOURCE / asset / (name + '.jpg'), info))
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            records = list(pool.map(fetch_file, jobs))
        manifest.append({'asset': asset, 'source': 'https://polyhaven.com/a/' + asset,
                         'licence': 'CC0-1.0', 'files': records})
        if asset in SURFACES:
            shutil.copytree(SOURCE / asset, ASSETS / asset, dirs_exist_ok=True)
        print('VERIFIED_CC0', asset, sum(path.stat().st_size for path, _ in jobs), flush=True)
    (SOURCE / ('intake-' + args.group + '.json')).write_text(json.dumps(manifest, indent=2) + '\n')
    (SOURCE / 'LICENSE.txt').write_text('Poly Haven assets are CC0 1.0. https://polyhaven.com/license\n')
    print('INTAKE_COMPLETE', flush=True)

if __name__ == '__main__':
    main()
