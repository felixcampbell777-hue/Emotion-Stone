"""Collapse the saved MakeHuman weights onto the project's reusable 16-bone rig.
Only derived data is edited. Canonical actions are reused, never regenerated.
"""
import bpy,math
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path('C:/Games/CoastalFoundation')
SOURCE_RIG=None
CANONICAL=None

def prepare():
    global SOURCE_RIG,CANONICAL
    SOURCE_RIG=bpy.data.objects['Human.rig']
	
    # The Store installation moved MPFB's skin folder. Resolve only that existing
    # local source; the personal file itself is never resaved by this recipe.
    for image in bpy.data.images:
        if image.type!='IMAGE' or image.packed_file or Path(bpy.path.abspath(image.filepath)).is_file():continue
        old='C:/Users/felix/AppData/Roaming/Blender Foundation/Blender/5.2/'
        new='C:/Users/felix/AppData/Local/Packages/BlenderFoundation.Blender_ppwjx1n5r4v9t/LocalCache/Roaming/Blender Foundation/Blender/5.2/'
        fixed=image.filepath.replace('\\','/').replace(old,new)
        if Path(fixed).is_file():image.filepath=fixed;image.reload();image.pack()
    with bpy.data.libraries.load(str(ROOT/'art/source/humanoid-v1.blend'),link=False) as (a,b):
        b.objects=a.objects
        b.actions=a.actions
    imported=[o for o in b.objects if o]
    CANONICAL=next(o for o in imported if o.type=='ARMATURE')
    # Match the canonical hanging-arm bind stance using the saved human rig.
    for side in ['L','R']:
        for name,end,canon in [('upperarm01.','lowerarm01.','upper_arm.'),('lowerarm01.','wrist.','forearm.')]:
            bone=SOURCE_RIG.pose.bones[name+side]
            bpy.context.view_layer.update()
            direction=SOURCE_RIG.pose.bones[end+side].head-bone.head
            target=CANONICAL.data.bones[canon+side].tail_local-CANONICAL.data.bones[canon+side].head_local
            rotation=direction.rotation_difference(target).to_matrix().to_4x4()
            matrix=rotation@bone.matrix;matrix.translation=bone.head;bone.matrix=matrix
    bpy.context.view_layer.update()

def group(name):
    side=name[-1] if name.endswith(('.L','.R')) else None
    if side:
        if name.startswith(('upperleg','pelvis.')):return 'thigh.'+side if name.startswith('upperleg') else 'pelvis'
        if name.startswith('lowerleg'):return 'shin.'+side
        if name.startswith(('foot.','toe')):return 'foot.'+side
        if name.startswith(('upperarm','shoulder')):return 'upper_arm.'+side
        if name.startswith(('lowerarm','wrist','finger','metacarpal')):return 'forearm.'+side
    if name=='root' or name=='spine05':return 'pelvis'
    if name.startswith(('spine','clavicle','breast')):return 'spine'
    if name.startswith(('Helper','Joint','helper','joint','Delete')) or name in ['Left','Mid','Right','body']:return None
    return 'head' if name in SOURCE_RIG.data.bones else None

def weights(obj,source):
    names=[b.name for b in CANONICAL.data.bones]
    mapping={g.index:group(g.name) for g in source.vertex_groups}
    fallback='hair_sway' if 'hair' in source.name.lower() or 'crown' in source.name.lower() else 'pelvis' if 'belt' in source.name.lower() or 'buckle' in source.name.lower() else 'spine'
    entries=[]
    for v in obj.data.vertices:
        result={}
        for old in v.groups:
            name=mapping.get(old.group)
            if name:result[name]=result.get(name,0)+old.weight
        if not result:result={fallback:1.0}
        result=dict(sorted(result.items(),key=lambda e:e[1],reverse=True)[:4]);total=sum(result.values())
        entries.append({names.index(k):w/total for k,w in result.items()})
    # Evaluated mesh copies retain the original object's group-name table.
    # Replace that table after reading its weights, before writing new indices.
    obj.vertex_groups.clear()
    for n in names:obj.vertex_groups.new(name=n)
    assert [g.name for g in obj.vertex_groups]==names
    # Remove copied deform indices before replacing with the consolidated groups.
    import bmesh
    bm=bmesh.new();bm.from_mesh(obj.data);layer=bm.verts.layers.deform.active
    if layer:
        for v in bm.verts:v[layer].clear()
    bm.to_mesh(obj.data);bm.free()
    for index,values in enumerate(entries):
        for g,w in values.items():obj.vertex_groups[g].add([index],w,'REPLACE')

def create(meshes,factor,bottom):
    data=bpy.data.armatures.new('Beta humanoid');rig=bpy.data.objects.new('BetaRig',data);bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
    aliases={'root':None,'pelvis':'root','spine':'spine03','head':'head','hair_sway':'head','skirt_sway':'root'}
    for side in ['L','R']:aliases.update({'upper_arm.'+side:'upperarm01.'+side,'forearm.'+side:'lowerarm01.'+side,'thigh.'+side:'upperleg01.'+side,'shin.'+side:'lowerleg01.'+side,'foot.'+side:'foot.'+side})
    for old in CANONICAL.data.bones:
        bone=data.edit_bones.new(old.name)
        at=Vector((0,0,0)) if old.name=='root' else SOURCE_RIG.pose.bones[aliases[old.name]].head.copy()
        if old.name!='root':at=Vector((at.x*factor,at.y*factor,(at.z-bottom)*factor))
        if old.name=='hair_sway':at.z+=.14
        matrix=old.matrix_local.copy();matrix.translation=at;bone.matrix=matrix;bone.length=max(.06,old.length*.9)
        if old.parent:bone.parent=data.edit_bones[old.parent.name]
        bone.use_deform=True
    bpy.ops.object.mode_set(mode='OBJECT')
    for obj in meshes:
        mod=obj.modifiers.new('Beta human skin','ARMATURE');mod.object=rig;obj.parent=rig
    rig.animation_data_create()
    clips=[]
    for action in sorted(bpy.data.actions,key=lambda a:a.name):
        key=action.name.removesuffix('_loop')
        if action.name not in ['idle_loop','walk_loop','interact','drag_idle_loop','drag_walk_loop','draw_sword','sheathe_sword','attack_light','attack_light2','attack_light3','attack_heavy','attack_water','attack_lance','parry_guard','attack_thrust','dodge_roll','stand_up','dodge_roll_sheathed','stand_up_sheathed']:continue
        track=rig.animation_data.nla_tracks.new();track.name=key
        strip=track.strips.new(key,1,action);strip.action_frame_start=action.frame_range[0];strip.action_frame_end=action.frame_range[1]
        clips.append(action.name)
    rig.animation_data.action=None
    bpy.context.scene.render.fps=30
    return rig,clips
