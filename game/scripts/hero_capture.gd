extends RefCounted
func picture(game:Node,path:String) -> void:
	await game.get_tree().create_timer(.15).timeout
	await RenderingServer.frame_post_draw
	game.world_view.get_texture().get_image().save_png(path)
func run(game:Node,directory:String) -> void:
	var model_only=OS.get_cmdline_user_args().has("--model-only")
	directory+="/hero-detail" if RenderingServer.get_current_rendering_method()=="forward_plus" else "/hero-detail-gl_compatibility"
	DirAccess.make_dir_recursive_absolute(directory)
	game.environment_profile="darkwood";game.load_map("coastal_path",Vector2.ZERO,true)
	game.set_resolution(0);game.gallery_mode=true
	if model_only:game.world_view.size=Vector2i(720,1000)
	game.set_process(false)
	game.current_world.visible=false
	for npc in game.npcs:npc.visible=false
	for enemy in game.enemies:enemy.visible=false;enemy.ai_enabled=false
	game.player.set_physics_process(false);game.player.position=Vector3.ZERO
	game.player.sword_drawn=false;game.player.set_sword_drawn(false)
	if model_only:
		game.player.animator.stop();game.player.skeleton.reset_bone_poses();game.player._place_on_back()
		game.player.equipment.visible=false;game.player.back_harness.visible=false
	else:
		game.player.animator.play(game.player.clips.idle_loop);game.player.animator.seek(0,true);game.player.animator.pause()
	game.environment_settings.fog_enabled=false;game.environment_settings.volumetric_fog_enabled=false
	game.environment_settings.background_mode=Environment.BG_COLOR;game.environment_settings.background_color=Color("#383b40")
	game.environment_settings.ambient_light_color=Color("#ced8e4");game.environment_settings.ambient_light_energy=.6
	var sun=game.world_root.get_node("WorldSun")
	if sun!=null: sun.light_energy=1.3;sun.rotation_degrees=Vector3(-30,-30,0)
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;game.camera.fov=35
	for view in [{"name":"front","yaw":0.0},{"name":"three-quarter","yaw":PI*.22},{"name":"back","yaw":PI},{"name":"side","yaw":PI*.5}]:
		game.player.visual.rotation.y=view.yaw
		game.camera.position=Vector3(0,.88,3.0) if model_only else Vector3(0,.99,3.5)
		game.camera.look_at(Vector3(0,.83,0) if model_only else Vector3(0,.90,0))
		await picture(game,directory+"/"+view.name+".png")
	game.player.visual.rotation.y=.12;game.camera.position=Vector3(0,1.57,.80);game.camera.look_at(Vector3(0,1.52,0))
	await picture(game,directory+"/face.png")
	game.EnvironmentArt.actor_quality(game.player,"original")
	await picture(game,directory+"/original-face.png")
	game.EnvironmentArt.actor_quality(game.player,"darkwood")
	if model_only:game.player.animator.stop();game.player.skeleton.reset_bone_poses();game.player._place_on_back()
	if model_only:game.player.equipment.visible=false;game.player.back_harness.visible=false
	game.camera.position=Vector3(0,.23,1.02);game.camera.look_at(Vector3(0,.20,0))
	await picture(game,directory+"/boots.png")
	if model_only:
		for obsolete in ["forest-gameplay.png","equipment-preview.png"]:
			if FileAccess.file_exists(directory+"/"+obsolete):DirAccess.remove_absolute(directory+"/"+obsolete)
		return
	# Real gameplay, same renderer and materials.
	game.gallery_mode=false;game.set_process(true);game.player.set_physics_process(true)
	game.load_map("slime_forest",Vector2(0,6),true)
	for enemy in game.enemies:enemy.ai_enabled=false
	game.camera_driver.set_mode("follow");game.camera_driver.yaw=0;game.camera_driver.distance=3.4;game.camera_driver.actual_distance=3.4
	game.player.visual.rotation.y=PI
	await picture(game,directory+"/forest-gameplay.png")
	game.toggle_inventory();game.inventory.show_page("equipment");game._refresh_simulation()
	await game.get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(directory+"/equipment-preview.png")
