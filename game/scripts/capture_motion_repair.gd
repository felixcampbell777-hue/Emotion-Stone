extends SceneTree
class LegacyHands extends "res://scripts/unarmed_hands.gd":
	func targets(actor:Node3D,frame:Transform3D) -> Dictionary:
		# Reproduction reference for before/after evidence, never used by gameplay.
		super.targets(actor,frame)
		var clock=float(actor.presentation_clock);var rate=lerpf(float(tuning.walk_rate),float(tuning.sprint_rate),running)
		var base=vector(tuning.idle).lerp(vector(tuning.walk).lerp(vector(tuning.sprint),running),moving)
		var forward=lerpf(float(tuning.walk_forward),float(tuning.sprint_forward),running)*moving
		var lift=lerpf(float(tuning.walk_lift),float(tuning.sprint_lift),running)*moving
		var result={}
		for side in ["R","L"]:
			var sign=1.0 if side=="R" else -1.0;var swing=sin(clock*rate)*sign
			result[side]=frame*Vector3(base.x*sign+sign*.015*moving*cos(clock*rate),base.y+lift*maxf(0,swing)+sin(clock*2)*.003*(1-moving),base.z-forward*swing)
		return result
func _initialize() -> void:call_deferred("run")
func key(code:int,pressed:bool) -> void:
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=pressed
	Input.parse_input_event(event);Input.flush_buffered_events()
func picture(game:Control,path:String) -> void:
	game.toast_time=0;game.toast.hide()
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
func input_sequence(game:Control,directory:String) -> void:
	game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide();game._refresh_simulation()
	game.set_process(false);game.set_physics_process(false);game.set_resolution(0)
	var actor=game.player;actor.set_physics_process(false);actor.set_meta("canonical_manual_step",true)
	for enemy in game.enemies:enemy.ai_enabled=false;enemy.set_physics_process(false)
	var driver=game.camera_driver;driver.yaw=PI;driver.first_pitch=0
	var metrics={}
	for variant in ["before","after"]:
		actor.position=Vector3(0,26,0);actor.state="free";actor.set_sword_drawn(false);actor.restore_stamina(100)
		actor.play_clip("idle_loop",0);actor.animator.seek(0,true);actor.set_meta("canonical_view_blend",0.0)
		if actor.has_node("BetaHero"):
			var gait=actor.get_node("BetaHero").gait;gait.phase=0;gait.run_blend=0;gait.blend=0
		actor.presentation_clock=600.0;driver.visuals.unarmed=LegacyHands.new() if variant=="before" else load("res://scripts/unarmed_hands.gd").new()
		key(KEY_W,true);await process_frame
		for tick in range(120):await physics_frame;actor._physics_process(1.0/60);driver.update_first_person(1.0/60)
		key(KEY_SHIFT,true);await process_frame
		var previous=game.camera.global_transform.affine_inverse()*driver.visuals.hand_targets.R;var peak=0.0
		for tick in range(30):
			await physics_frame
			actor._physics_process(1.0/60);driver.update_first_person(1.0/60)
			var local_hand=game.camera.global_transform.affine_inverse()*driver.visuals.hand_targets.R
			peak=maxf(peak,previous.distance_to(local_hand));previous=local_hand
			if tick%2==0:await picture(game,directory+"/input-%s-%02d.png"%[variant,tick])
		metrics[variant]={"peak_camera_hand_step":peak,"clock":actor.presentation_clock,"sprinting":actor.sprinting}
		key(KEY_SHIFT,false);key(KEY_W,false);await process_frame
	# Actual R and J key input routes through the production input handler.
	key(KEY_R,true);await process_frame;key(KEY_R,false)
	for tick in range(120):await physics_frame;actor._physics_process(1.0/60);driver.update_first_person(1.0/60)
	await picture(game,directory+"/input-ready.png")
	key(KEY_J,true);await process_frame;key(KEY_J,false)
	for tick in range(75):
		await physics_frame
		actor._physics_process(1.0/60);driver.update_first_person(1.0/60)
		if tick%5==0:await picture(game,directory+"/input-cut-%02d.png"%tick)
	var file=FileAccess.open(directory+"/input-metrics.json",FileAccess.WRITE);file.store_string(JSON.stringify(metrics,"\t"));file.close()
	actor.remove_meta("canonical_manual_step")
func cut_poses(game:Control,directory:String) -> void:
	game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide();game._refresh_simulation()
	game.set_process(false);game.set_physics_process(false);game.set_resolution(0)
	var actor=game.player;actor.set_physics_process(false);actor.set_meta("canonical_manual_step",true)
	for enemy in game.enemies:enemy.ai_enabled=false;enemy.set_physics_process(false)
	actor.position=Vector3(0,26,0);actor.set_sword_drawn(true);actor.restore_stamina(100)
	var driver=game.camera_driver;driver.yaw=PI;driver.first_pitch=0;driver.update_first_person(0)
	key(KEY_J,true);await process_frame;key(KEY_J,false)
	var phases=[.45,.55,.64,.74];var at=0
	for tick in range(180):
		await physics_frame
		actor._physics_process(1.0/60);driver.update_first_person(1.0/60)
		if actor.state=="light" and at<phases.size() and actor.state_time/actor.state_duration>=float(phases[at]):
			await picture(game,directory+"/guided-cut-%02d.png"%roundi(float(phases[at])*100));at+=1
		if at==phases.size():break
	actor.remove_meta("canonical_manual_step")
func run() -> void:
	var args=OS.get_cmdline_user_args()
	var directory="res://../output/verification/current-render/motion"
	if "--output" in args:directory=args[args.find("--output")+1]
	DirAccess.make_dir_recursive_absolute(directory)
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;await process_frame
	game.get_window().size=Vector2i(1280,720)
	if "--pose-only" in args:await cut_poses(game,directory)
	else:
		if "--input-only" not in args:await load("res://scripts/unarmed_capture.gd").new().run(game,directory,"world_rise")
		await input_sequence(game,directory)
	if game.audio!=null and game.audio.has_method("shutdown"):
		game.audio.shutdown();await create_timer(.15).timeout
	print("CAPTURE_OK World Rise Advanced motion poses ",directory)
	quit()
