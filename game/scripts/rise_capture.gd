extends RefCounted
var performance:Dictionary={}
func profile(g:Node,key:String) -> void:
	for i in range(10):await g.get_tree().process_frame
	var times=[];var before=Time.get_ticks_usec()
	for i in range(90):
		await g.get_tree().process_frame;var now=Time.get_ticks_usec();times.append((now-before)/1000.0);before=now
	times.sort();performance[key]={"median_ms":times[45],"p95_ms":times[85],"worst_ms":times[-1],"actors":g.enemies.size(),"detail_chunks":g.current_world.loaded_chunks.size(),"scope":"stationary native rendering; AI disabled for repeatable capture"}
func picture(g:Node,path:String) -> void:
	await g.get_tree().create_timer(.3).timeout;await RenderingServer.frame_post_draw
	g.get_viewport().get_texture().get_image().save_png(path)
func view(g:Node,at:Vector2,yaw:float,pitch:float) -> void:
	g.player.position=Vector3(at.x,0,at.y);g.player.position.y=g.current_world.ground_height(g.player.position)
	for i in range(100):g.current_world.update_details(g.player.position);g.worldrise.update_packs()
	for e in g.enemies:e.ai_enabled=false;e.set_physics_process(false)
	g.camera_driver.yaw=yaw;g.camera_driver.first_pitch=pitch;g.camera_driver.update_first_person();g.toast_time=0;g.toast.hide()
func uphill(g:Node,directory:String) -> void:
	view(g,Vector2(92,80),-3*PI/4,-.65)
	var boar=g.enemies.filter(func(e):return e.definition.kind=="library_boar" and e.health>0)[0]
	boar.position=Vector3(96,0,84);boar.position.y=g.current_world.support_height(boar,boar.position);boar.state="idle";boar.ai_enabled=true;boar.simulation_enabled=true;boar.encounter_owned=true;boar.encounter_engaged=false;boar.encounter_goal=Vector3(112,0,100)
	var start_player=g.player.position;var start_boar=boar.position
	await picture(g,directory+"/world-rise-uphill-start.png")
	for frame in range(90):
		await g.get_tree().physics_frame
		g.player.velocity=Vector3(1,0,1).normalized()*2.4;g.current_world.move_grounded(g.player,1.0/60);boar._physics_process(1.0/60);g.camera_driver.update_first_person()
	boar.ai_enabled=false
	await picture(g,directory+"/world-rise-uphill-finish.png")
	performance.uphill={"player_travel":Vector2(g.player.position.x-start_player.x,g.player.position.z-start_player.z).length(),"player_rise":g.player.position.y-start_player.y,"boar_travel":Vector2(boar.position.x-start_boar.x,boar.position.z-start_boar.z).length(),"boar_rise":boar.position.y-start_boar.y,"scope":"90 actual physics frames; player walking speed and real boar AI"}
func guild_view(g:Node,at:Vector3,target:Vector3) -> void:
	var house=g.current_world.get_node("AdventurersGuild");var pos=house.to_global(at);view(g,Vector2(pos.x,pos.z),0,0)
	var toward=house.to_global(target)-(g.player.position+Vector3.UP*1.6);g.camera_driver.yaw=atan2(-toward.x,-toward.z);g.camera_driver.first_pitch=-atan2(toward.y,Vector2(toward.x,toward.z).length());g.camera_driver.update_first_person()
func guild_capture(g:Node,directory:String) -> void:
	guild_view(g,Vector3(0,0,-26),Vector3(0,3,-5));await picture(g,directory+"/world-rise-guild-exterior.png")
	guild_view(g,Vector3(22,0,-30),Vector3(0,4,0));await picture(g,directory+"/world-rise-guild-approach.png")
	guild_view(g,Vector3(0,0,-7.6),Vector3(0,1.7,1));await picture(g,directory+"/world-rise-guild-hall.png")
	guild_view(g,Vector3(2,0,1),Vector3(-6,1.6,5));await picture(g,directory+"/world-rise-guild-workshop.png")
	var guild=g.worldrise.guild;guild.copper=1000;guild.materials={"boar_hide":5,"wolf_hide":8,"wolf_fang":2,"boar_tusk":1}
	var clerk=g.current_world.interactions.filter(func(t):return t.get("role","")=="wr_clerk")[0]
	g.player.position=clerk.position+Vector3(0,0,-1).rotated(Vector3.UP,PI/4);g.conversation.show_character(clerk);g._refresh_simulation();guild.dialogue(g.conversation,clerk,"wolf");await picture(g,directory+"/world-rise-guild-sales.png")
	guild.contracts={"boar":{"active":true,"count":7,"completed":false}};guild.dialogue(g.conversation,clerk,"contracts");await picture(g,directory+"/world-rise-guild-contracts.png");g.conversation.close()
	var armorer=g.current_world.interactions.filter(func(t):return t.get("role","")=="wr_armorer")[0]
	g.player.position=armorer.position+Vector3(0,0,-1).rotated(Vector3.UP,PI/4);g.progression.xp=int(g.progression.definition.level_thresholds[9]);g.apply_skill_stats();g.conversation.show_character(armorer);g._refresh_simulation();await picture(g,directory+"/world-rise-guild-crafting.png")
	g.get_window().size=Vector2i(960,540);await picture(g,directory+"/world-rise-guild-crafting-small.png");g.get_window().size=Vector2i(1366,768)
	for id in ["boar_hide_armor","wolf_hide_armor","cruel_charm"]:assert(guild.craft(id))
	g.conversation.close();g._refresh_simulation();g.toggle_inventory();g.inventory.selected_category="apparel";g.inventory.selected_slot="necklace";g.inventory.selected_item={"kind":"apparel","id":"cruel_charm"};g.inventory.refresh();await picture(g,directory+"/world-rise-guild-equipment.png");g.inventory.close();g._refresh_simulation()
func western_capture(g:Node,directory:String) -> void:
	view(g,Vector2(-237,54.5),PI/2,.12);await picture(g,directory+"/world-rise-west-connection.png")
	view(g,Vector2(-282,45),PI/2,.05);await picture(g,directory+"/world-rise-west-islands.png")
	view(g,Vector2(-413,55),PI/2,-.04);await picture(g,directory+"/world-rise-west-grove.png")
	g.worldrise.day_clock=800;g.worldrise.cycle_lighting();g.worldrise.spawn_ashfang()
	var boss=g.enemies.filter(func(e):return e.definition.id=="ashfang")[0];boss.set_physics_process(false);boss.ai_enabled=true;boss.simulation_enabled=true;boss.engaged=true
	view(g,Vector2(-427,55),PI/2,.04);boss.ai_enabled=true;boss.state="windup";boss.state_time=1.0;boss._physics_process(.01)
	await picture(g,directory+"/world-rise-ashfang-windup.png")
	boss.state="gnash";boss.state_time=.6;boss._physics_process(.01);await picture(g,directory+"/world-rise-ashfang-gnash.png")
	boss.health=180;boss._physics_process(.01)
	for enemy in g.enemies:enemy.set_physics_process(false)
	await picture(g,directory+"/world-rise-ashfang-wolves.png")
	var record={"materials":[],"bones":[]}
	for mesh in boss.animal.find_children("*","MeshInstance3D",true,false):
		for i in range(mesh.mesh.get_surface_count()):record.materials.append(mesh.mesh.surface_get_material(i).resource_name)
	for rig in boss.animal.find_children("*","Skeleton3D",true,false):
		for i in range(rig.get_bone_count()):record.bones.append(rig.get_bone_name(i))
	var file=FileAccess.open(directory+"/world-rise-ashfang-art.json",FileAccess.WRITE);file.store_string(JSON.stringify(record,"\t"));file.close()
	g.worldrise.day_clock=300;g.worldrise.cycle_lighting()
func run(g:Node,directory:String) -> void:
	g.game_mode="world_rise";g.start_new_game(false);g.title_screen.hide();g._refresh_simulation();g.set_resolution(0);g.player.set_physics_process(false);g.set_process(false);g.set_physics_process(false);g.camera_driver.set_mode("first_person")
	view(g,Vector2(0,4),0,-.05);await profile(g,"arrival");await picture(g,directory+"/world-rise-arrival.png")
	view(g,Vector2(42,-58),PI/2,.25);await profile(g,"hilltop");await picture(g,directory+"/world-rise-ridges.png")
	view(g,Vector2(40,43),0,.08);await picture(g,directory+"/world-rise-boar-valley.png")
	await uphill(g,directory)
	view(g,Vector2(-60,-42),.5,-.08);await profile(g,"forest");await picture(g,directory+"/world-rise-elderwood.png")
	view(g,Vector2(-63,-57),0,.08);await picture(g,directory+"/world-rise-wolf-pack.png")
	view(g,Vector2(239.6,0),-PI/2,.6);await picture(g,directory+"/world-rise-rim.png")
	view(g,Vector2(90,-150),0,-.08);await picture(g,directory+"/world-rise-ascent.png")
	await western_capture(g,directory)
	await guild_capture(g,directory)
	g.title_screen.show_menu();g.title_screen.mode_choice.select(3);g.title_screen.select_mode(3);await picture(g,directory+"/world-rise-title.png");g.title_screen.hide()
	g.toggle_inventory();g.inventory.show_page("quests");await picture(g,directory+"/world-rise-journal.png")
	var file=FileAccess.open(directory+"/world-rise-performance.json",FileAccess.WRITE);file.store_string(JSON.stringify(performance,"\t"));file.close()
