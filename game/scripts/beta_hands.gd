extends RefCounted
## Fit the reused body motion to the narrower hilt without stretching arm bones.
# Measured from the imported skin's inverse binds, rather than a guessed bone axis.
const PALM=Vector3(-.017,-.30,.012)
func apply(hero:Node3D) -> void:
	var actor=hero.actor
	if not actor.sword_equipped or not actor.sword_drawn: return
	var weight=1.0
	if actor.current_clip in ["draw_sword","sheathe_sword"]:
		var phase=actor.animator.current_animation_position/actor.animator.get_animation(actor.clips[actor.current_clip]).length
		if actor.current_clip=="sheathe_sword": phase=1-phase
		weight=smoothstep(.08,.32,phase)
	if weight<=0: return
	var to_rig=hero.rig.global_transform.affine_inverse()*actor.equipment.global_transform
	var beta_weapon=bool(actor.equipment.get_meta("beta_sword",false))
	fit(hero,"R",to_rig*Vector3(0,actor.BetaSwordMotion.GRIP if beta_weapon else .16,0),weight)
	if actor.current_clip in ["attack_light2","attack_light3","attack_heavy","attack_lance","attack_thrust"]:
		fit(hero,"L",to_rig*Vector3(0,.182 if beta_weapon else .08,0),weight)

func fit(hero:Node3D,side:String,target:Vector3,weight:float) -> void:
	var upper=hero.gait.bone(hero,"upper_arm",side); var lower=hero.gait.bone(hero,"forearm",side)
	var shoulder=hero.rig.get_bone_global_pose(upper).origin
	var lower_pose=hero.rig.get_bone_global_pose(lower)
	var elbow=lower_pose.origin
	var local_palm=PALM; local_palm.x*=1 if side=="R" else -1
	var palm=lower_pose*local_palm
	target=palm.lerp(target,weight)
	var a=hero.global_rests[upper].origin.distance_to(hero.global_rests[lower].origin)
	var b=local_palm.length()
	var direction=(target-shoulder).normalized()
	var distance=clampf(shoulder.distance_to(target),.02,a+b-.001)
	var along=(a*a-b*b+distance*distance)/(2*distance)
	var pole=elbow-shoulder; pole-=direction*pole.dot(direction)
	if pole.length_squared()<.00001: pole=Vector3.RIGHT if side=="L" else Vector3.LEFT
	var bent=shoulder+direction*along+pole.normalized()*sqrt(maxf(0,a*a-along*along))
	hero.gait.aim(hero,upper,lower,bent-shoulder)
	lower_pose=hero.rig.get_bone_global_pose(lower)
	var rotation=Basis(Quaternion((lower_pose.basis*local_palm).normalized(),(shoulder+direction*distance-bent).normalized()))
	hero.gait.set_global_basis(hero,lower,rotation*lower_pose.basis)
