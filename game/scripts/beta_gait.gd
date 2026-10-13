extends RefCounted
## Trusted Quaternius walk/jog/sprint samples fitted to the personal rig.
var library=JSON.parse_string(FileAccess.get_file_as_string("res://content/beta_locomotion_samples.json"))
var tuning=JSON.parse_string(FileAccess.get_file_as_string("res://content/beta.json")).locomotion
var blend=0.0
var phase=0.0
var body_drop=0.0
var run_blend=0.0

func advance_distance(actor:Node3D,distance:float,delta:float) -> void:
	if actor.state!="free": return
	run_blend=move_toward(run_blend,1.0 if actor.sprinting else 0.0,delta/.20)
	var cycle=lerpf(float(tuning.walk_cycle_distance),float(tuning.burden_run_cycle_distance if actor.sword_drawn else tuning.run_cycle_distance),run_blend)
	phase=fposmod(phase+distance/cycle,1.0)

func sample(clip:String,key:String,p:float):
	var frames=library.clips[clip].samples
	var cursor=fposmod(p,1.0)*120;var index=int(cursor);var weight=cursor-index
	var a=frames[index][key];var b=frames[index+1][key]
	if a.size()==4:return Quaternion(a[0],a[1],a[2],a[3]).slerp(Quaternion(b[0],b[1],b[2],b[3]),weight)
	return Vector3(a[0],a[1],a[2]).lerp(Vector3(b[0],b[1],b[2]),weight)

func motion(actor:Node3D,key:String):
	var walk=sample("Walk_Loop",key,phase)
	var run=sample("Jog_Fwd_Loop" if actor.sword_drawn else "Sprint_Loop",key,phase)
	return walk.slerp(run,run_blend) if walk is Quaternion else walk.lerp(run,run_blend)

func apply(hero:Node3D,delta:float) -> void:
	var actor=hero.actor
	if actor.state!="free" or actor.current_clip not in ["idle_loop","drag_idle_loop","walk_loop","drag_walk_loop"]:
		blend=0.0; body_drop=0.0; return
	var walking=actor.current_clip in ["walk_loop","drag_walk_loop"]
	if walking and not actor.is_physics_processing():
		phase=fposmod(actor.animator.current_animation_position/actor.animator.get_animation(actor.clips[actor.current_clip]).length,1.0)
		run_blend=1.0 if actor.sprinting else 0.0
	blend=move_toward(blend,1.0 if walking else 0.0,delta/0.16)
	if not actor.is_physics_processing(): blend=1.0 if walking else 0.0
	if blend<=0: body_drop=0.0;return
	var hip_motion:Vector3=motion(actor,"hip")
	body_drop=(.032-hip_motion.y*lerpf(.35,.45,run_blend))*blend
	var pelvis=hero.rig.find_bone("pelvis")
	var parent=hero.rig.get_bone_parent(pelvis)
	var parent_basis=hero.rig.get_bone_global_pose(parent).basis if parent>=0 else Basis.IDENTITY
	# Replace the inherited exaggerated bob rather than adding a second cycle.
	hero.rig.set_bone_pose_position(pelvis,hero.rests[pelvis].origin+parent_basis.inverse()*Vector3(hip_motion.x*.35*blend,-body_drop,0))
	hero.rig.force_update_all_bone_transforms()
	for pair in [["pelvis","pelvis_rotation"],["spine","spine_03_rotation"],["head","Head_rotation"]]:
		var index=hero.rig.find_bone(pair[0])
		var rotation:Quaternion=motion(actor,pair[1])
		rotation=Quaternion.IDENTITY.slerp(rotation,lerpf(1.0,.58,run_blend))
		var desired=Basis(rotation)*hero.global_rests[index].basis
		# Preserve the sword's forward burden and horizontal free forearm.
		if actor.sword_drawn and pair[0]!="pelvis": continue
		set_global_basis(hero,index,hero.rig.get_bone_global_pose(index).basis.slerp(desired,blend))
	for side in ["L","R"]:
		var foot=bone(hero,"foot",side)
		var rest:Vector3=hero.global_rests[foot].origin
		var source:Vector3=motion(actor,"foot_"+side.to_lower())
		var stride=lerpf(float(tuning.walk_stride_scale),float(tuning.burden_run_stride_scale if actor.sword_drawn else tuning.run_stride_scale),run_blend)
		var lift=maxf(0,source.y)*lerpf(float(tuning.walk_lift_scale),float(tuning.burden_run_lift_scale if actor.sword_drawn else tuning.run_lift_scale),run_blend)
		var target=rest.lerp(Vector3(.105 if side=="L" else -.105,rest.y+lift,rest.z+source.z*stride),blend)
		plant_leg(hero,side,target)
		# Keep walking soles almost level; allow the runner's backward heel recovery.
		var source_rotation:Quaternion=motion(actor,"foot_rotation_"+side.to_lower())
		var toe=clampf(source_rotation.get_euler().x,-.08,lerpf(.12,.65,run_blend))*blend
		var desired=Basis(Vector3.RIGHT,toe)*hero.global_rests[foot].basis
		set_global_basis(hero,foot,desired)
		if not actor.sword_drawn:
			var upper=bone(hero,"upper_arm",side);var lower=bone(hero,"forearm",side)
			var arm:Vector3=motion(actor,"upperarm_"+side.to_lower())
			var direction=(hero.rig.get_bone_global_pose(lower).origin-hero.rig.get_bone_global_pose(upper).origin).normalized().lerp(arm,blend).normalized()
			aim(hero,upper,lower,direction)
			var forearm:Vector3=motion(actor,"lowerarm_"+side.to_lower())
			var palm=hero.hands.PALM; palm.x*=1 if side=="R" else -1
			var pose=hero.rig.get_bone_global_pose(lower)
			var current=(pose.basis*palm).normalized()
			set_global_basis(hero,lower,Basis(Quaternion(current,current.lerp(forearm,blend).normalized()))*pose.basis)
	hero.rig.force_update_all_bone_transforms()

func bone(hero:Node3D,key:String,side:String) -> int:
	var index=hero.rig.find_bone(key+"_"+side)
	return index if index>=0 else hero.rig.find_bone(key+"."+side)

func set_global_basis(hero:Node3D,index:int,basis:Basis) -> void:
	var parent=hero.rig.get_bone_parent(index)
	if parent>=0: basis=hero.rig.get_bone_global_pose(parent).basis.inverse()*basis
	hero.rig.set_bone_pose_rotation(index,basis.get_rotation_quaternion())
	hero.rig.force_update_all_bone_transforms()

func aim(hero:Node3D,index:int,child:int,direction:Vector3) -> void:
	var pose=hero.rig.get_bone_global_pose(index)
	var old=hero.rig.get_bone_global_pose(child).origin-pose.origin
	set_global_basis(hero,index,Basis(Quaternion(old.normalized(),direction.normalized()))*pose.basis)

func plant_leg(hero:Node3D,side:String,target:Vector3) -> void:
	var thigh=bone(hero,"thigh",side); var shin=bone(hero,"shin",side); var foot=bone(hero,"foot",side)
	var hip=hero.rig.get_bone_global_pose(thigh).origin
	var upper:float=hero.global_rests[thigh].origin.distance_to(hero.global_rests[shin].origin)
	var lower:float=hero.global_rests[shin].origin.distance_to(hero.global_rests[foot].origin)
	var direction=(target-hip).normalized()
	var distance=clampf(hip.distance_to(target),.01,upper+lower-.001)
	var along=(upper*upper-lower*lower+distance*distance)/(2*distance)
	var pole=Vector3.BACK-direction*Vector3.BACK.dot(direction)
	var knee=hip+direction*along+pole.normalized()*sqrt(maxf(0,upper*upper-along*along))
	aim(hero,thigh,shin,knee-hip)
	aim(hero,shin,foot,hip+direction*distance-knee)
