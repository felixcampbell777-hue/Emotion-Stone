extends RefCounted
func run(game:Control,directory:String) -> void:
	var actor=game.player;var hero=actor.get_node("BetaHero")
	var base=actor.position
	actor.set_physics_process(false);hero.set_process(false)
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;game.camera.fov=36
	# Neutral review lighting keeps boots, knee bends and floor contacts readable.
	var light=DirectionalLight3D.new();game.world_root.add_child(light)
	light.rotation_degrees=Vector3(-35,30,0);light.light_energy=1.6
	for view in ["side","front"]:
		game.camera.position=base+(Vector3(4.7,1.1,0) if view=="side" else Vector3(0,1.1,4.7))
		game.camera.look_at(base+Vector3(0,.85,0))
		for mode in ["walk","run","burden-walk","burden-run"]:
			var drawn=mode.begins_with("burden")
			actor.set_sword_drawn(drawn);actor.state="free";actor.sprinting=mode.ends_with("run")
			actor.visual.rotation.y=0;actor.play_clip("drag_walk_loop" if drawn else "walk_loop",0)
			var sheet=Image.create(1536,864,false,Image.FORMAT_RGBA8)
			for index in range(9):
				actor.animator.seek(actor.animator.get_animation(actor.clips[actor.current_clip]).length*index/8.0,true)
				if drawn:actor._pose_sword("drag",0)
				hero.synchronize()
				await game.get_tree().create_timer(.06).timeout;await RenderingServer.frame_post_draw
				var frame=game.world_view.get_texture().get_image();frame.save_png(directory+"/gait-%s-%s-%03d.png"%[view,mode,index*12])
				frame.resize(512,288,Image.INTERPOLATE_LANCZOS);frame.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(frame,Rect2i(0,0,512,288),Vector2i((index%3)*512,(index/3)*288))
			sheet.save_png(directory+"/gait-%s-%s-sheet.png"%[view,mode])
	light.queue_free();actor.sprinting=false;hero.set_process(true)
