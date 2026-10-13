"""Export saved, editable Beta garment changes without re-baking the personal draft."""
import bpy,json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];SOURCE=ROOT/'art/source/beta-heroine.blend';OUTPUT=ROOT/'game/assets/characters/heroine-beta.glb'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE),load_ui=False,use_scripts=False)
if any(obj.animation_data and obj.animation_data.drivers for obj in bpy.data.objects):raise RuntimeError('Beta source must have no executable drivers')
# Retain the source's plain provenance/art notes; GLB never exports Text blocks.
rig=bpy.data.objects['BetaRig']
if len(rig.data.bones)!=16 or len(rig.animation_data.nla_tracks)!=19:raise RuntimeError('Existing Beta rig/action contract changed')
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.data.objects:
    if obj.type in ['ARMATURE','MESH']:obj.hide_set(False);obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUTPUT),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_yup=True)
path=ROOT/'art/character/beta-heroine-export.json';report=json.loads(path.read_text(encoding='utf-8'))
report.update(editable_source='art/source/beta-heroine.blend',editable_source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),export_sha256=hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),saved_source_reopened=True,current_export_recipe='tools/export_beta_saved.py',meshes=sum(o.type=='MESH' for o in bpy.data.objects),back_panel='Denim continuous back and shoulder panel')
path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('BETA_SAVED_SOURCE_EXPORTED',report['meshes'],'meshes',report['export_sha256'])
