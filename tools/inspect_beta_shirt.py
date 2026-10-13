import bpy,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/source/beta-heroine.blend'),load_ui=False,use_scripts=False)
for obj in bpy.data.objects:
    if obj.type=='MESH':
        print('PART',obj.name,len(obj.data.vertices),[(round(min(v.co[i] for v in obj.data.vertices),3),round(max(v.co[i] for v in obj.data.vertices),3)) for i in range(3)],[(m.name if m else '') for m in obj.data.materials])
    elif obj.type=='ARMATURE':print('RIG',obj.name,[(b.name,[round(x,3) for x in b.head_local]) for b in obj.data.bones])
mat=bpy.data.objects['Static_Human.punkduck_black_cocktail_dress_0'].data.materials[0]
print('TEXTS',[text.name for text in bpy.data.texts])
print('DRIVERS',[(obj.name,[d.data_path for d in obj.animation_data.drivers]) for obj in bpy.data.objects if obj.animation_data and obj.animation_data.drivers])
print('NLA',len(bpy.data.objects['BetaRig'].animation_data.nla_tracks))
for node in mat.node_tree.nodes:
    if node.type=='TEX_IMAGE':print('DENIM_IMAGE',node.image.name,node.image.size[:],node.image.filepath)
