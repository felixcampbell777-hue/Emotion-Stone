extends RefCounted
var results:Dictionary={}
func sample(g:Control,key:String,directory:String) -> void:
	for i in range(60):await g.get_tree().process_frame
	var gpu=0.0;var calls=0.0;var primitives=0.0;var start=Time.get_ticks_usec()
	for i in range(120):
		await g.get_tree().process_frame
		gpu+=RenderingServer.viewport_get_measured_render_time_gpu(g.world_view.get_viewport_rid())
		calls+=g.world_view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		primitives+=g.world_view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	results[key]={"fps":120000000.0/(Time.get_ticks_usec()-start),"gpu_ms":gpu/120,"draw_calls":calls/120,"primitives":primitives/120,"detail_chunks":g.current_world.loaded_chunks.size(),"resolution":str(g.world_view.size),"scope":"same stationary forest view; AI frozen; GPU timer excludes frame-cap waiting"}
	await RenderingServer.frame_post_draw
	g.get_viewport().get_texture().get_image().save_png(directory+"/render-budget-"+key+".png")
func run(g:Control,directory:String) -> void:
	g.game_mode="world_rise";g.start_new_game(false);g.title_screen.hide();g._refresh_simulation();g.set_resolution(0)
	g.set_process(false);g.set_physics_process(false);g.player.set_physics_process(false);g.camera_driver.set_mode("first_person")
	var b=g.render_budget;b.set_process(false);b.focused=true;b.select_quality("high",false)
	var view=load("res://scripts/rise_capture.gd").new();view.view(g,Vector2(-60,-42),.5,-.08)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(g.world_view.get_viewport_rid(),true)
	# Recreate the previous render settings in this fixture only.
	var legacy=b.profile().duplicate();legacy.load=110;legacy.unload=145;g.current_world.configure_render(legacy)
	for i in range(100):g.current_world.update_details(g.player.position)
	for mesh in g.get_tree().get_nodes_in_group("budget_scenery"):
		mesh.lod_bias=1;mesh.visibility_range_end=0 if mesh.get_meta("budget_kind","")=="skyline" else 65 if mesh.get_meta("budget_kind","")=="grass" else 110
		mesh.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		mesh.cast_shadow=mesh.get_meta("budget_shadow",mesh.cast_shadow)
	g.world_view.msaa_3d=Viewport.MSAA_8X;g.world_view.mesh_lod_threshold=1;g.environment_settings.ssao_enabled=true;g.world_root.get_node("WorldSun").directional_shadow_max_distance=90;Engine.max_fps=0
	await sample(g,"previous",directory)
	for quality in ["balanced","low"]:
		b.select_quality(quality,false);b.select_fps(60,false)
		for i in range(100):g.current_world.update_details(g.player.position)
		b.update_scenery();await sample(g,quality,directory)
	b.select_quality("balanced",false);b.select_fps(60,false);b.set_process(true)
	RenderingServer.viewport_set_measure_render_time(g.world_view.get_viewport_rid(),false);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	var file=FileAccess.open(directory+"/render-budget-metrics.json",FileAccess.WRITE);file.store_string(JSON.stringify(results,"\t"));file.close()
