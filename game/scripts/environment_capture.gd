extends RefCounted

func picture(game:Control,path:String) -> void:
	await game.get_tree().create_timer(.7).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)

func run(game:Control,directory:String) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1366,768))
	await game.get_tree().process_frame
	game.start_new_game(false)
	game.set_resolution(0)
	RenderingServer.viewport_set_measure_render_time(game.world_view.get_viewport_rid(),true)
	game.environment_profile="darkwood"
	game.camera_driver.set_mode("follow")
	var renderer=RenderingServer.get_current_rendering_method()
	directory+="/environment-"+renderer
	DirAccess.make_dir_recursive_absolute(directory)
	var metrics:Array=[]
	for view in [
		{"map":"coastal_path","at":Vector2(0,3),"yaw":0.0,"name":"coast"},
		{"map":"village_green","at":Vector2(0,4),"yaw":0.0,"name":"village"},
		{"map":"slime_forest","at":Vector2(0,2),"yaw":PI,"name":"slime"},
		{"map":"herb_glade","at":Vector2(0,-12.5),"yaw":PI,"name":"warden-road"},
		{"map":"herb_glade","at":Vector2(0,7),"yaw":PI,"name":"warden"},
		{"map":"jungle_approach","at":Vector2(8,0),"yaw":PI/2,"name":"jungle"},
		{"map":"queen_arena","at":Vector2(0,4),"yaw":PI,"name":"queen"},
		{"map":"lark_farm","at":Vector2(0,4),"yaw":0.0,"name":"farm"},
		{"map":"goblin_approach","at":Vector2(0,8),"yaw":0.0,"name":"palisade"},
		{"map":"goblin_cave","at":Vector2(0,6),"yaw":0.0,"name":"cave"},
		{"map":"goblin_depths","at":Vector2(0,6),"yaw":0.0,"name":"vault"},
		{"map":"home_downstairs","at":Vector2(0,2.4),"yaw":0.0,"name":"hearth"},
		{"map":"home_upstairs","at":Vector2(0,1),"yaw":0.0,"name":"bedroom"},
		{"map":"menagery","at":Vector2(-12,8),"yaw":PI,"name":"menagerie"},
		{"map":"menagery_cave","at":Vector2(0,6),"yaw":PI,"name":"cave-demo"}
	]:
		game.load_map(view.map,view.at,true)
		for enemy in game.enemies: enemy.ai_enabled=false
		game.camera_driver.yaw=view.yaw
		game.camera_driver.actual_distance=5.5; game.camera_driver.distance=5.5; game.camera_driver.pitch=.36
		await picture(game,directory+"/"+view.name+".png")
		if view.name in ["warden-road","coast","queen"]:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			var times:Array=[]; var gpu_times:Array=[]; var cpu_times:Array=[]; var last=Time.get_ticks_usec()
			for i in range(150):
				await game.get_tree().process_frame
				var now=Time.get_ticks_usec(); if i>=30: times.append((now-last)/1000.0)
				last=now
				if i>=30:
					gpu_times.append(RenderingServer.viewport_get_measured_render_time_gpu(game.world_view.get_viewport_rid()))
					cpu_times.append(RenderingServer.viewport_get_measured_render_time_cpu(game.world_view.get_viewport_rid()))
			times.sort(); var total=0.0
			for time in times: total+=time
			metrics.append({"area":view.map,"renderer":renderer,"frame_ms_average":total/times.size(),"frame_ms_p95":times[int(times.size()*.95)],"draw_calls":game.world_view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"resolution":[game.world_view.size.x,game.world_view.size.y],"gpu":RenderingServer.get_video_adapter_name()})
			gpu_times.sort(); cpu_times.sort()
			metrics[-1]["gpu_ms_p95"]=gpu_times[int(gpu_times.size()*.95)]; metrics[-1]["render_cpu_ms_p95"]=cpu_times[int(cpu_times.size()*.95)]
			metrics[-1]["window_focused"]=DisplayServer.window_is_focused(); metrics[-1]["sampling"]="120 warm frames, vsync disabled; background driver limits may cap wall-clock FPS"
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	var report=FileAccess.open(directory+"/performance.json",FileAccess.WRITE); report.store_string(JSON.stringify(metrics,"\t")); report.close()
	game.pause_menu.open()
	await picture(game,directory+"/graphics-menu.png")
	game.pause_menu.close()
	game.environment_profile="original"
	game.load_map("herb_glade",Vector2(0,-12.5),true)
	await picture(game,directory+"/original-preserved.png")
	print("CAPTURE_OK "+directory)
