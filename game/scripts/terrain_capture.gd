extends RefCounted
func picture(game:Node,path:String) -> void:
	await game.get_tree().process_frame
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
func run(game:Node,directory:String) -> void:
	game.load_map("menagery",Vector2(-11,-19),true)
	game.set_resolution(960)
	game.player.set_sword_drawn(false)
	game.player.set_physics_process(false)
	await game.get_tree().create_timer(.2).timeout
	game.set_process(false)
	game.environment_settings.fog_enabled=false
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	game.camera.fov=50
	for code in ["1F","2F","3F","4F"]:
		var prop=game.current_world.get_node("feature_"+code.to_lower())
		var at=prop.position
		game.player.position=at+Vector3(0,0,1.5)
		game.player.position.y=game.current_world.ground_height(game.player.position)
		game.camera.position=at+Vector3(9,8,12)
		game.camera.look_at(at+Vector3(0,.9,0),Vector3.UP)
		await picture(game,directory+"/terrain-"+code+".png")
	game.player.position=Vector3(-11,game.current_world.ground_height(Vector3(-11,0,-33)),-33)
	game.camera.position=Vector3(-3,7,-25)
	game.camera.look_at(Vector3(-11,1.3,-34),Vector3.UP)
	await picture(game,directory+"/terrain-bluff-summit.png")
	game.player.position=Vector3(15,0,-31.9)
	game.camera.position=Vector3(20,4,-26)
	game.camera.look_at(Vector3(15,1.2,-34),Vector3.UP)
	await picture(game,directory+"/terrain-cave-mouth.png")
	game.set_process(true)
	game.load_map("menagery_cave",Vector2(0,5.5),true)
	game.camera_driver.set_mode("follow"); game.camera_driver.yaw=0
	game.camera_target=game.player.position+Vector3.UP*.8
	await game.get_tree().create_timer(.5).timeout
	await picture(game,directory+"/terrain-cave-entry.png")
	game.player.position=Vector3(0,0,-3)
	game.camera_target=game.player.position+Vector3.UP*.8
	await game.get_tree().create_timer(.5).timeout
	await picture(game,directory+"/terrain-cave-chamber.png")
	game.camera_driver.set_mode("overhead")
	game.camera.size=10
	await game.get_tree().create_timer(.3).timeout
	await picture(game,directory+"/terrain-cave-overhead.png")
	game.player.set_physics_process(true)
	print("TERRAIN_CAPTURE_OK")
