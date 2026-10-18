"""Standalone two-headed wolf inspection draft, derived from the existing CC0 wolf."""
import bpy,bmesh,math
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'art/source/concepts/two-headed-wolf.blend'
OUT=ROOT/'art/character/two-headed-wolf'
DEST.parent.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/source/beta-wolf.blend'),load_ui=False,use_scripts=False)
bpy.context.preferences.filepaths.save_version=0
for o in list(bpy.data.objects):
 if o.type not in ['MESH','ARMATURE']:bpy.data.objects.remove(o,do_unlink=True)
for rig in [o for o in bpy.data.objects if o.type=='ARMATURE']:
 if rig.animation_data:rig.animation_data_clear()
 rig.data.pose_position='REST'
bpy.context.view_layer.update()
originals=[o for o in bpy.context.scene.objects if o.type=='MESH']
def head(v,cut=-1.35):return v.co.y < cut and v.co.z>1.35
def crop(obj,keep_head):
 bm=bmesh.new();bm.from_mesh(obj.data)
 bmesh.ops.delete(bm,geom=[v for v in bm.verts if head(v,-1.35 if keep_head else -1.65)!=keep_head],context='VERTS')
 bm.to_mesh(obj.data);bm.free();obj.data.update()
for original in originals:
 # Keep this visual draft static; a dedicated branched neck rig comes after design approval.
 bpy.ops.object.select_all(action='DESELECT');original.select_set(True);bpy.context.view_layer.objects.active=original
 for mod in list(original.modifiers):
  if mod.type=='ARMATURE':bpy.ops.object.modifier_apply(modifier=mod.name)
 original.parent=None;original.animation_data_clear()
 for side,label in [(-1,'Left'),(1,'Right')]:
  copy=original.copy();copy.data=original.data.copy();bpy.context.scene.collection.objects.link(copy);copy.name=label+' head '+original.name
  crop(copy,True)
  for v in copy.data.vertices:
   t=max(0,min(1,(-v.co.y-1.35)/.52));t=t*t*(3-2*t)
   pivot=Vector((0,-1.35,1.85));local=v.co-pivot
   turned=Matrix.Rotation(side*math.radians(12)*t,3,'Z')@local
   v.co=pivot+turned;v.co.x+=side*.48*t;v.co.z+=.035*t*(1 if side==1 else -1)
  for face in copy.data.polygons:face.use_smooth=True
 crop(original,False);original.name='Shared body '+original.name
for rig in [o for o in bpy.data.objects if o.type=='ARMATURE']:bpy.data.objects.remove(rig,do_unlink=True)
for image in bpy.data.images:
 if image.source=='FILE' and not image.packed_file:image.pack()
scene=bpy.context.scene;scene.world=bpy.data.worlds.new('Two-headed wolf studio');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.11,.14,.18,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.35
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
for name,location,power,color,size in [('Warm key',(-3,-4,6),950,(1,.85,.70),4),('Soft fill',(4,-1,4),700,(.7,.85,1),4),('Rim',(0,4,5),1200,(.78,.87,1),3)]:
 light=bpy.data.lights.new(name,'AREA');light.energy=power;light.color=color;light.shape='DISK';light.size=size
 obj=bpy.data.objects.new(name,light);scene.collection.objects.link(obj);obj.location=location;aim(obj,(0,0,1.3))
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.025));floor=bpy.context.object;floor.name='Studio ground'
mat=bpy.data.materials.new('Charcoal studio');mat.use_nodes=True;bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Base Color'].default_value=(.065,.08,.10,1);bsdf.inputs['Roughness'].default_value=.82;floor.data.materials.append(mat)
camdata=bpy.data.cameras.new('Draft camera');cam=bpy.data.objects.new('Draft camera',camdata);scene.collection.objects.link(cam);scene.camera=cam;camdata.type='ORTHO';camdata.ortho_scale=6.4
cam.location=(4,-7,3.4);aim(cam,(0,.05,1.2))
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=1200;scene.render.resolution_y=950;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
scene['draft_note']='Static visual concept only. Existing CC0 wolf body, two separately editable head/neck meshes. Not game-integrated or animation-ready.'
scene['source_license']='Existing Quaternius CC0 wolf and project-original fur maps; see art/library/beta-wolf-customization.json.'
# Make the file open on its camera with the creature selected and material colors visible.
bpy.ops.object.select_all(action='DESELECT')
for obj in originals:obj.select_set(True)
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.shading.type='MATERIAL'
scene.render.filepath=str(OUT/'two-headed-wolf.png');bpy.ops.wm.save_as_mainfile(filepath=str(DEST));bpy.ops.render.render(write_still=True)
print('TWO_HEADED_WOLF_READY',str(DEST),str(OUT/'two-headed-wolf.png'))
