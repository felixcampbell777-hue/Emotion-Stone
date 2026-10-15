extends RefCounted
var region_frames:Dictionary={}
func measure(game:Control,id:String) -> void:
	for i in range(20): await game.get_tree().process_frame
	var start=Time.get_ticks_usec()
	for i in range(45): await game.get_tree().process_frame
	var ms=(Time.get_ticks_usec()-start)/45000.0
	region_frames[id]={"frames":45,"mean_frame_ms":ms,"mean_fps":1000.0/ms}
func picture(game:Control,path:String) -> void:
	await game.get_tree().create_timer(.2).timeout;await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
func view(game:Control,id:String,at:Vector2,yaw:float,pitch:float=0) -> void:
	game.load_map(id,at,true);game.player.set_physics_process(false)
	for e in game.enemies: e.ai_enabled=false
	game.camera_driver.yaw=yaw;game.camera_driver.first_pitch=pitch;game.camera_driver.update_first_person()
func run(game:Control,directory:String) -> void:
	game.game_mode="alpha2";game.alpha2_import_path="user://alpha2-no-import-capture.json";game.start_new_game(false);game.alpha2.mark("begun");game.set_resolution(0);game.camera_driver.set_mode("first_person");game.player.set_sword_drawn(true);game.toast_time=0
	view(game,"a2_haven",Vector2(0,13),0,.02);await measure(game,"a2_haven");await picture(game,directory+"/alpha2-haven.png")
	for fixture in [["a2_crossroads",Vector2(0,12),0],["a2_mill",Vector2(0,10),0],["a2_fen",Vector2(0,14),0],["a2_quarry",Vector2(0,17),0],["a2_wood",Vector2(0,8),0],["a2_watch",Vector2(0,5),0],["a2_sanctum",Vector2(0,4),0],["a2_belfry",Vector2(0,9),0]]:
		view(game,fixture[0],fixture[1],fixture[2]);await measure(game,fixture[0]);await picture(game,directory+"/alpha2-"+String(fixture[0]).trim_prefix("a2_")+".png");print("ALPHA2_CAPTURE ",fixture[0])
		if fixture[0]=="a2_belfry":
			var boss=game.enemies[0];boss.health=boss.max_health-1;boss.state="slam_tell";boss.state_time=.8;boss._physics_process(.01);boss.set_physics_process(false);game.camera_driver.first_pitch=.12;await picture(game,directory+"/alpha2-boss-warning.png")
			boss.tell.visible=false;boss.begin_ring();boss.update_ring(.7);await picture(game,directory+"/alpha2-boss-wave.png")
	view(game,"a2_mill",Vector2(-8,-11),PI/2,.06);await picture(game,directory+"/alpha2-mill-wheel.png")
	view(game,"a2_fen",Vector2(-6,2),PI/2,.12);await picture(game,directory+"/alpha2-fen-water.png")
	view(game,"a2_haven",Vector2(0,9),0)
	for target in game.current_world.interactions:
		if target.id=="mother": game.conversation.show_character(target);break
	game._refresh_simulation();await picture(game,directory+"/alpha2-conversation.png");game.conversation.close();game._refresh_simulation()
	game.toggle_inventory();game.inventory.show_page("quests");await picture(game,directory+"/alpha2-journal.png");game.inventory.close()
	var samples=[]
	for i in range(30): await game.get_tree().process_frame
	for i in range(60):
		var before=Time.get_ticks_usec();await game.get_tree().process_frame;samples.append((Time.get_ticks_usec()-before)/1000.0)
	var frame_ms=0.0
	for value in samples: frame_ms+=value/samples.size()
	game.title_screen.show_menu();await picture(game,directory+"/alpha2-title.png")
	game.get_window().size=Vector2i(960,540);await picture(game,directory+"/alpha2-title-small.png")
	game.get_window().size=Vector2i(1280,720);await game.get_tree().process_frame
	var file=FileAccess.open(directory+"/alpha2-render-metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"camera":game.camera_mode,"art":game.environment_profile,"viewport":str(game.world_view.size),"regions":region_frames,"sample_frames":samples.size(),"steady_mean_fps":1000.0/frame_ms,"steady_mean_frame_ms":frame_ms,"target_minutes":game.alpha2.definition.target_minutes,"areas":9,"encounters":46},"\t"));file.close()

	print("ALPHA2_CAPTURE_COMPLETE");game.get_tree().quit()
