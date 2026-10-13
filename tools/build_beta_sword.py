"""Customize Quandtum's CC0 blade in a separate editable Beta Blender source.

Separate Beta longsword contract: source tip -.794837 and grip pivot .10.
Geometry is authored in Blender Z; glTF converts it to Godot Y.
No downloaded text, drivers, materials or addon code are evaluated/exported.
"""
import bpy, bmesh, math, json, hashlib, random
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/library/source/quandtum-knights-trust/LongSword_KnightsTrust_Quandtum.blend'
OUT=ROOT/'art/character/beta-sword-review'; OUT.mkdir(parents=True,exist_ok=True)
source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(SOURCE),load_ui=False,use_scripts=False)
donor=bpy.data.objects['Sword.LoPoly'].data
# Take the donor's actual diamond-section blade, excluding its decorative wings.
faces=[list(p.vertices) for p in donor.polygons if min(donor.vertices[i].co.z for i in p.vertices)>=8.2]
indices=sorted({i for f in faces for i in f}); remap={i:j for j,i in enumerate(indices)}
verts=[]
for i in indices:
    v=donor.vertices[i].co; phase=(v.z-8.248)/(26.883541107177734-8.248)
    verts.append((v.x*(.030/1.472)*(1-.22*phase),v.y*(.003/1.472/.29252204298973083)*(1-.4*phase),-.025-phase*(1.17/1.472-.025)))
faces=[[remap[i] for i in f] for f in faces]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=64
scene.world=bpy.data.worlds.new('Studio'); scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.22,.25,.3,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.55

def material(name,color,metallic,roughness):
    m=bpy.data.materials.new(name); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metallic; p.inputs['Roughness'].default_value=roughness
    return m
steel=material('SteelOriginal',(.52,.58,.65),1,.27)
edge=material('SteelEdge',(.66,.7,.74),1,.21)
hilt=material('ForgedHilt',(.27,.3,.33),1,.32)
leather=material('BrownLeather',(.065,.027,.013),0,.8)
seam=material('LeatherSeam',(.08,.034,.016),0,.86)
gem=material('gem_beta_blue',(.025,.14,.32),.22,.2)

def mesh(name,vs,fs,mat):
    data=bpy.data.meshes.new(name); data.from_pydata(vs,[],fs); data.update()
    o=bpy.data.objects.new(name,data); scene.collection.objects.link(o); data.materials.append(mat)
    bm=bmesh.new(); bm.from_mesh(data); bmesh.ops.holes_fill(bm,edges=[e for e in bm.edges if e.is_boundary],sides=0)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(data); bm.free()
    return o
blade=mesh('SwordBlade',verts,faces,steel)
blade['CC0_donor']='Quandtum / Long Sword – Knights Trust; original diamond blade topology, resized/tapered, ornamental wings removed'
blade['blade_contract']='Crossguard origin; Godot Y tip -0.7948369565; grip pivot .10; actor scale 1.6 and visual .92'

def bevel(o,width=.001,segments=3):
    mod=o.modifiers.new('Forged edge rounding','BEVEL'); mod.width=width; mod.segments=segments
    mod=o.modifiers.new('Weighted surface normals','WEIGHTED_NORMAL'); mod.keep_sharp=True; mod.weight=50

def cylinder(name,radius,depth,z,mat,vertices=32,scale_y=1):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=(0,0,z))
    o=bpy.context.object; o.name=name; o.scale.y=scale_y; o.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bevel(o,min(radius*.1,.0008)); return o

# A restrained slightly forward-curved crossguard, rather than the donor's gold sunburst.
guard_verts=[]; guard_faces=[]
for x in [-.0951,-.08,-.043,0,.043,.08,.0951]:
    z=-.008-.020*(abs(x)/.0951)**1.7
    for dy,dz in [(-.006,-.008),(.006,-.008),(.006,.008),(-.006,.008)]: guard_verts.append((x,dy,z+dz))
for n in range(6):
    for a in range(4): guard_faces.append((n*4+a,n*4+(a+1)%4,(n+1)*4+(a+1)%4,(n+1)*4+a))
guard_faces+=[(3,2,1,0),(24,25,26,27)]
guard=mesh('SwordGuard',guard_verts,guard_faces,hilt); bevel(guard,.0018)
# Oval 32cm two-handed leather grip; right hand near the guard, left behind it.
grip=cylinder('SwordGrip',.01155,.217,.1125,leather,32,.77)
for z in [.005,.221]: cylinder('SwordGripFerrule',.012,.014,z,hilt,32,.78)
# Close spiral seam modeled in the editable source (no proprietary texture).
curve=bpy.data.curves.new('Leather wrap seam','CURVE'); curve.dimensions='3D'; curve.bevel_depth=.00038; curve.bevel_resolution=1
spline=curve.splines.new('POLY'); spline.points.add(384)
for i,p in enumerate(spline.points):
    t=i/384; a=t*math.tau*16
    p.co=(.01160*math.cos(a),.00894*math.sin(a),.014+t*.197,1)
wrap=bpy.data.objects.new('SwordLeatherWrap',curve); scene.collection.objects.link(wrap); curve.materials.append(seam)
# Flattened steel wheel pommel; small blue inset keeps the game's weapon identity.
pommel=cylinder('SwordPommel',.025,.017,0,hilt,48)
pommel.rotation_euler.x=math.pi/2; pommel.location.z=.25
for side in [-1,1]:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=1,location=(0,side*.010,.25))
    o=bpy.context.object; o.name='SwordBlueInset'; o.scale=(.009,.003,.009); o.data.materials.append(gem)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)

gear=[o for o in scene.objects if o.type in {'MESH','CURVE'}]
for o in gear:
    bpy.context.view_layer.objects.active=o; o.select_set(True)
    if o.type=='CURVE': bpy.ops.object.convert(target='MESH')
    for other in scene.objects: other.select_set(False)
    o.select_set(True)
    for mod in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
    o.select_set(False)
gear=[o for o in scene.objects if o.type=='MESH']
scene['license']='CC0-1.0; original blade by Quandtum; Beta customization CC0'
scene['source_url']='https://opengameart.org/content/long-sword-%E2%80%93-knights-trust'
scene['presentation_scale']=1.6

# Save model-only edit state. Review lights/camera are added after the GLB export.
source_out=ROOT/'art/source/beta-greatsword.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(source_out))
runtime=ROOT/'game/assets/characters/greatsword-beta.glb'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(runtime),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)

def aim(o,point): o.rotation_euler=(Vector(point)-o.location).to_track_quat('-Z','Y').to_euler()
def area(name,position,energy,size,color):
    data=bpy.data.lights.new(name,'AREA'); data.energy=energy; data.shape='DISK'; data.size=size; data.color=color
    o=bpy.data.objects.new(name,data); scene.collection.objects.link(o); o.location=position; aim(o,(0,0,-.4))
area('Key',(-1,-2,1.8),220,2,(.86,.93,1))
area('Edge',(1.2,.8,.3),260,1.5,(1,.91,.77))
area('Long reflection',(.25,-.7,-.5),35,.7,(.7,.81,1))
camera_data=bpy.data.cameras.new('Review Camera'); camera=bpy.data.objects.new('Review Camera',camera_data); scene.collection.objects.link(camera)
camera.location=(.2,-2.6,.18); aim(camera,(0,0,-.265)); camera_data.type='ORTHO'; camera_data.ortho_scale=1.25; scene.camera=camera
scene.render.resolution_x=700; scene.render.resolution_y=1100; scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'; scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(OUT/'custom-greatsword.png'); bpy.ops.render.render(write_still=True)
camera.location=(.14,-1.2,.3); aim(camera,(0,0,.13)); camera_data.ortho_scale=.36
scene.render.resolution_x=900; scene.render.resolution_y=750; scene.render.filepath=str(OUT/'hilt-detail.png'); bpy.ops.render.render(write_still=True)
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_hash
report={'license':'CC0-1.0','donor_author':'Quandtum','source_url':scene['source_url'],'donor_sha256':source_hash,'donor_unchanged':True,'derived_source':str(source_out.relative_to(ROOT)),'source_sha256':hashlib.sha256(source_out.read_bytes()).hexdigest(),'runtime_sha256':hashlib.sha256(runtime.read_bytes()).hexdigest(),'runtime':str(runtime.relative_to(ROOT)),'donor_blade_vertices':len(indices),'donor_blade_faces':len(faces),'triangles':sum(len(p.vertices)-2 for o in gear for p in o.data.polygons),'presentation_scale':1.6,'visual_scale':.92,'blade_length_m':1.17,'blade_width_m':.06,'blade_thickness_m':.006,'guard_width_m':.28,'grip_diameter_m':.034,'blade_tip_local_y':-1.17/1.472,'grip_pivot_local_y':.10,'reach_m':1.17+.10*1.472,'overall_length_m':1.17+.275*1.472,'note':'Historically proportioned longsword; still almost as tall as the 1.67m heroine. Ground catches and damage use its shorter actual steel.','embedded_texts':len(bpy.data.texts),'drivers':sum(len(o.animation_data.drivers) if o.animation_data else 0 for o in gear)}
(OUT/'customization.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
