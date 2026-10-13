"""Read-only CC0 rat source; export only selected existing motion and original skin."""
import bpy,json,hashlib
from pathlib import Path
ROOT=Path('C:/Games/CoastalFoundation')
path=ROOT/'art/library/source/giant-rat/rat_2.blend'
original=hashlib.sha256(path.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(path),load_ui=False,use_scripts=False)
meshes=[o for o in bpy.data.objects if o.type=='MESH' and o.visible_get()]
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
for material in bpy.data.materials:
    image=bpy.data.images.get('rat-body' if material.name=='body' else 'rat-head' if material.name.startswith('head') else '')
    color=tuple(material.diffuse_color)
    material.use_nodes=True;nodes=material.node_tree.nodes;nodes.clear()
    p=nodes.new('ShaderNodeBsdfPrincipled');out=nodes.new('ShaderNodeOutputMaterial');material.node_tree.links.new(p.outputs[0],out.inputs['Surface']);p.inputs['Roughness'].default_value=.82
    p.inputs['Base Color'].default_value=color
    if image:
        node=nodes.new('ShaderNodeTexImage');node.image=image;material.node_tree.links.new(node.outputs['Color'],p.inputs['Base Color'])
clips=['Idle.001','Walk','Run','Attack.000','Hit','Die']
rig.animation_data_create();rig.animation_data.action=None
for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
for name in clips:
    action=bpy.data.actions.get(name);assert action,name
    track=rig.animation_data.nla_tracks.new();track.name=name;track.strips.new(name,1,action)
bpy.context.scene.render.fps=30
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in meshes:obj.select_set(True)
output=ROOT/'game/assets/creatures/beta-rat.glb'
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_morph=False,export_cameras=False,export_lights=False)
assert hashlib.sha256(path.read_bytes()).hexdigest()==original
(ROOT/'art/library/BETA-RUNTIME-ASSETS.json').write_text(json.dumps({'rat_source':str(path),'source_sha256':original,'source_unchanged':True,'output':str(output),'output_sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'existing_clips':clips,'license':'CC0-1.0','author':'CDmir / TinyWorlds','source_url':'https://opengameart.org/content/evil-giant-rat'},indent=2))
