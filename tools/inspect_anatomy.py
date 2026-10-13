"""Read-only geometry inventory for the verified CC0 anatomy bundle."""
import bpy
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[1]
with bpy.data.libraries.load(str(root/'art/character/source/human_base_meshes_bundle.blend'),link=False) as (src,dst):
    print('ANATOMY_MESHES',src.meshes)
    dst.meshes=[n for n in src.meshes if 'female' in n.lower() or n=='GEO-head_animation_realistic']
for mesh in dst.meshes:
    bounds=[(min(v.co[i] for v in mesh.vertices),max(v.co[i] for v in mesh.vertices)) for i in range(3)]
    print('ANATOMY',mesh.name,len(mesh.vertices),bounds,'UV',bool(mesh.uv_layers))
    if mesh.name=='GEO-body_female_realistic':
        import bmesh
        bm=bmesh.new();bm.from_mesh(mesh)
        pending={v for e in bm.edges if e.is_boundary for v in e.verts}
        while pending:
            seed=pending.pop();group={seed};todo=[seed]
            while todo:
                v=todo.pop()
                for e in v.link_edges:
                    if not e.is_boundary:continue
                    other=e.other_vert(v)
                    if other in pending:pending.remove(other);group.add(other);todo.append(other)
            center=sum((v.co for v in group),Vector())/len(group)
            print('BOUNDARY',len(group),tuple(center),[(min(v.co[i] for v in group),max(v.co[i] for v in group)) for i in range(3)])
        bm.free()
        for z in [.14,.40,.65,.82,.95,1.10,1.20,1.30,1.35,1.40,1.45,1.50,1.55,1.60]:
            vs=[v.co for v in mesh.vertices if abs(v.co.z-z)<.012]
            print('SECTION',z,[(min(v[i] for v in vs),max(v[i] for v in vs)) for i in range(3)] if vs else [])
bpy.ops.wm.open_mainfile(filepath=str(root/'art/character/source/human_base_meshes_bundle.blend'))
for obj in bpy.data.objects:
    if obj.name.startswith('GEO-body_female_realistic'):print('OBJECT',obj.name,'LOCAL',tuple(obj.location),'MATRIX',[list(row) for row in obj.matrix_world])
bpy.ops.wm.open_mainfile(filepath=str(root/'art/source/humanoid-v1.blend'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
for b in rig.data.bones: print('BONE',b.name,tuple(b.head_local),tuple(b.tail_local))
