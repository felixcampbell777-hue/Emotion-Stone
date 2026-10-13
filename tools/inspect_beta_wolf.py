import bpy,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'art/library/source/quaternius-animals/glTF/Wolf.gltf'))
for obj in bpy.data.objects:
    if obj.type=='MESH':
        print('WOLF_MESH',obj.name,len(obj.data.vertices),len(obj.data.polygons),[(m.name if m else '') for m in obj.data.materials],list(obj.dimensions),list(obj.location),obj.rotation_euler[:])
        for mat in obj.data.materials:
            if mat and mat.use_nodes:
                for node in mat.node_tree.nodes:
                    if node.type=='BSDF_PRINCIPLED':print('COLOR',mat.name,node.inputs['Base Color'].default_value[:])
        print('BOUNDS',[(min(v.co[i] for v in obj.data.vertices),max(v.co[i] for v in obj.data.vertices)) for i in range(3)])
    if obj.type=='ARMATURE':print('RIG',obj.name,len(obj.data.bones),[(b.name,list(b.head_local)) for b in obj.data.bones][:12])
print('ACTIONS',[(a.name,a.frame_range[:]) for a in bpy.data.actions])
