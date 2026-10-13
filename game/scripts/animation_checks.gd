extends RefCounted
func run(test:RefCounted) -> void:
	var actor=test.game.player
	actor.set_sword_drawn(true)
	actor.set_physics_process(false)
	var spine=actor.skeleton.find_bone("spine")
	actor.set_sword_drawn(false)
	var mounted=actor.equipment.global_transform
	var mount_pose=actor.back_mount_pose()
	var mounted_grip=mount_pose*Vector3(0,.256,0)
	var mounted_tip=mount_pose*Vector3(0,-1.872,0)
	test.check(absf((mounted_grip.x+mounted_tip.x)*.5)<.04 and mounted_grip.x<-.5 and mounted_tip.x>.5,"Sheathed steel is centered across the back with the hilt above the right shoulder")
	test.check(mounted_grip.z>-.28 and mounted_tip.z>-.65,"Back carry sits closer to the shoulders with space for walking skirt sway")
	actor.toggle_sword()
	test.check(actor.equipment.global_transform.origin.distance_to(mounted.origin)<.001,"Beginning a draw keeps the sword on its actual back mount without teleporting")
	actor.play_clip("draw_sword",0)
	actor.animator.seek(0,true)
	actor._pose_sword("draw",0)
	var stable=true
	var above_floor=true
	var previous_tip=actor.sword_tip()
	var previous_right=actor.equipment.basis.x.normalized()
	# Keep the original .85/240-second sample interval as draw timing changes.
	var draw_samples=ceili(240*maxf(1,float(actor.combat.draw_seconds)/.85))
	for index in range(1,draw_samples+1):
		var phase=index/float(draw_samples)
		actor.animator.seek(phase*actor.animator.get_animation(actor.clips.draw_sword).length,true)
		actor._pose_sword("draw",phase)
		stable=stable and actor.sword_tip().distance_to(previous_tip)<.10 and actor.equipment.basis.x.normalized().dot(previous_right)>.90
		above_floor=above_floor and actor.sword_tip().y-actor.global_position.y>=.005
		previous_tip=actor.sword_tip()
		previous_right=actor.equipment.basis.x.normalized()
	test.check(stable,"Draw extraction and blade orientation remain continuous at the established time interval across draw subframes")
	test.check(above_floor,"Crescent draw keeps the blade above the ground throughout its full orbit")
	actor.animator.seek(.485*actor.animator.get_animation(actor.clips.draw_sword).length,true)
	actor._pose_sword("draw",.485)
	test.check(actor.sword_tip().y-actor.global_position.y>3.2,"Draw raises the full blade above the head before lowering it into drag")
	var orbit=0.0
	var previous_angle=0.0
	for index in range(241):
		var phase=lerpf(.24,.82,index/240.0)
		var point=actor.motion_pose("draw",phase)
		var direction:Vector3=point.tip-point.grip
		var angle=atan2(direction.z,direction.y)
		if index>0: orbit+=wrapf(angle-previous_angle,-PI,PI)
		previous_angle=angle
	test.check(orbit>TAU-.5 and orbit<TAU+.9,"Shoulder extraction continues through a near-full vertical orbit instead of reversing from the overhead lift")
	actor.animator.seek(actor.animator.get_animation(actor.clips.draw_sword).length,true)
	actor._pose_sword("draw",1)
	var final_draw=actor.equipment.transform
	actor.state="free"
	actor._pose_sword("drag",0)
	test.check(final_draw.origin.distance_to(actor.equipment.position)<.001 and final_draw.basis.is_equal_approx(actor.equipment.basis),"Drawing finishes exactly on the dragging sword pose")
	actor.state="draw"
	actor._pose_sword("draw",.25)
	test.check(actor.sword_holders[0].visible and actor.sword_holders[0].position.y<actor.holder_rest[0].origin.y-.03 and actor.holder_material.albedo_color.a==1 and actor.holder_material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and actor.harness_material.albedo_color.a==1,"Sword holders droop during extraction with fully opaque leather and base straps")
	actor._pose_sword("draw",.60)
	test.check(not actor.sword_holders[0].visible and actor.back_harness.visible and actor.sword_holders[0].position.distance_to(actor.holder_anchors[0]+Vector3(0,0,.008))<.002,"Sword holders retract into their leather backing while the base harness remains")
	var impact=actor.motion_pose("draw",.82)
	var rebound=actor.motion_pose("draw",.90)
	var settle=actor.motion_pose("draw",1)
	test.check(impact.tip.y<.05 and rebound.tip.y>impact.tip.y+.28 and settle.tip.y<.05,"Draw lands the blade behind, visibly rebounds, then settles into dragging")
	actor.set_sword_drawn(false)
	test.check(actor.sword_holders[0].visible and actor.holder_material.albedo_color.a==1 and actor.sword_holders[0].transform.is_equal_approx(actor.holder_rest[0]),"Sheathing and equipment reset restore the current holders without stale falling transforms")
	for stowing in [false,true]:
		actor.state="sheathe" if stowing else "draw"
		var timed_clip="sheathe_sword" if stowing else "draw_sword"
		actor.play_clip(timed_clip,0)
		var monotone=true
		var continuous=true
		var last=0.0
		var last_tip=Vector3.ZERO
		for index in range(801):
			var phase=actor.sword_action_phase(index/800.0,stowing)
			monotone=monotone and phase>=last and phase<=1
			actor.animator.seek(phase*actor.animator.get_animation(actor.clips[timed_clip]).length,true)
			actor._pose_sword("drag",phase)
			if index>0: continuous=continuous and actor.sword_tip().distance_to(last_tip)<.10
			last_tip=actor.sword_tip()
			last=phase
		test.check(monotone and continuous and is_equal_approx(last,1),"Gravity-timed "+timed_clip+" preserves continuous body/blade movement and completes the full path")
		var peak_time=.73 if stowing else .65
		var catch_time=.95 if stowing else .88
		var raised=actor.sword_action_phase(peak_time,stowing)
		var lowered=actor.sword_action_phase(catch_time,stowing)
		test.check((lowered-raised)/(catch_time-peak_time)>1.7*raised/peak_time,"Gravity-assisted descent is distinctly faster than lifting in "+timed_clip)
	actor.set_sword_drawn(true)
	for clip in actor.clips:
		actor.play_clip(clip,0)
		var poses=[]
		for phase in [.12,.30,.52,.72,.92]:
			actor.animator.seek(phase*actor.animator.get_animation(actor.clips[clip]).length,true)
			poses.append(actor.skeleton.get_bone_pose_rotation(spine))
		var excursion=0.0
		for pose in poses: excursion=maxf(excursion,poses[0].angle_to(pose))
		test.check(excursion>.01,"Torso motion remains authored in "+clip)
	var middle=actor.dodge_transform("roll",.52)
	test.check(middle.basis.y.dot(Vector3.UP)<-.95 and middle.basis.x.dot(Vector3.RIGHT)>.99,"Dodge completes a forward head-over-heels somersault around the lateral axis")
	test.check(actor.dodge_transform("roll",1).is_equal_approx(actor.dodge_transform("stand",0)),"Somersault landing and stand-up share the same root transform")
	test.check(actor.dodge_transform("stand",1).is_equal_approx(Transform3D.IDENTITY),"Stand-up restores the upright root without a residual offset")
	actor.play_clip("attack_light",0)
	actor.animator.seek(.52*actor.animator.get_animation(actor.clips.attack_light).length,true)
	actor._pose_sword("light",.52)
	actor.skeleton.force_update_all_bone_transforms()
	var forearm=actor.skeleton.find_bone("forearm_L")
	if forearm<0: forearm=actor.skeleton.find_bone("forearm.L")
	var wrist_offset=actor.skeleton.get_bone_global_rest(forearm).affine_inverse()*Vector3(.385,.88,.015)
	var hand=actor.skeleton.global_transform*(actor.skeleton.get_bone_global_pose(forearm)*wrist_offset)
	var grip=actor.equipment.global_transform*Vector3(0,.16,0)
	test.check(hand.distance_to(grip)>.30,"Opening cut leaves the free hand off the grip for a one-handed swing")
	actor.play_clip("parry_guard",0)
	actor.animator.seek(.45*actor.animator.get_animation(actor.clips.parry_guard).length,true)
	actor._pose_sword("parry",.45)
	actor.skeleton.force_update_all_bone_transforms()
	var pelvis=actor.skeleton.find_bone("pelvis")
	test.check(actor.skeleton.get_bone_pose_rotation(pelvis).angle_to(Quaternion.IDENTITY)>.50 and absf(actor.skeleton.get_bone_pose_rotation(spine).get_euler().y)>.40,"Parry turns both hips and chest into the blade guard")
	forearm=actor.skeleton.find_bone("forearm_R")
	if forearm<0: forearm=actor.skeleton.find_bone("forearm.R")
	wrist_offset=actor.skeleton.get_bone_global_rest(forearm).affine_inverse()*Vector3(-.385,.88,.015)
	hand=actor.skeleton.global_transform*(actor.skeleton.get_bone_global_pose(forearm)*wrist_offset)
	grip=actor.equipment.global_transform*Vector3(0,.16,0)
	test.check(hand.distance_to(grip)<.13,"Turning into the parry keeps the right hand attached to the hilt")
	var chest_offset=actor.skeleton.get_bone_global_rest(spine).affine_inverse()*Vector3(0,1.20,.06)
	var chest=actor.skeleton.global_transform*(actor.skeleton.get_bone_global_pose(spine)*chest_offset)
	var blade_front=grip+(actor.sword_tip()-grip).normalized()*.30
	test.check(blade_front.z>chest.z+.08 and absf(blade_front.x-chest.x)<.40,"Parry places blade steel in front of the twisted torso, rather than only the pommel")
	for clip in ["dodge_roll","stand_up"]:
		actor.play_clip(clip,0)
		var full_width=true
		var continuous=true
		var previous=Vector3.ZERO
		var scale=float(actor.combat.sword_scale)
		for index in range(241):
			var phase=float(index)/240
			actor.animator.seek(phase*actor.animator.get_animation(actor.clips[clip]).length,true)
			actor._pose_sword("roll" if clip=="dodge_roll" else "stand",phase)
			var basis=actor.equipment.basis
			full_width=full_width and actor.equipment.is_visible_in_tree() and basis.determinant()>pow(scale,3)*.99 and absf(basis.x.length()-scale)<.001 and absf(basis.z.length()-scale)<.001
			var right=basis.x.normalized()
			if index>0: continuous=continuous and previous.dot(right)>.95
			previous=right
		test.check(full_width,"Sword stays visible with full width and thickness at every sampled "+clip+" phase")
		test.check(continuous,"Sword orientation follows "+clip+" continuously without a basis flip")
	actor.play_clip("attack_light",0)
	actor.animator.seek(.74*actor.animator.get_animation(actor.clips.attack_light).length,true)
	actor._pose_sword("light",.74)
	actor.skeleton.force_update_all_bone_transforms()
	var knee=actor.skeleton.find_bone("shin_R")
	if knee<0: knee=actor.skeleton.find_bone("shin.R")
	var knee_height=(actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(knee).origin).y-actor.global_position.y
	test.check(knee_height>=-.02 and knee_height<.18,"The opening cut catches its momentum with the rear knee close to the ground")
	var catch_poses=[]
	for bone in [pelvis,spine]: catch_poses.append(actor.skeleton.get_bone_pose(bone))
	actor.play_clip("attack_light2",0)
	actor.animator.seek(0,true)
	actor.skeleton.force_update_all_bone_transforms()
	var connected=true
	for index in range(2):
		var bone=[pelvis,spine][index]
		var pose=actor.skeleton.get_bone_pose(bone)
		connected=connected and pose.origin.distance_to(catch_poses[index].origin)<.005 and pose.basis.get_rotation_quaternion().angle_to(catch_poses[index].basis.get_rotation_quaternion())<.01
	test.check(connected,"Return cut begins from the opening swing's kneeling hip and torso pose")
	actor.animator.seek(.30*actor.animator.get_animation(actor.clips.attack_light2).length,true)
	test.check((actor.skeleton.get_bone_pose_position(pelvis).y-actor.skeleton.get_bone_rest(pelvis).origin.y)>-.24 and (actor.skeleton.get_bone_pose_position(pelvis).y-actor.skeleton.get_bone_rest(pelvis).origin.y)<-.10,"Return cut rises into a loaded crouch rather than standing upright")
	actor.animator.seek(.74*actor.animator.get_animation(actor.clips.attack_light2).length,true)
	var buried=[]
	for bone in [pelvis,spine]: buried.append(actor.skeleton.get_bone_pose(bone))
	actor.play_clip("attack_light3",0)
	actor.animator.seek(0,true)
	var matched=true
	for index in range(2):
		var pose=actor.skeleton.get_bone_pose([pelvis,spine][index])
		matched=matched and pose.origin.distance_to(buried[index].origin)<.005 and pose.basis.get_rotation_quaternion().angle_to(buried[index].basis.get_rotation_quaternion())<.01
	test.check(matched,"Spin inherits the buried backhand's hip and chest pose")
	var shoulder_entry=actor.motion_pose("light3",.27)
	test.check(actor.spin_rotation(.27)>PI and actor.spin_rotation(.27)<TAU-.5 and shoulder_entry.grip.y>1.25 and shoulder_entry.tip.y>2.1,"Spin lifts toward the shoulder while still facing backward")
	var shoulder_roll=actor.motion_pose("light3",.34)
	test.check(shoulder_roll.grip.x<-.4 and shoulder_roll.grip.z<0 and shoulder_roll.tip.y>3,"Spin carries the blade over the right shoulder before the overhead hammer")
	var skirt=actor.skeleton.find_bone("skirt_sway")
	actor.play_clip("attack_thrust",0)
	for phase in [.18,.24,.38,.52,.64]:
		actor.animator.seek(phase*actor.animator.get_animation(actor.clips.attack_thrust).length,true)
		actor._pose_sword("thrust",phase)
		actor.skeleton.force_update_all_bone_transforms()
		for side in ["R","L"]:
			var arm=actor.skeleton.find_bone("forearm_"+side)
			if arm<0: arm=actor.skeleton.find_bone("forearm."+side)
			var wrist=actor.skeleton.get_bone_global_rest(arm).affine_inverse()*Vector3(-.385 if side=="R" else .385,.88,.015)
			var actual=actor.skeleton.global_transform*(actor.skeleton.get_bone_global_pose(arm)*wrist)
			var target=actor.equipment.global_transform*Vector3(0,.16 if side=="R" else .26,0)
			test.check(actual.distance_to(target)<.09,"Thrust keeps "+side+" hand on the grip at phase %.2f" % phase)
		if phase==.18:
			test.check(actor.skeleton.get_bone_pose_position(pelvis).y-actor.skeleton.get_bone_rest(pelvis).origin.y<-.25,"Thrust charge sinks into its loaded low stance")
		if phase==.64:
			test.check(actor.motion_pose("thrust",phase).grip.z>.95,"Thrust finishes with a long forward extension")
	for clip in ["walk_loop","drag_walk_loop"]:
		actor.play_clip(clip,0)
		actor.animator.seek(.25*actor.animator.get_animation(actor.clips[clip]).length,true)
		var first=actor.skeleton.get_bone_pose_rotation(skirt)
		actor.animator.seek(.75*actor.animator.get_animation(actor.clips[clip]).length,true)
		test.check(first.angle_to(actor.skeleton.get_bone_pose_rotation(skirt))>.35,"Increased cloth sway covers the leg stride in "+clip)
	actor.set_sword_drawn(true)
	actor.set_physics_process(true)
