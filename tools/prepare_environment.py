"""Blender recipe: optimize CC0 scanned meshes without changing gameplay geometry."""
import bpy
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art/environment/source/polyhaven_cc0'
OUT = ROOT / 'game/assets/environment/polyhaven_cc0/models'
OUT.mkdir(parents=True, exist_ok=True)
requested = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
assets = requested or ['fir_tree_01', 'fir_sapling', 'rock_moss_set_01', 'fern_02', 'tree_stump_01']
report = []
for asset in assets:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = next((SOURCE / asset).glob('*.gltf'))
    bpy.ops.import_scene.gltf(filepath=str(scene))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    if asset == 'grass_medium_01':
        groups = [[meshes[0]]]
    elif asset in ['fir_tree_01', 'fir_sapling', 'rock_moss_set_01']:
        groups = [[obj] for obj in meshes]
    else:
        groups = [meshes]
    for index, group in enumerate(groups):
        for obj in bpy.context.scene.objects:
            obj.select_set(False)
        before = sum(len(obj.data.polygons) for obj in group)
        # Alpha needle cards restore density without millions of individual needles.
        target = 25000 if asset == 'fir_tree_01' else 18000 if asset == 'fir_sapling' else 8000
        for obj in group:
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            if before > target:
                modifier = obj.modifiers.new('Runtime triangle budget', 'DECIMATE')
                modifier.ratio = min(1, target / before)
                bpy.ops.object.modifier_apply(modifier=modifier.name)
            for poly in obj.data.polygons:
                poly.use_smooth = True
        name = ('fir_' + chr(97 + index)) if asset == 'fir_tree_01' else (asset + '_' + chr(97 + index)) if len(groups) > 1 else asset
        bpy.ops.export_scene.gltf(filepath=str(OUT / (name + '.glb')), export_format='GLB',
                                  use_selection=True, export_yup=True, export_apply=True)
        after = sum(len(obj.data.polygons) for obj in group)
        report.append({'id': name, 'source': asset, 'source_faces': before, 'runtime_faces': after})
        print('ENVIRONMENT_PREPARED', name, before, after, flush=True)
(OUT / ('recipe-' + '-'.join(assets) + '.json')).write_text(json.dumps(report, indent=2))
