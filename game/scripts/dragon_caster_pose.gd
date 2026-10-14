extends RefCounted
## Terrain-anchored channel pose. Existing body/weapon assets remain authoritative.
var tuning=JSON.parse_string(FileAccess.get_file_as_string("res://content/sea_dragon_pose.json"))
var incoming=Transform3D.IDENTITY
func vector(value:Array) -> Vector3: return Vector3(value[0],value[1],value[2])
func phase(actor:Node3D) -> float: return 1-clampf(actor.state_time/actor.state_duration,0,1) if actor.state=="dragon_recover" else clampf(actor.state_time/float(tuning.entry_seconds),0,1)
func frame(actor:Node3D) -> Transform3D: return Transform3D(Basis(Vector3.UP,actor.visual.rotation.y),actor.global_position)
func plant(actor:Node3D) -> Transform3D:
	var body=frame(actor);var offset=vector(tuning.tip_offset)
	if not actor.equipment.get_meta("beta_sword",false): offset.z=1.30
	var tip=body*offset
	if is_instance_valid(actor.ground_world): tip.y=actor.ground_world.ground_height(tip)+float(tuning.tip_offset[1])
	var up=(body.basis*(vector(tuning.blade_up) if actor.equipment.get_meta("beta_sword",false) else Vector3(0,.72,-.694))).normalized()
	var right=body.basis.x-up*body.basis.x.dot(up);right=right.normalized()
	var axis=Basis(right,up,right.cross(up));var end=actor.BetaSwordMotion.TIP if actor.equipment.get_meta("beta_sword",false) else -1.285
	return Transform3D(axis*float(actor.combat.sword_scale),tip-up*end*float(actor.combat.sword_scale))
func start(actor:Node3D) -> void: incoming=frame(actor).affine_inverse()*actor.equipment.global_transform
func weapon(actor:Node3D) -> void:
	var t=phase(actor);var body=frame(actor);var planted=plant(actor)
	var hilt=actor.BetaSwordMotion.GRIP if actor.equipment.get_meta("beta_sword",false) else .16
	var initial=body*incoming
	var start_grip=initial*Vector3(0,hilt,0)
	var end_grip=planted*Vector3(0,hilt,0)
	var middle=body*vector(tuning.middle_grip)
	var grip=start_grip.lerp(middle,smoothstep(0,.4,t)) if t<.4 else middle.lerp(end_grip,smoothstep(.4,1,t))
	var mid_up=(body.basis*vector(tuning.middle_up)).normalized()
	var up=initial.basis.y.normalized().slerp(mid_up,smoothstep(0,.4,t)) if t<.4 else mid_up.slerp(planted.basis.y.normalized(),smoothstep(.4,1,t))
	var right=body.basis.x-up*body.basis.x.dot(up)
	if right.length_squared()<.00001: right=body.basis.z-up*body.basis.z.dot(up)
	right=right.normalized();var basis=Basis(right,up,right.cross(up))*float(actor.combat.sword_scale)
	actor.equipment.global_transform=Transform3D(basis,grip-basis*Vector3(0,hilt,0))
func set_basis(rig:Skeleton3D,index:int,global_basis:Basis) -> void:
	var parent=rig.get_bone_parent(index)
	if parent>=0: global_basis=rig.get_bone_global_pose(parent).basis.inverse()*global_basis
	rig.set_bone_pose_rotation(index,global_basis.orthonormalized().get_rotation_quaternion());rig.force_update_all_bone_transforms()
func aim(rig:Skeleton3D,index:int,child:int,direction:Vector3) -> void:
	var old=rig.get_bone_global_pose(child).origin-rig.get_bone_global_pose(index).origin
	set_basis(rig,index,Basis(Quaternion(old.normalized(),direction.normalized()))*rig.get_bone_global_pose(index).basis)
func chain(rig:Skeleton3D,upper:int,lower:int,end:Vector3,target:Vector3,pole:Vector3) -> void:
	var shoulder=rig.get_bone_global_pose(upper).origin;var elbow=rig.get_bone_global_pose(lower).origin
	var a=rig.get_bone_global_rest(upper).origin.distance_to(rig.get_bone_global_rest(lower).origin);var b=end.length()
	var direction=(target-shoulder).normalized();var distance=clampf(shoulder.distance_to(target),.02,a+b-.001)
	var along=(a*a-b*b+distance*distance)/(2*distance)
	pole-=direction*pole.dot(direction)
	if pole.length_squared()<.00001: pole=Vector3.RIGHT
	var bent=shoulder+direction*along+pole.normalized()*sqrt(maxf(0,a*a-along*along))
	aim(rig,upper,lower,bent-shoulder)
	var pose=rig.get_bone_global_pose(lower)
	set_basis(rig,lower,Basis(Quaternion((pose.basis*end).normalized(),(shoulder+direction*distance-bent).normalized()))*pose.basis)
func apply_rig(rig:Skeleton3D,actor:Node3D,personal:bool) -> void:
	var weight=smoothstep(0,1,phase(actor));var original=[]
	for i in range(rig.get_bone_count()): original.append(rig.get_bone_pose(i));rig.set_bone_pose(i,rig.get_bone_rest(i))
	rig.force_update_all_bone_transforms()
	var to_rig=rig.global_transform.affine_inverse();var body=frame(actor)
	var pelvis=rig.find_bone("pelvis");var shifted=rig.get_bone_rest(pelvis)
	shifted.origin+=to_rig.basis*Vector3(0,-float(tuning.pelvis_drop),0);rig.set_bone_pose(pelvis,shifted);rig.force_update_all_bone_transforms()
	var rest_spine=rig.get_bone_global_rest(rig.find_bone("spine")).basis
	set_basis(rig,rig.find_bone("spine"),Basis(Vector3.RIGHT,.15)*Basis(Vector3.BACK,-.15)*rest_spine)
	set_basis(rig,rig.find_bone("head"),Basis(Vector3.RIGHT,.04)*rig.get_bone_global_rest(rig.find_bone("head")).basis)
	for side in ["L","R"]:
		var thigh=rig.find_bone("thigh."+side);var shin=rig.find_bone("shin."+side);var foot=rig.find_bone("foot."+side)
		var target=body*vector(tuning.left_ankle if side=="L" else tuning.right_ankle)
		if is_instance_valid(actor.ground_world): target.y=actor.ground_world.ground_height(target)+float((tuning.left_ankle if side=="L" else tuning.right_ankle)[1])
		var foot_vector=rig.get_bone_rest(foot).origin
		var pole=to_rig.basis*body.basis*(Vector3(0,1,.7) if side=="L" else Vector3(0,-.8,1))
		chain(rig,thigh,shin,foot_vector,to_rig*target,pole)
		set_basis(rig,foot,(Basis.IDENTITY if side=="L" else Basis(Vector3.RIGHT,.85))*rig.get_bone_global_rest(foot).basis)
	# A small clavicle lift lets her support the oversized hilt without stretching the arm.
	var shoulder=rig.find_bone("upper_arm.R");var shoulder_pose=rig.get_bone_pose(shoulder)
	var shoulder_parent=rig.get_bone_parent(shoulder)
	shoulder_pose.origin+=rig.get_bone_global_pose(shoulder_parent).basis.inverse()*to_rig.basis*Vector3(0,float(tuning.shoulder_lift),0)
	rig.set_bone_pose(shoulder,shoulder_pose);rig.force_update_all_bone_transforms()
	var skirt=rig.find_bone("skirt_sway")
	if skirt>=0:
		rig.set_bone_pose_rotation(skirt,(Basis(Vector3.RIGHT,-.35)*rig.get_bone_rest(skirt).basis).get_rotation_quaternion());rig.set_bone_pose_scale(skirt,Vector3(1.12,1,1.18))
	# Blend body/legs from the incoming pose, then fit palms to the real hilt/knee.
	for i in range(original.size()): rig.set_bone_pose(i,original[i].interpolate_with(rig.get_bone_pose(i),weight))
	rig.force_update_all_bone_transforms()
	for side in ["L","R"]:
		var upper=rig.find_bone("upper_arm."+side);var lower=rig.find_bone("forearm."+side)
		var palm=Vector3(-.017 if side=="R" else .017,-.30,.012) if personal else Vector3(0,.31,0)
		var current=rig.get_bone_global_pose(lower)*palm
		var hilt=actor.BetaSwordMotion.GRIP if actor.equipment.get_meta("beta_sword",false) else .16
		var grip=lerpf(hilt,float(tuning.right_grip),weight)
		var target=to_rig*(actor.equipment.global_transform*Vector3(0,grip,0)) if side=="R" else current.lerp(rig.get_bone_global_pose(rig.find_bone("shin.L")).origin+to_rig.basis*body.basis*Vector3(.015,.075,.025),weight)
		var pole=to_rig.basis*body.basis*Vector3(-.8 if side=="R" else .8,-.5,-.2)
		chain(rig,upper,lower,palm,target,pole)
