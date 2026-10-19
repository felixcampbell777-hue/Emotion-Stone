extends RefCounted
## Body-only presentation wrists reuse the accepted view-hand solver and skin curl.
const ViewFrame=preload("res://scripts/network/wr_view_frame.gd")
var solver=preload("res://scripts/first_person_visuals.gd").new()
var query=ViewFrame.collision_query()
var prepared={}
var hand_targets={}
var grasps={"R":0.0,"L":0.0}

func visible_presentation(hero:Node3D) -> bool:
	return bool(hero.actor.get_meta("body_wrist_inspection",false)) or (DisplayServer.get_name()!="headless" and hero.actor.is_visible_in_tree())

func prepare_transition(hero:Node3D) -> void:
	var actor=hero.actor
	if visible_presentation(hero) and actor.first_person_driver!=null and actor.sword_equipped and (actor.sword_drawn or actor.state in ["draw","sheathe"]) and (actor.weapon_runtime==null or not actor.weapon_runtime.enabled()):prepare(hero)
	# Authority snapshots contain only original rig bones. Added visual wrists
	# start at rest when restoring an in-progress carry transition.
	if not hero.carry_transition.is_empty():
		while hero.carry_transition.size()<hero.rig.get_bone_count():
			hero.carry_transition.append(hero.rig.get_bone_rest(hero.carry_transition.size()))

func prepare(hero:Node3D) -> void:
	var rig:Skeleton3D=hero.rig
	solver.rig=rig;solver.personal_skin=true
	for side in ["L","R"]:
		if rig.find_bone("view_hand."+side)<0:
			var index=rig.get_bone_count();rig.add_bone("view_hand."+side)
			rig.set_bone_parent(index,hero.gait.bone(hero,"forearm",side))
			var rest=Transform3D(Basis.IDENTITY,Vector3(0,-.26,0));rig.set_bone_rest(index,rest)
			hero.rests.append(rest);hero.global_rests.append(rig.get_bone_global_rest(index))
		solver.palms[side]=Vector3(-.017 if side=="R" else .017,-.30,.012)
	solver.global_rests=hero.global_rests
	for item in hero.dragon_grips:
		var part:MeshInstance3D=item[0];var identity=part.get_instance_id()
		var source:Mesh=item[1]
		var cached:Dictionary=prepared.get(identity,{})
		if not cached.is_empty() and source==cached.mesh:continue
		var skin:Skin=part.get_meta("body_grip_original_skin",part.skin)
		var fitted_skin=solver.wrist_skin(skin)
		var mesh=solver.grip_blends(source,skin,rig,fitted_skin)
		prepared[identity]={"mesh":mesh,"skin":fitted_skin,"source":source}
		part.set_meta("body_grip_original_mesh",source);part.set_meta("body_grip_original_skin",skin)
		part.set_meta("body_grip_mesh",mesh)
		part.skin=fitted_skin;item[1]=mesh

func reset(hero:Node3D) -> void:
	hand_targets.clear();grasps={"R":0.0,"L":0.0}
	for side in ["L","R"]:
		var wrist=hero.rig.find_bone("view_hand."+side)
		if wrist>=0:hero.rig.set_bone_pose(wrist,hero.rig.get_bone_rest(wrist))
	for item in hero.dragon_grips:
		var part:MeshInstance3D=item[0]
		if not prepared.has(part.get_instance_id()):continue
		var cached:Dictionary=prepared[part.get_instance_id()]
		if item[1]!=cached.mesh:continue
		part.skin=cached.skin
		if part.mesh!=cached.mesh:part.mesh=cached.mesh
		part.set_blend_shape_value(0,0);part.set_blend_shape_value(1,0)

func apply(hero:Node3D) -> bool:
	var actor=hero.actor
	if actor.first_person_driver==null:return false
	if not visible_presentation(hero):return false
	var active=actor.sword_equipped and (actor.sword_drawn or actor.state in ["draw","sheathe"]) and (actor.weapon_runtime==null or not actor.weapon_runtime.enabled()) and actor.state not in ["roll","stand","dragon_channel","dragon_recover"]
	if not active:
		reset(hero);return false
	prepare(hero);reset(hero)
	var driver=actor.first_person_driver
	# Direct pure sampling avoids recursively calling BetaHero.synchronize(). Arm
	# changes cannot affect the head chain, canonical steel, resources or clocks.
	var frame=ViewFrame.from_rig(actor,hero.rig,driver.tuning,driver.yaw,driver.first_pitch,float(actor.get_meta("canonical_view_blend",driver.locomotion_camera_blend)),actor.get_world_3d().direct_space_state,query)
	solver.view_frame=frame;solver.grip_sample=actor.get_meta("view_sword_sample",{"key":"drag","phase":0.0});solver.weapon_grip=false
	var drawn=actor.state in ["draw","sheathe"]
	var phase=actor.state_time/maxf(.001,actor.state_duration) if drawn else 1.0
	if actor.state=="sheathe":phase=1-phase
	var right_grasp=smoothstep(.10,.40,phase) if drawn else 1.0
	var left_grasp=smoothstep(.35,.75,phase) if drawn else 1.0
	if actor.state=="water":
		var action_phase=actor.state_time/maxf(.001,actor.state_duration)
		left_grasp=maxf(1-smoothstep(0,.14,action_phase),smoothstep(.80,1,action_phase))
	var beta=actor.equipment.get_meta("beta_sword",false)
	var right=actor.equipment.global_transform*Vector3(0,actor.BetaSwordMotion.GRIP if beta else .16,0)
	var left=(frame*Vector3(-.24,-.16,-.48)).lerp(actor.equipment.global_transform*Vector3(0,.20 if beta else .08,0),left_grasp)
	var brace=0.0
	var support_motion=0.0
	if actor.state=="parry":
		var action_phase=actor.parry_pose_phase(actor.state_time/maxf(.001,actor.state_duration))
		brace=smoothstep(.10,.30,action_phase)*(1-smoothstep(.65,.90,action_phase))
		support_motion=smoothstep(0,.12,action_phase)*(1-smoothstep(.82,1,action_phase))
		left=left.lerp(actor.equipment.global_transform*Vector3(0,-.34,.045),brace);left_grasp*=1-brace
	var authored_left={}
	for bone in [solver.bone("upper_arm","L"),solver.bone("forearm","L"),hero.rig.find_bone("view_hand.L")]:authored_left[bone]=hero.rig.get_bone_pose(bone)
	var axis=-actor.equipment.global_basis.y.normalized()
	solver.fit("R",right,axis,right_grasp)
	solver.fit("L",left,axis.slerp(actor.equipment.global_basis.x.normalized(),brace),left_grasp)
	if support_motion>0:
		# An open bracing hand follows its authored arm rather than forcing an
		# unreachable gripping wrist through a half turn beside the guard.
		for bone in authored_left:hero.rig.set_bone_pose(bone,hero.rig.get_bone_pose(bone).interpolate_with(authored_left[bone],support_motion))
		hero.rig.force_update_all_bone_transforms();left_grasp=minf(left_grasp,1-support_motion)
	hand_targets={"R":right,"L":left};grasps={"R":right_grasp,"L":left_grasp}
	for item in hero.dragon_grips:
		var part:MeshInstance3D=item[0]
		if not prepared.has(part.get_instance_id()) or item[1]!=prepared[part.get_instance_id()].mesh:continue
		part.set_blend_shape_value(0,right_grasp);part.set_blend_shape_value(1,left_grasp)
	return true
