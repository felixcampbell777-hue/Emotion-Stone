"""Render the saved customized sword without changing source or runtime."""
import bpy
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'art/character/beta-sword-review'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/source/beta-greatsword.blend'),load_ui=False,use_scripts=False)
scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=64
def aim(o,point):o.rotation_euler=(Vector(point)-o.location).to_track_quat('-Z','Y').to_euler()
def area(name,position,energy,size,color):
    data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.shape='DISK';data.size=size;data.color=color
    o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);o.location=position;aim(o,(0,0,-.25))
area('Key',(-1,-2,1.8),220,2,(.86,.93,1))
area('Edge',(1.2,.8,.3),260,1.5,(1,.91,.77))
area('Reflection',(.25,-.7,-.5),35,.7,(.7,.81,1))
data=bpy.data.cameras.new('Review');camera=bpy.data.objects.new('Review',data);scene.collection.objects.link(camera)
scene.camera=camera;data.type='ORTHO';data.ortho_scale=1.25
camera.location=(.2,-2.6,.18);aim(camera,(0,0,-.35))
data.ortho_scale=1.42
scene.render.resolution_x=700;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(OUT/'custom-greatsword.png');bpy.ops.render.render(write_still=True)
camera.location=(.14,-1.2,.3);aim(camera,(0,0,.13));data.ortho_scale=.36
scene.render.resolution_x=900;scene.render.resolution_y=750;scene.render.filepath=str(OUT/'hilt-detail.png');bpy.ops.render.render(write_still=True)
