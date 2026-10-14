extends RefCounted
func picture(game:Control,path:String) -> void:
	await game.get_tree().create_timer(.08).timeout;await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
func run(game:Control,directory:String) -> void:
	game.game_mode="beta";game.start_new_game(false);game.set_resolution(0);game.camera_driver.set_mode("first_person")
	var actor=game.player;actor.set_physics_process(false);actor.position=Vector3(12,0,-12);actor.set_sword_drawn(false)
	for enemy in game.enemies: enemy.ai_enabled=false
	game.camera_driver.yaw=-PI/2;game.camera_driver.first_pitch=0
	for mode in ["idle","walk","sprint"]:
		actor.velocity=Vector3.ZERO if mode=="idle" else Vector3(4.6 if mode=="sprint" else actor.walk_speed,0,0);actor.sprinting=mode=="sprint"
		for i in range(40): actor.presentation_clock+=.02;game.camera_driver.update_first_person(0)
		for phase in range(4):
			var rate=10.5 if mode=="sprint" else 7.0
			actor.presentation_clock=(ceil(actor.presentation_clock*rate/TAU)+phase*.25+.25)*TAU/rate
			game.camera_driver.update_first_person(0);await picture(game,directory+"/unarmed-%s-%d.png"%[mode,phase])
	actor.velocity=Vector3.ZERO;actor.sprinting=false
	for i in range(40): actor.presentation_clock+=.02;game.camera_driver.update_first_person(0)
	game.camera_driver.first_pitch=1.0;game.camera_driver.update_first_person(0)
	await picture(game,directory+"/unarmed-look-down.png")
	actor.set_physics_process(true)
