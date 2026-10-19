extends RefCounted
## Fit the reused body motion to the narrower hilt without stretching arm bones.
# Measured from the imported skin's inverse binds, rather than a guessed bone axis.
const PALM=Vector3(-.017,-.30,.012)
var body_wrist=preload("res://scripts/wr_body_wrist.gd").new()
func prepare_transition(hero:Node3D) -> void:
	body_wrist.prepare_transition(hero)

func capture_hurt_shoulders(hero:Node3D) -> void:
	# Hurt anatomy reads accepted body/gait anchors before view-only carry/IK.
	var anchors={}
	for side in ["L","R"]:
		var upper=hero.gait.bone(hero,"upper_arm",side)
		anchors[side]=(hero.rig.global_transform*hero.rig.get_bone_global_pose(upper)).origin
	hero.rig.set_meta("canonical_hurt_shoulders",anchors)

func apply(hero:Node3D) -> void:
	var actor=hero.actor
	if body_wrist.apply(hero):return
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
	if actor.first_person_driver!=null and (actor.weapon_runtime==null or not actor.weapon_runtime.enabled()):
		# Third-person and remote observers hold the same forward steel as the
		# canonical contact frame. This only fits body arms, never moves the blade.
		var left_weight=0.0 if actor.state in ["roll","stand"] else 1.0
		if actor.state in ["draw","sheathe"]:
			var phase=actor.state_time/maxf(.001,actor.state_duration)
			if actor.state=="sheathe":phase=1-phase
			left_weight=smoothstep(.35,.75,phase)
		if actor.state=="water":
			var phase=actor.state_time/maxf(.001,actor.state_duration)
			left_weight=maxf(1-smoothstep(0,.14,phase),smoothstep(.80,1,phase))
		var left=Vector3(0,.20 if beta_weapon else .08,0)
		if actor.state=="parry":
			var phase=actor.parry_pose_phase(actor.state_time/maxf(.001,actor.state_duration))
			var brace=smoothstep(.10,.30,phase)*(1-smoothstep(.65,.90,phase))
			left=left.lerp(Vector3(0,-.34,.045),brace)
			left_weight*=1-brace
		if left_weight>0:fit(hero,"L",to_rig*left,weight*left_weight)
	elif actor.current_clip in ["attack_light2","attack_light3","attack_heavy","attack_lance","attack_thrust"]:
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
	if hero.actor.first_person_driver!=null and (hero.actor.weapon_runtime==null or not hero.actor.weapon_runtime.enabled()):
		# Canonical forward grips include the head's safe forward offset. Bounded
		# shoulder protraction reaches that hilt without stretching the arm bones.
		var excess=maxf(0,shoulder.distance_to(target)-a-b+.003)
		if excess>0:
			var parent=hero.rig.get_bone_parent(upper)
			var parent_basis=hero.rig.get_bone_global_pose(parent).basis if parent>=0 else Basis.IDENTITY
			var pose=hero.rig.get_bone_pose(upper)
			var rest=hero.rig.get_bone_rest(upper).origin
			pose.origin=rest+(pose.origin-rest+parent_basis.inverse()*(target-shoulder).normalized()*excess).limit_length(.24)
			hero.rig.set_bone_pose(upper,pose);hero.rig.force_update_all_bone_transforms()
			shoulder=hero.rig.get_bone_global_pose(upper).origin
			elbow=hero.rig.get_bone_global_pose(lower).origin
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
