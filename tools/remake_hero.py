"""Reference-led heroine: custom head/bob, coherent body fit and current choreography."""
import ast, math, random, json
from pathlib import Path
import bpy, bmesh
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
from motion_math import sample_draw, draw_pose, dodge_godot, dodge_blender, smooth
ROOT=Path(__file__).resolve().parents[1]
SCALE=1.10
BASE=ROOT/'art/character/source/human_base_meshes_bundle.blend'
# Canonical design controls. These are source inputs, never recovered from exports.
DESIGN={'body_width':.87,'leg_height':.95,'torso_height':.88,
        'head_width':1.19,'head_height':1.12,'head_center':1.565,
        'hair_crown':1.739,'hair_width':.139,'hair_end':1.315,
        'realistic_head_width':.78,'realistic_head_height':.76,'stature_scale':1.08}

def proportion_fit(co,hair=False):
    """Whole-model final landmarks: lean human proportions, consistent clothes/rests."""
    w=smooth(1.37,1.49,co.z)
    xy=DESIGN['realistic_head_width'] if hair else 1-(1-DESIGN['realistic_head_width'])*w
    z=co.z+(1.415+(co.z-1.415)*DESIGN['realistic_head_height']-co.z)*w
    return Vector((co.x*xy,co.y*xy,z))*DESIGN['stature_scale']

def body_fit(co):
    z=co.z;body_z=z*DESIGN['leg_height'] if z<=1 else DESIGN['leg_height']+(z-1)*DESIGN['torso_height']
    x=co.x*DESIGN['body_width'];y=co.y*.90
    head=smooth(1.51,1.565,z)
    if head:
        # Sculpt proportions while retaining connected anatomical facial loops.
        hx=co.x*DESIGN['head_width'];hy=co.y*.94;hz=DESIGN['head_center']+(z-1.688)*DESIGN['head_height']
        if co.y<-.060:
            for sign in [-1,1]:
                d=co.x-sign*.03614;e=math.exp(-(d/.034)**2-((z-1.688)/.034)**2)
                hx+=d*.17*e;hz+=(z-1.688)*.26*e
            hy+=.010*math.exp(-(co.x/.023)**2-((z-1.663)/.031)**2)
            hx*=1-.18*math.exp(-(co.x/.028)**2-((z-1.656)/.030)**2)
            hy-=.0035*math.exp(-((abs(co.x)-.057)/.030)**2-((z-1.649)/.027)**2)
        x=x*(1-head)+hx*head;y=y*(1-head)+hy*head;body_z=body_z*(1-head)+hz*head
    return Vector((x,y,body_z))

def material(name, rgb):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes=True;m.diffuse_color=(*rgb,1)
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*rgb,1)
    return m

def weight(v):
    x,y,z=v;side='L' if x>=0 else 'R';ax=abs(x)
    if z>1.48:return {'head':1.0}
    if z>1.41:return {'head':smooth(1.41,1.49,z),'spine':1-smooth(1.41,1.49,z)}
    # Anatomical arm region, including its continuous shoulder blend.
    arm_edge=.155 if z>1.25 else .175 if z>1.17 else .19 if z>1.00 else .215 if z>.85 else .275
    if ax>arm_edge and z>.63:
        shoulder=smooth(arm_edge,arm_edge+(.040 if z>1.18 else .020),ax)
        upper=smooth(1.00,1.10,z)
        return {'spine':1-shoulder,'upper_arm.'+side:shoulder*upper,'forearm.'+side:shoulder*(1-upper)}
    if z>1.00:return {'spine':smooth(1,1.18,z),'pelvis':1-smooth(1,1.18,z)}
    if z>.83:return {'pelvis':smooth(.83,.97,z),'thigh.'+side:1-smooth(.83,.97,z)}
    if z>.47:return {'thigh.'+side:smooth(.47,.56,z),'shin.'+side:1-smooth(.47,.56,z)}
    if z>.12:return {'shin.'+side:smooth(.12,.20,z),'foot.'+side:1-smooth(.12,.20,z)}
    return {'foot.'+side:1.0}

def make(name, vertices, faces, mats, groups=None, uvs=None, source_uv=None):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    for m in mats:mesh.materials.append(m)
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    for i,v in enumerate(vertices):
        for bone,w in (groups[i] if groups else weight(Vector(v)/SCALE)).items():
            if w<=.00001:continue
            group=obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone);group.add([i],w,'REPLACE')
    layer=mesh.uv_layers.new(name='UVMap')
    for p in mesh.polygons:
        p.use_smooth=True
        for li in p.loop_indices:
            v=mesh.vertices[mesh.loops[li].vertex_index].co
            layer.data[li].uv=source_uv[li] if source_uv else uvs[mesh.loops[li].vertex_index] if uvs else (v.x*4,v.z*4)
    return obj

def substitute(name, new):
    old=bpy.data.objects[name]
    groups=[g.name for g in new.vertex_groups];saved=[[(w.group,w.weight) for w in v.groups] for v in new.data.vertices]
    old.data=new.data;old.vertex_groups.clear()
    for name in groups:old.vertex_groups.new(name=name)
    for index,weights in enumerate(saved):
        for group,w in weights:old.vertex_groups[group].add([index],w,'REPLACE')
    # The shared mesh group records survive data transfer; modifiers remain authoritative.
    bpy.data.objects.remove(new,do_unlink=True)
    return old

def weld_join(obj, parts):
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
    for p in parts:p.select_set(True)
    bpy.context.view_layer.objects.active=obj;bpy.ops.object.join()

def refine(obj, level=1):
    bpy.context.view_layer.objects.active=obj
    modifier=obj.modifiers.new('Tailored smooth surface','SUBSURF');modifier.levels=level
    obj.modifiers.move(len(obj.modifiers)-1,0);bpy.ops.object.modifier_apply(modifier=modifier.name)

def curve(name,points,width,depth,mat,bone='head',sway=0,wave=0):
    vertices=[];faces=[];uv=[];groups=[]
    p=[Vector(v) for v in points];steps=18;sides=8
    for j in range(steps+1):
        t=j/steps;at=(1-t)**3*p[0]+3*(1-t)**2*t*p[1]+3*(1-t)*t*t*p[2]+t**3*p[3]
        at.x+=math.sin(t*math.tau*1.4)*wave*t
        tangent=(-3*(1-t)**2*p[0]+3*(1-t)*(1-3*t)*p[1]+3*t*(2-3*t)*p[2]+3*t*t*p[3]).normalized()
        across=tangent.cross(Vector((0,1,0))).normalized();deep=tangent.cross(across).normalized()
        taper=max(.012,math.sin(math.pi*(.055+.944*t))**.7)
        for k in range(sides):
            a=k*math.tau/sides
            vertices.append(at+across*math.cos(a)*width*taper+deep*math.sin(a)*depth*taper)
            uv.append((k/sides,t));groups.append({bone:1-sway*t*t,'hair_sway':sway*t*t} if sway else {bone:1})
        if j:
            for k in range(sides):faces.append(((j-1)*sides+k,(j-1)*sides+(k+1)%sides,j*sides+(k+1)%sides,j*sides+k))
    faces += [tuple(reversed(range(sides))),tuple(steps*sides+k for k in range(sides))]
    return make(name,vertices,faces,[mat],groups,uv)

def build_face(body,skin):
    """Sculpted source topology retains real lid, nose, mouth and ear articulation."""
    parts=[];white=material('eyewhite_detail',(.82,.81,.75));iris=material('iris_detail',(.22,.105,.042))
    brow=material('eyebrows_detail',(.17,.095,.048));freckle=material('freckles_detail',(.40,.22,.135));rng=random.Random(34)
    tree=BVHTree.FromPolygons([v.co for v in body.data.vertices],[tuple(p.vertices) for p in body.data.polygons])
    for sign in [-1,1]:
        center=body_fit(Vector((sign*.03285,-.11876,1.53444))*SCALE)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,location=center)
        eye=bpy.context.object;eye.name='Lid-covered eye';eye.scale=(.019,.0178,.018)
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        for poly in eye.data.polygons:poly.use_smooth=True
        eye.data.materials.append(white);eye.vertex_groups.new(name='head').add(list(range(len(eye.data.vertices))),1,'REPLACE');parts.append(eye)
        r=.0118;v=[center+Vector((0,-.0182,0))];uv=[(.5,.5)];f=[]
        for k in range(64):
            a=k*math.tau/64;v.append(center+Vector((r*math.cos(a),-.0180,r*math.sin(a))))
            uv.append((.5+.5*math.cos(a),.5+.5*math.sin(a)));f.append((0,k+1,(k+1)%64+1))
        parts.append(make('Brown iris',v,f,[iris],[{'head':1}]*len(v),uv))
        # Lid surfaces cover the spherical white above/below an almond opening.
        for upper in [True,False]:
            v=[];f=[];rim=[]
            for k in range(33):
                q=-1+2*k/32;x=q*.019
                z=(.008 if upper else -.006)*math.sqrt(max(0,1-q*q))+.0015*q*sign
                rim.append(center+Vector((x,-.0178*math.sqrt(max(0,1-q*q-(z/.020)**2))-.0015,z)))
                for j in range(5):
                    t=j/4;end=(.025 if upper else -.019)*math.sqrt(max(0,1-q*q))
                    zz=z*(1-t)+end*t
                    hit=tree.ray_cast(Vector((center.x+x,-.4,center.z+zz)),Vector((0,1,0)))[0]
                    outer_y=hit.y-center.y-.0004 if hit is not None else -.010
                    yy=-.0192*(1-smooth(.15,1,t))+outer_y*smooth(.15,1,t)
                    v.append(center+Vector((x,yy,zz)))
                    if k and j:
                        face=((k-1)*5+j-1,(k-1)*5+j,k*5+j,k*5+j-1)
                        f.append(face if not upper else tuple(reversed(face)))
            parts.append(make('Sculpted upper lid' if upper else 'Sculpted lower lid',v,f,[skin],[{'head':1}]*len(v)))
            if upper:parts.append(curve('Soft upper lash',[rim[0],rim[10],rim[22],rim[-1]],.0009,.00065,brow))
    tree=BVHTree.FromPolygons([v.co for v in body.data.vertices],[tuple(p.vertices) for p in body.data.polygons])
    def surface(x,z,offset=.001):
        hit=tree.ray_cast(Vector((x,-.40,z)),Vector((0,1,0)))[0]
        return hit+Vector((0,-offset,0)) if hit is not None else Vector((x,-.13,z))
    eye_z=body_fit(Vector((0,0,1.688))).z
    for sign in [-1,1]:
        points=[surface(sign*x,eye_z+dz,.0018) for x,dz in [(.017,.022),(.032,.027),(.051,.026),(.071,.019)]]
        parts.append(curve('Soft arched brow',points,.0021,.0013,brow))
        for i in range(21):
            x=sign*rng.uniform(.039,.078);z=eye_z-rng.uniform(.032,.053);at=surface(x,z,.0006);r=rng.uniform(.0006,.0011)
            vv=[at]+[at+Vector((math.cos(k*math.tau/8)*r,0,math.sin(k*math.tau/8)*r)) for k in range(8)]
            parts.append(make('Warm freckles',vv,[(0,k+1,(k+1)%8+1) for k in range(8)],[freckle],[{'head':1}]*9))
    weld_join(body,parts)

def hair_lock(name,points,width,depth,mat,sway=.40,twist=0):
    # Authored multi-point flowing lock; solid flattened profile, not a round strand.
    points=[Vector(p) for p in points];v=[];f=[];uv=[];weights=[];steps=40;n=10
    def center(t):
        u=t*(len(points)-1);i=min(len(points)-2,int(u));s=u-i
        p0=points[max(0,i-1)];p1=points[i];p2=points[i+1];p3=points[min(len(points)-1,i+2)]
        return .5*((2*p1)+(-p0+p2)*s+(2*p0-5*p1+4*p2-p3)*s*s+(-p0+3*p1-3*p2+p3)*s*s*s)
    for j in range(steps+1):
        t=j/steps;at=center(t);axis=(center(min(1,t+.002))-center(max(0,t-.002))).normalized()
        hint=Vector((0,1,0)) if abs(axis.y)<.92 else Vector((1,0,0))
        across=axis.cross(hint).normalized();deep=axis.cross(across).normalized()
        angle=twist*math.sin(t*math.pi);a0=across.copy();across=a0*math.cos(angle)+deep*math.sin(angle);deep=axis.cross(across).normalized()
        taper=(.30+.75*math.sin(math.pi*t*.9))*(1-smooth(.78,1,t))+.012
        for k in range(n):
            a=k*math.tau/n
            v.append(at+across*math.cos(a)*width*taper+deep*math.sin(a)*depth*taper)
            uv.append((k/n,t));w=sway*smooth(.25,.95,t);weights.append({'head':1-w,'hair_sway':w})
            if j:f.append(((j-1)*n+k,(j-1)*n+(k+1)%n,j*n+(k+1)%n,j*n+k))
    f.extend([tuple(reversed(range(n))),tuple(steps*n+k for k in range(n))])
    return make(name,v,f,[mat],weights,uv)

def hair_card(name,points,width,mat,sway=.32):
    points=[Vector(p) for p in points];v=[];f=[];uv=[];weights=[];steps=28;columns=8
    def center(t):
        u=t*(len(points)-1);i=min(len(points)-2,int(u));q=u-i
        p0=points[max(0,i-1)];p1=points[i];p2=points[i+1];p3=points[min(len(points)-1,i+2)]
        return .5*((2*p1)+(-p0+p2)*q+(2*p0-5*p1+4*p2-p3)*q*q+(-p0+3*p1-3*p2+p3)*q*q*q)
    for j in range(steps+1):
        t=j/steps;at=center(t);axis=(center(min(1,t+.002))-center(max(0,t-.002))).normalized()
        radial=Vector((at.x,at.y-.008,0)).normalized()
        if radial.length_squared<.01:radial=Vector((0,-1,0))
        across=axis.cross(radial).normalized();normal=across.cross(axis).normalized()
        taper=(.72+.30*math.sin(t*math.pi*.92))*(1-smooth(.92,1,t))+.008
        for k in range(columns+1):
            u=k/columns;q=u*2-1
            v.append(at+across*q*width*taper+normal*(1-q*q)*.003)
            uv.append((u,t));w=sway*smooth(.32,.96,t);weights.append({'head':1-w,'hair_sway':w})
            if j and k:f.append(((j-1)*(columns+1)+k-1,(j-1)*(columns+1)+k,j*(columns+1)+k,j*(columns+1)+k-1))
    return make(name,v,f,[mat],weights,uv)

def build_bob(hair):
    bob=bpy.data.objects['hair_bob'];bob.data.clear_geometry();parts=[];rng=random.Random(722)
    cards=[material('hair_card',(.34,.20,.11)),material('hair_card_light',(.39,.25,.14)),material('hair_card_dark',(.29,.16,.085))]
    v=[];f=[];uv=[];n=80;rows=21
    for j in range(rows):
        for k in range(n):
            a=k*math.tau/n;front=max(0,-math.sin(a));theta=.015+(2.45-1.42*front**4)*j/(rows-1)
            v.append((.120*math.sin(theta)*math.cos(a),.006+.110*math.sin(theta)*math.sin(a),1.565+.169*math.cos(theta)))
            uv.append((k/n,j/(rows-1)))
            if j:f.append((j*n+k,j*n+(k+1)%n,(j-1)*n+(k+1)%n,(j-1)*n+k))
    parts.append(make('Hair crown volume',v,f,[hair],[{'head':1}]*len(v),uv))
    for i in range(32):
        a=i*math.tau/32;end=1.07 if math.sin(a)<-.60 else 1.60
        points=[]
        for theta in [.22,.53,.84,end]:
            flow=a+.025*math.sin(theta*3)
            points.append((.124*math.sin(theta)*math.cos(flow),.006+.114*math.sin(theta)*math.sin(flow),1.565+.172*math.cos(theta)))
        parts.append(hair_card('Swept crown hair',points,.012,cards[i%3],sway=.02))
    for layer,count in [(0,36),(1,34),(2,32)]:
        for i in range(count):
            a=math.tau*(i+.38*layer)/count
            if math.sin(a)<-.72:continue
            theta=.58+.28*layer;radius=.127+.008*layer;end=DESIGN['hair_end']+rng.uniform(-.023,.025)
            points=[(math.cos(a)*.120*math.sin(theta),.006+math.sin(a)*.110*math.sin(theta),1.565+.169*math.cos(theta)),
                    (math.cos(a+.035)*.119,math.sin(a+.035)*.108,1.643-.020*layer),
                    (math.cos(a-.095)*radius,math.sin(a-.095)*.117,1.529-.015*layer),
                    (math.cos(a+.115)*(radius+.014),math.sin(a+.115)*.120,1.413),
                    (math.cos(a-.070)*(radius-.002),math.sin(a-.070)*.112,end)]
            parts.append(hair_card('Shoulder length layered hair',points,rng.uniform(.010,.014),cards[(i+layer)%3],sway=.25))
    for i in range(15):
        x=-.110+i*.0155
        end=1.593+.025*abs(x/.11)+rng.uniform(-.009,.007)
        points=[(x*.65,-.055,1.710-.018*abs(x/.11)),(x*.72,-.100,1.684),(x*.89,-.141,1.637),(x,-.145,end)]
        parts.append(hair_card('Soft broken fringe',points,.011,cards[i%3],sway=.07))
    for sign in [-1,1]:
        for j in range(6):
            x=sign*(.094+j*.006)
            points=[(x,-.071,1.679),(sign*.126,-.087,1.589),(sign*.139,-.085,1.469),(sign*.117,-.063,1.333+j*.008)]
            parts.append(hair_card('Face framing shoulder hair',points,.013,cards[j%3],sway=.22))
    for i in range(16):
        a=i*math.tau/16
        if math.sin(a)<-.5:continue
        points=[(math.cos(a)*.09,math.sin(a)*.10,1.64),(math.cos(a)*.133,math.sin(a)*.12,1.54),(math.cos(a+.11)*.143,math.sin(a+.11)*.126,1.40),(math.cos(a-.05)*.137,math.sin(a-.05)*.114,1.32)]
        parts.append(curve('Fine loose wisp',points,.0012,.0007,hair,sway=.23))
    weld_join(bob,parts)

def fit_rig():
    rig=bpy.data.objects['Humanoid'];bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    rests={'pelvis':((0,0,.88),(0,0,1.08)), 'spine':((0,0,1.08),(0,0,1.48)),
           'head':((0,0,1.48),(0,0,1.78)),'hair_sway':((0,.01,1.76),(0,.01,1.49))}
    for side,sign in [('L',1),('R',-1)]:
        rests['upper_arm.'+side]=((sign*.19,0,1.43),(sign*.30,-.015,1.16))
        rests['forearm.'+side]=((sign*.30,-.015,1.16),(sign*.425,-.094,.845))
        rests['thigh.'+side]=((sign*.12,.012,.89),(sign*.128,.016,.52))
        rests['shin.'+side]=((sign*.128,.016,.52),(sign*.127,.035,.15))
        rests['foot.'+side]=((sign*.127,.035,.15),(sign*.127,-.13,.060))
    for name,(head,tail) in rests.items():
        rig.data.edit_bones[name].head=body_fit(Vector(head));rig.data.edit_bones[name].tail=body_fit(Vector(tail))
    # The larger designed head is fitted after the whole-body proportion change.
    rig.data.edit_bones['head'].head=(0,0,1.375);rig.data.edit_bones['head'].tail=(0,0,1.720)
    rig.data.edit_bones['hair_sway'].head=(0,.01,1.720);rig.data.edit_bones['hair_sway'].tail=(0,.01,1.330)
    for name in ['skirt_sway']:
        bone=rig.data.edit_bones[name];bone.head=body_fit(bone.head);bone.tail=body_fit(bone.tail)
    for bone in rig.data.edit_bones:
        bone.head=proportion_fit(bone.head,bone.name=='hair_sway');bone.tail=proportion_fit(bone.tail,bone.name=='hair_sway')
    bpy.ops.object.mode_set(mode='OBJECT');return rig

def retarget(rig):
    # Reuse the current authored movement/phase logic, solving limbs against NEW rests.
    authored=(ROOT/'tools/build_character.py').read_text()
    # The fitted palms tuck ahead of the chest while the sheathed blade remains on the spine.
    replacements={
        "rig.animation_data.action = action\n    for frame in range(1,end+1):":"rig.animation_data.action = action\n    previous_rotations={}\n    for frame in range(1,end+1):",
        "bone.keyframe_insert('rotation_euler', frame=frame, group=bone.name)":"rotation=bone.rotation_euler.to_quaternion()\n            if bone.name in previous_rotations and rotation.dot(previous_rotations[bone.name])<0:rotation.negate()\n            bone.rotation_quaternion=rotation\n            previous_rotations[bone.name]=rotation.copy()\n            bone.keyframe_insert('rotation_quaternion', frame=frame, group=bone.name)",
        "hand=pose['grip']+(pose['tip']-pose['grip']).normalized()*.16*(1-smooth(.10,.31,f))":"hand=pose['grip']-(pose['tip']-pose['grip']).normalized()*.035*(1-smooth(.10,.31,f))",
        "Vector((-.385,.88,.015)).lerp(Vector((-.24,1.24,.34)),tuck)":"Vector((-.425,.845,.094)).lerp(Vector((-.14,1.25,.48)),tuck)",
        "arm_ik('R',right_hand,dodge_godot(key,t) @ Vector((-.50,1.32,.43)))":"arm_ik('R',right_hand,dodge_godot(key,t) @ Vector((-.46,1.30,.66)))",
        "Vector((.385,.88,.015)).lerp(Vector((.24,1.24,.34)),tuck)":"Vector((.425,.845,.094)).lerp(Vector((.14,1.25,.48)),tuck)"}
    for old,new in replacements.items():
        if old not in authored:raise RuntimeError('Current animation recipe changed; review fitted dodge hands')
        authored=authored.replace(old,new)
    source=ast.parse(authored)
    namespace={'bpy':bpy,'math':math,'Vector':Vector,'Matrix':Matrix,'rig':rig,
               'MOTION':json.loads((ROOT/'game/content/sword_motion.json').read_text()),
               'sample_draw':sample_draw,'draw_pose':draw_pose,'dodge_godot':dodge_godot,
               'dodge_blender':dodge_blender,'smooth':smooth}
    for action in list(bpy.data.actions):bpy.data.actions.remove(action)
    rig.animation_data_create()
    names={'sample_motion','aim_bone','arm_ik','plant_leg'}
    functions=[n for n in source.body if isinstance(n,ast.FunctionDef) and n.name in names]
    exec(compile(ast.Module(body=functions,type_ignores=[]),'fitted_animation_helpers','exec'),namespace)
    original_ik=namespace['arm_ik']
    def fitted_ik(side,target,pole=None):
        name=namespace.get('name','');phase=namespace.get('t',0)
        if side=='R' and name.endswith('sword'):pole=Vector((-.92,1.70,.22))
        if side=='R' and name=='parry_guard':
            shoulder=rig.pose.bones['upper_arm.R'].head
            default=Vector((shoulder.x,shoulder.z,-shoulder.y))+Vector((0,0,1))
            envelope=smooth(.60,.68,phase)*(1-smooth(.78,.94,phase))
            pole=default.lerp(Vector((-.70,1.80,.55)),envelope)
        original_ik(side,target,pole)
    namespace['arm_ik']=fitted_ik
    nodes = [n for n in source.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='actions' for t in n.targets)]
    nodes += [n for n in source.body if isinstance(n,ast.For) and isinstance(n.target,ast.Tuple) and any(isinstance(e,ast.Name) and e.id=='clip_name' for e in n.target.elts)]
    exec(compile(ast.Module(body=nodes,type_ignores=[]),str(ROOT/'tools/build_character.py'),'exec'),namespace)
    # Dense IK keys use continuous quaternions, avoiding Euler singularities
    # and Bezier overshoot that otherwise pull the palm away from the hilt.
    for action in bpy.data.actions:
        for layer in action.layers:
            for strip in layer.strips:
                for channelbag in strip.channelbags:
                    for curve in channelbag.fcurves:
                        for key in curve.keyframe_points:key.interpolation='LINEAR'
    for bone in rig.pose.bones:bone.rotation_mode='QUATERNION'
    rig.animation_data.action=bpy.data.actions['idle_loop'];bpy.context.scene.frame_set(1)

def remake(animate=True):
    review=ROOT/'art/character/model-review.json'
    if animate and review.exists() and json.loads(review.read_text()).get('status')=='awaiting_user_approval':
        raise RuntimeError('User approval of the static model is required before animation fitting.')
    rig=fit_rig()
    names=['GEO-body_female_realistic','GEO-body_female_realistic.eye.L','GEO-body_female_realistic.eye.R']
    with bpy.data.libraries.load(str(BASE),link=False) as (src,dst):dst.meshes=names
    base=dst.meshes[0];skin=material('skin_detail',(.90,.72,.56))
    cloth=material('dress_detail',(.34,.42,.48));hair=material('hair_detail',(.33,.20,.12))
    leather=material('leather_detail',(.36,.24,.14));cream=material('socks_detail',(.76,.73,.66))
    vv=[]
    for v in base.vertices:
        co=v.co.copy()
        # Curl the fingers naturally instead of compressing an entire hand into a mitten.
        if abs(co.x)>.32 and co.z<.735:
            d=.735-co.z;angle=min(1.8,d*15)
            co.y-=math.sin(angle)*d*.55;co.z=.735-math.cos(angle)*d
        at=co*SCALE
        if 1.26<at.z<1.54 and abs(at.x)<.17 and at.y<-.07:at.y=max(at.y,-.139+.025*(at.x/.20)**2)
        vv.append(at)
    body_polys=[p for p in base.polygons if not all(base.vertices[i].co.z<.19 for i in p.vertices)]
    body=make('Anatomical body',vv,[tuple(p.vertices) for p in body_polys],[skin],
              [weight(v.co) for v in base.vertices],source_uv=[base.uv_layers.active.data[li].uv.copy() for p in body_polys for li in p.loop_indices])
    lips=material('lips_detail',(.57,.31,.27));body.data.materials.append(lips)
    body=substitute('module_body',body);refine(body)
    # Separate modular left arm is disabled for this complete, connected body.
    bpy.data.objects['left_arm_human'].data.clear_geometry()
    # The blouse is cut from the same shoulder/arm topology, with ease added over skin.
    keep=[]
    for p in base.polygons:
        coords=[base.vertices[i].co for i in p.vertices]
        if all(1.06<v.z<1.42 and not (abs(v.x)>.20 and v.z<1.135) for v in coords):keep.append(p)
    vertices=[];indices={};faces=[];uv=[];weights=[]
    for p in keep:
        face=[]
        for vi in p.vertices:
            if vi not in indices:
                v=base.vertices[vi];at=v.co*SCALE+v.normal*.014
                at.y-=.015 if at.y<0 else 0
                if 1.26<at.z<1.54 and at.y<-.07:
                    at.y=-.171+.035*(at.x/.20)**2+.0035*math.sin(at.x*72+at.z*8)
                cinch=.10*math.exp(-((at.z-1.235)/.068)**2)
                if abs(at.x)<.23:at.x*=1-cinch
                indices[vi]=len(vertices);vertices.append(at);weights.append(weight(v.co))
            face.append(indices[vi])
        faces.append(face)
        uv.extend(base.uv_layers.active.data[li].uv.copy() for li in p.loop_indices)
    blouse=make('Connected blouse',vertices,faces,[cloth],weights,source_uv=uv)
    # Replace the whole old dress; no primitive shirt, sleeves or detached collar survive.
    dress=substitute('outfit_dress',blouse);refine(dress)
    pieces=[]
    # A knee-length, pleated skirt with two-bone secondary motion and hem thickness.
    rings=[(1.260,.194,.187),(1.15,.218,.186),(1.02,.243,.193),(.86,.281,.216),(.70,.319,.239),(.58,.345,.258)]
    v=[];f=[];uv=[];weights=[];n=96
    for j,(z,rx,ry) in enumerate(rings):
        for k in range(n):
            a=k*math.tau/n;pleat=.020*(j/(len(rings)-1))*math.cos(a*12)
            # Walking knees need front ease; retain the audited back silhouette
            # beside the mounted sword rather than widening the entire skirt.
            front_ease=.055*j/5*max(0,-math.sin(a))**2
            v.append((math.cos(a)*(rx+pleat),math.sin(a)*(ry+pleat)-front_ease,z+.007*math.sin(a*3)*j/5))
            uv.append((k/n,j/5));sway=.45*j/5;spine=smooth(1.04,1.25,z)*(1-sway)
            weights.append({'spine':spine,'pelvis':1-sway-spine,'skirt_sway':sway})
            if j:f.append((j*n+k,j*n+(k+1)%n,(j-1)*n+(k+1)%n,(j-1)*n+k))
    skirt=make('Pleated skirt',v,f,[cloth],weights,uv);refine(skirt)
    pieces.append(skirt)
    # Rolled cuffs follow the anatomical arm surface at the sleeve opening.
    for sign,side in [(-1,'R'),(1,'L')]:
        start=Vector((sign*.276,-.016,1.267));end=Vector((sign*.291,-.015,1.230))
        axis=(end-start).normalized();across=axis.cross(Vector((0,1,0))).normalized();front=axis.cross(across)
        v=[];f=[];uv=[]
        for j in range(5):
            at=start.lerp(end,j/4);r=.049+.003*math.sin(j/4*math.pi)
            for k in range(32):
                a=k*math.tau/32;v.append(at+across*math.cos(a)*r+front*math.sin(a)*r)
                uv.append((k/32,j/4))
                if j:f.append(((j-1)*32+k,(j-1)*32+(k+1)%32,j*32+(k+1)%32,j*32+k))
        pieces.append(make('Rolled cuff',v,f,[cream],[{'upper_arm.'+side:1}]*len(v),uv))
    # Neckband/collar and placket follow the surface rather than floating at shoulder height.
    v=[];f=[]
    for j,z in enumerate([1.531,1.561]):
        for k in range(48):
            a=k*math.tau/48;v.append((math.cos(a)*.092,-.018+math.sin(a)*.088,z))
            if j and math.sin(a)>-.60:f.append((k,(k+1)%48,48+(k+1)%48,48+k))
    pieces.append(make('Finished neckband',v,f,[cloth],[{'spine':.8,'head':.2}]*len(v)))
    for sign in [-1,1]:
        p=[(sign*.030,-.177,1.545),(sign*.070,-.162,1.530),(sign*.092,-.184,1.447),(sign*.031,-.196,1.493)]
        faces=[(0,1,2,3) if sign<0 else (3,2,1,0)]
        collar=make('Pointed collar',p,faces,[cloth],[{'spine':1}]*4)
        solid=collar.modifiers.new('Collar thickness','SOLIDIFY');solid.thickness=.003
        bpy.context.view_layer.objects.active=collar;bpy.ops.object.modifier_apply(modifier=solid.name)
        pieces.append(collar)
    tree=BVHTree.FromPolygons([v.co for v in dress.data.vertices],[tuple(p.vertices) for p in dress.data.polygons])
    button=material('buttons_detail',(.16,.12,.075))
    for z in [1.28,1.34,1.40,1.46,1.51]:
        hit=tree.ray_cast(Vector((0,-.4,z)),Vector((0,1,0)))[0]
        if hit is None:continue
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,location=hit+Vector((0,-.004,0)))
        o=bpy.context.object;o.scale=(.006,.003,.006);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        o.data.materials.append(button);o.vertex_groups.new(name='spine').add(list(range(len(o.data.vertices))),1,'REPLACE');pieces.append(o)
    # Low-profile leather belt and rectangular metal buckle.
    belt_vertices=[];belt_faces=[]
    for part in [dress,skirt]:
        offset=len(belt_vertices);belt_vertices.extend(v.co.copy() for v in part.data.vertices)
        belt_faces.extend(tuple(offset+i for i in p.vertices) for p in part.data.polygons)
    belt_tree=BVHTree.FromPolygons(belt_vertices,belt_faces)
    v=[];f=[]
    for j,z in enumerate([1.203,1.219,1.235,1.251,1.267]):
        for k in range(64):
            a=k*math.tau/64;outward=Vector((math.cos(a),math.sin(a),0))
            hit=belt_tree.ray_cast(outward*.24+Vector((0,0,z)),-outward)[0]
            v.append(hit+outward*.004 if hit is not None else Vector((math.cos(a)*.206,math.sin(a)*.185,z)))
            if j:f.append(((j-1)*64+k,(j-1)*64+(k+1)%64,j*64+(k+1)%64,j*64+k))
    pieces.append(make('Leather belt',v,f,[leather],[{'spine':1}]*len(v)))
    buckle=material('metal_detail',(.57,.47,.30))
    belt_front=belt_tree.ray_cast(Vector((0,-.3,1.235)),Vector((0,1,0)))[0]
    buckle_y=belt_front.y-.009 if belt_front is not None else -.211
    for at,size in [((0,buckle_y,1.265),(.052,.008,.006)),((0,buckle_y,1.205),(.052,.008,.006)),((-.029,buckle_y,1.235),(.006,.008,.058)),((.029,buckle_y,1.235),(.006,.008,.058))]:
        bpy.ops.mesh.primitive_cube_add(size=1,location=at);o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        o.data.materials.append(buckle);o.vertex_groups.new(name='spine').add(list(range(len(o.data.vertices))),1,'REPLACE');pieces.append(o)
    weld_join(dress,pieces)
    # Compact boot lasts: sole, vamp, ankle, folded sock cuff and laced tongue.
    boots=bpy.data.objects['footwear_boots'];boots.data.clear_geometry();parts=[]
    for sign,side in [(-1,'R'),(1,'L')]:
        rings=[(.018,.063,.116,-.037),(.038,.066,.118,-.038),(.072,.066,.114,-.036),(.102,.061,.098,-.022),(.140,.052,.072,.017),(.185,.049,.054,.049),(.220,.051,.053,.052),(.247,.053,.055,.052)]
        v=[];f=[];weights=[]
        for j,(z,rx,ry,cy) in enumerate(rings):
            for k in range(48):
                a=k*math.tau/48;v.append((sign*.14+math.cos(a)*rx,cy+math.sin(a)*ry,z))
                shin=smooth(.11,.25,z);weights.append({'foot.'+side:1-shin,'shin.'+side:shin})
                if j:f.append(((j-1)*48+k,(j-1)*48+(k+1)%48,j*48+(k+1)%48,j*48+k))
        f.append(tuple(reversed(range(48))))
        shoe=make('Compact boot vamp',v,f,[leather],weights);refine(shoe);parts.append(shoe)
        dark=material('leather_dark',(.22,.14,.09))
        v=[];f=[]
        for j,(z,rx,ry) in enumerate([(.002,.066,.121),(.016,.067,.122),(.032,.066,.121)]):
            for k in range(48):
                a=k*math.tau/48;v.append((sign*.14+math.cos(a)*rx,-.037+math.sin(a)*ry,z))
                if j:f.append(((j-1)*48+k,(j-1)*48+(k+1)%48,j*48+(k+1)%48,j*48+k))
        f.extend([tuple(reversed(range(48))),tuple(96+k for k in range(48))])
        parts.append(make('Boot welt and sole',v,f,[dark],[{'foot.'+side:1}]*len(v)))
        v=[];f=[]
        for j,(z,r) in enumerate([(.238,.050),(.260,.054),(.286,.055),(.302,.052)]):
            for k in range(40):
                a=k*math.tau/40;v.append((sign*.14+math.cos(a)*r*1.05,.045+math.sin(a)*r*1.18,z))
                if j:f.append(((j-1)*40+k,(j-1)*40+(k+1)%40,j*40+(k+1)%40,j*40+k))
        cuff=make('Folded knitted socks',v,f,[cream],[{'shin.'+side:1}]*len(v));parts.append(cuff)
        for j in range(5):
            z=.115+j*.022
            lower,upper=next((lo,hi) for lo,hi in zip(rings,rings[1:]) if lo[0]<=z<=hi[0])
            t=(z-lower[0])/(upper[0]-lower[0]);ry=lower[2]*(1-t)+upper[2]*t;cy=lower[3]*(1-t)+upper[3]*t
            for direction in [-1,1]:
                front=cy-ry-.003;edge=cy-ry*.85-.003
                parts.append(curve('Boot lace',[(sign*.14-direction*.027,edge,z),(sign*.14-direction*.011,front,z+.005),(sign*.14+direction*.011,front,z+.012),(sign*.14+direction*.027,edge,z+.018)],.0021,.0021,cream,'shin.'+side))
    weld_join(boots,parts)
    for obj in [body,dress,boots]:
        for vertex in obj.data.vertices:vertex.co=body_fit(vertex.co)
        obj.data.update()
    # New face and hairstyle are modeled in the final design coordinates.
    build_face(body,skin)
    build_bob(hair)
    for obj in [body,dress,boots,bpy.data.objects['hair_bob']]:
        for vertex in obj.data.vertices:vertex.co=proportion_fit(vertex.co,obj.name=='hair_bob')
        obj.data.update()
    if animate:retarget(rig)
    else:
        rig.animation_data_clear()
        for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
    return {'height_m':max(v.co.z for v in bpy.data.objects['hair_bob'].data.vertices)*.92,'body_source':'CC0 anatomical topology sculpted to reference proportions','whole_body':True,'rig_retargeted':animate,'design':DESIGN}


