"""Derive the Advanced mesh from the current rig; never overwrite original art."""
import bpy
from pathlib import Path
import json
import math
import bmesh
import sys
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
def apply_detail(hero=True,model_only=False):
    report = []
    for obj in list(bpy.context.scene.objects):
        if obj.type != 'MESH':
            continue
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        before = len(obj.data.vertices)
        modifier = obj.modifiers.new('Advanced rounded silhouette', 'SUBSURF')
        modifier.levels = 2 if hero and obj.name=='outfit_dress' else 1
        modifier.render_levels = modifier.levels
        obj.modifiers.move(len(obj.modifiers) - 1, 0)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
        if not obj.data.uv_layers:
            layer=obj.data.uv_layers.new(name='UVMap')
            for loop in obj.data.loops:
                v=obj.data.vertices[loop.vertex_index].co
                layer.data[loop.index].uv=(math.atan2(v.y,v.x)/math.tau+.5,v.z*2)
        report.append({'mesh': obj.name, 'original_vertices': before, 'advanced_vertices': len(obj.data.vertices)})
    if hero:
        metrics=sculpt_hero(animate=not model_only)
        (ROOT/'art/character/hero-design-metrics.json').write_text(json.dumps(metrics,indent=2)+'\n')
        for entry in report:
            entry['advanced_vertices']=len(bpy.data.objects[entry['mesh']].data.vertices)
    return report

sys.path.insert(0, str(ROOT / 'tools'))
from remake_hero import remake as sculpt_hero

if __name__ == '__main__':
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'art/source/humanoid-v1.blend'))
    npc='--npc' in sys.argv
    report = apply_detail(hero=not npc,model_only='--model-only' in sys.argv)
    bpy.context.preferences.filepaths.save_version=0
    if not npc:bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/source/hero-detailed.blend'))
    model_only='--model-only' in sys.argv
    out = ROOT / ('game/assets/characters/humanoid-advanced-v1.glb' if npc else 'game/assets/characters/humanoid-hero-preview.glb' if model_only else 'game/assets/characters/humanoid-hero-v1.glb')
    bpy.ops.export_scene.gltf(filepath=str(out), export_format='GLB', export_animations=not npc and not model_only, export_animation_mode='ACTIONS', export_frame_range=False, export_force_sampling=True,
                              export_yup=True, export_def_bones=True)
    (ROOT / ('art/environment/character-detail-recipe.json' if npc else 'art/character/hero-detail-recipe.json')).write_text(json.dumps(report, indent=2))
    print('CHARACTER_DETAIL_READY', out, sum(item['advanced_vertices'] for item in report))

