"""Add a body-weighted denim back/shoulder under-panel to the CURRENT Beta source.
Canonical and personal sources are never opened for writing.
"""
import bpy,bmesh,json,hashlib,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
from mathutils.geometry import barycentric_transform
ROOT=Path(__file__).resolve().parents[1];SOURCE=ROOT/'art/source/beta-heroine.blend'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE),load_ui=False,use_scripts=False)
bpy.context.preferences.filepaths.save_version=0
body=bpy.data.objects['Static_Human_0'];rig=bpy.data.objects['BetaRig']
existing=bpy.data.objects.get('Denim continuous back and shoulder panel')
if existing:
    # Recover the covered skin topology from the current panel's reference surface
    # before refining its hem. No older source/export is loaded.
    previous=json.loads((ROOT/'art/character/shirt-review/coverage.json').read_text(encoding='utf-8'))
    kd=KDTree(len(body.data.vertices))
    for v in body.data.vertices:kd.insert(v.co,v.index)
    kd.balance();mapping_old=[kd.find(Vector(sample['position']))[1] for sample in previous['coverage_samples']]
    body.data.calc_loop_triangles();points_skin=[];tris_skin=[];uv_skin=[]
    for tri in body.data.loop_triangles:
        tris_skin.append(tuple(range(len(points_skin),len(points_skin)+3)))
        points_skin.extend([body.data.vertices[index].co.copy() for index in tri.vertices])
        uv_skin.append([Vector((*body.data.uv_layers.active.data[loop].uv,0)) for loop in tri.loops])
    skin_bvh=BVHTree.FromPolygons(points_skin,tris_skin,all_triangles=True)
    bm=bmesh.new();bm.from_mesh(body.data);bm.verts.ensure_lookup_table();layer=bm.loops.layers.uv.active
    for poly in existing.data.polygons:
        face=bm.faces.new([bm.verts[mapping_old[index]] for index in poly.vertices])
        face.smooth=True
        for loop in face.loops:
            point,normal,index,distance=skin_bvh.find_nearest(loop.vert.co)
            tri=tris_skin[index];mapped=barycentric_transform(point,points_skin[tri[0]],points_skin[tri[1]],points_skin[tri[2]],*uv_skin[index])
            loop[layer].uv=(mapped.x,mapped.y)
    bm.to_mesh(body.data);bm.free();bpy.data.objects.remove(existing,do_unlink=True)
shirt=bpy.data.objects['Static_Denim open shirt collar and fitted yoke_0']
material=shirt.data.materials[0]
donors=[shirt,bpy.data.objects['Static_Denim short shirt sleeves_0'],bpy.data.objects['Static_Human.punkduck_black_cocktail_dress_0']]
# Transfer the nearest actual donor cloth UV; reuse its baked denim map verbatim.
triangles=[];points=[];donor_uv=[]
for donor in donors:
    donor.data.calc_loop_triangles();uv=donor.data.uv_layers.active.data
    for tri in donor.data.loop_triangles:
        triangles.append(tuple(range(len(points),len(points)+3)))
        points.extend([donor.data.vertices[index].co.copy() for index in tri.vertices])
        donor_uv.append([Vector((uv[loop].uv.x,uv[loop].uv.y,0)) for loop in tri.loops])
bvh=BVHTree.FromPolygons(points,triangles,all_triangles=True)
selected=[]
for poly in body.data.polygons:
    p=poly.center
    # Full upper back plus the rear/side shoulders, ending inside the short sleeves.
    sleeve_limit=(abs(p.x)<=.17 or p.z>=1.18)
    if .995<=p.z<=1.407 and abs(p.x)<=.276 and sleeve_limit and (p.y>=-.045 or (abs(p.x)>.139 and p.y>=-.09 and p.z>=1.18)):
        selected.append(poly)
if len(selected)<150:raise RuntimeError('Back coverage selection unexpectedly small')
indices=sorted({index for poly in selected for index in poly.vertices});mapping={old:new for new,old in enumerate(indices)}
vertices=[body.data.vertices[index].co+body.data.vertices[index].normal*.005 for index in indices]
faces=[tuple(mapping[i] for i in poly.vertices) for poly in selected]
mesh=bpy.data.meshes.new('Continuous denim back surface');mesh.from_pydata(vertices,[],faces);mesh.update()
panel=bpy.data.objects.new('Denim continuous back and shoulder panel',mesh);bpy.context.collection.objects.link(panel)
panel.matrix_world=body.matrix_world.copy();panel.parent=rig
mesh.materials.append(material)
for poly in mesh.polygons:poly.use_smooth=True
uv=mesh.uv_layers.new(name='Denim inherited atlas')
for poly in mesh.polygons:
    for loop in poly.loop_indices:
        at=mesh.vertices[mesh.loops[loop].vertex_index].co
        nearest=bvh.find_nearest(at)
        point,normal,index,distance=nearest
        tri=triangles[index]; mapped=barycentric_transform(point,points[tri[0]],points[tri[1]],points[tri[2]],*donor_uv[index])
        uv.data[loop].uv=(mapped.x,mapped.y)
for group in body.vertex_groups:panel.vertex_groups.new(name=group.name)
weights=[]
for new,old in enumerate(indices):
    entry={}
    for group in body.data.vertices[old].groups:
        panel.vertex_groups[group.group].add([new],group.weight,'REPLACE');entry[body.vertex_groups[group.group].name]=group.weight
    weights.append(entry)
modifier=panel.modifiers.new('Matching body skin','ARMATURE');modifier.object=rig
# Covered skin has no visible triangles beneath this panel. Shared topology/weights
# preserve the seam in every pose, without fabric/skin intersections flashing through.
covered_ids={poly.index for poly in selected}
bm=bmesh.new();bm.from_mesh(body.data);bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm,geom=[face for face in bm.faces if face.index in covered_ids],context='FACES_ONLY');bm.to_mesh(body.data);bm.free()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
directory=ROOT/'art/character/shirt-review';directory.mkdir(exist_ok=True)
report={'editable_source':'art/source/beta-heroine.blend','source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'panel':panel.name,'covered_body_faces':len(selected),'panel_vertices':len(vertices),'panel_faces':len(faces),'offset_m':.005,'body_weights_copied':True,'original_denim_material_reused':material.name,'personal_source_unchanged':True,'rest_bounds':[[min(v[i] for v in vertices),max(v[i] for v in vertices)] for i in range(3)],'coverage_samples':[{'position':list(body.data.vertices[old].co),'panel_position':list(vertices[new]),'weights':weights[new]} for new,old in enumerate(indices)]}
(directory/'coverage.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('BACK_SHIRT_COVERAGE',len(selected),'faces',len(vertices),'vertices')
