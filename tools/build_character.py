"""Run inside pinned Blender: reproducible editable precursor + shared animated GLB."""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SPEC = json.loads((ROOT / 'art/rig-spec.json').read_text())
OUT = ROOT / 'game/assets/characters'
SOURCE = ROOT / 'art/source'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
MATERIALS = {}
PALETTE = {'skin': 'E6B78D', 'hair': '865E3D', 'dress': '617688', 'leather': '725136', 'metal': 'BDC4CE', 'gem': '247BCB', 'socks': 'D6D0BF', 'eyes': '282D30'}


def material(slot, tone='base'):
    key = f'{slot}_{tone}'
    if key in MATERIALS:
        return MATERIALS[key]
    raw = PALETTE[slot]
    color = [int(raw[i:i+2], 16) / 255 for i in (0, 2, 4)]
    color = [c * .72 if tone == 'dark' else c + (1-c) * .22 if tone == 'light' else c for c in color]
    mat = bpy.data.materials.new(key)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = .95
    MATERIALS[key] = mat
    return mat


def finish(obj, name, slot, bone=None, tone='base'):
    obj.name = name
    obj.data.materials.append(material(slot, tone))
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if bone:
        obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))), 1, 'REPLACE')
        mod = obj.modifiers.new('HumanoidSkin', 'ARMATURE')
        mod.object = rig
        obj.parent = rig
    return obj


def box(name, center, scale, slot, bone=None, tone='base', bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.scale = scale
    if bevel:
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        mod = obj.modifiers.new('FacetedCorners', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj, name, slot, bone, tone)


def blob(name, center, scale, slot, bone=None, tone='base', segments=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=6, radius=1, location=center)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, slot, bone, tone)


def tapered(name, rings, slot, bone=None, segments=12):
    verts = [(rx * math.cos(2*math.pi*i/segments), ry * math.sin(2*math.pi*i/segments), z) for z, rx, ry in rings for i in range(segments)]
    faces = [tuple(reversed(range(segments)))]
    for ring in range(len(rings)-1):
        for i in range(segments):
            faces.append((ring*segments+i, ring*segments+(i+1)%segments, (ring+1)*segments+(i+1)%segments, (ring+1)*segments+i))
    faces.append(tuple((len(rings)-1)*segments+i for i in range(segments)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    finish(obj, name, slot, bone)
    obj.data.materials.append(material(slot, 'dark'))
    obj.data.materials.append(material(slot, 'light'))
    for poly in obj.data.polygons:
        if poly.index % 7 == 0:
            poly.material_index = 1
        elif poly.index % 7 == 3:
            poly.material_index = 2
    obj.select_set(False)
    return obj


arm = bpy.data.armatures.new('humanoid_v1')
rig = bpy.data.objects.new('Humanoid', arm)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
bones = [
    ('root', (0,0,0), (0,0,.2), None),
    ('pelvis', (0,0,.88), (0,0,1.12), 'root'),
    ('spine', (0,0,1.12), (0,0,1.47), 'pelvis'),
    ('head', (0,0,1.47), (0,0,1.85), 'spine'),
]
for side, sign in [('L', 1), ('R', -1)]:
    bones.extend([
        (f'upper_arm.{side}', (sign*.235,0,1.40), (sign*.345,0,1.12), 'spine'),
        (f'forearm.{side}', (sign*.345,0,1.12), (sign*.385,-.015,.88), f'upper_arm.{side}'),
        (f'thigh.{side}', (sign*.13,0,.86), (sign*.13,0,.47), 'pelvis'),
        (f'shin.{side}', (sign*.13,0,.47), (sign*.13,0,.14), f'thigh.{side}'),
        (f'foot.{side}', (sign*.13,0,.14), (sign*.13,-.14,.06), f'shin.{side}'),
    ])
for name, head, tail, parent in bones:
    bone = arm.edit_bones.new(name)
    bone.head, bone.tail = head, tail
    if parent:
        bone.parent = arm.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
rig.select_set(False)

# Shared skin/body: large readable features, with faceted rather than strand detail.
blob('body_head', (0,-.012,1.675), (.246,.204,.255), 'skin', 'head')
box('body_neck', (0,0,1.445), (.125,.13,.19), 'skin', 'head', bevel=.02)
for side, sign in [('L',1),('R',-1)]:
    blob(f'body_ear_{side}', (sign*.241,0,1.655), (.045,.035,.063), 'skin', 'head')
    box(f'body_eye_white_{side}', (sign*.079,-.199,1.687), (.086,.013,.058), 'socks', 'head', 'light', bevel=.01)
    box(f'body_eye_{side}', (sign*.082,-.209,1.687), (.041,.01,.05), 'eyes', 'head', bevel=.006)
    box(f'body_brow_{side}', (sign*.079,-.199,1.735), (.084,.014,.014), 'hair', 'head', 'dark')
    blob(f'body_forearm_{side}', (sign*.365,-.008,1.01), (.048,.05,.148), 'skin', f'forearm.{side}')
    blob(f'body_hand_{side}', (sign*.39,-.02,.879), (.055,.041,.066), 'skin', f'forearm.{side}')
    blob(f'body_leg_{side}', (sign*.13,0,.58), (.078,.082,.28), 'skin', f'thigh.{side}')
    box(f'body_sock_{side}', (sign*.13,0,.30), (.135,.135,.10), 'socks', f'shin.{side}', bevel=.015)
    box(f'body_boot_shaft_{side}', (sign*.13,.012,.193), (.159,.165,.205), 'leather', f'shin.{side}', bevel=.018)
    box(f'body_boot_toe_{side}', (sign*.13,-.072,.082), (.176,.30,.124), 'leather', f'foot.{side}', bevel=.035)
    box(f'body_boot_cuff_{side}', (sign*.13,0,.266), (.179,.184,.045), 'leather', f'shin.{side}', 'dark')
blob('body_nose', (0,-.207,1.647), (.025,.035,.03), 'skin', 'head', 'light', segments=8)
box('body_mouth', (0,-.199,1.594), (.052,.01,.009), 'skin', 'head', 'dark')

for hair in ['bob', 'crop']:
    blob(f'hair_{hair}_crown', (0,.015,1.855), (.268,.22,.118), 'hair', 'head')
    blob(f'hair_{hair}_back', (0,.128,1.705 if hair=='bob' else 1.80), (.254,.136,.205 if hair=='bob' else .10), 'hair', 'head', 'dark')
    for sign in [-1,1]:
        blob(f'hair_{hair}_side_{sign}', (sign*.239,.036,1.665 if hair=='bob' else 1.776), (.082,.145,.193 if hair=='bob' else .09), 'hair', 'head')
    for i in range(5):
        obj = blob(f'hair_{hair}_fringe_{i}', ((i-2)*.084,-.151,1.797+(i%2)*.013), (.070,.084,.083), 'hair', 'head', 'light' if i==1 else 'base', segments=8)

for outfit in ['dress','tunic']:
    prefix = f'outfit_{outfit}'
    tapered(f'{prefix}_torso', [(1.04,.192,.139),(1.22,.218,.146),(1.41,.236,.135)], 'dress', 'spine')
    if outfit == 'dress':
        tapered(f'{prefix}_skirt', [(.54,.384,.274),(.74,.29,.205),(1.05,.193,.145)], 'dress', 'pelvis', segments=16)
    else:
        tapered(f'{prefix}_hem', [(.81,.263,.18),(1.05,.193,.145)], 'dress', 'pelvis')
        for side,sign in [('L',1),('R',-1)]:
            box(f'{prefix}_trousers_{side}', (sign*.13,0,.62), (.16,.173,.38), 'leather', f'thigh.{side}', 'dark', bevel=.02)
    tapered(f'{prefix}_belt', [(1.036,.201,.15),(1.09,.201,.15)], 'leather', 'pelvis')
    box(f'{prefix}_buckle', (0,-.154,1.064), (.074,.023,.063), 'metal', 'pelvis', 'light')
    box(f'{prefix}_buckle_inner', (0,-.167,1.064), (.044,.012,.037), 'leather', 'pelvis', 'dark')
    for side,sign in [('L',1),('R',-1)]:
        blob(f'{prefix}_sleeve_{side}', (sign*.27,0,1.33), (.083,.087,.145), 'dress', f'upper_arm.{side}')
        box(f'{prefix}_cuff_{side}', (sign*.318,0,1.205), (.119,.14,.06), 'dress', f'upper_arm.{side}', 'light', bevel=.012)
        box(f'{prefix}_collar_{side}', (sign*.06,-.136,1.397), (.105,.027,.067), 'dress', 'spine', 'light', bevel=.015)
    for z in [1.32,1.23,1.15]:
        box(f'{prefix}_button_{z}', (0,-.151,z), (.016,.009,.016), 'leather', 'spine', 'dark')

# Join by swappable module. The skin groups and material slots are preserved.
for prefix, final_name in [('body_', 'module_body'), ('hair_bob_', 'hair_bob'), ('hair_crop_', 'hair_crop'), ('outfit_dress_', 'outfit_dress'), ('outfit_tunic_', 'outfit_tunic')]:
    bpy.ops.object.select_all(action='DESELECT')
    objects = [obj for obj in bpy.data.objects if obj.type=='MESH' and obj.name.startswith(prefix)]
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    bpy.context.object.name = final_name

rig.animation_data_create()
for name, end in [('idle_loop',61),('walk_loop',25),('interact',31)]:
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    for frame in range(1,end+1):
        phase = (frame-1)/(end-1)*math.tau
        for bone in rig.pose.bones:
            bone.rotation_mode='XYZ'
            bone.rotation_euler=(0,0,0)
            bone.location=(0,0,0)
        if name=='walk_loop':
            for side,sign in [('L',1),('R',-1)]:
                rig.pose.bones[f'thigh.{side}'].rotation_euler.x = math.sin(phase)*.57*sign
                rig.pose.bones[f'shin.{side}'].rotation_euler.x = max(0, math.sin(phase)*sign)*.31
                rig.pose.bones[f'upper_arm.{side}'].rotation_euler.x = -math.sin(phase)*.23*sign
                rig.pose.bones[f'forearm.{side}'].rotation_euler.x = -.12
            rig.pose.bones['pelvis'].location.y = .012*math.cos(phase*2)
            rig.pose.bones['spine'].rotation_euler.y = .035*math.sin(phase)
        elif name=='idle_loop':
            rig.pose.bones['spine'].rotation_euler.x = .018*math.sin(phase)
            rig.pose.bones['head'].rotation_euler.z = .018*math.sin(phase)
        else:
            rig.pose.bones['forearm.R'].rotation_euler.x = -.9*math.sin(phase/2)
            rig.pose.bones['upper_arm.R'].rotation_euler.x = -.4*math.sin(phase/2)
        for bone in rig.pose.bones:
            bone.keyframe_insert('rotation_euler', frame=frame, group=bone.name)
            bone.keyframe_insert('location', frame=frame, group=bone.name)

rig.animation_data.action = bpy.data.actions['idle_loop']
bpy.context.scene.render.fps = SPEC['animation_fps']
bpy.context.scene.frame_start=1
bpy.context.scene.frame_end=61
bpy.context.scene.frame_set(1)
rig['rig_family']='humanoid_v1'
rig['forward']='Blender -Y / Godot +Z'
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / 'humanoid-v1.blend'))
options = {'filepath':str(OUT/'humanoid-v1.glb'), 'export_format':'GLB', 'export_animations':True, 'export_animation_mode':'ACTIONS', 'export_frame_range':False, 'export_force_sampling':True, 'export_yup':True, 'export_def_bones':True}
valid = {p.identifier for p in bpy.ops.export_scene.gltf.get_rna_type().properties}
bpy.ops.export_scene.gltf(**{k:v for k,v in options.items() if k in valid})

# A separate equipment source: crossguard origin, tip down, pommel up.
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
box('SwordBlade', (0,0,-.52), (.17,.055,.95), 'metal', tone='base', bevel=.025)
bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0, radius2=.12, depth=.20, location=(0,0,-1.07), rotation=(0,0,math.pi/4))
finish(bpy.context.object,'SwordTip','metal')
box('SwordGuard', (0,0,-.01), (.43,.078,.07), 'metal', tone='dark', bevel=.018)
box('SwordGrip', (0,0,.16), (.064,.064,.27), 'leather', bevel=.012)
blob('SwordGemMount', (0,0,.355), (.07,.045,.105), 'metal', tone='light', segments=8)
blob('SwordBlueGem', (0,-.043,.365), (.046,.018,.074), 'gem', tone='light', segments=8)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'greatsword-v1.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'greatsword-v1.glb'), export_format='GLB', export_animations=False)
print('ASSET_BUILD_OK humanoid-v1.glb greatsword-v1.glb')
