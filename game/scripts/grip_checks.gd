extends RefCounted
func run(test:RefCounted) -> void:
	var g=test.game;var actor=g.player;var driver=g.camera_driver;var h=driver.visuals
	actor.set_physics_process(false);actor.set_sword_drawn(true);actor.state="free";actor.play_clip("drag_idle_loop",0);actor._pose_sword("drag",0);driver.update_first_person(0)
	var meshes=h.rig.get_children().filter(func(n):return n is MeshInstance3D)
	test.check(not meshes.is_empty() and meshes.all(func(m):return m.mesh.get_blend_shape_count()==2 and m.mesh.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_RELATIVE),"Visible hands have independent additive grip shapes without multiplying their skin positions")
	test.check(meshes.all(func(m):return m.get_blend_shape_value(0)>.99 and m.get_blend_shape_value(1)>.99),"Both hands close around the actual ready hilt")
	var fitting=0.0;var alignment=1.0
	for side in ["R","L"]:
		var pose=h.rig.get_bone_global_pose(h.rig.find_bone("view_hand."+side));var center=h.palms[side]+Vector3(.009 if side=="R" else -.009,-.018,.012)
		fitting=maxf(fitting,(h.rig.global_transform*(pose*(center-Vector3(0,-.26,0)))).distance_to(h.hand_targets[side]))
		alignment=minf(alignment,(h.rig.global_basis*pose.basis.z).normalized().dot(-actor.equipment.global_basis.y.normalized()))
	test.check(fitting<.003 and alignment>.65,"Actual skinned wrist centers meet the hilt with both thumb axes toward the guard, never an inverted right hand")
	var ready_wrist=h.rig.get_bone_global_pose(h.rig.find_bone("view_hand.R")).basis.y.angle_to(h.rig.get_bone_global_pose(h.bone("forearm","R")).basis.y)
	print("READY WRIST DEGREES ",rad_to_deg(ready_wrist))
	test.check(h.grip_motion.sample("drag",0).direction.z>.15 and rad_to_deg(ready_wrist)<17,"Ready sword leans back toward the player rather than away from the right wrist")
	var wrist_roll=1.0
	for side in ["R","L"]:
		var hand=h.rig.get_bone_global_pose(h.rig.find_bone("view_hand."+side)).basis
		var arm=h.rig.get_bone_global_pose(h.bone("forearm",side)).basis
		var projected=hand.z-arm.y*hand.z.dot(arm.y)
		wrist_roll=minf(wrist_roll,arm.z.normalized().dot(projected.normalized()))
	test.check(wrist_roll>.999,"Forearms carry grip pronation so neither wrist contains a concentrated axial twist")
	var separation=true;var curled=0;var finite=true
	for m in meshes:
		for surface in range(m.mesh.get_surface_count()):
			var base=m.mesh.get_meta("source_mesh").surface_get_arrays(surface);var source_skin:Skin=m.mesh.get_meta("source_skin");var shapes=m.mesh.get_meta("closed_shapes").map(func(shape):return shape.surface_get_arrays(surface))
			for i in range(base[Mesh.ARRAY_VERTEX].size()):
				for j in range(4):
					var bind=base[Mesh.ARRAY_BONES][i*4+j];var bone=source_skin.get_bind_bone(bind);var name=String(h.rig.get_bone_name(bone)) if bone>=0 else String(source_skin.get_bind_name(bind))
					if not name.begins_with("forearm") or base[Mesh.ARRAY_WEIGHTS][i*4+j]<.85:continue
					var original=source_skin.get_bind_pose(bind)*base[Mesh.ARRAY_VERTEX][i];var closed=source_skin.get_bind_pose(bind)*shapes[0 if name.ends_with("R") else 1][Mesh.ARRAY_VERTEX][i]
					finite=finite and closed.is_finite()
					if original.y<-.345:
						separation=separation and absf(closed.z-original.z)<.0001
						if closed.y>original.y+.01:curled+=1
					break
	test.check(finite and separation and curled>100,"Fingers curl back around the handle while keeping their separation; index fingertips are not pulled into the thumb")
	for fixture in [["water","attack_water",.45,0.0],["parry","parry_guard",.4,0.0],["lance_charge","attack_lance",.4,1.0]]:
		actor.state=fixture[0];actor.state_duration=3;actor.state_time=3*fixture[2];actor.play_clip(fixture[1],0)
		actor._pose_sword("water" if fixture[0]=="water" else "parry" if fixture[0]=="parry" else "lance",fixture[2]);driver.update_first_person(0)
		test.check(meshes.all(func(m):return m.get_blend_shape_value(0)>.99 and absf(m.get_blend_shape_value(1)-fixture[3])<.01),fixture[0]+": gripping hand stays closed while the supporting or bracing palm uses its own pose")
	var max_bend=0.0;var max_step=0.0;var max_gap=0.0;var max_upper_step=0.0;var opener_left_step=0.0;var elbow_above=-100.0
	for stage in range(1,4):
		var previous={}
		for sample in range(121):
			var phase=sample/120.0;var clip="attack_light"+(str(stage) if stage>1 else "")
			actor.state="light";actor.combo_stage=stage;actor.state_duration=2;actor.state_time=2*phase;actor.play_clip(clip,0)
			actor.animator.seek(actor.animator.get_animation(actor.clips[clip]).length*phase,true)
			actor._pose_sword("light"+(str(stage) if stage>1 else ""),phase);driver.update_first_person(0)
			for side in ["R","L"]:
				var hand=h.rig.get_bone_global_pose(h.rig.find_bone("view_hand."+side))
				var arm=h.rig.get_bone_global_pose(h.bone("forearm",side))
				if stage==1 and side=="L" and phase>=.12 and phase<=.74:
					var elbow=h.view_frame.affine_inverse()*(h.rig.global_transform*arm.origin)
					var wrist=h.view_frame.affine_inverse()*(h.rig.global_transform*hand.origin)
					elbow_above=maxf(elbow_above,elbow.y-wrist.y)
				var bend=rad_to_deg(hand.basis.y.angle_to(arm.basis.y))
				max_bend=maxf(max_bend,bend)
				var center=h.palms[side]+Vector3(.009 if side=="R" else -.009,-.018,.012)
				max_gap=maxf(max_gap,(h.rig.global_transform*(hand*(center-Vector3(0,-.26,0)))).distance_to(h.hand_targets[side]))
				var rotation=hand.basis.get_rotation_quaternion()
				if previous.has(side):
					var step=rad_to_deg(previous[side].angle_to(rotation))
					max_step=maxf(max_step,step)
				previous[side]=rotation
				var upper_rotation=h.rig.get_bone_global_pose(h.bone("upper_arm",side)).basis.get_rotation_quaternion()
				var upper_key=side+"upper"
				if previous.has(upper_key):
					var step=rad_to_deg(previous[upper_key].angle_to(upper_rotation))
					if stage==1 and side=="L":opener_left_step=maxf(opener_left_step,step)
					max_upper_step=maxf(max_upper_step,step)
				previous[upper_key]=upper_rotation
	print("SWING LIMBS bend=",max_bend," step=",max_step," gap=",max_gap)
	test.check(max_bend<38,"Three swing paths keep wrist deviation within a human bend envelope")
	test.check(max_step<25,"Swing wrists rotate continuously without sudden inversion between adjacent samples")
	test.check(max_gap<.018,"Both skinned grip centers stay on the moving hilt throughout the combo")
	print("UPPER ARM MAX STEP ",max_upper_step," LEFT OPENER ",opener_left_step)
	test.check(opener_left_step<25,"Upper arms stay continuous as forearm roll crosses the signed-angle seam; no left-arm inversion during the opener")
	test.check(max_upper_step<25,"Both guided upper arms remain continuous across all three cuts")
	print("LEFT ELBOW ABOVE WRIST ",elbow_above)
	test.check(elbow_above<-.015,"Opening cut keeps the support elbow below the wrist rather than rolling over above the hand")
	var join_error=0.0
	for stage in [1,2]:
		var poses={}
		for entry in [[stage,.74],[stage+1,0.0]]:
			var clip="attack_light"+(str(entry[0]) if entry[0]>1 else "")
			actor.state="light";actor.combo_stage=entry[0];actor.state_duration=2;actor.state_time=2*entry[1];actor.play_clip(clip,0)
			actor.animator.seek(actor.animator.get_animation(actor.clips[clip]).length*entry[1],true)
			actor._pose_sword("light"+(str(entry[0]) if entry[0]>1 else ""),entry[1]);driver.update_first_person(0)
			for side in ["R","L"]:
				var pose=h.rig.get_bone_global_pose(h.rig.find_bone("view_hand."+side)).basis.get_rotation_quaternion()
				if poses.has(side):join_error=maxf(join_error,rad_to_deg(poses[side].angle_to(pose)))
				poses[side]=pose
	print("COMBO WRIST JOIN ",join_error)
	test.check(join_error<8,"Linked swings retain hand rotation at the actual combo entry without a ready-pose reset")
	actor.state="draw";actor.state_duration=1;actor.play_clip("draw_sword",0);actor.animator.seek(actor.animator.get_animation(actor.clips.draw_sword).length*.25,true);driver.update_first_person(0)
	test.check(meshes.all(func(m):return m.get_blend_shape_value(0)>0 and m.get_blend_shape_value(0)<1),"Drawing blends finger closure instead of swapping instantly between open and closed meshes")
	var rise=[];var max_rise_step=0.0;var previous={}
	for sample in range(81):
		var phase=sample/80.0
		actor.state="draw";actor.animator.seek(actor.animator.get_animation(actor.clips.draw_sword).length*phase,true)
		actor._pose_sword("draw",phase);driver.update_first_person(0)
		for side in ["R","L"]:
			if previous.has(side):max_rise_step=maxf(max_rise_step,(h.view_frame.affine_inverse()*h.hand_targets[side]).distance_to(previous[side]))
			previous[side]=h.view_frame.affine_inverse()*h.hand_targets[side]
		rise.append(h.view_frame.affine_inverse()*h.hand_targets.R)
	print("HAND RISE ",rise[0]," ",rise[-1]," step ",max_rise_step)
	test.check(rise[0].y<-.55 and rise[-1].y>-.12 and max_rise_step<.065,"Drawing raises the hands continuously from below view into ready without spawning at chest height")
	var raised={"R":h.view_frame.affine_inverse()*h.hand_targets.R,"L":h.view_frame.affine_inverse()*h.hand_targets.L}
	actor.state="free";actor.set_sword_drawn(true);actor._pose_sword("drag",0);driver.update_first_person(0)
	test.check((h.view_frame.affine_inverse()*h.hand_targets.R).distance_to(raised.R)<.02 and (h.view_frame.affine_inverse()*h.hand_targets.L).distance_to(raised.L)<.02,"Raised draw endpoint meets the live ready grips without a hand-position jump")
	var shoulder=h.rig.get_bone_global_pose(h.bone("upper_arm","R")).origin
	h.fit_wrist("R",h.rig.global_transform*(shoulder+Vector3.DOWN*.4),h.rig.global_basis*Vector3.DOWN,1,1)
	test.check(h.rig.get_bone_global_pose(h.rig.find_bone("view_hand.R")).basis.is_finite(),"Vertical sword alignment keeps a finite wrist orientation instead of collapsing its twist axis")
	actor.state="free";actor.set_sword_drawn(false);actor.set_physics_process(true)
