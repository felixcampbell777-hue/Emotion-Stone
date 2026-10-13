extends RefCounted
func picture(game:Control,path:String) -> void:
	await game.get_tree().create_timer(.8).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
func run(game:Control,directory:String) -> void:
	game.start_new_game(false);game.set_resolution(0)
	game.camera_driver.set_mode("first_person");game.camera_driver.yaw=PI;game.camera_driver.first_pitch=.08
	game.load_map("slime_forest",Vector2(0,-5),true)
	for enemy in game.enemies: enemy.ai_enabled=false
	await picture(game,directory+"/camera-first-person-alpha.png")
	game.player.set_sword_drawn(true)
	await picture(game,directory+"/alpha-advanced-first-person-sword.png")
	game.player.begin_parry();game.player.set_physics_process(false)
	await parry_views(game,directory)
	game.player.state_time=game.player.state_duration*.4;game.player._physics_process(0)
	await picture(game,directory+"/alpha-advanced-first-person-parry.png")
	game.player.state_time=game.player.state_duration;game.player._physics_process(0);game.player.set_physics_process(true)
	await load("res://scripts/lance_control_capture.gd").new().run(game,directory)
	await load("res://scripts/first_person_combat_capture.gd").new().run(game,directory)
	game.game_mode="beta";game.start_new_game(false)
	for enemy in game.enemies: enemy.ai_enabled=false
	game.camera_driver.set_mode("first_person");game.camera_driver.yaw=PI;game.camera_driver.first_pitch=.08
	await picture(game,directory+"/camera-first-person-meadow.png")
	await movement_views(game,directory)
	var mouse=InputEventMouseMotion.new();mouse.relative=Vector2(85,0);mouse.position=game.world_rect.get_center()
	Input.parse_input_event(mouse);Input.flush_buffered_events()
	await picture(game,directory+"/camera-first-person-look-right.png")
	mouse=InputEventMouseMotion.new();mouse.relative=Vector2(-170,0);mouse.position=game.world_rect.get_center()
	Input.parse_input_event(mouse);Input.flush_buffered_events()
	await picture(game,directory+"/camera-first-person-look-left.png")
	game.camera_driver.yaw=PI;game.player.set_sword_drawn(true);game.player.restore_stamina(100)
	game.player.combo_stage=2;game.player.combo_remaining=1;game.player.begin_attack("light");game.player.set_physics_process(false)
	game.player.chain_blend=0;game.player.action_transition_remaining=0
	for phase in [.05,.12,.205,.27,.36]:
		game.player.state_time=game.player.state_duration*phase;game.player._physics_process(0)
		await picture(game,directory+"/camera-first-person-spin-%03d.png"%int(phase*100))
	game.player.state_time=game.player.state_duration;game.player._physics_process(0);game.player.combo_remaining=0;game.player.set_physics_process(true)
	game.toggle_pause();await picture(game,directory+"/camera-first-person-paused.png")
	game.pause_menu.close();game.toggle_inventory();await picture(game,directory+"/camera-first-person-inventory.png")
	game.inventory.close()
	print("CAPTURE_OK "+directory)

func parry_views(game:Control,directory:String) -> void:
	var actor=game.player;var driver=game.camera_driver
	var tuning=driver.tuning.first_person_parry_motion;var samples=[]
	driver.first_pitch=.08;driver.yaw=PI
	actor.action_transition_remaining=0
	for phase in [.05,.25,.50,.75,.95]:
		actor.state_time=actor.state_duration*phase;actor._physics_process(0)
		driver.tuning.first_person_parry_motion=1;driver.update_first_person()
		var neutral=Basis(Vector3.UP,driver.yaw)*Basis(Vector3.RIGHT,-driver.first_pitch)
		var full=neutral.get_rotation_quaternion().angle_to(game.camera.global_basis.get_rotation_quaternion())
		driver.tuning.first_person_parry_motion=tuning;driver.update_first_person()
		var reduced=neutral.get_rotation_quaternion().angle_to(game.camera.global_basis.get_rotation_quaternion())
		var name="camera-parry-forward-%02d"%int(phase*100)
		await picture(game,directory+"/"+name+".png")
		samples.append({"phase":phase,"full_angle_degrees":rad_to_deg(full),"reduced_angle_degrees":rad_to_deg(reduced),"view":name})
	var file=FileAccess.open(directory+"/camera-parry-motion.json",FileAccess.WRITE);file.store_string(JSON.stringify(samples,"\t"));file.close()

func movement_views(game:Control,directory:String) -> void:
	var actor=game.player;var hero=actor.get_node("BetaHero");var driver=game.camera_driver
	actor.set_physics_process(false);hero.set_process(false);game.set_process(false)
	var samples=[];var scale=driver.tuning.get("first_person_movement_motion",.5)
	for drawn in [false,true]:
		actor.set_sword_drawn(drawn);actor.state="free"
		for sprint in [false,true]:
			actor.sprinting=sprint
			var clip="drag_walk_loop" if drawn else "walk_loop"
			actor.play_clip(clip,0)
			for phase in [.25,.75]:
				actor.animator.seek(actor.animator.get_animation(actor.clips[clip]).length*phase,true);actor.animator.pause()
				driver.tuning.first_person_movement_motion=1;driver.update_first_person()
				var full=game.camera.global_transform
				driver.tuning.first_person_movement_motion=scale;driver.update_first_person()
				var reduced=game.camera.global_transform
				var name="camera-gait-%s-%s-%02d"%["drawn" if drawn else "sheathed","sprint" if sprint else "walk",int(phase*100)]
				await picture(game,directory+"/"+name+".png")
				samples.append({"view":name,"full_eye":[full.origin.x,full.origin.y,full.origin.z],"reduced_eye":[reduced.origin.x,reduced.origin.y,reduced.origin.z],"scale":scale})
	var file=FileAccess.open(directory+"/camera-gait-motion.json",FileAccess.WRITE);file.store_string(JSON.stringify(samples,"\t"));file.close()
	actor.sprinting=false;actor.set_sword_drawn(false);actor.play_clip("idle_loop",0)
	driver.locomotion_camera_blend=0;hero.set_process(true);actor.set_physics_process(true);game.set_process(true)
