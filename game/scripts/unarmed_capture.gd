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
	game.camera_driver.first_pitch=0;actor.velocity=Vector3.ZERO;actor.state="free";actor.set_sword_drawn(true);actor.play_clip("drag_idle_loop",0)
	actor._pose_sword("drag",0);game.camera_driver.update_first_person(0);await picture(game,directory+"/hands-ready-grip.png")
	for fixture in [["parry","parry_guard",.4],["water","attack_water",.45],["lance_charge","attack_lance",.45]]:
		actor.state=fixture[0];actor.state_duration=3;actor.state_time=3*fixture[2];actor.play_clip(fixture[1],0);actor.animator.seek(actor.animator.get_animation(actor.clips[fixture[1]]).length*fixture[2],true)
		actor._pose_sword("parry" if fixture[0]=="parry" else "water" if fixture[0]=="water" else "lance",fixture[2]);game.camera_driver.update_first_person(0);await picture(game,directory+"/hands-"+fixture[0]+".png")
	for stage in range(1,4):
		for phase in [.14,.35,.55,.74]:
			var clip="attack_light"+(str(stage) if stage>1 else "")
			actor.state="light";actor.combo_stage=stage;actor.state_duration=2;actor.state_time=2*phase;actor.play_clip(clip,0)
			actor.animator.seek(actor.animator.get_animation(actor.clips[clip]).length*phase,true)
			actor._pose_sword("light"+(str(stage) if stage>1 else ""),phase);game.camera_driver.update_first_person(0)
			await picture(game,directory+"/hands-swing-%d-%02d.png"%[stage,roundi(phase*100)])
	actor.set_physics_process(true)
