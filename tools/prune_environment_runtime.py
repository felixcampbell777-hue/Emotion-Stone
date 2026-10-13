"""Keep selected runtime assets; preserve complete licensed source kits separately."""
from pathlib import Path
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
ASSETS = (ROOT / 'game/assets/environment').resolve()
SOURCE = ROOT / 'art/environment/source/quaternius_medieval_village_cc0'
KIT = ASSETS / 'quaternius_medieval_village_cc0'
selected = ['glTF/Roof_RoundTiles_4x4.gltf', 'glTF/Wall_UnevenBrick_Straight.gltf']
keep = set(selected)
for file in selected:
    source = SOURCE / file
    document = json.loads(source.read_text(encoding='utf-8-sig'))
    for entry in document.get('images', []) + document.get('buffers', []):
        if 'uri' in entry and not entry['uri'].startswith('data:'):
            path = (source.parent / entry['uri']).resolve()
            keep.add(path.relative_to(SOURCE.resolve()).as_posix())
for name in ['Plaster', 'UnevenBrick']:
    for map_name in ['BaseColor', 'Normal']:
        keep.add(f'Textures/T_{name}_{map_name}.png')
keep.add('License_Standard.txt')
removed = []
for path in KIT.rglob('*'):
    if not path.is_file():
        continue
    relative = path.relative_to(KIT).as_posix()
    base = relative.removesuffix('.import')
    if base not in keep:
        resolved = path.resolve()
        if not resolved.is_relative_to(ASSETS):
            raise RuntimeError('Unsafe runtime prune target')
        path.unlink()
        removed.append(str(path.relative_to(ROOT)))
unused = ASSETS / 'quaternius_stylized_nature_cc0'
if unused.exists():
    if unused.resolve().parent != ASSETS:
        raise RuntimeError('Unsafe unused-kit target')
    shutil.rmtree(unused)
    removed.append(str(unused.relative_to(ROOT)))
models = ASSETS / 'polyhaven_cc0/models'
recipes = {}
for path in sorted(models.glob('recipe-*.json'), key=lambda file: file.stat().st_mtime):
    for entry in json.loads(path.read_text()):
        recipes[entry['id']] = entry
for stem in ['fir_sapling', 'rock_moss_set_01']:
    for path in models.iterdir():
        if path.name in [stem + '.glb', stem + '.glb.import'] or path.name.startswith(stem + '_' + stem):
            if not path.resolve().is_relative_to(ASSETS):
                raise RuntimeError('Unsafe obsolete model target')
            path.unlink()
            removed.append(str(path.relative_to(ROOT)))
    recipes.pop(stem, None)
for path in models.glob('recipe-*.json'):
    path.unlink()
report = {'models': list(recipes.values()), 'architecture': sorted(keep), 'removed_runtime_files': removed,
          'source_policy': 'Full CC0 sources remain under art/environment/source; only selected assets ship.'}
(ROOT / 'art/environment/runtime-manifest.json').write_text(json.dumps(report, indent=2))
print('ENVIRONMENT_RUNTIME_PRUNED', len(removed), 'obsolete or unused runtime entries')
