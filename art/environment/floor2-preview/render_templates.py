import bpy,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
nature=ROOT/'art/environment/source/quaternius_stylized_nature_cc0/glTF'
models=ROOT/'game/assets/environment/polyhaven_cc0/models'
assets=[('twisted-tree',nature/'TwistedTree_2.gltf'),('dead-tree',nature/'DeadTree_3.gltf'),('shore-grass',nature/'Grass_Wispy_Tall.gltf'),('fern',models/'fern_02.glb'),('moss-rock',models/'rock_moss_set_01_b.glb'),('stump',models/'tree_stump_01.glb')]
def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
for name,path in assets:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(path));scene=bpy.context.scene;bpy.context.view_layer.update()
 objects=[o for o in scene.objects if o.type=='MESH'];points=[o.matrix_world@Vector(v) for o in objects for v in o.bound_box]
 lo=Vector([min(v[i] for v in points) for i in range(3)]);hi=Vector([max(v[i] for v in points) for i in range(3)])
 center=(lo+hi)*.5;span=max(hi-lo)
 for label,offset,power,color in [('Key',(-2,-3,4),900,(1,.94,.83)),('Fill',(3,-1,2),600,(.74,.86,1)),('Rim',(0,3,3),1000,(.9,1,.9))]:
  data=bpy.data.lights.new(label,'AREA');data.energy=power*span*span/9;data.size=span*1.3;data.color=color
  obj=bpy.data.objects.new(label,data);scene.collection.objects.link(obj);obj.location=center+Vector(offset)*span*.7;aim(obj,center)
 bpy.ops.mesh.primitive_plane_add(size=span*200,location=(center.x,center.y,lo.z-.01*span));plane=bpy.context.object
 mat=bpy.data.materials.new('Neutral preview ground');mat.diffuse_color=(.085,.105,.09,1);plane.data.materials.append(mat)
 scene.world=bpy.data.worlds.new('Preview world');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.15,.18,.15,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.45
 data=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',data);scene.collection.objects.link(cam);scene.camera=cam;data.type='ORTHO';data.ortho_scale=span*1.95
 cam.location=center+Vector((1.8,-3,1.25))*span;aim(cam,center)
 scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=True
 scene.render.resolution_x=600;scene.render.resolution_y=430;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
 scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
 print('TEMPLATE_READY',name,flush=True)
