extends RefCounted
func run(test:RefCounted) -> void:
	var game=test.game;game.game_mode="beta";game.start_new_game(false);game.set_resolution(0);game.camera_driver.set_mode("first_person")
	var actor=game.player;actor.set_physics_process(false);actor.set_sword_drawn(false);actor.position=Vector3(12,0,-12)
	for enemy in game.enemies: enemy.ai_enabled=false
	game.camera_driver.yaw=PI;game.camera_driver.first_pitch=0;actor.velocity=Vector3.ZERO;actor.sprinting=false
	var hands=game.camera_driver.visuals
	for i in range(30): actor.presentation_clock+=.02;game.camera_driver.update_first_person(0)
	var idle=hands.hand_targets.duplicate();var view=game.camera.global_transform.affine_inverse()
	test.check((view*idle.R).y<-.5 and (view*idle.L).y<-.5,"Unarmed hands hang below the waist view instead of hovering in a combat stance")
	test.check(game.camera.unproject_position(idle.R).y>game.world_view.size.y and game.camera.unproject_position(idle.L).y>game.world_view.size.y,"Relaxed idle hands stay below the forward screen")
	game.camera_driver.first_pitch=1.0;game.camera_driver.update_first_person(0)
	test.check(game.camera.unproject_position(hands.hand_targets.R).y>game.world_view.size.y,"Relaxed idle hands keep the view clear while looking down")
	game.camera_driver.first_pitch=0;actor.velocity=Vector3(0,0,actor.walk_speed)
	for i in range(40): actor.presentation_clock+=.02;game.camera_driver.update_first_person(0)
	var walking=[]
	for i in range(50):
		actor.presentation_clock+=.02;game.camera_driver.update_first_person(0)
		var inverse=game.camera.global_transform.affine_inverse();walking.append([inverse*hands.hand_targets.R,inverse*hands.hand_targets.L])
	var anti=true;var walk_span=0.0
	for pose in walking:
		anti=anti and absf((pose[0].z-hands.unarmed.tuning.walk[2])+(pose[1].z-hands.unarmed.tuning.walk[2]))<.025
		walk_span=maxf(walk_span,absf(pose[0].z-pose[1].z))
	test.check(anti and walk_span>.25,"Walking swings opposite arms forward and back")
	actor.sprinting=true;actor.velocity=Vector3(0,0,4.6)
	for i in range(40): actor.presentation_clock+=.02;game.camera_driver.update_first_person(0)
	var run_span=0.0;var visible=false
	for i in range(45):
		actor.presentation_clock+=.02;game.camera_driver.update_first_person(0)
		var inverse=game.camera.global_transform.affine_inverse();run_span=maxf(run_span,absf((inverse*hands.hand_targets.R).z-(inverse*hands.hand_targets.L).z))
		for side in ["R","L"]:
			var screen=game.camera.unproject_position(hands.hand_targets[side]);visible=visible or Rect2(Vector2.ZERO,Vector2(game.world_view.size)).has_point(screen)
	test.check(run_span>walk_span*1.25 and visible,"Sprint uses a stronger alternating swing with hands briefly visible at the lower edges")
	var before=hands.hand_targets.R;var frozen=actor.presentation_clock;game.toggle_pause();actor._physics_process(.3);game.camera_driver.update_first_person(0)
	test.check(actor.presentation_clock==frozen and hands.hand_targets.R.distance_to(before)<.005,"Menu pause freezes arm swing and its blend envelopes")
	game.pause_menu.close();game._refresh_simulation();actor.velocity=Vector3.ZERO;actor.sprinting=false
	for i in range(45): actor.presentation_clock+=.02;game.camera_driver.update_first_person(0)
	test.check(hands.unarmed.moving<.02 and hands.unarmed.running<.02,"Stopping eases the arms back down to relaxed idle")
	actor.state="roll";game.camera_driver.update_first_person(0)
	test.check(not hands.root.visible,"Unarmed hands stay clear of the view during the somersault")
	actor.set_sword_drawn(true);game.camera_driver.update_first_person(0)
	var grip=actor.equipment.global_transform*Vector3(0,.065,0)
	test.check(hands.root.visible and hands.hand_targets.R.distance_to(grip)<.001,"Drawing the sword restores the existing real hilt grip")
	actor.set_sword_drawn(false);actor.set_physics_process(true)
