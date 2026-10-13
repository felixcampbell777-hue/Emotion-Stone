"""Independent saved-source checks for body-following opaque garment coverage."""
import bpy,json,hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];SOURCE=ROOT/'art/source/beta-heroine.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE),load_ui=False,use_scripts=False)
report=json.loads((ROOT/'art/character/shirt-review/coverage.json').read_text(encoding='utf-8'))
panel=bpy.data.objects[report['panel']];body=bpy.data.objects['Static_Human_0'];rig=bpy.data.objects['BetaRig']
assert len(panel.data.vertices)==len(report['coverage_samples'])
for vertex,sample in zip(panel.data.vertices,report['coverage_samples']):
    weights={panel.vertex_groups[g.group].name:g.weight for g in vertex.groups}
    assert weights.keys()==sample['weights'].keys()
    assert all(abs(value-sample['weights'][name])<1e-6 for name,value in weights.items())
    assert abs((vertex.co-Vector(sample['position'])).length-.005)<1e-5
visible_skin=0
for face in body.data.polygons:
    p=face.center
    if .995<=p.z<=1.407 and abs(p.x)<=.276 and (abs(p.x)<=.17 or p.z>=1.18) and (p.y>=-.045 or (abs(p.x)>.139 and p.y>=-.09 and p.z>=1.18)):visible_skin+=1
assert visible_skin==0,'Covered back contains surviving visible skin triangles'
assert len(rig.data.bones)==16 and len(rig.animation_data.nla_tracks)==19
assert panel.modifiers[0].object==rig
bsdf=next(n for n in panel.active_material.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
assert bsdf.inputs['Alpha'].default_value==1 and not bsdf.inputs['Alpha'].is_linked
result={'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'panel_vertices_checked':len(panel.data.vertices),'matching_body_weights':True,'normal_offset_m':.005,'visible_skin_triangles_in_covered_region':visible_skin,'bones':16,'clips':19,'opaque_denim':True,'passed':True}
(ROOT/'art/character/shirt-review/source-checks.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print('SHIRT_SOURCE_CHECKS_PASS',len(panel.data.vertices),'weighted vertices; no visible covered skin')
