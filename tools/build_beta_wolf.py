"""Derive an editable, softer skinned wolf with original fur maps/cards.
Reads the already scanned local Quaternius donor, never executes donor code.
"""
import bpy,bmesh,json,random,hashlib,math
from mathutils import Vector
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DONOR=ROOT/'art/library/source/quaternius-animals/glTF/Wolf.gltf'
DEST=ROOT/'game/assets/creatures';TEX=DEST/'wolf-fur'
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
bpy.ops.import_scene.gltf(filepath=str(DONOR))
wolf=bpy.data.objects['Wolf'];rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
rig.data.pose_position='REST'
for obj in list(bpy.data.objects):
    if obj.type not in ['MESH','ARMATURE'] or (obj.type=='MESH' and obj!=wolf):bpy.data.objects.remove(obj,do_unlink=True)
bpy.context.view_layer.objects.active=wolf;wolf.select_set(True);rig.select_set(False)
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.remove_doubles(threshold=.0001);bpy.ops.object.mode_set(mode='OBJECT')
# Preserve the donor rig/weights; soften the coat silhouette without a body remake.
sub=wolf.modifiers.new('Coat silhouette','SUBSURF');sub.levels=1;sub.render_levels=1
bpy.ops.object.modifier_move_up(modifier=sub.name)
bpy.ops.object.modifier_apply(modifier=sub.name)
for face in wolf.data.polygons:face.use_smooth=True
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT')
def texture(name):return bpy.data.images.load(str(TEX/name),check_existing=True)
for mat in wolf.data.materials:
    if mat.name not in ['Main','Main_Light']:continue
    nodes=mat.node_tree.nodes;links=mat.node_tree.links;bsdf=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
    al=nodes.new('ShaderNodeTexImage');al.image=texture('coat-albedo.png')
    tint=nodes.new('ShaderNodeMixRGB');tint.blend_type='MULTIPLY';tint.inputs[0].default_value=1
    tint.inputs[2].default_value=(1.22,1.18,1.08,1) if mat.name=='Main_Light' else (.84,.86,.87,1)
    links.new(al.outputs['Color'],tint.inputs[1]);links.new(tint.outputs[0],bsdf.inputs['Base Color'])
    normal=nodes.new('ShaderNodeTexImage');normal.image=texture('coat-normal.png');normal.image.colorspace_settings.name='Non-Color'
    nm=nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.65;links.new(normal.outputs['Color'],nm.inputs['Color']);links.new(nm.outputs[0],bsdf.inputs['Normal'])
    rough=nodes.new('ShaderNodeTexImage');rough.image=texture('coat-roughness.png');rough.image.colorspace_settings.name='Non-Color';links.new(rough.outputs['Color'],bsdf.inputs['Roughness'])
# Add small weighted tapered tufts, concentrated on neck/back/tail, not paws/eyes.
verts=[];faces=[];uvs=[];weights=[];randomizer=random.Random(27027)
for face in wolf.data.polygons:
    if face.material_index not in [0,2]:continue
    center=face.center;normal=face.normal
    if center.z<.65 or (center.y < -1.75 and center.z>1.8):continue
    if randomizer.random()>.38:continue
    if normal.z<-.25:continue
    # Rest-space flow follows the coat toward the rump, with a downward flank slope.
    flow=Vector((0,1,-.45));flow-=normal*flow.dot(normal)
    if flow.length<.1:flow=normal.cross(Vector((1,0,0)))
    flow.normalize();side=normal.cross(flow).normalized()
    length=randomizer.uniform(.13,.23);width=randomizer.uniform(.012,.028)
    root=center+normal*.004;tip=root+flow*length+normal*length*.17
    groups={}
    for vi in face.vertices:
        for g in wolf.data.vertices[vi].groups:groups[g.group]=groups.get(g.group,0)+g.weight/len(face.vertices)
    start=len(verts)
    for p in [root-side*width*.5,root+side*width*.5,tip+side*width*.08,tip-side*width*.08]:verts.append(p);weights.append(groups)
    faces.append((start,start+1,start+2,start+3));uvs.extend([(0,0),(1,0),(1,1),(0,1)])
mesh=bpy.data.meshes.new('Weighted coat tufts');mesh.from_pydata(verts,[],faces);mesh.update()
tufts=bpy.data.objects.new('FurTufts',mesh);bpy.context.collection.objects.link(tufts)
for group in wolf.vertex_groups:tufts.vertex_groups.new(name=group.name)
for i,group in enumerate(weights):
    for gi,w in group.items():tufts.vertex_groups[gi].add([i],w,'REPLACE')
tufts.matrix_world=wolf.matrix_world.copy();tufts.parent=wolf.parent
arm=tufts.modifiers.new('Animal skin','ARMATURE');arm.object=rig
uv=mesh.uv_layers.new(name='TuftUV')
for i,item in enumerate(uv.data):item.uv=uvs[i]
mat=bpy.data.materials.new('FurTips');mat.use_nodes=True;mat.surface_render_method='DITHERED';mat.use_backface_culling=False
nodes=mat.node_tree.nodes;bsdf=nodes.get('Principled BSDF');tx=nodes.new('ShaderNodeTexImage');tx.image=texture('fur-tuft.png')
mat.node_tree.links.new(tx.outputs['Color'],bsdf.inputs['Base Color']);mat.node_tree.links.new(tx.outputs['Alpha'],bsdf.inputs['Alpha']);bsdf.inputs['Roughness'].default_value=.92
mesh.materials.append(mat)
rig.data.pose_position='POSE';bpy.context.scene.frame_set(0)
for image in bpy.data.images:
    if image.source=='FILE':image.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/source/beta-wolf.blend'))
# Export all supplied clips through NLA (same names and durations as donor).
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(DEST/'beta-wolf.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_skins=True,export_yup=True)
report={'source':'art/source/beta-wolf.blend','runtime':'game/assets/creatures/beta-wolf.glb','donor':str(DONOR.relative_to(ROOT)).replace('\\','/'),'donor_sha256':hashlib.sha256(DONOR.read_bytes()).hexdigest(),'license':'Quaternius legacy CC0; use embedded in game','original_fur_maps_license':'CC0-1.0','body_vertices':len(wolf.data.vertices),'tufts':len(faces),'clips':[a.name for a in bpy.data.actions]}
for key,path in [('source_sha256',ROOT/report['source']),('runtime_sha256',ROOT/report['runtime'])]:report[key]=hashlib.sha256(path.read_bytes()).hexdigest()
(ROOT/'art/library/beta-wolf-customization.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('BETA_WOLF',json.dumps(report))
