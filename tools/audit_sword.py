"""Blender audit of blade volume against evaluated, animated heroine geometry."""
import bpy, json, math, hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix, Euler
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
import sys
sys.path.insert(0,str(ROOT/'tools'))
from motion_math import sample_draw, draw_mount, draw_pose, draw_right, dodge_godot, sword_right
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/source/humanoid-v1.blend'))
advanced='--advanced' in sys.argv
if advanced:
    from prepare_character_detail import apply_detail
    apply_detail()
rig=bpy.data.objects['Humanoid']
motion=json.loads((ROOT/'game/content/sword_motion.json').read_text())
modules=['module_body','left_arm_human','hair_bob','outfit_dress','footwear_boots']
objects=[bpy.data.objects[n] for n in modules]
# Only these modules are visible on the heroine. Unused NPC variants needlessly
# reevaluate their armature modifiers at every subframe; remove them from this test scene.
for obj in list(bpy.context.scene.objects):
    if obj.type=='MESH' and obj not in objects:bpy.data.objects.remove(obj,do_unlink=True)
def sample(key,t):
    poses=motion[key]
    for a,b in zip(poses,poses[1:]):
        if t<=b['t']:
            f=max(0,min(1,(t-a['t'])/(b['t']-a['t'])));f=f*f*(3-2*f)
            return [Vector(a[k]).lerp(Vector(b[k]),f) for k in ['grip','tip']]
    return [Vector(poses[-1][k]) for k in ['grip','tip']]
def convert(v): return Vector((v.x,-v.z,v.y))
conversion=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
failures=[]; count=0
starts=[]; sheathed_starts=[]
for start_clip in ['drag_walk_loop','drag_idle_loop','walk_loop','idle_loop']:
    start_action=bpy.data.actions[start_clip]
    rig.animation_data.action=start_action
    for phase in ([i/8 for i in range(8)] if start_clip in ['drag_walk_loop','walk_loop'] else [0]):
        frame=1+phase*(start_action.frame_range[1]-1)
        bpy.context.scene.frame_set(int(frame),subframe=frame-int(frame))
        (sheathed_starts if start_clip in ['walk_loop','idle_loop'] else starts).append((start_clip+str(phase),[b.matrix_basis.copy() for b in rig.pose.bones]))
combat=json.loads((ROOT/'game/content/combat.json').read_text())
combo_starts={}
for target,previous in [('attack_light2','attack_light'),('attack_light3','attack_light2')]:
    previous_action=bpy.data.actions[previous]
    rig.animation_data.action=previous_action
    frame=1+.74*(previous_action.frame_range[1]-1)
    bpy.context.scene.frame_set(int(frame),subframe=frame-int(frame))
    combo_starts[target]=[b.matrix_basis.copy() for b in rig.pose.bones]
thrust_starts={}
thrust_action=bpy.data.actions['attack_thrust']
rig.animation_data.action=thrust_action
for charged in [.42,.65,4.0]:
    phase=float(combat['thrust_charge']['ready_phase'])*min(1,charged/float(combat['thrust_charge']['prepare_seconds']))**2*(3-2*min(1,charged/float(combat['thrust_charge']['prepare_seconds'])))
    frame=1+phase*(thrust_action.frame_range[1]-1)
    bpy.context.scene.frame_set(int(frame),subframe=frame-int(frame))
    grip,tip=sample('thrust',phase)
    up=(grip-tip).normalized();right=sword_right(up,'thrust',phase)
    basis=Matrix((right,up,right.cross(up))).transposed()
    thrust_starts['thrust-release-'+str(charged)]=([b.matrix_basis.copy() for b in rig.pose.bones],basis.to_quaternion(),grip-basis@Vector((0,.256,0)),phase,charged)
roll_starts={}
roll_action=bpy.data.actions['stand_up']
rig.animation_data.action=roll_action
for phase in [float(combat['dodge']['attack_exit_phase']),float(combat['dodge']['attack_exit_phase'])+.035]:
    frame=1+phase*(roll_action.frame_range[1]-1)
    bpy.context.scene.frame_set(int(frame),subframe=frame-int(frame))
    grip,tip=sample('stand',phase)
    transform=dodge_godot('stand',phase)
    grip,tip=transform@grip,transform@tip
    up=(grip-tip).normalized();right=sword_right(up,'stand',phase)
    basis=Matrix((right,up,right.cross(up))).transposed()
    origin=grip-basis@Vector((0,.256,0))
    roll_starts['roll-exit-'+str(phase)]=([b.matrix_basis.copy() for b in rig.pose.bones],basis.to_quaternion(),origin)
for action in bpy.data.actions:
    name=action.name
    if '--clips' in sys.argv and name not in sys.argv[sys.argv.index('--clips')+1].split(','):continue
    base=name.removesuffix("_sheathed")
    sheathed=name.endswith("_sheathed")
    if not (name.startswith(('attack_','drag_')) or base in ['parry_guard','draw_sword','sheathe_sword','idle_loop','walk_loop','interact','dodge_roll','stand_up']): continue
    key=name.removeprefix('attack_') if name.startswith('attack_') else 'parry' if name=='parry_guard' else 'roll' if base=='dodge_roll' else 'stand' if base=='stand_up' else 'draw' if name.endswith('sword') else 'drag'
    rig.animation_data.action=action
    cases=[(i/240,None,1.0,'authored') for i in range(241)]
    if base in ['attack_light','attack_heavy','attack_water','attack_lance','attack_thrust','parry_guard','dodge_roll']:
        blend_seconds=.10 if key=='roll' else .20 if key=='lance' else .18 if key=='water' else .16
        duration=float(combat['dodge']['duration']) if key=='roll' else float(combat[key]['duration']) if key!='lance' else float(combat['lance']['charge_seconds'])/.70
        for label,bones in (sheathed_starts if sheathed else starts):
            for index in range(14):
                elapsed=blend_seconds*index/13
                weight=index/13;weight=weight*weight*(3-2*weight)
                cases.append((elapsed/duration,bones,weight,label))
    if name=='attack_thrust':
        tuning=combat['thrust'];windup=tuning['duration']*tuning['active_start']*combat['rush_heavy_windup']
        for label,bones in starts:
            for index in range(14):
                elapsed=.16*index/13;weight=index/13;weight=weight*weight*(3-2*weight)
                phase=tuning['active_start']*elapsed/windup if elapsed<windup else tuning['active_start']+(elapsed-windup)/tuning['duration']
                cases.append((phase,bones,weight,'rush-'+label))
    if name in combo_starts:
        duration=float(combat['combo'][0 if name=='attack_light2' else 1]['duration'])
        for index in range(14):
            weight=index/13
            cases.append((.12*weight/duration,combo_starts[name],weight,'combo-link'))
    if name=='attack_light':
        for label,(bones,rotation,origin) in roll_starts.items():
            for index in range(25):
                weight=index/24
                cases.append((float(combat['dodge']['attack_exit_blend'])*weight/float(combat['light']['duration']),bones,weight,label))
    if name=='attack_thrust':
        for label,(bones,rotation,origin,ready,charged) in thrust_starts.items():
            for rushing in [False,True]:
                windup=float(combat['thrust_charge']['release_windup_seconds'])*(combat['rush_heavy_windup'] if rushing else 1)
                launch=float(combat['thrust_charge']['launch_seconds'])+charged*float(combat['thrust_charge']['launch_seconds_per_charge'])
                for index in range(25):
                    elapsed=.12*index/24
                    phase=ready+(.24-ready)*elapsed/windup if elapsed<windup else .24+.40*(elapsed-windup)/launch
                    cases.append((phase,bones,index/24,label))
    if '--quick' in sys.argv and '--dense' not in sys.argv: cases=cases[::12]
    for t,start_bones,weight,label in cases:
        frame=1+t*(action.frame_range[1]-1)
        bpy.context.scene.frame_set(int(frame),subframe=frame-int(frame))
        if start_bones is not None:
            for bone,start in zip(rig.pose.bones,start_bones):
                bone.matrix_basis=start.lerp(bone.matrix_basis,weight)
            bpy.context.view_layer.update()
        graph=bpy.context.evaluated_depsgraph_get()
        grip,tip=sample_draw(motion['draw'],t if name!='sheathe_sword' else 1-t) if key=='draw' else sample(key,t)
        if key in ['roll','stand']:
            transform=dodge_godot(key,t)
            grip,tip=transform @ grip,transform @ tip
        if name.endswith('sword'):
            f=t if name=='draw_sword' else 1-t
            grip,tip=draw_pose(grip,tip,rig.pose.bones['spine'].matrix,rig.data.bones['spine'].matrix_local,f)
        direction=(tip-grip).normalized(); up=-direction
        right=draw_right(up,rig.pose.bones['spine'].matrix,rig.data.bones['spine'].matrix_local,f) if name.endswith('sword') else sword_right(up,key,t); depth=right.cross(up)
        if sheathed or name in ['idle_loop','walk_loop','interact']:
            mount=draw_mount(rig.pose.bones['spine'].matrix,rig.data.bones['spine'].matrix_local)
            grip=mount @ Vector((0,.256,0))
            tip=mount @ Vector((0,-1.872,0))
            direction=(tip-grip).normalized()
            right=(mount.to_3x3() @ Vector((1,0,0))).normalized()
            depth=right.cross(-direction)
        if label in roll_starts or label in thrust_starts:
            old_bones,old_rotation,old_origin=(roll_starts[label] if label in roll_starts else thrust_starts[label][:3])
            basis=Matrix((right,up,depth)).transposed()
            origin=grip-basis@Vector((0,.256,0))
            basis=old_rotation.slerp(basis.to_quaternion(),weight).to_matrix()
            origin=old_origin.lerp(origin,weight)
            grip=origin+basis@Vector((0,.256,0))
            tip=origin+basis@Vector((0,-1.872,0))
            direction=(tip-grip).normalized();right=basis.col[0];depth=basis.col[2]
        vertices=[];polygons=[]; labels=[];triangle_sources=[]
        for obj in objects:
            ev=obj.evaluated_get(graph); mesh=ev.to_mesh(); offset=len(vertices)
            # Bulk extraction keeps exact evaluated geometry affordable for dense assets.
            coords=np.empty(len(mesh.vertices)*3,dtype=np.float32);mesh.vertices.foreach_get('co',coords)
            transform=np.asarray(ev.matrix_world,dtype=np.float32)
            vertices.extend((coords.reshape(-1,3)@transform[:3,:3].T+transform[:3,3]).tolist())
            mesh.calc_loop_triangles();tris=np.empty(len(mesh.loop_triangles)*3,dtype=np.int32)
            mesh.loop_triangles.foreach_get('vertices',tris)
            polygons.extend((tris.reshape(-1,3)+offset).tolist())
            triangle_sources.append((len(labels),len(mesh.loop_triangles),obj,tris.reshape(-1,3).copy()))
            labels.extend([obj.name]*len(mesh.loop_triangles));ev.to_mesh_clear()
        tree=BVHTree.FromPolygons(vertices,polygons,all_triangles=True,epsilon=.002)
        # Actual blade: guard-to-tip length, 27.2cm wide, 8.8cm deep.
        # Twenty-five parallel rails cover its width/depth plus boundary.
        hit=None
        for w in [-.136,-.068,0,.068,.136]:
            for d in [-.044,-.022,0,.022,.044]:
                start=grip+direction*.33+right*w+depth*d
                point,normal,poly,dist=tree.ray_cast(convert(start),convert(direction),1.90)
                if point is not None:
                    hit={'clip':name,'phase':round(t,5),'scenario':label,'module':labels[poly],'point':[round(v,4) for v in point]}
                    if '--quick' in sys.argv:
                        for first,n,obj,tris in triangle_sources:
                            if first<=poly<first+n and len(obj.data.vertices)==len(obj.evaluated_get(graph).data.vertices):
                                hit['bind_vertices']=[list(obj.data.vertices[int(i)].co) for i in tris[poly-first]]
                                hit['weights']=[[obj.vertex_groups[w.group].name for w in obj.data.vertices[int(i)].groups if w.weight>.1] for i in tris[poly-first]]
                    break
            if hit: break
        if hit: failures.append(hit)
        count+=1
files=['art/source/humanoid-v1.blend','art/source/greatsword-v1.blend','game/content/sword_motion.json','game/content/combat.json','tools/audit_sword.py','tools/motion_math.py']
if advanced: files+=['tools/prepare_character_detail.py','tools/remake_hero.py','tools/build_character.py','game/assets/characters/humanoid-hero-v1.glb','art/character/source/human_base_meshes_bundle.blend']
report={'passed':not failures,'samples':count,'failures':failures,'inputs':{f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in files}}
path=ROOT/('output/verification/quick-sword-clearance.json' if '--quick' in sys.argv else 'output/verification/advanced-sword-clearance.json' if advanced else 'output/verification/sword-clearance.json');path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(report,indent=2))
print('SWORD_CLEARANCE',count,'samples',len(failures),'intersections')
if failures: raise RuntimeError('Blade intersects heroine; see sword-clearance.json')

