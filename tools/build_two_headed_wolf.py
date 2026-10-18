"""Create a separate game-ready branched wolf rig from the existing local CC0 donor."""
import bpy,bmesh,math
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/source/beta-wolf.blend'),load_ui=False,use_scripts=False)
bpy.context.preferences.filepaths.save_version=0
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.data.pose_position='REST'
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
branch=[b.name for b in rig.data.bones if b.name.startswith(('Neck','Ear')) or b.name=='Head']
def deform(v,side):
 t=max(0,min(1,(-v.y-1.35)/.52));t=t*t*(3-2*t)
 pivot=Vector((0,-1.35,1.85));out=pivot+Matrix.Rotation(side*math.radians(12)*t,3,'Z')@(v-pivot)
 out.x+=side*.48*t;out.z+=.035*t*(1 if side==1 else -1);return out
def crop(obj,keep):
 bm=bmesh.new();bm.from_mesh(obj.data);cut=-1.35 if keep else -1.65
 bmesh.ops.delete(bm,geom=[v for v in bm.verts if ((v.co.y<cut and v.co.z>1.35)!=keep)],context='VERTS');bm.to_mesh(obj.data);bm.free()
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
for side,suffix in [(-1,'A'),(1,'B')]:
 for name in branch:
  src=rig.data.edit_bones[name];bone=rig.data.edit_bones.new(name+'_'+suffix);bone.head=deform(src.head,side);bone.tail=deform(src.tail,side);bone.roll=src.roll;bone.use_deform=True
 for name in branch:
  parent=rig.data.edit_bones[name].parent
  rig.data.edit_bones[name+'_'+suffix].parent=rig.data.edit_bones[parent.name+'_'+suffix] if parent and parent.name in branch else parent
bpy.ops.object.mode_set(mode='OBJECT')
for name in branch:
 for suffix in ['A','B']:
  constraint=rig.pose.bones[name+'_'+suffix].constraints.new('COPY_ROTATION');constraint.target=rig;constraint.subtarget=name;constraint.target_space='LOCAL';constraint.owner_space='LOCAL'
for original in meshes:
 for side,suffix in [(-1,'A'),(1,'B')]:
  obj=original.copy();obj.data=original.data.copy();bpy.context.scene.collection.objects.link(obj);obj.name='Head_'+suffix+'_'+original.name;crop(obj,True)
  for v in obj.data.vertices:v.co=deform(v.co,side)
  for name in branch:
   group=obj.vertex_groups.get(name)
   if group:group.name=name+'_'+suffix
 crop(original,False);original.name='Shared_'+original.name
rig.data.pose_position='POSE';bpy.context.scene.frame_set(0)
for image in bpy.data.images:
 if image.source=='FILE' and not image.packed_file:image.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/source/two-headed-wolf.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.context.scene.objects:
 if obj.type in ['ARMATURE','MESH']:obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'game/assets/creatures/two-headed-wolf.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_skins=True,export_yup=True,export_force_sampling=True)
print('TWO_HEADED_WOLF_RIG_READY',len(rig.data.bones),[a.name for a in bpy.data.actions])
