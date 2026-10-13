extends RefCounted
func picture(game:Control,path:String) -> void:
	await game.get_tree().create_timer(.8).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
func run(game:Control,directory:String) -> void:
	game.start_new_game()
	game.camera_driver.set_mode("overhead")
	await picture(game,directory+"/home-wake-up.png")
	game.advance_dialogue()
	await picture(game,directory+"/home-bedroom.png")
	game.camera_driver.set_mode("follow")
	game.camera_driver.yaw=0
	game.player.visual.rotation.y=PI
	await picture(game,directory+"/home-bedroom-follow.png")
	game.player.position=Vector3(1.8,0,.7)
	game.camera_driver.yaw=PI
	game.camera_driver.pitch=.96
	game.camera_driver.distance=3.4
	await picture(game,directory+"/home-descending-stairwell.png")
	game.camera_driver.set_mode("overhead")
	game.player.position=Vector3(1.6,0,2)
	await picture(game,directory+"/home-stairwell-overhead.png")
	game.load_map("home_downstairs",Vector2(0,2.2))
	game.camera_driver.set_mode("overhead")
	await picture(game,directory+"/home-hearth-room.png")
	game.camera_driver.set_mode("follow")
	game.camera_driver.yaw=0
	game.player.position=Vector3(0,0,-1.5)
	await picture(game,directory+"/home-fireplace-follow.png")
	game.player.position=Vector3(1.8,0,.7)
	game.camera_driver.yaw=PI
	game.camera_driver.pitch=.4
	await picture(game,directory+"/home-ascending-staircase.png")
	game.player.position=Vector3(0,0,2.4)
	await picture(game,directory+"/home-framed-door.png")
	game.camera_driver.set_mode("overhead")
	game.player.position=Vector3(0,0,4.1)
	game.exit_cooldown=0
	await game.get_tree().process_frame
	game.open_nearest()
	await picture(game,directory+"/home-door-locked.png")
	game.player.position=Vector3(-.1,0,-2.8)
	await game.get_tree().create_timer(.2).timeout
	game.open_nearest()
	await picture(game,directory+"/home-mother-morning.png")
	game.conversation.morning_farewell()
	await picture(game,directory+"/home-mother-farewell.png")
	game.conversation.accept_quest()
	await picture(game,directory+"/home-mother-quest.png")
	game.conversation.reveal_arm()
	await picture(game,directory+"/home-mother-reveal.png")
	game.conversation.close()
	game.player.position=Vector3(0,0,4.1)
	game.exit_cooldown=0
	await game.get_tree().process_frame
	game.open_nearest()
	await picture(game,directory+"/home-coastal-doorstep.png")
