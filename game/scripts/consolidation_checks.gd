extends RefCounted
func run(test: RefCounted) -> void:
	var game=test.game
	game.load_map("coastal_path",Vector2(0,3))
	var actor=game.player
	actor.input_enabled=true
	actor.health=100
	actor.set_sword_drawn(true)
	actor.set_physics_process(false)
	actor.play_clip("drag_walk_loop",0)
	var pelvis=actor.skeleton.find_bone("pelvis")
	var spine=actor.skeleton.find_bone("spine")
	var thigh=actor.skeleton.find_bone("thigh_L")
	if thigh<0:
		thigh=actor.skeleton.find_bone("thigh.L")
	var axes=[]
	for phase in [.125,.625]:
		actor.animator.seek(phase*actor.animator.get_animation(actor.clips.drag_walk_loop).length,true)
		actor.skeleton.force_update_all_bone_transforms()
		var row=[]
		for bone in [pelvis,spine,thigh]:
			var axis=actor.skeleton.get_bone_global_pose(bone).basis.x
			row.append(Vector2(axis.x,axis.z).normalized())
		axes.append(row)
	test.check(abs(axes[0][0].angle_to(axes[1][0]))>.06,"Burden walk rotates the hips around the vertical axis")
	test.check(abs(axes[0][1].angle_to(axes[1][1]))>.06,"Burden walk rotates the torso rather than only tilting it")
	test.check(abs(axes[0][2].angle_to(axes[1][2]))>.06,"Legs pivot with the hips during the burden gait")
	actor.set_sword_drawn(true)
	actor.set_physics_process(true)
	actor.restore_stamina(100)
	Input.action_press("move_up")
	await test.frames(15)
	Input.action_release("move_up")
	var walk_pose=actor.skeleton.get_bone_pose_rotation(spine)
	test.check(actor.begin_water(),"Water cut starts from the burden walk")
	await test.frames(22)
	var cut_pose=actor.skeleton.get_bone_pose_rotation(spine)
	test.check(walk_pose.angle_to(cut_pose)>.15,"Water cut animates the torso during the actual running action")
	await test.frames(55)
	actor.restore_stamina(100)
	test.check(actor.begin_water_lance(),"Lance starts after the animated water cut")
	await test.frames(40)
	var early=actor.skeleton.get_bone_pose_rotation(spine)
	var fx=actor.lance_charge_fx
	test.check(not actor.sword_material_backup.is_empty(),"Sword lights blue while lance charges")
	test.check(actor.sword_energy_materials.size()==2 and actor.sword_energy_front<0,"Lance leaves blade steel while energy accumulates at the hilt")
	var phase=actor.state_time/actor.state_duration*actor.LANCE_HOLD_PHASE
	var expected=phase*actor.animator.get_animation(actor.clips.attack_lance).length
	test.check(abs(actor.animator.current_animation_position-expected)<.03,"Lance body and sword sample the same swing-and-charge timeline")
	await test.frames(95)
	test.check(early.angle_to(actor.skeleton.get_bone_pose_rotation(spine))>.02,"Lance continues changing body pose into the two-hand hold")
	await test.frames(28)
	test.check(actor.sword_energy_front>0 and actor.sword_energy_front<1,"Energy front moves partway down the blade before full charge")
	await test.frames(14)
	test.check(actor.sword_energy_front>1,"Blade becomes fully blue only after energy reaches the tip")
	await test.frames(18)
	test.check(actor.state=="lance_fire" and actor.sword_material_backup.is_empty(),"Lance release restores sword material before recovery")
	await test.frames(60)
	test.check(actor.state=="free" and actor.sword_material_backup.is_empty() and not is_instance_valid(fx),"Lance completes recovery without deferred effect restoring blue glow")
	var drag=actor.motion_pose("drag",0)
	var returned=actor.motion_pose("lance",1)
	test.check(drag.grip.is_equal_approx(returned.grip) and drag.tip.is_equal_approx(returned.tip),"Lance recovery ends at the same drawn-walk sword pose")
	actor.restore_stamina(100)
	actor.begin_water_lance()
	await test.frames(8)
	actor.set_sword_drawn(false)
	await test.frames(3)
	test.check(actor.sword_material_backup.is_empty() and not is_instance_valid(actor.lance_charge_fx),"Sheathing during charge stops the effect and restores the weapon")

