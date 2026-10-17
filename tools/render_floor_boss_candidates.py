"""Read-only studio previews of the saved boss candidate Blender models."""
import bpy, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'art/character/floor-boss-candidates'
OUT.mkdir(parents=True,exist_ok=True)
for name,source in [('elder',ROOT/'art/library/source/forest-monster/forest-monster-final.blend'),('ashfang',ROOT/'art/source/beta-wolf.blend')]:
    bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False,use_scripts=False)
    scene=bpy.context.scene
    for image in bpy.data.images:
        if not image.packed_file:
            candidates=list(source.parent.rglob(Path(image.filepath.replace('\\','/')).name))
            if candidates:
                image.filepath=str(candidates[0]);image.reload()
    for obj in list(scene.objects):
        if obj.type not in ['MESH','ARMATURE']: bpy.data.objects.remove(obj,do_unlink=True)
    for rig in [o for o in scene.objects if o.type=='ARMATURE']:
        if rig.animation_data: rig.animation_data_clear()
        rig.data.pose_position='REST'
    # Legacy Blender Internal materials need explicit image nodes for modern renders.
    for mat in bpy.data.materials:
        if not mat.use_nodes or not any(n.type=='TEX_IMAGE' for n in mat.node_tree.nodes):
            mat.use_nodes=True
            bsdf=mat.node_tree.nodes.get('Principled BSDF')
            if name=='elder':
                image_path=source.parent/'texture/forest-monster-skin.png'
                tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(image_path),check_existing=True)
                mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
                bsdf.inputs['Roughness'].default_value=.85
    if name=='elder':
        tree=bpy.data.objects.get('Tree')
        if tree:
            mat=bpy.data.materials.new('Supplied tree foliage');mat.use_nodes=True
            bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=.9
            tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(source.parent/'texture/tree.png'),check_existing=True)
            mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
            mat.node_tree.links.new(tex.outputs['Alpha'],bsdf.inputs['Alpha'])
            tree.data.materials.clear();tree.data.materials.append(mat)
    bpy.context.view_layer.update()
    meshes=[o for o in scene.objects if o.type=='MESH' and not o.hide_render and o.visible_get() and o.name!='Root']
    points=[o.matrix_world@Vector(corner) for o in meshes for corner in o.bound_box]
    lo=Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    center=(lo+hi)*.5;span=max(hi-lo)
    print(name,[(o.name,tuple(o.dimensions)) for o in meshes],tuple(lo),tuple(hi),flush=True)
    def aim(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
    for label,offset,power,color in [('Key',(-2,-3,4),1100,(1,.90,.78)),('Fill',(3,-1,2),650,(.7,.83,1)),('Rim',(0,3,3),1400,(.75,.92,1))]:
        data=bpy.data.lights.new(label,'AREA');data.energy=power*span*span/9;data.size=span*1.3;data.color=color
        obj=bpy.data.objects.new(label,data);scene.collection.objects.link(obj);obj.location=center+Vector(offset)*span*.7;aim(obj,center)
    bpy.ops.mesh.primitive_plane_add(size=200,location=(center.x,center.y,lo.z-.025))
    plane=bpy.context.object;mat=bpy.data.materials.new('Studio floor');mat.diffuse_color=(.12,.14,.15,1);plane.data.materials.append(mat)
    scene.world=bpy.data.worlds.new('Review world');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.15,.18,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.4
    data=bpy.data.cameras.new('Review');cam=bpy.data.objects.new('Review',data);scene.collection.objects.link(cam);scene.camera=cam;data.type='ORTHO';data.ortho_scale=span*1.45
    scene.render.engine='CYCLES';scene.cycles.samples=24
    scene.render.resolution_x=1100;scene.render.resolution_y=900;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
    for view,offset in [('three-quarter',(1.5,-2.7,1.0)),('reverse',(-1.5,2.7,1.0))]:
        cam.location=center+Vector(offset)*span;aim(cam,center)
        scene.render.filepath=str(OUT/(name+'-'+view+'.png'));bpy.ops.render.render(write_still=True)
