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
	game.player.position.y=game.current_world.ground_height(game.player.position)
	for e in game.enemies: e.ai_enabled=false
	game.camera_driver.yaw=yaw;game.camera_driver.first_pitch=pitch;game.camera_driver.update_first_person()
func run(game:Control,directory:String) -> void:
	game.game_mode="alpha2";game.alpha2_import_path="user://alpha2-no-import-capture.json";game.start_new_game(false);game.alpha2.mark("begun");game.set_resolution(0);game.camera_driver.set_mode("first_person");game.player.set_sword_drawn(true);game.toast_time=0
	view(game,"a2_haven",Vector2(0,13),0,.02);await measure(game,"a2_haven");await picture(game,directory+"/alpha2-haven.png")
	for fixture in [["a2_crossroads",Vector2(1,12),0],["a2_mill",Vector2(7,16),.9],["a2_fen",Vector2(-5,12),0],["a2_quarry",Vector2(0,12),0],["a2_wood",Vector2(-8,9),0],["a2_watch",Vector2(0,5),0],["a2_sanctum",Vector2(0,4),0],["a2_belfry",Vector2(0,7),0]]:
		view(game,fixture[0],fixture[1],fixture[2]);await measure(game,fixture[0]);await picture(game,directory+"/alpha2-"+String(fixture[0]).trim_prefix("a2_")+".png");print("ALPHA2_CAPTURE ",fixture[0])
		if fixture[0]=="a2_belfry":
			var boss=game.enemies[0];boss.health=boss.max_health-1;boss.state="slam_tell";boss.state_time=.8;boss._physics_process(.01);boss.set_physics_process(false);game.camera_driver.first_pitch=.12;await picture(game,directory+"/alpha2-boss-warning.png")
			boss.tell.visible=false;boss.begin_ring();boss.update_ring(.7);await picture(game,directory+"/alpha2-boss-wave.png")
	view(game,"a2_mill",Vector2(-5,13),.85,.05);await picture(game,directory+"/alpha2-wreck-salvage.png")
	view(game,"a2_fen",Vector2(-6,2),PI/2,.12);await picture(game,directory+"/alpha2-fen-water.png")
	view(game,"a2_wood",Vector2(22,-5),PI/2,.1);await picture(game,directory+"/alpha2-nest-warning.png")
	game.player.position=Vector3(20,0,-5);game.player.position.y=game.current_world.ground_height(game.player.position);game.camera_driver.update_first_person();game.alpha2.encounters.tick(.01)
	await game.get_tree().create_timer(.9).timeout;await picture(game,directory+"/alpha2-nest-emergence.png")
	view(game,"a2_quarry",Vector2(23,15),.05);await picture(game,directory+"/alpha2-seaward-route.png")
	view(game,"a2_wood",Vector2(-23,-22),-.8);await picture(game,directory+"/alpha2-root-discovery.png")
	for fixture in [["a2_mill","library_crab"],["a2_mill","library_rat"],["a2_wood","library_boar"],["a2_wood","library_spider"],["a2_wood","library_wolf"],["a2_quarry","library_sentinel"],["a2_belfry","bellkeeper"]]:
		view(game,fixture[0],Vector2(0,10),0,.12)
		for e in game.enemies:
			if e.definition.kind!=fixture[1]:e.visible=false;continue
			game.player.position=e.position+Vector3(0,0,4.5 if fixture[1]=="bellkeeper" else 3.3);game.player.position.y=game.current_world.ground_height(game.player.position)
			e.visual.rotation.y=0;e.set_physics_process(false);e.art.pose("idle",.3);game.camera_driver.update_first_person()
			await picture(game,directory+"/alpha2-creature-"+fixture[1]+".png")
			e.art.pose("attack",.65);await picture(game,directory+"/alpha2-creature-"+fixture[1]+"-attack.png");break
	view(game,"a2_mill",Vector2(22.5,5),-PI/2,.15);await picture(game,directory+"/alpha2-wading.png")
	view(game,"a2_belfry",Vector2(0,5),0,.08)
	var guardian=game.enemies[0];guardian.ai_enabled=true;guardian.state="rock_tell";guardian.state_time=.25;guardian.direction=Vector3.BACK;guardian._physics_process(.001);guardian.set_physics_process(false);await picture(game,directory+"/alpha2-seed-windup.png")
	guardian.state="roots_tell";guardian.seed.visible=false;guardian.prepare_roots();game.player.position+=Vector3(3,0,3);game.player.position.y=game.current_world.ground_height(game.player.position);game.camera_driver.yaw=.6;game.camera_driver.update_first_person();await picture(game,directory+"/alpha2-root-warning.png");guardian.update_roots(.5);await picture(game,directory+"/alpha2-root-eruption.png")
	view(game,"a2_grove",Vector2(0,5),0,.08)
	game.conversation.show_character({"role":"a2_forest_chime","title":"The listening bells"});game._refresh_simulation();await picture(game,directory+"/alpha2-forest-puzzle.png");game.conversation.close();game._refresh_simulation()
	view(game,"a2_haven",Vector2(0,9),0)
	for target in game.current_world.interactions:
		if target.id=="mother": game.conversation.show_character(target);break
	game._refresh_simulation();await picture(game,directory+"/alpha2-conversation.png");game.conversation.close();game._refresh_simulation()
	game.toggle_inventory();game.inventory.show_page("quests");await picture(game,directory+"/alpha2-journal.png");game.inventory.close()
	game.toggle_inventory();game.inventory.show_page("level");game.skill_tree.branch="Mana";game.skill_tree.refresh();await picture(game,directory+"/alpha2-constellation-hidden.png")
	var growth=game.progression.snapshot();game.progression.restore({"tree_version":3,"xp":10000,"learned":["mana","mana_lance"],"passives":[]});game.skill_tree.refresh();await picture(game,directory+"/alpha2-constellation.png")
	game.get_window().size=Vector2i(960,540);await picture(game,directory+"/alpha2-constellation-small.png");game.get_window().size=Vector2i(1280,720);game.progression.restore(growth);game.inventory.close()
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
