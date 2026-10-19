"""Static-only appearance alternatives from the approved Beta source.

Run in pinned Blender. Never replaces a runtime asset or fits/regenerates motion.
The old rejected-model gate remains untouched; this writes a separate candidate.
"""
from pathlib import Path
import hashlib
import json
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art/source/beta-heroine.blend'
DEST = ROOT / 'art/source/appearance-candidates.blend'
EVIDENCE = ROOT / 'art/character/appearance-review'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bell(value, center, radius):
    return max(0.0, 1.0 - abs(value-center)/radius) ** 2


assert bpy.app.version[:3] == (4, 5, 3), 'Use the pinned Blender 4.5.3'
before = sha(SOURCE)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE), load_ui=False, use_scripts=False)
scene = bpy.context.scene
meshes = [o for o in scene.objects if o.type == 'MESH']
source_rig = next(o for o in scene.objects if o.type == 'ARMATURE')
source_rig.animation_data_clear()
for bone in source_rig.pose.bones:
    bone.matrix_basis.identity()
bpy.context.view_layer.update()
source_objects = meshes + [source_rig]
# The saved sleeves reuse a dress-only baked atlas: their UVs sample its black
# background (also visible in the accepted GLB). Repair that material only in
# this separate review stage, using the already-owned seamless matching denim.
fallback_image=bpy.data.images['Continuous matching denim albedo']
repairs={}
for source in meshes:
    for slot in source.material_slots:
        material=slot.material
        if material is None or 'punkduck_black_cocktail_dress' not in material.name:continue
        if material.name in repairs:continue
        repair=material.copy();repair.name='Review only repaired denim'
        nodes=repair.node_tree.nodes;links=repair.node_tree.links
        original=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
        output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
        albedo=original.inputs['Base Color'].links[0].from_socket
        bw=nodes.new('ShaderNodeRGBToBW');links.new(albedo,bw.inputs[0])
        mask=nodes.new('ShaderNodeMath');mask.operation='LESS_THAN';mask.inputs[1].default_value=.006;links.new(bw.outputs[0],mask.inputs[0])
        fallback=nodes.new('ShaderNodeBsdfPrincipled');fallback.inputs['Roughness'].default_value=.72
        texture=nodes.new('ShaderNodeTexImage');texture.image=fallback_image;links.new(texture.outputs['Color'],fallback.inputs['Base Color'])
        mix=nodes.new('ShaderNodeMixShader');links.new(mask.outputs[0],mix.inputs[0]);links.new(original.outputs[0],mix.inputs[1]);links.new(fallback.outputs[0],mix.inputs[2]);links.new(mix.outputs[0],output.inputs['Surface'])
        repairs[material.name]=repair
groups = {}
counts = {}
specs = [('original', 'ORIGINAL SHAPE'), ('soft_cheeks', 'FACE: SOFTER CHEEKS'),
         ('short_layers', 'HAIR: SHORTER LAYERS'), ('subtle_shape', 'BODY: SUBTLE SILHOUETTE')]
for index, (kind, label) in enumerate(specs):
    collection = bpy.data.collections.new('Appearance review '+kind)
    scene.collection.children.link(collection)
    root = bpy.data.objects.new('Candidate '+kind, None)
    collection.objects.link(root)
    root['review_status'] = 'existing_approved_default' if kind == 'original' else 'awaiting_static_model_review'
    root['animation_fitting_approved'] = False
    rig = source_rig.copy();rig.data = source_rig.data.copy();rig.animation_data_clear()
    collection.objects.link(rig);rig.parent=root
    changes=0
    for source in meshes:
        obj=source.copy();obj.data=source.data.copy();collection.objects.link(obj)
        for slot in obj.material_slots:
            if slot.material and slot.material.name in repairs:slot.material=repairs[slot.material.name]
        transform=source.matrix_world.copy();obj.parent=root;obj.matrix_world=transform
        for modifier in obj.modifiers:
            if modifier.type=='ARMATURE':modifier.object=rig
        inverse=transform.inverted()
        for vertex in obj.data.vertices:
            p=transform@vertex.co;old=p.copy()
            if kind=='soft_cheeks' and source.name=='Static_Human_0':
                weight=bell(p.z,1.515,.075)*bell(abs(p.x),.055,.045)
                # Preserve the eye region, neck attachment and central mouth seam.
                if p.y<.05 and p.z<1.548:p.x*=1+.10*weight
            elif kind=='short_layers' and 'relaxed layered hair_0' in source.name:
                if p.z<1.48:
                    weight=min(1.0,(1.48-p.z)/.18)
                    p.x*=1-.32*weight
                    limit=.13+.025*max(0,min(1,(p.z-1.4)/.18))
                    p.x=max(-limit,min(limit,p.x))
                    p.z=1.48+(p.z-1.48)*.45
            elif kind=='subtle_shape' and not any(word in source.name.lower() for word in ['hair','crown','high-poly','teeth','tongue','eyebrow','eyelash']):
                if abs(p.x)<.22:
                    p.x*=1-.055*bell(p.z,1.03,.17)+.025*bell(p.z,.82,.16)
            if (p-old).length>1e-9:
                vertex.co=inverse@p;changes+=1
        obj.data.update()
    root.location.x=(index-1.5)*.94
    groups[kind]=root;counts[kind]=changes
    text_data=bpy.data.curves.new(label,'FONT');text_data.body=label;text_data.align_x='CENTER';text_data.size=.065
    text=bpy.data.objects.new(label,text_data);collection.objects.link(text)
    text.parent=root;text.location=(0,-.05,1.91);text.rotation_euler=(math.pi/2,0,0)
    material=bpy.data.materials.new('Review label');material.diffuse_color=(.8,.74,.56,1);text.data.materials.append(material)

for obj in source_objects:bpy.data.objects.remove(obj,do_unlink=True)
for obj in list(scene.objects):
    if obj.type in {'LIGHT','CAMERA'}:bpy.data.objects.remove(obj,do_unlink=True)

scene.render.engine='CYCLES';scene.cycles.samples=32
scene.render.image_settings.file_format='PNG';scene.render.resolution_percentage=100
scene.render.resolution_x=1800;scene.render.resolution_y=1000
scene.render.film_transparent=False
scene.world=bpy.data.worlds.new('Neutral review');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.045,.06,.05,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.45
target=Vector((0,0,1.0))
for at,energy,size in [((-2,-4,4),450,4),((3,-2,2.5),250,3),((0,2,3),400,3)]:
    data=bpy.data.lights.new('Review light','AREA');data.energy=energy;data.shape='DISK';data.size=size
    obj=bpy.data.objects.new('Review light',data);scene.collection.objects.link(obj);obj.location=at
    obj.rotation_euler=(target-obj.location).to_track_quat('-Z','Y').to_euler()
data=bpy.data.cameras.new('Static option sheet');data.type='ORTHO';data.ortho_scale=4.0
camera=bpy.data.objects.new('Static option sheet',data);scene.collection.objects.link(camera)
camera.location=(0,-6,1.0);camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();scene.camera=camera
scene.view_settings.view_transform='AgX'
EVIDENCE.mkdir(parents=True,exist_ok=True)
scene.render.filepath=str(EVIDENCE/'appearance-static-options.png')
bpy.ops.render.render(write_still=True)
# Save the editable, animation-free review stage, leaving source and runtime intact.
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(DEST))
# A closer comparison makes the intentionally bounded cheek change reviewable.
for kind,root in groups.items():
    if kind in {'short_layers','subtle_shape'}:
        for obj in root.children_recursive:obj.hide_render=True
    else:
        root.location.x=-.235 if kind=='original' else .235
        for obj in root.children:
            if obj.type=='FONT':obj.data.size=.032;obj.location.z=1.81
data.ortho_scale=.98;target=Vector((0,0,1.52));camera.location=(0,-6,1.52)
camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.resolution_x=1400;scene.render.resolution_y=900
scene.render.filepath=str(EVIDENCE/'appearance-face-options.png')
bpy.ops.render.render(write_still=True)
assert sha(SOURCE)==before,'Approved source unexpectedly changed'
report={'status':'awaiting_static_model_review','source':str(SOURCE.relative_to(ROOT)),
        'source_sha256':before,'candidate_source':str(DEST.relative_to(ROOT)),
        'candidate_sha256':sha(DEST),'render':'appearance-static-options.png',
        'render_sha256':sha(EVIDENCE/'appearance-static-options.png'),
        'face_render':'appearance-face-options.png','face_render_sha256':sha(EVIDENCE/'appearance-face-options.png'),
        'blender':bpy.app.version_string,'modified_vertices':counts,
        'rig_rest_changes':0,'animation_fitting':False,'runtime_replaced':False,
        'candidate_only_material_repair':'Dress-atlas black background sampled by sleeve UVs is filled using existing seamless matching denim; all review columns share this repair. Approved runtime/default/source untouched.',
        'notes':'Subtle local surface alternatives only; unchanged rig rests, heights, hands and existing approved sources. Review before any animation fitting or runtime adoption. Original shape column shares review-only denim repair for fair comparison.'}
(EVIDENCE/'review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('APPEARANCE_STATIC_REVIEW',json.dumps(report))
