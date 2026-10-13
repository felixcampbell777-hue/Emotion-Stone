extends RefCounted
const Props=preload("res://scripts/props.gd")
func run(game:Control,directory:String) -> void:
	game.conversation.close()
	game.inventory.close()
	game.help_panel.visible=false
	game.camera_driver.set_mode("overhead")
	game.set_resolution(0)
	game.gallery_mode=true
	game.camera.size=4.6
	game.load_map("coastal_path",Vector2(0,0),true)
	game.camera.size=4.6
	game.current_world.visible=false
	for actor in game.npcs: actor.visible=false
	for enemy in game.enemies: enemy.visible=false
	game.player.set_physics_process(false)
	game.player.position=Vector3.ZERO
	game.player.visual.rotation.y=0
	game.player.set_sword_glow(false)
	var floor_mesh=Props.box(game.world_root,Vector3(0,-.12,0),Vector3(14,.08,14),"#7c8c81")
	var clips=["idle_loop","walk_loop","interact","drag_idle_loop","drag_walk_loop","draw_sword","sheathe_sword","attack_light","attack_light2","attack_light3","attack_heavy","attack_water","attack_lance","parry_guard","attack_thrust","dodge_roll","stand_up","dodge_roll_sheathed","stand_up_sheathed"]
	for view in ["front","side","back"]:
		game.camera_offset=Vector3(0,2.8,8) if view=="front" else Vector3(0,2.8,-8) if view=="back" else Vector3(8,2.5,0)
		for clip in clips:
			if view=="back" and clip not in ["idle_loop","walk_loop","draw_sword","sheathe_sword","dodge_roll","stand_up","dodge_roll_sheathed","stand_up_sheathed"]: continue
			if view=="side" and clip not in ["walk_loop","drag_walk_loop","attack_light","attack_light2","attack_light3","attack_heavy","attack_lance","attack_thrust","parry_guard","dodge_roll","stand_up","draw_sword","sheathe_sword","dodge_roll_sheathed","stand_up_sheathed"]: continue
			game.player.set_sword_drawn(clip not in ["idle_loop","walk_loop","interact","dodge_roll_sheathed","stand_up_sheathed"])
			game.player.play_clip(clip,0)
			var key=clip.trim_prefix("attack_") if clip.begins_with("attack_") else "parry" if clip=="parry_guard" else "roll" if clip.begins_with("dodge_roll") else "stand" if clip.begins_with("stand_up") else "drag"
			var phases=[0.0,.10,.18,.24,.38,.52,.64,.76,.90,1.0] if clip=="attack_thrust" else [0.0,.28,.44,.54,.66,.74,.84,.94,1.0] if clip=="attack_light" else [0.0,.20,.32,.43,.55,.62,.74,.88,1.0] if clip=="attack_light2" else [0.0,.16,.205,.27,.34,.44,.53,.58,.68,.80,1.0] if clip=="attack_light3" else [0.0,.12,.35,.55,.62,.68,.80,.90,1.0] if clip=="attack_heavy" else [0.0,.12,.31,.48,.65,.75,.815,.85,.88,.935,.975,1.0] if clip=="draw_sword" else [0.0,.08,.16,.30,.43,.58,.73,.81,.88,.95,1.0] if clip=="sheathe_sword" else [0.0,.12,.30,.52,.72,.92,1.0]
			var sheet=Image.create(1536,288*ceili(phases.size()/3.0),false,Image.FORMAT_RGBA8)
			for index in range(phases.size()):
				var clock_phase=phases[index]
				var phase=game.player.sword_action_phase(clock_phase,clip=="sheathe_sword") if clip in ["draw_sword","sheathe_sword"] else clock_phase
				game.player.state="draw" if clip=="draw_sword" else "sheathe" if clip=="sheathe_sword" else "free"
				game.player.animator.seek(phase*game.player.animator.get_animation(game.player.clips[clip]).length,true)
				game.player.action_transition_remaining=0
				if game.player.sword_drawn: game.player._pose_sword(key,phase)
				game.player.visual.rotation.y=game.player.spin_rotation(phase) if clip=="attack_light3" else 0
				if game.game_mode=="beta":
					game.player.get_node("BetaHero").synchronize()
					# Give the derived skin's render buffers a complete frame after seeking.
					await game.get_tree().create_timer(.04).timeout
				await game.get_tree().process_frame
				await RenderingServer.frame_post_draw
				var frame=game.world_view.get_texture().get_image()
				frame.save_png(directory+"/motion-"+view+"-"+clip+"-%03d.png" % roundi(clock_phase*100))
				frame.resize(512,288,Image.INTERPOLATE_LANCZOS)
				frame.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(frame,Rect2i(0,0,512,288),Vector2i((index%3)*512,(index/3)*288))
			sheet.save_png(directory+"/motion-"+view+"-"+clip+"-sheet.png")
	floor_mesh.queue_free()
	game.gallery_mode=false
	game.camera_driver.set_mode("follow")
	game.load_map("coastal_path",Vector2(0,3),true)
	game.player.set_physics_process(false)
	for clip in ["walk_loop","drag_walk_loop"]:
		game.player.set_sword_drawn(clip=="drag_walk_loop")
		game.player.play_clip(clip,0)
		for phase in [.25,.75]:
			game.player.animator.seek(phase*game.player.animator.get_animation(game.player.clips[clip]).length,true)
			if game.player.sword_drawn: game.player._pose_sword("drag",0)
			for yaw in [0.0,PI/2,PI]:
				game.camera_driver.yaw=yaw
				game.camera_driver.pitch=.28
				game.camera_driver.actual_distance=3.8
				await game.get_tree().create_timer(.3).timeout
				await RenderingServer.frame_post_draw
				game.get_viewport().get_texture().get_image().save_png(directory+"/walk-follow-%s-%03d-%03d.png" % [clip,int(phase*100),int(rad_to_deg(yaw))])
	print("ANIMATION_CAPTURE_OK")
