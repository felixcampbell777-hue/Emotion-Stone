extends RefCounted
func picture(game:Node,path:String,world_only:bool=false) -> void:
	await game.get_tree().process_frame
	await RenderingServer.frame_post_draw
	(game.world_view if world_only else game.get_viewport()).get_texture().get_image().save_png(path)
func run(game:Node,directory:String) -> void:
	game.load_map("menagery",Vector2(10,0),true)
	game.player.restore_health(100)
	game.player.set_sword_drawn(true)
	game.camera_driver.set_mode("overhead")
	game.set_resolution(640)
	await game.get_tree().create_timer(.45).timeout
	await picture(game,directory+"/menagery-arrival.png")
	game.menagery.toggle()
	await picture(game,directory+"/menagery-spawn-buttons.png")
	game.menagery.close()
	for code in game.menagery.spawn_buttons:
		var mob=game.menagery.spawn(code); mob.ai_enabled=false; mob.set_physics_process(false)
	game.player.set_physics_process(false)
	game.camera.size=12
	await picture(game,directory+"/menagery-ten-specimens.png")
	game.camera_driver.set_mode("follow")
	game.camera_driver.yaw=0
	game.player.position=Vector3(-8,0,-7)
	await game.get_tree().create_timer(.45).timeout
	await picture(game,directory+"/menagery-tree-gallery.png")
	game.camera_driver.set_mode("overhead")
	game.gallery_mode=true
	game.camera_offset=Vector3(0,16,12)
	game.camera.size=36
	game.camera_target=Vector3(-5,0,0)
	await picture(game,directory+"/menagery-feature-overview.png")
	game.gallery_mode=false
	game.camera.size=7
	game.camera_driver.set_mode("follow")
	for prop in game.current_world.get_children():
		if not prop.name.begins_with("feature_"): continue
		game.player.position=prop.position+Vector3(0,0,3)
		game.player.position.y=game.current_world.ground_height(game.player.position)
		await game.get_tree().create_timer(.45).timeout
		await picture(game,directory+"/menagery-"+str(prop.name)+".png",true)
	game.player.position=Vector3(10,0,0)
	var resin=game.menagery.spawned["2E"]; resin._release_ability()
	var bramble=game.menagery.spawned["3E"]; bramble.direction=Vector3.FORWARD; bramble._release_ability()
	await game.get_tree().create_timer(.45).timeout
	await picture(game,directory+"/menagery-resin-seeds.png")
	game.menagery.clear()
	game.player.set_physics_process(true)
	print("MENAGERY_CAPTURE_OK")
