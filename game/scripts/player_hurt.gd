extends RefCounted
## Combat-only anatomy; the existing movement capsule and terrain solver are unchanged.
## Dimensions follow the approved neutral heroine: shoulders ~1.28m, head pivot ~1.50m,
## crown ~1.67m. Anchors use the accepted animated rig, independent of cosmetic meshes.
const Steel=preload("res://scripts/steel_contact.gd")
const HEAD_RADIUS=.115
const HEAD_CENTER=.055
const TORSO_RADIUS=.19

static func volumes(actor:Node3D) -> Array:
 var result=[{"from":actor.global_position+Vector3.UP*.23,"to":actor.global_position+Vector3.UP*.89,"radius":.23,"region":"lower_body"}]
 var rig:Skeleton3D=preload("res://scripts/network/wr_view_frame.gd").actor_rig(actor)
 if not is_instance_valid(rig):return result
 rig.force_update_all_bone_transforms()
 var head=rig.find_bone("head");var pelvis=rig.find_bone("pelvis")
 var left=rig.find_bone("upper_arm.L");var right=rig.find_bone("upper_arm.R")
 if head<0 or pelvis<0 or left<0 or right<0:return result
 var head_pose=rig.global_transform*rig.get_bone_global_pose(head)
 var shoulder=((rig.global_transform*rig.get_bone_global_pose(left)).origin+(rig.global_transform*rig.get_bone_global_pose(right)).origin)*.5
 var hip=(rig.global_transform*rig.get_bone_global_pose(pelvis)).origin
 result.append({"from":hip,"to":shoulder,"radius":TORSO_RADIUS,"region":"torso"})
 var cranial_up=(head_pose.basis*rig.get_bone_global_rest(head).basis.inverse()*Vector3.UP).normalized()
 var center=head_pose.origin+cranial_up*HEAD_CENTER
 result.append({"from":center,"to":center,"radius":HEAD_RADIUS,"region":"head"})
 return result

static func steel_contact(actor:Node3D,current:Array,previous:Array,margin:float,clearance:Callable=Callable()) -> Dictionary:
 if current.size()!=2:return {"hit":false,"point":Vector3.ZERO,"region":""}
 var best={"hit":false,"point":Vector3.ZERO,"region":"","fraction":INF}
 for volume in volumes(actor):
  # Rotate an arbitrary native capsule into the vertical solver's coordinate system.
  var axis:Vector3=volume.to-volume.from
  var length=axis.length()
  var up=axis/length if length>.000001 else Vector3.UP
  var right=up.cross(Vector3.FORWARD).normalized() if absf(up.dot(Vector3.FORWARD))<.99 else up.cross(Vector3.RIGHT).normalized()
  var basis=Basis(right,up,right.cross(up))
  var inverse=basis.transposed()
  var local_current=[inverse*(current[0]-volume.from),inverse*(current[1]-volume.from)]
  var local_previous=local_current
  if previous.size()==2:local_previous=[inverse*(previous[0]-volume.from),inverse*(previous[1]-volume.from)]
  var radius=float(volume.radius)
  var clear=Callable()
  if clearance.is_valid():clear=func(point:Vector3):return clearance.call(volume.from+basis*point)
  var hit=Steel.capsule(local_current,local_previous,Vector3.DOWN*radius,radius,length+radius*2,margin,clear)
  if hit.hit and float(hit.fraction)<float(best.fraction):best={"hit":true,"point":volume.from+basis*hit.point,"region":volume.region,"fraction":hit.fraction}
 return best

static func segment_contact(actor:Node3D,from:Vector3,to:Vector3) -> Dictionary:
 return segment_volumes(volumes(actor),from,to)

static func segment_volumes(accepted_volumes:Array,from:Vector3,to:Vector3) -> Dictionary:
 var best={"hit":false,"point":Vector3.ZERO,"fraction":INF,"region":""}
 for volume in accepted_volumes:
  var fraction=segment_capsule(from,to,volume.from,volume.to,float(volume.radius))
  if fraction>=0 and fraction<float(best.fraction):
   var point=from.lerp(to,fraction);var axis:Vector3=volume.to-volume.from
   var closest:Vector3=volume.from
   if axis.length_squared()>.000000001:closest+=axis*clampf((point-volume.from).dot(axis)/axis.length_squared(),0,1)
   var normal=(point-closest).normalized()
   if normal.length_squared()<.000001:normal=(from-to).normalized()
   best={"hit":true,"point":point,"fraction":fraction,"region":volume.region,"normal":normal}
 return best

static func segment_capsule(from:Vector3,to:Vector3,a:Vector3,b:Vector3,radius:float) -> float:
 var direction=to-from;var axis=b-a;var offset=from-a
 var axis_squared=axis.length_squared()
 var closest=a+axis*clampf(offset.dot(axis)/axis_squared,0,1) if axis_squared>.000000001 else a
 if from.distance_squared_to(closest)<=radius*radius:return 0.0
 var best=INF
 for center in [a,b]:
  var relative=from-center;var aa=direction.length_squared()
  if aa<=.000000001:continue
  var bb=relative.dot(direction);var cc=relative.length_squared()-radius*radius
  var discriminant=bb*bb-aa*cc
  if discriminant>=0:
   var fraction=(-bb-sqrt(discriminant))/aa
   if fraction>=0 and fraction<=1:best=minf(best,fraction)
 if axis_squared>.000000001:
  var axis_direction=axis.dot(direction);var axis_offset=axis.dot(offset)
  var aa=axis_squared*direction.length_squared()-axis_direction*axis_direction
  var bb=axis_squared*direction.dot(offset)-axis_offset*axis_direction
  var cc=axis_squared*offset.length_squared()-axis_offset*axis_offset-radius*radius*axis_squared
  var discriminant=bb*bb-aa*cc
  if absf(aa)>.000000001 and discriminant>=0:
   var fraction=(-bb-sqrt(discriminant))/aa
   var along=axis_offset+fraction*axis_direction
   if fraction>=0 and fraction<=1 and along>=0 and along<=axis_squared:best=minf(best,fraction)
 return best if best<INF else -1.0
