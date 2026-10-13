"""Export the current editable Beta sword; never regenerate a hand-edited source."""
import bpy, json, hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'art/source/beta-greatsword.blend'
runtime=ROOT/'game/assets/characters/greatsword-beta.glb'
report_path=ROOT/'art/character/beta-sword-review/customization.json'
bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False,use_scripts=False)
assert not bpy.data.texts, 'Unexpected embedded text in derived sword'
objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith('Sword')]
assert objects and all(not o.animation_data or not o.animation_data.drivers for o in objects)
blade=next(o for o in objects if o.name=='SwordBlade')
points=[blade.matrix_world@v.co for v in blade.data.vertices]
report=json.loads(report_path.read_text())
tip=min(points,key=lambda v:v.z)
assert (tip-Vector((0,0,report['blade_tip_local_y']))).length<.0001, 'Blade tip must match the runtime contract'
assert abs((max(v.x for v in points)-min(v.x for v in points))*1.472-report['blade_width_m'])<.0002
assert abs((max(v.y for v in points)-min(v.y for v in points))*1.472-report['blade_thickness_m'])<.0002
bpy.ops.object.select_all(action='DESELECT')
for o in objects:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(runtime),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
report.update(source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),runtime_sha256=hashlib.sha256(runtime.read_bytes()).hexdigest(),saved_source_reopened=True,blade_width_m=(max(v.x for v in points)-min(v.x for v in points))*1.472,blade_thickness_m=(max(v.y for v in points)-min(v.y for v in points))*1.472,triangles=sum(len(poly.vertices)-2 for obj in objects for poly in obj.data.polygons))
report_path.write_text(json.dumps(report,indent=2)+'\n')
print('Reopened current Beta sword and verified its actual steel dimensions.')
