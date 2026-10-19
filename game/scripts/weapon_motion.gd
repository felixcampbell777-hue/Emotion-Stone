extends RefCounted
const Models=preload("res://scripts/weapon_models.gd")
## Deterministic camera/observer-local poses. Weapon -Y points toward its tip.
static func sample(kind:String,key:String,t:float,charge:float=0.0) -> Dictionary:
 var grip=Vector3(.26,-.34,-.55)
 var direction=Vector3(.06,.13,-1).normalized()
 var left=Vector3(-.25,-.35,-.48)
 var pulse=smoothstep(.12,.36,t)*(1-smoothstep(.58,.92,t))
 if kind=="spear":
  grip=Vector3(.10,-.16,-.40);direction=Vector3(-.06,-.22,-1).normalized()
  if key=="attack":grip+=Vector3(-.04,.025,-.12)*pulse
  left=grip-direction*.06
 elif kind=="rapier":
  grip=Vector3(.16,-.16,-.42);direction=Vector3(-.08,-.40,-1).normalized()
  if key=="attack":grip+=Vector3(-.06,.015,-.14)*pulse
  left=Vector3(-.29,-.31,-.38)+Vector3(-.07,.025,.06)*pulse
 elif kind=="bow":
  grip=Models.bow_grip();direction=Vector3.DOWN
  left=grip
  # The right hand follows the nock backward to the cheek as the string draws.
  if key=="attack":charge*=1-smoothstep(0,.4,t)
 if key=="parry":
  var brace=smoothstep(0,.12,t)*(1-smoothstep(.65,1,t))
  grip=grip.lerp(Vector3(.12,-.16,-.58),brace)
  if kind!="bow":direction=direction.slerp(Vector3(.35,.9,-.18).normalized(),brace)
 if key in ["draw","sheathe"]:grip.y-=.8*(1-smoothstep(0,1,t));left.y-=.6*(1-smoothstep(0,1,t))
 if kind=="spear":left=grip-direction*.06
 elif kind=="bow":left=grip
 var right=grip
 if kind=="bow":right=grip+Models.nock_position(charge)
 return {"grip":grip,"direction":direction,"right_hand":right,"left_hand":left,"right_axis":direction if kind!="bow" else Vector3.UP,"left_axis":direction if kind!="bow" else Vector3.UP,"grasp_right":1.0,"grasp_left":1.0 if kind in ["bow","spear"] else 0.0}
static func weapon_transform(frame:Transform3D,pose:Dictionary) -> Transform3D:
 var up:Vector3=-pose.direction.normalized()
 var right=Vector3.RIGHT-up*up.x
 if right.length_squared()<.00001:right=Vector3.FORWARD-up*up.z
 right=right.normalized()
 return frame*Transform3D(Basis(right,up,right.cross(up)),pose.grip)
static func contact_segments(transform:Transform3D,profile:Dictionary) -> Array:
 var reach=float(profile.get("length",0))
 var start=maxf(0,reach-float(profile.get("damaging_length",0)))
 return [transform*Vector3(0,-start,0),transform*Vector3(0,-reach,0)]
