extends SceneTree
## Native first-person evidence for the historically failing uphill physics fixture.
var game:Node
func _initialize() -> void:call_deferred("run")
func picture(path:String) -> void:
	await create_timer(.3).timeout;await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;await process_frame
	game.get_window().size=Vector2i(1280,720);game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide();game._refresh_simulation()
	game.player.position=Vector3(92,0,80);game.player.position.y=game.current_world.support_height(game.player,game.player.position)
	for i in range(64):game.worldrise.update_packs();game.worldrise.tick(.001)
	game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
	for enemy in game.enemies:enemy.set_physics_process(false);enemy.ai_enabled=false
	var candidates=game.enemies.filter(func(enemy):return enemy.definition.kind=="library_boar" and enemy.health>0)
	if candidates.is_empty():push_error("Native slope capture requires a streamed boar");quit(1);return
	var boar=candidates[0];boar.position=Vector3(96,0,84);boar.position.y=game.current_world.support_height(boar,boar.position);boar.state="idle";boar.ai_enabled=true;boar.simulation_enabled=true;boar.encounter_owned=true;boar.encounter_engaged=false;boar.encounter_goal=Vector3(112,0,100)
	game.camera_driver.yaw=-3*PI/4;game.camera_driver.first_pitch=-.5;game.camera_driver.update_first_person();game.toast.hide()
	var directory="res://../output/verification/current-render/slopes";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var player_start=game.player.position;var boar_start=boar.position
	await picture(directory+"/uphill-start.png")
	for i in range(90):
		await physics_frame
		game.player.velocity=Vector3(1,0,1).normalized()*2.4;game.current_world.move_grounded(game.player,1.0/60);boar._physics_process(1.0/60);game.camera_driver.update_first_person()
	boar.ai_enabled=false;await picture(directory+"/uphill-finish.png")
	var result={"player_travel":Vector2(game.player.position.x-player_start.x,game.player.position.z-player_start.z).length(),"player_rise":game.player.position.y-player_start.y,"boar_travel":Vector2(boar.position.x-boar_start.x,boar.position.z-boar_start.z).length(),"boar_rise":boar.position.y-boar_start.y,"physics_frames":90,"renderer":RenderingServer.get_current_rendering_method()}
	var file=FileAccess.open(directory+"/uphill-metrics.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	var ok=result.player_travel>2 and result.player_rise>.1 and result.boar_travel>.9 and result.boar_rise>.1
	if game.audio!=null:ok=await game.audio.shutdown_and_drain() and ok
	print("NATIVE_SLOPE_CAPTURE ",JSON.stringify(result)," passed=",ok)
	quit(0 if ok else 1)
