"""Shared authored dodge root transform (Godot axes -> Blender)."""
import math
from mathutils import Matrix, Vector, Euler
CONVERSION=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
def smooth(a,b,t):
 f=max(0,min(1,(t-a)/(b-a)));return f*f*(3-2*f)
def dodge_godot(key,t):
 tuck=smooth(.02,.18,t) if key=='roll' else 1-smooth(.04,.90,t)
 turn=math.tau*smooth(.16,.88,t) if key=='roll' else math.tau
 rot=Matrix.Rotation(turn,4,'X')
 pivot=Vector((0,.95,0))
 height=.95-.31*tuck+.04*math.sin(turn*.5) if key=='roll' else .95-.31*tuck
 center=Vector((0,height,0))
 rot.translation=center-rot.to_3x3() @ pivot
 return rot
def dodge_blender(key,t): return CONVERSION @ dodge_godot(key,t) @ CONVERSION.inverted()

def sword_right(up,key,t):
 rotation=dodge_godot(key,t).to_3x3() if key in ['roll','stand'] else Matrix.Identity(3)
 local_up=rotation.inverted() @ up
 weight=smooth(.02,.16,t) if key=='roll' else 1-smooth(.72,1,t) if key=='stand' else 0
 hint=Vector((1-weight,-weight,0))
 right=hint-local_up*hint.dot(local_up)
 if right.length_squared<.00001: right=Vector((0,1,0))-local_up*local_up.y
 return rotation @ right.normalized()


def back_mount_pose():
    up=Vector((-.82,.55,.10)).normalized()
    right=(Vector((1,0,0))-up*up.x).normalized()
    depth=right.cross(up)
    basis=Matrix((right,up,depth)).transposed().to_4x4()
    basis.translation=Vector((-.88,1.62,-.20))-up*.256
    return basis

def draw_mount(spine,rest):
    # Author in character space, then follow the animated spine relative to bind pose.
    return CONVERSION.inverted() @ spine @ rest.inverted() @ CONVERSION @ back_mount_pose()

def sample_draw(poses,t):
    def value(i,key):
        grip=Vector(poses[i]['grip'])
        return grip if key=='grip' else (Vector(poses[i]['tip'])-grip).normalized()
    def tangent(i,key):
        if poses[i]['t']<=.10 or poses[i]['t']>=.82: return Vector((0,0,0))
        return (value(i+1,key)-value(i-1,key))/(poses[i+1]['t']-poses[i-1]['t'])
    for i,(a,b) in enumerate(zip(poses,poses[1:])):
        if t<=b['t']:
            f=max(0,min(1,(t-a['t'])/(b['t']-a['t'])))
            if a['t']>=.10 and b['t']<=.82:
                dt=b['t']-a['t']
                def curve(key):
                    return value(i,key)*(2*f**3-3*f**2+1)+tangent(i,key)*dt*(f**3-2*f**2+f)+value(i+1,key)*(-2*f**3+3*f**2)+tangent(i+1,key)*dt*(f**3-f**2)
                grip=curve('grip'); direction=curve('direction').normalized()
            else:
                f=f*f*(3-2*f)
                grip=value(i,'grip').lerp(value(i+1,'grip'),f)
                direction=value(i,'direction').slerp(value(i+1,'direction'),f)
            return grip,grip+direction*2.128
    return Vector(poses[-1]['grip']),Vector(poses[-1]['tip'])

def draw_pose(grip,tip,spine,rest,phase):
    mount=draw_mount(spine,rest)
    delta=mount @ back_mount_pose().inverted()
    weight=smooth(.10,.31,phase)
    direction=(tip-grip).normalized()
    grip=(delta @ grip).lerp(grip,weight)
    direction=(delta.to_3x3() @ direction).normalized().slerp(direction,weight)
    return grip,grip+direction*2.128

def draw_right(up,spine,rest,phase):
    hint=(draw_mount(spine,rest).to_3x3() @ Vector((1,0,0))).lerp(Vector((1,0,0)),smooth(.10,.31,phase))
    right=hint-up*hint.dot(up)
    return right.normalized() if right.length_squared>.00001 else sword_right(up,'drag',0)
