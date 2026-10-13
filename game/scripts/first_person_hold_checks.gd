extends RefCounted
func run(test:RefCounted) -> void:
	var game=test.game;var actor=game.player;var driver=game.camera_driver
	driver.set_mode("first_person");driver.yaw=PI;driver.first_pitch=0
	actor.set_physics_process(false);actor.set_sword_drawn(true);actor.visual.rotation.y=0
	var hands=driver.visuals
	var on_screen=true;var grasp_error=0.0;var missing=[]
	for pitch in [-.7,0,.7]:
		driver.first_pitch=pitch
		for drawn in [false,true]:
			actor.set_sword_drawn(drawn)
			for stance in ["idle_loop","walk_loop","drag_idle_loop","drag_walk_loop"]:
				actor.play_clip(stance,0);actor.animator.seek(.4,true)
				actor._pose_sword("drag",0);driver.update_first_person()
				for side in ["L","R"]:
					var index=hands.bone("forearm",side);var palm=hands.PALM;palm.x*=1 if side=="R" else -1
					var at=hands.rig.global_transform*(hands.rig.get_bone_global_pose(index)*palm)
					var screen=game.camera.unproject_position(at)
					on_screen=on_screen and not game.camera.is_position_behind(at) and Rect2(Vector2.ZERO,Vector2(game.world_view.size)).has_point(screen)
					if not Rect2(Vector2.ZERO,Vector2(game.world_view.size)).has_point(screen): missing.append([side,pitch,drawn,stance,screen])
					if drawn: grasp_error=maxf(grasp_error,at.distance_to(hands.hand_targets[side]))
	test.check(on_screen,"Actual left/right palms remain visible while armed/unarmed, walking and looking up/down "+str(missing))
	test.check(grasp_error<.055,"Forward-ready fists meet the real hilt without extending or stretching the arm bones")
	test.check(hands.root.get_parent()==actor and hands.rig!=actor.get_node("BetaHero").rig,"First-person arm rig is independent of the hidden full-body drag and hurt blink")
	driver.first_pitch=0;actor.set_sword_drawn(true)
	actor.play_clip("drag_idle_loop",0);actor._pose_sword("drag",0);driver.update_first_person()
	var direction=driver.sample_first_person().basis.inverse()*(-actor.equipment.global_basis.y.normalized())
	var right_hand=game.camera.unproject_position(hands.hand_targets.R)
	var left_hand=game.camera.unproject_position(hands.hand_targets.L)
	test.check(direction.y>.8 and direction.x>.2 and right_hand.x>game.world_view.size.x*.55 and right_hand.y<left_hand.y,"Reference ready hold is upright on screen right, with the guard hand above the pommel hand")
	var clear=true;var minimum=99.0;var endpoint_error=0.0;var opening_grip_error=0.0
	for key in ["light","light2","light3","heavy","water","lance","thrust","parry"]:
		var clip="parry_guard" if key=="parry" else "attack_"+key
		actor.state="light" if key.begins_with("light") else "lance_charge" if key=="lance" else key
		actor.combo_stage=3 if key=="light3" else 2 if key=="light2" else 1
		actor.state_duration=3.0;actor.play_clip(clip,0)
		for index in range(81):
			var phase=float(index)/80;actor.state_time=actor.state_duration*phase
			actor.animator.seek(actor.animator.get_animation(actor.clips[clip]).length*phase,true)
			actor.visual.rotation.y=actor.spin_rotation(phase) if key=="light3" else 0
			actor._pose_sword(key,phase);driver.update_first_person()
			var rails=actor.blade_segment()
			endpoint_error=maxf(endpoint_error,rails[1].distance_to(actor.sword_tip()))
			for side in ["L","R"]:
				var upper=hands.bone("upper_arm",side);var lower=hands.bone("forearm",side)
				var shoulder=hands.rig.global_transform*hands.rig.get_bone_global_pose(upper).origin
				var elbow=hands.rig.global_transform*hands.rig.get_bone_global_pose(lower).origin
				var palm=hands.PALM;palm.x*=1 if side=="R" else -1
				var wrist=hands.rig.global_transform*(hands.rig.get_bone_global_pose(lower)*palm)
				if key in ["light","light2"]:
					var hilt=actor.equipment.global_transform*Vector3(0,.065 if side=="R" else .20,0)
					opening_grip_error=maxf(opening_grip_error,wrist.distance_to(hilt))
				# Parry deliberately braces the blade with the palm; the forearm stays clear.
				var end=elbow.lerp(wrist,.65) if key=="parry" and side=="L" else wrist
				for segment in [[shoulder,elbow],[elbow,end]]:
					for offset in [Vector3.ZERO,actor.equipment.global_basis.x.normalized()*.05,-actor.equipment.global_basis.x.normalized()*.05]:
						var near=Geometry3D.get_closest_points_between_segments(rails[0]+offset,rails[1]+offset,segment[0],segment[1])
						var distance=near[0].distance_to(near[1]);minimum=minf(minimum,distance)
						clear=clear and distance>.035
	test.check(clear,"Sword steel stays outside the visible upper arms and forearms across 648 attack/charge/parry subframes (minimum %.3fm)"%minimum)
	test.check(opening_grip_error<.055,"Both palms stay fitted through the opening and returning cuts without letting go at the combo join")
	test.check(endpoint_error<.0001,"First-person melee rails terminate at the same steel tip the player sees")
	var joins=true
	for pair in [["light","light2"],["light2","light3"]]:
		actor.visual.rotation.y=0;actor.state="light"
		actor.play_clip("attack_"+pair[0],0);actor.animator.seek(actor.animator.get_animation(actor.clips["attack_"+pair[0]]).length*.74,true)
		actor._pose_sword(pair[0],.74);var end=actor.equipment.global_transform
		actor.play_clip("attack_"+pair[1],0);actor.animator.seek(0,true);actor._pose_sword(pair[1],0)
		joins=joins and end.origin.distance_to(actor.equipment.global_position)<.035 and end.basis.get_rotation_quaternion().angle_to(actor.equipment.global_basis.get_rotation_quaternion())<.05
	test.check(joins,"Linked return cut and spinning overhead start at the previous strike's held-blade endpoint")
	actor.set_sword_drawn(true);actor.lance_unlocked=true;actor.restore_stamina(actor.max_stamina);actor.invulnerability=0
	driver.first_pitch=.4;actor.begin_water_lance();actor.state_time=actor.state_duration*.5;actor._physics_process(0);driver.update_first_person()
	var aura=actor.lance_charge_fx
	test.check(aura.get_parent()==actor and aura.is_visible_in_tree() and aura.global_basis.get_scale().length()<.8,"First-person charge aura follows the live hilt outside the hidden body and stays small enough to see through")
	actor.state_time=actor.state_duration;actor._physics_process(0)
	var beam=game.projectiles[-1]
	test.check(beam.direction.y<-.25 and beam.direction.dot(-driver.sample_first_person().basis.z)>.995,"Water Lance fires down the visible forward blade when aiming downward")
	actor.set_sword_drawn(true);driver.first_pitch=0
	var rats=game.enemies.filter(func(enemy): return enemy.definition.kind=="beta_rat")
	if not rats.is_empty():
		var rat=rats[0];var home=rat.position;var health=rat.health;var location=actor.position;var ai=rat.ai_enabled
		rat.set_physics_process(false);rat.ai_enabled=false;rat.health=rat.max_health;rat.position=Vector3(0,0,-10.8)
		actor.position=Vector3(0,0,-12);actor.set_sword_drawn(true);actor.restore_stamina(actor.max_stamina);actor.combo_stage=0;actor.combo_remaining=0
		driver.first_pitch=.55;actor.begin_attack("light");actor.action_transition_remaining=0
		for index in range(81): actor.state_time=actor.state_duration*.9*index/80.0;actor._physics_process(0)
		test.check(rat.health==rat.max_health-int(actor.combat.light.damage),"An actual forward-held opening cut aimed down damages a low rat once through the live contact callback (%d HP; %d damage)"%[rat.health,actor.combat.light.damage])
		rat.health=health;rat.position=home;rat.knockback=Vector3.ZERO;rat.ai_enabled=ai;rat.set_physics_process(true)
		actor.position=location;actor.set_sword_drawn(true);driver.first_pitch=0
	actor.set_sword_drawn(true);actor.play_clip("drag_idle_loop",0);actor._pose_sword("drag",0);driver.update_first_person()
	var pose=hands.root.global_transform;var weapon=actor.equipment.global_transform;game.toggle_pause();await test.frames(3)
	test.check(hands.root.global_transform.is_equal_approx(pose) and actor.equipment.global_transform.is_equal_approx(weapon),"Pause freezes first-person hands and weapon without a separate viewmodel clock")
	game.pause_menu.close();actor.set_physics_process(true)
