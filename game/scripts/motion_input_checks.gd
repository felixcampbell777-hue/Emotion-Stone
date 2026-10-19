extends RefCounted
func key(code:int,pressed:bool) -> void:
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=pressed
	Input.parse_input_event(event);Input.flush_buffered_events()
func run(test:RefCounted) -> void:
	var game=test.game;game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide();game._refresh_simulation()
	game.set_process(false);game.set_physics_process(false)
	var actor=game.player;actor.set_physics_process(false);actor.set_meta("canonical_manual_step",true)
	for enemy in game.enemies:enemy.ai_enabled=false;enemy.set_physics_process(false)
	actor.position=Vector3(0,26,0);actor.presentation_clock=600;actor.set_sword_drawn(false)
	var driver=game.camera_driver;driver.yaw=PI;driver.first_pitch=0
	key(KEY_W,true);await test.frames(2)
	for tick in range(120):await test.frames(1);actor._physics_process(1.0/60);driver.update_first_person(1.0/60)
	key(KEY_SHIFT,true);await test.frames(2)
	var previous=game.camera.global_transform.affine_inverse()*driver.visuals.hand_targets.R;var largest_step=0.0;var moved=actor.position
	for tick in range(60):
		await test.frames(1)
		actor._physics_process(1.0/60);driver.update_first_person(1.0/60)
		var point=game.camera.global_transform.affine_inverse()*driver.visuals.hand_targets.R;largest_step=maxf(largest_step,point.distance_to(previous));previous=point
	test.check(actor.sprinting and actor.position.distance_to(moved)>3,"Actual World Rise W/Shift input drives the grounded sprint after a long session")
	test.check(largest_step<.06,"Actual World Rise long-clock sprint keeps camera-relative hand targets bounded (%.4fm/frame)"%largest_step)
	print("MOTION_INPUT camera_hand_step=",largest_step)
	key(KEY_SHIFT,false);key(KEY_W,false);await test.frames(2)
	key(KEY_R,true);await test.frames(2);key(KEY_R,false)
	test.check(actor.state=="draw","Actual R input enters drawn-sword transition from sprint")
	for tick in range(180):await test.frames(1);actor._physics_process(1.0/60);driver.update_first_person(1.0/60)
	test.check(actor.sword_drawn and actor.state=="free","Real draw action returns to forward-ready without a fixture-only state swap")
	key(KEY_J,true);await test.frames(2);key(KEY_J,false)
	test.check(actor.state=="light","Actual J input begins the repaired opening swing")
	var stamina=actor.stamina
	for tick in range(120):await test.frames(1);actor._physics_process(1.0/60);driver.update_first_person(1.0/60)
	test.check(actor.state=="free" and actor.stamina>=stamina,"Repaired real-input swing completes its action/recovery without another stamina charge")
	actor.remove_meta("canonical_manual_step");actor.set_physics_process(true)
	await test.frames(3)
