"""Inventory icon rendered from the saved actual Beta Blender sword."""
import bpy,math
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/source/beta-greatsword.blend'),load_ui=False,use_scripts=False)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=64
rotation=Matrix.Rotation(.70,4,'Y')
for obj in list(scene.objects):obj.matrix_world=rotation@obj.matrix_world
center=rotation@Vector((0,0,-.35))
def aim(o):o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
for position,energy,size in [((-1,-2,1),220,2),((1,-.5,-.2),160,1),((0,1,0),250,1.8)]:
    data=bpy.data.lights.new('Icon light','AREA');data.energy=energy;data.size=size
    obj=bpy.data.objects.new('Icon light',data);scene.collection.objects.link(obj);obj.location=position;aim(obj)
data=bpy.data.cameras.new('Icon');data.type='ORTHO';data.ortho_scale=1.16
camera=bpy.data.objects.new('Icon',data);scene.collection.objects.link(camera);camera.location=center+Vector((0,-3,0));aim(camera);scene.camera=camera
scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX'
scene.render.filepath=str(ROOT/'art/character/beta-sword-review/beta-longsword-icon.png');bpy.ops.render.render(write_still=True)
