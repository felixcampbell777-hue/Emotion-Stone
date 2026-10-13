"""Export the current editable wolf without regenerating its art."""
import bpy,json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/source/beta-wolf.blend';RUNTIME=ROOT/'game/assets/creatures/beta-wolf.glb';REPORT=ROOT/'art/library/beta-wolf-customization.json'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE),load_ui=False,use_scripts=False)
if bpy.data.texts or any(obj.animation_data and obj.animation_data.drivers for obj in bpy.data.objects):raise RuntimeError('Wolf source must contain no embedded scripts/drivers')
rig=next(obj for obj in bpy.data.objects if obj.type=='ARMATURE')
if len(rig.data.bones)!=51:raise RuntimeError('Donor wolf skeleton unexpectedly changed')
expected={'Attack','Walk','Gallop','Idle','Idle_HitReact1','Death'}
if not expected.issubset({action.name for action in bpy.data.actions}):raise RuntimeError('Wolf source lost gameplay animation clips')
rig.data.pose_position='POSE';bpy.context.scene.frame_set(0)
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.data.objects:
    if obj.type in ['MESH','ARMATURE']:obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(RUNTIME),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_skins=True,export_yup=True)
report=json.loads(REPORT.read_text(encoding='utf-8'))
for key,file in [('source_sha256',SOURCE),('runtime_sha256',RUNTIME)]:report[key]=hashlib.sha256(file.read_bytes()).hexdigest()
report.update(saved_source_reopened=True,embedded_scripts=0,drivers=0,clips=[action.name for action in bpy.data.actions])
REPORT.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('WOLF_EXPORT_SAVED_SOURCE',report['runtime_sha256'])
