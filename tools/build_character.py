"""Run inside pinned Blender: reproducible editable precursor + shared animated GLB."""
import bpy
# Keep one editable source; project cleanup policy excludes backup copies.
bpy.context.preferences.filepaths.save_version = 0
import math
import json
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
SPEC = json.loads((ROOT / 'art/rig-spec.json').read_text())
MOTION = json.loads((ROOT / 'game/content/sword_motion.json').read_text())
OUT = ROOT / 'game/assets/characters'
SOURCE = ROOT / 'art/source'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
MATERIALS = {}
PALETTE = {'skin': 'E6B78D', 'hair': '865E3D', 'dress': '617688', 'leather': '725136', 'metal': 'BDC4CE', 'gem': '247BCB', 'socks': 'D6D0BF', 'eyes': '282D30', 'cream': 'DDD0B5', 'rust': '8B402B', 'wrap': '252528', 'flame': 'F1882D'}


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


def blob(name, center, scale, slot, bone=None, tone='base', segments=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=8, radius=1, location=center)
    obj = bpy.context.object
    obj.scale = scale
    finish(obj, name, slot, bone, tone)
    if slot == 'hair':
        # Broken painterly values on individual facets, shared palette remains recolorable.
        obj.data.materials.append(material(slot, 'dark'))
        obj.data.materials.append(material(slot, 'light'))
        for poly in obj.data.polygons:
            if poly.index % 13 == 0:
                poly.material_index = 1
            elif poly.index % 11 == 0:
                poly.material_index = 2
    return obj


def tapered(name, rings, slot, bone=None, segments=24):
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
    triangulate = obj.modifiers.new('ClothFacets', 'TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=triangulate.name)
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
bones += [('hair_sway', (0,.05,1.82), (0,.05,1.55), 'head'), ('skirt_sway', (0,0,1.05), (0,0,.55), 'pelvis')]
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
    arm_prefix = 'left_arm_human' if side == 'L' else 'body'
    blob(f'{arm_prefix}_forearm_{side}', (sign*.365,-.008,1.01), (.048,.05,.148), 'skin', f'forearm.{side}')
    blob(f'{arm_prefix}_hand_{side}', (sign*.39,-.02,.879), (.055,.041,.066), 'skin', f'forearm.{side}')
    blob(f'body_leg_{side}', (sign*.13,0,.58), (.078,.082,.28), 'skin', f'thigh.{side}')
    box(f'footwear_boots_sock_{side}', (sign*.13,0,.30), (.135,.135,.10), 'socks', f'shin.{side}', bevel=.015)
    box(f'footwear_boots_shaft_{side}', (sign*.13,.012,.193), (.159,.165,.205), 'leather', f'shin.{side}', bevel=.018)
    box(f'footwear_boots_toe_{side}', (sign*.13,-.055,.082), (.151,.23,.110), 'leather', f'foot.{side}', bevel=.030)
    box(f'footwear_boots_cuff_{side}', (sign*.13,0,.266), (.179,.184,.045), 'leather', f'shin.{side}', 'dark')
    blob(f'footwear_bare_ankle_{side}', (sign*.13,0,.185), (.073,.077,.16), 'skin', f'shin.{side}')
    blob(f'footwear_bare_foot_{side}', (sign*.13,-.058,.065), (.073,.13,.054), 'skin', f'foot.{side}')
blob('body_nose', (0,-.207,1.647), (.025,.035,.03), 'skin', 'head', 'light', segments=8)
box('body_mouth', (0,-.199,1.594), (.052,.01,.009), 'skin', 'head', 'dark')

for hair in ['bob', 'crop', 'headscarf']:
    blob(f'hair_{hair}_crown', (0,.015,1.855), (.268,.22,.118), 'hair', 'head')
    blob(f'hair_{hair}_back', (0,.128,1.705 if hair=='bob' else 1.80), (.254,.136,.205 if hair=='bob' else .10), 'hair', 'head', 'dark')
    for sign in [-1,1]:
        blob(f'hair_{hair}_side_{sign}', (sign*.239,.036,1.665 if hair=='bob' else 1.776), (.082,.145,.193 if hair=='bob' else .09), 'hair', 'head')
    for i in range(5):
        obj = blob(f'hair_{hair}_fringe_{i}', ((i-2)*.084,-.151,1.797+(i%2)*.013), (.070,.084,.083), 'hair', 'head', 'light' if i==1 else 'base', segments=8)
    if hair == 'headscarf':
        blob('hair_headscarf_cloth', (0,.04,1.85), (.277,.228,.135), 'cream', 'head')
        blob('hair_headscarf_knot', (.20,.16,1.78), (.09,.08,.09), 'cream', 'head', 'dark')
        box('hair_headscarf_tail', (.23,.13,1.64), (.09,.047,.22), 'cream', 'head', 'light', bevel=.02)

# Broken crown silhouette: overlapping angular locks and small flyaways.
for i in range(13):
    a=i*2.399
    r=.08+.012*i
    blob(f'hair_bob_crownlock_{i}', (r*math.cos(a),r*.72*math.sin(a),1.85+.02*math.sin(i)), (.083,.072,.080), 'hair', 'head', 'light' if i%4==0 else 'base', segments=8)
for sign in [-1,1]:
    blob(f'hair_bob_flyaway_{sign}', (sign*.275,.025,1.74), (.058,.024,.041), 'hair', 'hair_sway', segments=6)

# Layered angular bob locks, distinct from the underlying crown.
for i in range(22):
    angle=math.tau*i/22
    x,y=.249*math.cos(angle),.19*math.sin(angle)+.028
    if y < -.105:
        continue
    lock=blob(f'hair_bob_lock_{i}', (x,y,1.67+.025*math.sin(i*2.7)), (.050,.050,.19), 'hair', 'hair_sway', ['base','dark','light'][i%3], segments=8)
for i in range(9):
    x=(i-4)*.048
    blob(f'hair_bob_bang_{i}', (x,-.188,1.79+.035*math.cos(i)), (.039,.037,.103), 'hair', 'hair_sway', 'light' if i%4==0 else 'base', segments=8)
for side,sign in [('L',1),('R',-1)]:
    for j in range(4):
        box(f'footwear_boots_lace_{side}_{j}', (sign*.13,-.086,.14+j*.033), (.12,.012,.012), 'leather', f'shin.{side}', 'light', bevel=.004)
    box(f'footwear_boots_sole_{side}', (sign*.13,-.05,.024), (.160,.245,.030), 'leather', f'foot.{side}', 'dark', bevel=.012)
    for j in range(3):
        blob(f'body_freckle_{side}_{j}', (sign*(.11+j*.024),-.189,1.646+(j%2)*.013), (.004,.004,.004), 'leather', 'head', segments=6)

for outfit in ['dress','tunic','workdress']:
    prefix = f'outfit_{outfit}'
    if outfit == 'workdress':
        tapered(f'{prefix}_blouse', [(1.05,.21,.16),(1.23,.25,.17),(1.41,.25,.15)], 'cream', 'spine')
        tapered(f'{prefix}_skirt', [(.14,.42,.30),(.6,.36,.25),(1.07,.21,.16)], 'dress', 'pelvis', segments=16)
        tapered(f'{prefix}_hem', [(.14,.427,.305),(.27,.405,.292)], 'rust', 'pelvis')
        tapered(f'{prefix}_bodice', [(1.05,.216,.168),(1.24,.258,.179)], 'dress', 'spine')
        tapered(f'{prefix}_belt', [(1.05,.219,.17),(1.11,.219,.17)], 'rust', 'pelvis')
        for side, sign in [('L',1),('R',-1)]:
            box(f'{prefix}_strap_{side}', (sign*.15,-.153,1.34), (.065,.035,.26), 'rust', 'spine', bevel=.014)
            blob(f'{prefix}_sleeve_{side}', (sign*.275,0,1.33), (.10,.105,.145), 'cream', f'upper_arm.{side}')
            box(f'{prefix}_cuff_{side}', (sign*.319,-.004,1.21), (.14,.153,.065), 'cream', f'upper_arm.{side}', 'light', bevel=.02)
            for z in [1.29,1.34]:
                box(f'{prefix}_embroidery_{side}_{z}', (sign*.27,-.104,z), (.038,.013,.025), 'rust', f'upper_arm.{side}')
        continue
    tapered(f'{prefix}_torso', [(1.04,.192,.139),(1.22,.218,.146),(1.41,.236,.135)], 'dress', 'spine')
    if outfit == 'dress':
        skirt=tapered(f'{prefix}_skirt', [(.52,.425,.38),(.62,.395,.33),(.80,.30,.255),(1.05,.193,.145)], 'dress', 'pelvis', segments=32)
        # Anchored waist, moving hem; pleat depth is modeled, not painted.
        sway=skirt.vertex_groups.new(name='skirt_sway')
        pelvis=skirt.vertex_groups['pelvis']
        for v in skirt.data.vertices:
            weight=max(0,min(.90,(1.05-v.co.z)/.53))
            sway.add([v.index],weight,'REPLACE')
            pelvis.add([v.index],1-weight,'REPLACE')
            if v.co.z<.95 and v.index%2==0:
                v.co.x*=1.055; v.co.y*=1.055
        box(f'{prefix}_belt_tail', (.20,-.16,.88), (.045,.025,.32), 'leather', 'skirt_sway', 'dark', bevel=.008)
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

# The mother's crude anatomical LEFT prosthetic, with a separate removable wrap.
box('arm_prototype_upper', (.318,0,1.245), (.09,.09,.20), 'metal', 'upper_arm.L', 'dark', bevel=.006)
blob('arm_prototype_hinge', (.345,0,1.12), (.074,.065,.062), 'metal', 'forearm.L', 'dark', segments=8)
for sign in [-1,1]:
    box(f'arm_prototype_rod_{sign}', (.364+sign*.027,0,1.015), (.018,.026,.19), 'metal', 'forearm.L')
box('arm_prototype_plate', (.368,-.045,1.005), (.11,.018,.14), 'metal', 'forearm.L', 'dark')
for z in [1.065,.95]:
    for x in [.332,.400]:
        blob(f'arm_prototype_bolt_{x}_{z}', (x,-.059,z), (.012,.009,.012), 'rust', 'forearm.L', segments=6)
box('arm_prototype_palm', (.39,-.025,.869), (.104,.052,.10), 'metal', 'forearm.L', 'dark', bevel=.008)
blob('arm_prototype_firegem', (.39,-.061,.88), (.037,.022,.043), 'flame', 'forearm.L', 'light', segments=8)
box('arm_prototype_crack_vertical', (.391,-.083,.88), (.008,.009,.075), 'wrap', 'forearm.L')
box('arm_prototype_crack_branch', (.405,-.082,.886), (.027,.009,.009), 'wrap', 'forearm.L')
for i in range(4):
    x=.35+i*.026
    box(f'arm_prototype_finger_{i}', (x,-.033,.79), (.018,.025,.075), 'metal', 'forearm.L', 'dark')
box('arm_prototype_thumb', (.457,-.04,.845), (.02,.03,.075), 'metal', 'forearm.L', 'dark')
for i in range(8):
    z=1.29-i*.065
    x=.315+(1.29-z)*.16
    bone='upper_arm.L' if z>1.13 else 'forearm.L'
    box(f'arm_wrapped_strip_{i}', (x,-.01,z), (.135,.14,.057), 'wrap', bone, 'light' if i%3==0 else 'base', bevel=.006)
for i in range(4):
    box(f'arm_wrapped_finger_{i}', (.35+i*.026,-.034,.79), (.023,.031,.079), 'wrap', 'forearm.L')

# Slightly smaller head brings proportions toward the supplied character sheet.
for obj in bpy.data.objects:
    if obj.type=='MESH' and any(g.name in ['head','hair_sway'] for g in obj.vertex_groups):
        for v in obj.data.vertices:
            v.co.x*=.90
            v.co.y*=.90
            v.co.z=1.47+(v.co.z-1.47)*.90

# Join by swappable module. Skin groups/material slots remain editable.
modules=[('body_', 'module_body'), ('left_arm_human_', 'left_arm_human'), ('arm_prototype_', 'arm_prototype'), ('arm_wrapped_', 'arm_wrapped')]
modules += [(f'hair_{key}_',f'hair_{key}') for key in ['bob','crop','headscarf']]
modules += [(f'outfit_{key}_',f'outfit_{key}') for key in ['dress','tunic','workdress']]
modules += [(f'footwear_{key}_',f'footwear_{key}') for key in ['boots','bare']]
for prefix, final_name in modules:
    bpy.ops.object.select_all(action='DESELECT')
    objects = [obj for obj in bpy.data.objects if obj.type=='MESH' and obj.name.startswith(prefix)]
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    bpy.context.object.name = final_name

import sys
sys.path.insert(0,str(ROOT/'tools'))
from motion_math import sample_draw, draw_pose, dodge_godot, dodge_blender, smooth

def sample_motion(key, t):
    poses = MOTION[key]
    for a,b in zip(poses,poses[1:]):
        if t <= b['t']:
            f=max(0,min(1,(t-a['t'])/(b['t']-a['t'])))
            f=f*f*(3-2*f)
            return {k:Vector(a[k]).lerp(Vector(b[k]),f) for k in ['grip','tip']}
    return {k:Vector(poses[-1][k]) for k in ['grip','tip']}


def aim_bone(bone, start, end):
    rest=bone.bone.matrix_local.to_3x3()
    direction=rest @ Vector((0,1,0))
    rotation=direction.rotation_difference((end-start).normalized()).to_matrix() @ rest
    bone.matrix=Matrix.Translation(start) @ rotation.to_4x4()
    bpy.context.view_layer.update()


def arm_ik(side, godot_target, godot_pole=None):
    target=Vector((godot_target.x,-godot_target.z,godot_target.y))
    upper=rig.pose.bones[f'upper_arm.{side}']
    lower=rig.pose.bones[f'forearm.{side}']
    start=upper.head.copy()
    direction=(target-start).normalized()
    l1,l2=upper.bone.length,lower.bone.length
    distance=min((target-start).length,l1+l2-.001)
    a=(l1*l1-l2*l2+distance*distance)/(2*distance)
    bend=Vector((0,-1,0)) if godot_pole is None else Vector((godot_pole.x,-godot_pole.z,godot_pole.y))-start
    bend=(bend-direction*bend.dot(direction)).normalized()
    elbow=start+direction*a+bend*math.sqrt(max(0,l1*l1-a*a))
    aim_bone(upper,start,elbow)
    aim_bone(lower,elbow,start+direction*distance)


def plant_leg(side, target, weight):
    upper=rig.pose.bones[f'thigh.{side}'];lower=rig.pose.bones[f'shin.{side}'];foot=rig.pose.bones[f'foot.{side}']
    original=[bone.matrix_basis.copy() for bone in [upper,lower,foot]]
    goal=Vector((target.x,-target.z,target.y));start=upper.head.copy()
    direction=(goal-start).normalized();l1,l2=upper.bone.length,lower.bone.length
    distance=max(.01,min((goal-start).length,l1+l2-.001))
    a=(l1*l1-l2*l2+distance*distance)/(2*distance)
    bend=Vector((0,-1,0));bend=(bend-direction*bend.dot(direction)).normalized()
    elbow=start+direction*a+bend*math.sqrt(max(0,l1*l1-a*a))
    aim_bone(upper,start,elbow);aim_bone(lower,elbow,start+direction*distance)
    aim_bone(foot,foot.head.copy(),foot.head+Vector((0,-.14,-.08)))
    for bone,old in zip([upper,lower,foot],original): bone.matrix_basis=old.lerp(bone.matrix_basis,weight)
    bpy.context.view_layer.update()


rig.animation_data_create()
actions=[('idle_loop',61),('walk_loop',25),('interact',31),('drag_idle_loop',61),('drag_walk_loop',41),('attack_light',47),('attack_heavy',75),('attack_light2',41),('attack_light3',55),('attack_water',35),('parry_guard',43),('attack_lance',73),('draw_sword',49),('sheathe_sword',49),('attack_thrust',63),('dodge_roll',85),('stand_up',55),('dodge_roll_sheathed',85),('stand_up_sheathed',55)]
for clip_name, end in actions:
    name=clip_name.removesuffix("_sheathed")
    sheathed=clip_name.endswith("_sheathed")
    action = bpy.data.actions.new(clip_name)
    action.use_fake_user = True
    rig.animation_data.action = action
    for frame in range(1,end+1):
        phase = (frame-1)/(end-1)*math.tau
        for bone in rig.pose.bones:
            bone.rotation_mode='XYZ'
            bone.rotation_euler=(0,0,0)
            bone.location=(0,0,0)
        t=(frame-1)/(end-1)
        if name in ['walk_loop','drag_walk_loop']:
            for side,sign in [('L',1),('R',-1)]:
                rig.pose.bones[f'thigh.{side}'].rotation_euler.x = math.sin(phase)*(.37 if name.startswith('drag') else .57)*sign
                rig.pose.bones[f'shin.{side}'].rotation_euler.x = max(0, math.sin(phase)*sign)*.31
                rig.pose.bones[f'upper_arm.{side}'].rotation_euler.x = -math.sin(phase)*.23*sign
                rig.pose.bones[f'forearm.{side}'].rotation_euler.x = -.12
            rig.pose.bones['pelvis'].location.y = .020*math.cos(phase*2)
            rig.pose.bones['pelvis'].rotation_euler.y = -.12*math.sin(phase)
            rig.pose.bones['pelvis'].rotation_euler.z = .035*math.sin(phase)
            rig.pose.bones['spine'].rotation_euler.y = .26*math.sin(phase-.12)
            rig.pose.bones['spine'].rotation_euler.x = .07+.035*math.sin(phase*2)
            rig.pose.bones['head'].rotation_euler.y=-.08*math.sin(phase-.18)
            for side,sign in [('L',1),('R',-1)]:
                rig.pose.bones[f'thigh.{side}'].rotation_euler.y=.055*math.sin(phase)*sign
                rig.pose.bones[f'foot.{side}'].rotation_euler.y=.045*math.sin(phase)*sign
            if name=='drag_walk_loop':
                # She leans into the greatsword's weight and keeps the free
                # left hand forward for balance throughout the gait cycle.
                rig.pose.bones['spine'].rotation_euler.x=.30+.018*math.sin(phase)
                rig.pose.bones['spine'].rotation_euler.z=.025*math.sin(phase)
        elif name in ['idle_loop','drag_idle_loop']:
            rig.pose.bones['spine'].rotation_euler.x = .028*math.sin(phase)
            rig.pose.bones['spine'].rotation_euler.y = .025*math.sin(phase-.3)
            rig.pose.bones['pelvis'].rotation_euler.y = -.018*math.sin(phase)
            rig.pose.bones['pelvis'].location.y=.006*math.sin(phase)
            rig.pose.bones['head'].rotation_euler.z = .018*math.sin(phase)
        elif name=='interact':
            rig.pose.bones['spine'].rotation_euler.x=.10*math.sin(phase*.5)
            rig.pose.bones['spine'].rotation_euler.y=-.12*math.sin(phase*.5)
            rig.pose.bones['pelvis'].rotation_euler.y=.04*math.sin(phase*.5)
            rig.pose.bones['head'].rotation_euler.x=.06*math.sin(phase)
            rig.pose.bones['forearm.R'].rotation_euler.x = -.9*math.sin(phase/2)
            rig.pose.bones['upper_arm.R'].rotation_euler.x = -.4*math.sin(phase/2)
        if name.startswith('drag') or name.startswith('attack') or name.endswith('sword') or name in ['parry_guard','dodge_roll','stand_up']:
            key=name.removeprefix('attack_') if name.startswith('attack_') else 'parry' if name=='parry_guard' else 'roll' if name=='dodge_roll' else 'stand' if name=='stand_up' else 'draw' if name.endswith('sword') else 'drag'
            pose=sample_motion(key,t if name!='sheathe_sword' else 1-t)
            if key=='draw':
                grip,tip=sample_draw(MOTION['draw'],t if name!='sheathe_sword' else 1-t)
                pose={'grip':grip,'tip':tip}
            rig.pose.bones['spine'].rotation_euler.x=.34+.055*math.sin(phase*2) if name=='drag_walk_loop' else .25+.025*math.sin(phase) if name.startswith('drag') else .22+.09*math.sin(t*math.pi)
            if name.endswith('sword'):
                f=t if name=='draw_sword' else 1-t
                rig.pose.bones['spine'].rotation_euler.x=.22*smooth(.35,1,f)+.10*smooth(.31,.485,f)*(1-smooth(.61,.775,f))
                rig.pose.bones['spine'].rotation_euler.y=-.22*math.sin(f*math.pi)
                rig.pose.bones['pelvis'].rotation_euler.y=.08*math.sin(f*math.pi)
                rig.pose.bones['pelvis'].location.y=-.035*math.sin(f*math.pi)-.09*smooth(.76,.82,f)*(1-smooth(.82,.96,f))
                rig.pose.bones['spine'].rotation_euler.z=.16*math.sin(min(1,f/.31)*math.pi)*(1-smooth(.31,.45,f))
            if name.startswith('attack'):
                turn=math.sin(t*math.pi)*(.48 if name=='attack_light' else -.48 if name=='attack_light2' else .24)
                rig.pose.bones['spine'].rotation_euler.y=turn*1.25
                rig.pose.bones['spine'].rotation_euler.z=.045*math.sin(t*math.pi)
                rig.pose.bones['pelvis'].rotation_euler.y=turn*.32
                rig.pose.bones['pelvis'].location.z=-.08*math.sin(t*math.pi)
                rig.pose.bones['pelvis'].location.y=-.045*math.sin(t*math.pi)
                rig.pose.bones['head'].rotation_euler.x=-.06*math.sin(t*math.pi)
                rig.pose.bones['head'].rotation_euler.y=-turn*.2
                rig.pose.bones['thigh.L'].rotation_euler.x=.3*math.sin(t*math.pi)
                rig.pose.bones['thigh.R'].rotation_euler.x=-.3*math.sin(t*math.pi)
                rig.pose.bones['thigh.L'].rotation_euler.y=-turn*.20
                rig.pose.bones['thigh.R'].rotation_euler.y=turn*.24
            if name=='attack_light':
                coil=smooth(.04,.28,t)
                sweep=smooth(.36,.70,t)
                recovery=smooth(.74,1,t)
                twist=(-.48*coil+1.10*sweep)*(1-recovery)
                rig.pose.bones['spine'].rotation_euler.y=twist
                rig.pose.bones['spine'].rotation_euler.x=.25+.14*coil-.23*sweep+.08*recovery
                rig.pose.bones['pelvis'].rotation_euler.y=twist*.55
                rig.pose.bones['head'].rotation_euler.y=-twist*.35
                rig.pose.bones['thigh.L'].rotation_euler.x=-.38*math.sin(t*math.pi)
                rig.pose.bones['shin.L'].rotation_euler.x=.35*math.sin(t*math.pi)
            if name in ['attack_light','attack_light2']:
                sink=smooth(.48,.66,t)*(1-smooth(.76,1,t)) if name=='attack_light' else 1-smooth(0,.22,t)
                rig.pose.bones['pelvis'].location.y=-.045*math.sin(t*math.pi)*(1-sink)-.40*sink
                rig.pose.bones['pelvis'].location.z=-.08*math.sin(t*math.pi)*(1-sink)-.10*sink
                if name=='attack_light':
                    rig.pose.bones['spine'].rotation_euler.x+=.38*sink
                else:
                    # Start the return cut from the same planted kneel at the
                    # .74 combo join, then push back up into the reverse swing.
                    rig.pose.bones['spine'].rotation_euler.x=.22+.09*math.sin(t*math.pi)+.32*sink
                    rig.pose.bones['spine'].rotation_euler.y=turn*1.25*(1-sink)+.62*sink
                    rig.pose.bones['spine'].rotation_euler.z=.045*math.sin(t*math.pi)*(1-sink)+.0328*sink
                    rig.pose.bones['pelvis'].rotation_euler.y=turn*.32*(1-sink)+.341*sink
                    rig.pose.bones['head'].rotation_euler.y=-turn*.2*(1-sink)-.217*sink
                    rig.pose.bones['head'].rotation_euler.x=-.06*math.sin(t*math.pi)*(1-sink)-.0437*sink
            if name=='attack_light2':
                rise=smooth(0,.26,t)
                cut=smooth(.32,.56,t)
                load=smooth(.05,.26,t)*(1-cut)
                impact=smooth(.43,.62,t)
                recover=smooth(.76,1,t)
                twist=(.62+.18*load-1.40*cut)*(1-recover)
                rig.pose.bones['spine'].rotation_euler.y=twist
                rig.pose.bones['pelvis'].rotation_euler.y=twist*.55
                rig.pose.bones['head'].rotation_euler.y=-twist*.35
                rig.pose.bones['spine'].rotation_euler.x=(.54-.10*rise+.20*impact)*(1-recover)+.22*recover
                rig.pose.bones['spine'].rotation_euler.z=.0328*(1-rise)+.08*impact*(1-recover)
                rig.pose.bones['pelvis'].location.y=(-.40*(1-rise)-.16*rise-.08*impact)*(1-recover)
                rig.pose.bones['pelvis'].location.z=-.10*(1-recover)
                rig.pose.bones['head'].rotation_euler.x=-.0437*(1-recover)
                rig.pose.bones['thigh.L'].rotation_euler.x=.20*rise+.24*impact
                rig.pose.bones['shin.L'].rotation_euler.x=.35*rise+.40*impact
                rig.pose.bones['thigh.R'].rotation_euler.x=-.32*rise
                rig.pose.bones['shin.R'].rotation_euler.x=.40*impact
            if name=='attack_light3':
                unwind=smooth(0,.20,t)
                settle=smooth(.70,1,t)
                catch=smooth(.42,.60,t)*(1-settle)
                rig.pose.bones['spine'].rotation_euler.y=-.78*(1-unwind)+.18*math.sin(t*math.pi)*unwind
                rig.pose.bones['pelvis'].rotation_euler.y=-.429*(1-unwind)
                rig.pose.bones['head'].rotation_euler.y=.273*(1-unwind)
                rig.pose.bones['spine'].rotation_euler.x=.64-.42*unwind+.20*catch
                rig.pose.bones['spine'].rotation_euler.z=.08*(1-unwind)+.045*math.sin(t*math.pi)*unwind
                rig.pose.bones['pelvis'].location.z=-.10*(1-unwind)-.08*math.sin(t*math.pi)*unwind
                rig.pose.bones['head'].rotation_euler.x=-.0437*(1-unwind)-.06*math.sin(t*math.pi)*unwind
                rig.pose.bones['pelvis'].location.y=-.24*(1-unwind)-.16*catch
                rig.pose.bones['thigh.L'].rotation_euler.x=.44*(1-unwind)+.25*catch
                rig.pose.bones['shin.L'].rotation_euler.x=.75*(1-unwind)+.40*catch
                rig.pose.bones['thigh.R'].rotation_euler.x=-.32*(1-unwind)
                rig.pose.bones['shin.R'].rotation_euler.x=.40*(1-unwind)
            if name in ['attack_heavy','attack_light3']:
                # A shared two-handed hammer finish: lift, snap down, catch, extract.
                join=smooth(.205,.34,t) if name=='attack_light3' else 1
                lift=smooth(.205,.53,t)*(1-smooth(.58,.68,t)) if name=='attack_light3' else smooth(.08,.46,t)*(1-smooth(.58,.68,t))
                impact=smooth(.58,.68,t)*(1-smooth(.82,1,t))
                def slam_bone(bone,axis,value):
                    r=rig.pose.bones[bone].rotation_euler
                    setattr(r,axis,getattr(r,axis)*(1-join)+value*join)
                slam_bone('spine','x',.22-.28*lift+.62*impact)
                slam_bone('spine','y',.28*lift-.12*impact)
                if name=='attack_light3':
                    rig.pose.bones['spine'].rotation_euler.z+=-.20*math.sin(math.pi*smooth(.205,.53,t))*(1-smooth(.58,.68,t))
                slam_bone('pelvis','y',.16*lift-.08*impact)
                slam_bone('head','x',.06*lift-.14*impact)
                b=rig.pose.bones['pelvis']
                b.location.y=b.location.y*(1-join)+(-.04*lift-.30*impact)*join
                b.location.z=b.location.z*(1-join)+(-.12*impact)*join
                slam_bone('thigh.L','x',.20*lift+.55*impact)
                slam_bone('shin.L','x',.16*lift+.90*impact)
                slam_bone('thigh.R','x',-.20*lift-.32*impact)
                slam_bone('shin.R','x',.18*lift+.58*impact)
            if name=='attack_water':
                sweep=max(0,min(1,(t-.24)/.43))
                sweep=sweep*sweep*(3-2*sweep)
                twist=math.sin(t*math.pi)*(.78-1.42*sweep)
                rig.pose.bones['spine'].rotation_euler.y=twist
                rig.pose.bones['spine'].rotation_euler.z=.07*math.sin(t*math.pi)
                rig.pose.bones['spine'].rotation_euler.x=.22-.30*math.sin(t*math.pi)
                rig.pose.bones['pelvis'].rotation_euler.y=twist*.30
                rig.pose.bones['pelvis'].location.z=-.15*math.sin(t*math.pi)
                rig.pose.bones['thigh.L'].rotation_euler.x=.68*math.sin(t*math.pi)
                rig.pose.bones['thigh.R'].rotation_euler.x=-.48*math.sin(t*math.pi)
                rig.pose.bones['shin.L'].rotation_euler.x=.42*math.sin(t*math.pi)
            if name=='parry_guard':
                brace=smooth(.02,.28,t)*(1-smooth(.68,1,t))
                # Turn the hips and chest into the outside-right guard. The
                # blade stays on its clear path; the body closes behind it.
                rig.pose.bones['spine'].rotation_euler.z=.38*brace
                rig.pose.bones['spine'].rotation_euler.x=-.10*brace
                rig.pose.bones['spine'].rotation_euler.y=.55*brace
                rig.pose.bones['pelvis'].rotation_euler.y=.65*brace
                rig.pose.bones['head'].rotation_euler.y=-.30*brace
                rig.pose.bones['pelvis'].location.x=-.10*brace
                rig.pose.bones['pelvis'].location.y=-.04*brace
                rig.pose.bones['upper_arm.R'].rotation_euler.z=-.16*brace
                rig.pose.bones['thigh.L'].rotation_euler.x=.16*brace
                rig.pose.bones['shin.L'].rotation_euler.x=.20*brace
                rig.pose.bones['thigh.R'].rotation_euler.y=-.24*brace
            if name=='attack_lance':
                charge=max(0,min(1,(t-.06)/.26))
                charge=charge*charge*(3-2*charge)
                recovery=max(0,min(1,(t-.76)/.24))
                charge*=1-recovery
                rig.pose.bones['spine'].rotation_euler.x=.22-.10*charge+.025*math.sin(t*math.pi*6)*charge
                rig.pose.bones['spine'].rotation_euler.y=-.25*math.sin(min(1,t/.34)*math.pi)
                rig.pose.bones['pelvis'].rotation_euler.y=rig.pose.bones['spine'].rotation_euler.y*.3
                rig.pose.bones['pelvis'].location.z=-.035*charge
                rig.pose.bones['thigh.L'].rotation_euler.x=.08*charge
                rig.pose.bones['shin.L'].rotation_euler.x=.16*charge
                rig.pose.bones['pelvis'].location.y=-.035*charge
            if name=='attack_thrust':
                load=smooth(0,.18,t)*(1-smooth(.70,1,t))
                extension=smooth(.24,.48,t)*(1-smooth(.64,.95,t))
                rig.pose.bones['spine'].rotation_euler.x=.28+.12*load+.18*extension
                rig.pose.bones['spine'].rotation_euler.y=-.18*load+.40*extension
                rig.pose.bones['pelvis'].rotation_euler.y=.14*load-.22*extension
                rig.pose.bones['head'].rotation_euler.x=-.20*load-.12*extension
                rig.pose.bones['head'].rotation_euler.y=.08*load-.14*extension
                # Bone-local Y is vertical; Z translates the hips forward.
                rig.pose.bones['pelvis'].location.y=-.27*load-.10*extension
                rig.pose.bones['pelvis'].location.z=.10*load+.25*extension
            if name in ['dodge_roll','stand_up']:
                # Tuck, rotate head-over-heels, then recover from a crouched landing.
                transform=dodge_godot(key,t)
                rig.pose.bones['root'].matrix=dodge_blender(key,t) @ rig.pose.bones['root'].bone.matrix_local
                for field in ['grip','tip']: pose[field]=transform @ pose[field]
                tuck=smooth(.02,.18,t) if name=='dodge_roll' else 1-smooth(.04,.90,t)
                rig.pose.bones['pelvis'].rotation_euler.x=.16*tuck
                rig.pose.bones['thigh.L'].rotation_euler.x=-1.45*tuck
                rig.pose.bones['thigh.R'].rotation_euler.x=-1.40*tuck
                rig.pose.bones['shin.L'].rotation_euler.x=2.10*tuck
                rig.pose.bones['shin.R'].rotation_euler.x=2.05*tuck
                rig.pose.bones['spine'].rotation_euler.x=.25+.40*tuck
                rig.pose.bones['spine'].rotation_euler.y=-.10*tuck
                rig.pose.bones['spine'].rotation_euler.z=.08*tuck
                rig.pose.bones['pelvis'].rotation_euler.y=.04*tuck
                rig.pose.bones['head'].rotation_euler.x=.35*tuck
            bpy.context.view_layer.update()
            if name=='attack_thrust':
                plant_leg('L',Vector((.18,.14,.22+.50*extension)),load)
                plant_leg('R',Vector((-.20,.14,-.30)),load)
            if name in ['attack_light','attack_light2']:
                for side,sign,reach in [('L',1,.50),('R',-1,-.35)]:
                    plant_leg(side,Vector((sign*.16,.14,reach)),sink)
            if name.endswith('sword'):
                catch=.035*math.sin(f*math.pi)+.09*smooth(.76,.82,f)*(1-smooth(.82,.96,f))
                for side,sign in [('L',1),('R',-1)]:
                    plant_leg(side,Vector((sign*.13,.14,0)),smooth(.70,.82,f)*(1-smooth(.90,1,f)))
            if name=='stand_up':
                for side,sign in [('L',1),('R',-1)]:
                    plant_leg(side,Vector((sign*.13,.14,-.40*(1-t))),smooth(.08,.34,t))
            if name.endswith('sword'):
                bpy.context.view_layer.update()
                pose['grip'],pose['tip']=draw_pose(pose['grip'],pose['tip'],rig.pose.bones['spine'].matrix,rig.data.bones['spine'].matrix_local,f)
                resting=rig.pose.bones['forearm.R'].tail.copy()
                resting=Vector((resting.x,resting.z,-resting.y))
                hand=pose['grip']+(pose['tip']-pose['grip']).normalized()*.16*(1-smooth(.10,.31,f))
                reach=resting.lerp(Vector((-.50,1.60,.20)),smooth(0,.055,f)).lerp(hand,smooth(.055,.10,f))
                arm_ik('R',reach,Vector((-.65,1.90,.30)))
                arm_ik('L',Vector((.04,1.14,.26)),Vector((.42,1.14,.26)))
            elif name in ['dodge_roll','stand_up']:
                right_hand=dodge_godot(key,t) @ Vector((-.385,.88,.015)).lerp(Vector((-.24,1.24,.34)),tuck) if sheathed else pose['grip']
                arm_ik('R',right_hand,dodge_godot(key,t) @ Vector((-.50,1.32,.43)))
            else:
                arm_ik('R',pose['grip'])
            if name.startswith('attack'):
                handle=(pose['grip']-pose['tip']).normalized()
                left_target=pose['grip']+handle*.16
                if name not in ['attack_light2','attack_light3']:
                    catch=max(0,min(1,(t-.02)/(.23 if name=='attack_lance' else .16)))
                    catch=catch*catch*(3-2*catch)
                    release=max(0,min(1,(t-.86)/.14))
                    release=release*release*(3-2*release)
                    left_target=Vector((.04,1.14,.26)).lerp(left_target,catch*(1-release))
                if name=='attack_light':
                    # Free arm trails the weight, then returns to the burden brace.
                    spread=math.sin(t*math.pi)
                    left_target=Vector((.04,1.14,.26)).lerp(Vector((.46,1.18,-.25)),spread)
                    left_target+=Vector((0,-.40,.10))*sink
                arm_ik('L',left_target)
            elif name in ['dodge_roll','stand_up']:
                left_hand=Vector((.385,.88,.015)).lerp(Vector((.24,1.24,.34)),tuck) if sheathed else Vector((.04,1.14,.26)).lerp(Vector((.17,1.24,.34)),tuck)
                hand=dodge_godot(key,t) @ left_hand
                if name=='stand_up':
                    plant=smooth(0,.12,t)*(1-smooth(.18,.72,t))
                    hand=hand.lerp(Vector((.32,.15,.38)),plant)
                arm_ik('L',hand,dodge_godot(key,t) @ Vector((.42,1.14,.26)))
            elif name=='parry_guard':
                blade=(pose['tip']-pose['grip']).normalized()
                # Keep the guard hand close to the hilt and draw the blade
                # around the heroine's right side instead of across her body.
                brace=min(1,t/.30)*min(1,(.92-t)/.20)
                guard_hand=pose['grip']-blade*.20+Vector((0,-.05,-.02))
                resting_hand=Vector((.40,1.03,.22))
                arm_ik('L',resting_hand.lerp(guard_hand,max(0,brace)))
            elif name.startswith('drag'):
                free_hand=Vector((.04,1.14,.26+.025*math.sin(phase)))
                arm_ik('L',free_hand,Vector((.42,1.14,.26)))
        moving=name in ['walk_loop','drag_walk_loop']
        rig.pose.bones['hair_sway'].rotation_euler.x=.07*math.sin(phase-.7) if moving else .014*math.sin(phase)
        rig.pose.bones['hair_sway'].rotation_euler.y=.05*math.sin(phase*.5) if moving else .012*math.sin(phase)
        rig.pose.bones['skirt_sway'].rotation_euler.x=.20*math.sin(phase-.20) if moving else .012*math.sin(phase)
        rig.pose.bones['skirt_sway'].rotation_euler.y=.12*math.sin(phase) if moving else 0
        if name.startswith('attack'):
            rig.pose.bones['skirt_sway'].rotation_euler.x=-.12*math.sin(t*math.pi)
            rig.pose.bones['skirt_sway'].rotation_euler.y=.20*math.sin(t*math.pi)
            rig.pose.bones['hair_sway'].rotation_euler.x=.13*math.sin(t*math.pi)
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
blob('SwordGemMount', (0,0,.355), (.091,.033,.118), 'metal', tone='light', segments=8)
blob('SwordBlueGem', (0,-.032,.365), (.064,.027,.085), 'gem', tone='light', segments=8)
blob('SwordBlueGemBack', (0,.032,.365), (.064,.027,.085), 'gem', tone='light', segments=8)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'greatsword-v1.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'greatsword-v1.glb'), export_format='GLB', export_animations=False)
print('ASSET_BUILD_OK humanoid-v1.glb greatsword-v1.glb')
