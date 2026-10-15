"""Prepare collected art only. Never execute embedded scripts or modify library sources."""
import bpy, hashlib, json, shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
LIB=ROOT/'art/library/source'
OUT=ROOT/'game/assets/alpha2'
OUT.mkdir(parents=True,exist_ok=True)
entries={
 'boar':('boar/boar_0.blend',{'idle':'default','walk':'walk','attack':'attack'}),
 'spider':('spider/Spider.blend',{'idle':'SpiderStand','walk':'SpiderWalk','attack':'SpiderWalk'}),
 'forest_guardian':('forest-monster/forest-monster-final.blend',{'idle':'Idle','walk':'Walk','attack':'Attack','brace':'Melee_Hold','death':'Dying'}),
 'crab':('crab/source/minecrab.fbx',{'idle':'idle','walk':'run_cache','attack':'attaque','burrow':'rentrer_sol','rise':'sortie_attaque','death':'mort'}),
}
report=[]
def texture(material,base,normal=None):
 material.use_nodes=True;nodes=material.node_tree.nodes;nodes.clear();links=material.node_tree.links
 shader=nodes.new('ShaderNodeBsdfPrincipled');output=nodes.new('ShaderNodeOutputMaterial');links.new(shader.outputs[0],output.inputs['Surface'])
 shader.inputs['Base Color'].default_value=(.42,.36,.26,1);shader.inputs['Roughness'].default_value=.78
 if base:
  tex=nodes.new('ShaderNodeTexImage');tex.image=base;links.new(tex.outputs['Color'],shader.inputs['Base Color'])
 if normal:
  normal.colorspace_settings.name='Non-Color';tex=nodes.new('ShaderNodeTexImage');tex.image=normal
  n=nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.65;links.new(tex.outputs['Color'],n.inputs['Color']);links.new(n.outputs[0],shader.inputs['Normal'])
def image(name):return bpy.data.images.get(name)
for id,(relative,clips) in entries.items():
 source=LIB/relative;before=hashlib.sha256(source.read_bytes()).hexdigest()
 if source.suffix=='.blend':bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False,use_scripts=False)
 else:
  bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.fbx(filepath=str(source))
 if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
 # Remove any disabled legacy drivers from this derived session; no donor file is saved.
 for obj in bpy.data.objects:
  if obj.animation_data:
   for driver in list(obj.animation_data.drivers):obj.animation_data.drivers.remove(driver)
 for text in list(bpy.data.texts):bpy.data.texts.remove(text)
 if id=='spider':
  tex=bpy.data.images.load(str(LIB/'spider/Spider_0.png'),check_existing=True)
  for mat in bpy.data.materials:texture(mat,tex)
 elif id=='boar':
  for mat in bpy.data.materials:texture(mat,image('boar'))
 elif id=='forest_guardian':
  for mat in bpy.data.materials:
   texture(mat,image('forest-monster-skin1.png') if mat.name=='Monster' else image('skin_dieing.png'),image('forest-monster-norm.png') if mat.name=='Monster' else image('tree-norm.png'))
 elif id=='crab':
  for im in bpy.data.images:
   if im.type=='IMAGE' and (LIB/'crab/textures'/Path(im.filepath).name).exists():im.filepath=str(LIB/'crab/textures'/Path(im.filepath).name);im.reload()
  for mat in bpy.data.materials:
   # FBX imports preserve the original wood, metal and shell texture assignments.
   if mat.use_nodes:
    bs=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
    if bs:bs.inputs['Roughness'].default_value=.72;bs.inputs['Metallic'].default_value=.35 if 'metal' in mat.name.lower() else .0
 meshes=[o for o in bpy.data.objects if o.type=='MESH' and o.visible_get()]
 rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
 for obj in meshes:
  for poly in obj.data.polygons:poly.use_smooth=True
  # Actual subdivision adds silhouette continuity to the older, already textured donors.
  if id in ['boar','spider']:
   mod=obj.modifiers.new('Smooth runtime silhouette','SUBSURF');mod.levels=1;mod.render_levels=1
 rig.animation_data_create();rig.animation_data.action=None
 for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
 used={}
 for alias,name in clips.items():
  action=bpy.data.actions.get(name)
  if id=='crab':action=next((a for a in bpy.data.actions if '|'+name+'|' in a.name),None)
  assert action,(id,name)
  if action.frame_range[1]-action.frame_range[0]<1:
   action=action.copy();action.name=alias+'_still';action.use_frame_range=True;action.frame_start=0;action.frame_end=30
  track=rig.animation_data.nla_tracks.new();track.name=alias;track.strips.new(alias,1,action);used[alias]=action.name
 bpy.context.scene.render.fps=30
 bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
 for obj in meshes:obj.select_set(True)
 path=OUT/(id+'.glb')
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_morph=False,export_cameras=False,export_lights=False,export_apply=True)
 assert hashlib.sha256(source.read_bytes()).hexdigest()==before
 report.append({'id':id,'source':relative,'source_sha256':before,'source_unchanged':True,'runtime':str(path.relative_to(ROOT)),'runtime_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'clips':used,'materials':[m.name for m in bpy.data.materials]})
 print('ALPHA2_CREATURE_PREPARED',id,flush=True)
# Nature is retained in GLB with photographed materials; simplify only oversized scans.
for id in ['coastal_cliff_01','coast_rocks_01','boulder_01','rock_moss_set_02','nettle_plant','flower_heliophila']:
 bpy.ops.wm.read_factory_settings(use_empty=True);source=next((LIB/('ph-'+id)).glob('*.gltf'));bpy.ops.import_scene.gltf(filepath=str(source))
 meshes=[o for o in bpy.data.objects if o.type=='MESH'];faces=sum(len(o.data.polygons) for o in meshes)
 for obj in meshes:
  if faces>22000:
   bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Runtime budget','DECIMATE');mod.ratio=22000/faces;bpy.ops.object.modifier_apply(modifier=mod.name)
  for poly in obj.data.polygons:poly.use_smooth=True
 bpy.ops.export_scene.gltf(filepath=str(OUT/(id+'.glb')),export_format='GLB',export_animations=False,export_cameras=False,export_lights=False,export_apply=True)
 report.append({'id':id,'source':str(source.relative_to(LIB)),'runtime_sha256':hashlib.sha256((OUT/(id+'.glb')).read_bytes()).hexdigest(),'source_faces':faces})
for id in ['coast_sand_01','damp_beach_sand','cliff_side','rock_face','castle_brick_01']:
 target=OUT/id;target.mkdir(exist_ok=True)
 for name in ['albedo.jpg','normal.jpg','roughness.jpg']:shutil.copy2(LIB/('ph-'+id)/name,target/name)
for id,name in {'wreck':'ship-wreck','dock':'structure-platform-dock','watchtower':'tower-watch','barrel':'barrel'}.items():
 source=LIB/'kenney-pirate-kit/Models/GLB format'/(name+'.glb');shutil.copy2(source,OUT/(id+'.glb'))
 report.append({'id':id,'source':str(source.relative_to(LIB)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'runtime_sha256':hashlib.sha256((OUT/(id+'.glb')).read_bytes()).hexdigest()})
(OUT/'Textures').mkdir(exist_ok=True);shutil.copy2(LIB/'kenney-pirate-kit/Models/GLB format/Textures/colormap.png',OUT/'Textures/colormap.png')
(ROOT/'art/library/ALPHA2-RUNTIME-ASSETS.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
