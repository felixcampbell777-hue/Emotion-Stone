extends RefCounted
func picture(game:Control,path:String,window:bool=false) -> void:
	await game.get_tree().create_timer(.7).timeout
	await RenderingServer.frame_post_draw
	var viewport=game.get_viewport() if window else game.world_view
	viewport.get_texture().get_image().save_png(path)

func run(game:Control,directory:String) -> void:
	directory+="/standalone";DirAccess.make_dir_recursive_absolute(directory)
	game.start_new_game(false);game.environment_profile="darkwood"
	game.load_map("coastal_path",Vector2(-5.8,.1),true)
	for enemy in game.enemies:enemy.ai_enabled=false
	game.set_character_profile("standalone");game.set_resolution(0)
	game.gallery_mode=true;game.set_process(false);game.player.set_physics_process(false)
	game.player.visual.rotation.y=0
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;game.camera.fov=38
	var base=game.player.position
	for shot in [{"name":"door-scale","offset":Vector3(0,1.12,4.1),"target":.95,"yaw":0.0},{"name":"three-quarter","offset":Vector3(2.1,1.1,3.6),"target":.96,"yaw":0.0},{"name":"back","offset":Vector3(0,1.1,3.7),"target":.96,"yaw":PI},{"name":"face","offset":Vector3(0,1.5,.85),"target":1.47,"yaw":.1}]:
		game.player.visual.rotation.y=shot.yaw
		game.camera.position=base+shot.offset;game.camera.look_at(base+Vector3(0,shot.target,0))
		await picture(game,directory+"/"+shot.name+".png")
	# Neutral lighting isolates material/shape transfer from canopy/house shadows.
	game.current_world.visible=false
	for npc in game.npcs:npc.visible=false
	game.environment_settings.fog_enabled=false;game.environment_settings.volumetric_fog_enabled=false
	game.environment_settings.background_mode=Environment.BG_COLOR;game.environment_settings.background_color=Color("#383b40")
	game.environment_settings.ambient_light_energy=.7;game.environment_settings.adjustment_enabled=false
	var sun=game.world_root.get_node("WorldSun");sun.rotation_degrees=Vector3(-30,-30,0);sun.light_energy=1.3
	game.player.visual.rotation.y=.1
	game.camera.position=base+Vector3(0,1.5,.85);game.camera.look_at(base+Vector3(0,1.47,0))
	await picture(game,directory+"/face-neutral.png")
	var box=game.StandaloneHero.bounds(game.player.get_node("StandaloneHero"))
	var report={"height_m":box.size.y,"ground_y":box.position.y,"door_height_m":2.24,"renderer":RenderingServer.get_current_rendering_method(),"animation_players":0,"skeletons":0,"source":"heroinedraft1.blend (non-anime)"}
	var file=FileAccess.open(directory+"/scale.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	game.gallery_mode=false;game.set_process(true);game.player.set_physics_process(true)
	game.load_map("slime_forest",Vector2(0,6),true)
	for enemy in game.enemies:enemy.ai_enabled=false
	game.camera_driver.set_mode("follow");game.camera_driver.yaw=PI;game.camera_driver.distance=3.8;game.camera_driver.actual_distance=3.8
	game.player.visual.rotation.y=0
	await picture(game,directory+"/forest-follow.png",true)
	game.camera_driver.set_mode("overhead")
	await picture(game,directory+"/forest-overhead.png",true)
	game.toggle_inventory();game.inventory.show_page("equipment")
	await picture(game,directory+"/inventory.png",true)
	game.inventory.close();game.toggle_pause()
	await picture(game,directory+"/pause-menu.png",true)
	print("CAPTURE_OK "+directory)
