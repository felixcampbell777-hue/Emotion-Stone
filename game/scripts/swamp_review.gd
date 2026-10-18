extends RefCounted
const Fen=preload("res://scripts/swamp_shape.gd")
var checks=0
var failures:Array=[]
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error("SWAMP: "+message)
func picture(g:Node,directory:String,label:String,at:Vector2,target:Vector2) -> void:
	g.player.position=Vector3(at.x,g.current_world.ground_height(Vector3(at.x,0,at.y)),at.y)
	for i in range(25):g.current_world.update_details(g.player.position)
	g.worldrise.swamp.stream()
	for i in range(20):
		if not g.worldrise.swamp.queue.is_empty():g.worldrise.swamp.spawn(g.worldrise.swamp.queue.pop_front())
	for e in g.enemies:e.ai_enabled=false;e.set_physics_process(false)
	var toward=Vector3(target.x,0,target.y)-g.player.position;g.camera_driver.yaw=atan2(-toward.x,-toward.z);g.camera_driver.first_pitch=.15;g.camera_driver.update_first_person();g.toast.hide();g.toast_time=0
	for i in range(5):await g.get_tree().process_frame
	await g.get_tree().create_timer(.25).timeout;await RenderingServer.frame_post_draw
	g.get_viewport().get_texture().get_image().save_png(directory+"/swamp-"+label+".png")
func run(g:Node,directory:String="") -> bool:
	g.game_mode="world_rise";g.start_new_game(false);g.title_screen.hide();g._refresh_simulation();g.player.set_physics_process(false);g.set_process(false);g.set_physics_process(false);g.camera_driver.set_mode("first_person")
	var cp=g.worldrise.checkpoints;var original_xp=g.progression.xp
	check(not g.worldrise.swamp.travel_floor(2),"Floor Two is gated before Elder victory")
	g.worldrise.flags.append("elder_defeated");g.worldrise.guild.copper=305;g.progression.xp=3217;g.apply_skill_stats();g.player.restore_health(g.player.max_health)
	check(g.worldrise.swamp.travel_floor(2),"Platform travels into Floor Two")
	check(g.map_id=="wr_floor_02","Floor Two is the active map")
	check(g.progression.xp==3217 and g.worldrise.guild.copper==305,"Character and purse survive floor travel")
	check(Fen.spec.nodes.size()>=80 and Fen.spec.edges.size()>Fen.spec.nodes.size(),"Many small islands with loops")
	var visited={0:true};var changed=true
	while changed:
		changed=false
		for edge in Fen.spec.edges:
			if visited.has(int(edge.a)) and not visited.has(int(edge.b)):visited[int(edge.b)]=true;changed=true
			if visited.has(int(edge.b)) and not visited.has(int(edge.a)):visited[int(edge.a)]=true;changed=true
	check(visited.size()==Fen.spec.nodes.size(),"Every island is connected")
	var fast_edges=Fen.spec.edges.filter(func(edge):return edge.water_tier=="shoal");var fast_visited={int(Fen.spec.fast_islands[0]):true};changed=true
	while changed:
		changed=false
		for edge in fast_edges:
			if fast_visited.has(int(edge.a)) and not fast_visited.has(int(edge.b)):fast_visited[int(edge.b)]=true;changed=true
			if fast_visited.has(int(edge.b)) and not fast_visited.has(int(edge.a)):fast_visited[int(edge.a)]=true;changed=true
	check(Fen.spec.fast_islands.size()==76 and fast_visited.size()==76,"Fast shoals form one connected network reaching 75% of islands")
	var fast_edge=fast_edges[0];var fast_mid=Vector3(fast_edge.points[1][0],0,fast_edge.points[1][1]);fast_mid.y=Fen.height(fast_mid)
	check(Fen.depth(fast_mid)<.3 and Fen.movement_factor(fast_mid)>.8 and Fen.movement_factor(fast_mid)<1,"Fast shoals are ankle-deep and slightly slower than dry land")
	check(g.current_world.get_node("SwampArrival/ArrivalCrystals").get_child_count()==8,"Arrival has four crystal pedestals")
	check(g.current_world.grass_material.shader.code.contains("rise_metal.gdshaderinc"),"Arrival uses the identical shared Floor One silver material")
	check(g.current_world.deep_fog_material.get_shader_parameter("density")>=.19 and is_equal_approx(g.environment_settings.fog_density,.055),"Deep-water clouds are dense while general mist is unchanged")
	var max_depth=0.0
	for edge in Fen.spec.edges:
		for segment in range(edge.points.size()-1):
			var a=Vector2(edge.points[segment][0],edge.points[segment][1]);var b=Vector2(edge.points[segment+1][0],edge.points[segment+1][1])
			for i in range(21):
				var p=a.lerp(b,i/20.0);max_depth=maxf(max_depth,Fen.depth(Vector3(p.x,0,p.y)))
	check(max_depth<1.1,"All authored crossings remain safely wadeable")
	for enemy in g.enemies:enemy.collision_layer=0;enemy.ai_enabled=false
	await g.get_tree().physics_frame
	for edge_index in [0,23,68,100]:
		var route=Fen.spec.edges[edge_index].points;var first=route[0];g.player.position=Vector3(first[0],Fen.height(Vector3(first[0],0,first[1]))+.008,first[1]);var reached=true
		for index in range(1,route.size()):
			var target=Vector3(route[index][0],0,route[index][1]);var steps=0
			while ((target-g.player.position)*Vector3(1,0,1)).length()>.25 and steps<2400:
				g.player.velocity=((target-g.player.position)*Vector3(1,0,1)).normalized()*3.4;g.current_world.move_grounded(g.player,1.0/60);steps+=1
			if steps>=2400:reached=false
		check(reached,"Actual character traverses winding crossing %d"%edge_index)
	g.toggle_inventory();var paused_clock=g.worldrise.day_clock;g.worldrise.tick(1.0)
	check(g.worldrise.day_clock==paused_clock and not g.player.input_enabled,"Inventory pauses floor time and enemies")
	g.inventory.close();g._refresh_simulation()

	check(g.environment_settings.fog_density>=.05,"Mist obscures distant islands")
	var e=Fen.spec.edges.filter(func(edge):return edge.water_tier=="wade")[0];var mid=Vector2(e.points[1][0],e.points[1][1]);var p=Vector3(mid.x,Fen.height(Vector3(mid.x,0,mid.y)),mid.y)
	g.player.position=p;var start=g.player.position;g.player.velocity=Vector3(1,0,0)*3;g.current_world.move_grounded(g.player,.1)
	check(g.player.position.distance_to(start)<.25,"Shallow water significantly slows movement")
	g.worldrise.swamp.stream()
	for i in range(20):
		if not g.worldrise.swamp.queue.is_empty():g.worldrise.swamp.spawn(g.worldrise.swamp.queue.pop_front())
	check(not g.enemies.is_empty(),"Nearby slime encounters stream in")
	if not g.enemies.is_empty():
		var enemy=g.enemies[0];enemy.set_physics_process(false);enemy.take_damage(7,Vector3.ZERO)
		g.worldrise.swamp.snapshot();check(g.worldrise.swamp.states[enemy.definition.id].health==enemy.health,"Damaged slime health is recorded")
		check(enemy.max_health>=160 and enemy.specimen.damage>=16,"Floor Two slime stats suit later progression")
	g.player.position=Vector3(Fen.arrival().x,.85,Fen.arrival().y);g.player.state="free";g.recovering=false
	var data=g.save_data();check(g.Save.write(data,"user://swamp-review.json")==OK,"Private Floor Two save writes")
	check(not g.Save.read("user://swamp-review.json").is_empty(),"Floor Two save passes strict validation")
	check(g.worldrise.swamp.travel_floor(1),"Platform returns to Floor One")
	check(g.map_id=="wr_floor_01" and g.worldrise.guild.copper==305,"Floor One and shared character are retained")
	check(g.apply_save(g.Save.read("user://swamp-review.json")),"Loading restores Floor Two")
	check(g.map_id=="wr_floor_02","Load resumes on last saved floor")
	var legacy=data.duplicate(true);legacy.world_rise.erase("swamp");legacy.world_rise.erase("unlocked_checkpoints");legacy.map="wr_floor_01";legacy.position=[0,0];legacy.ground_y=0
	check(g.worldrise.valid(legacy.world_rise),"Legacy World Rise data defaults the new floor safely")
	check(g.apply_save(legacy) and cp.unlocked==["arrival"],"Legacy checkpoint discovery stays on Floor One")
	var unsafe=data.duplicate(true);unsafe.position=[225,0];unsafe.ground_y=-3.6
	check(g.apply_save(unsafe) and Vector2(g.player.position.x,g.player.position.z).distance_to(Fen.arrival())<1,"Unsafe swamp save falls back to its own checkpoint")
	check(not g.current_world.safe_position(Vector3(225,0,0)),"Deep swamp is rejected as a safe save position")
	check(g.enemy_xp_reward("green_slime")==18,"Floor Two XP uses its explicit final reward")
	var water_at=Vector3(mid.x,Fen.height(Vector3(mid.x,0,mid.y)),mid.y)
	g.monster_cores.defeated("green_slime",water_at,false,0,1)
	check(float(g.monster_cores.pending.back().at[1])>=.039,"Core loot remains visible above swamp water")
	var patch=load("res://scripts/menagery_hazard.gd").new();g.current_world.add_child(patch);patch.configure(g,water_at,true)
	check(patch.position.y>=.025,"Resin puddles float above the shallows");patch.queue_free()
	var save_path=OS.get_environment("USERPROFILE").replace("\\","/")+"/AppData/Roaming/Godot/app_userdata/Coastal Foundation/world-rise-save-v1.json"
	if FileAccess.file_exists(save_path):check(not g.Save.read(save_path).is_empty(),"Existing player save remains readable without modifying it")
	var specimen=Fen.spec.enemies[0];var spawn_at=Vector3(specimen.at[0],0,specimen.at[1]);g.player.position=spawn_at;g.worldrise.swamp.spawn(specimen)
	var killed=g.worldrise.swamp.live[specimen.id];killed.set_physics_process(false);var before_xp=g.progression.xp;var reward=g.enemy_xp_reward(specimen.style)
	killed.take_damage(10000,Vector3.ZERO);g._enemy_defeated("wr_floor_02/"+specimen.id,specimen.style,killed)
	check(g.progression.xp==before_xp+reward and "wr_floor_02/"+specimen.id in g.defeated_enemies,"Slime kill awards its final XP once")
	g.defeated_enemies.append("wr_floor_01/wr_boar_test")
	g.worldrise.swamp.respawn_reset()
	check("wr_floor_02/"+specimen.id not in g.defeated_enemies and "wr_floor_01/wr_boar_test" in g.defeated_enemies,"Swamp rest resets only its own enemies")
	g.defeated_enemies.erase("wr_floor_01/wr_boar_test")
	g.worldrise.day_clock=800;g.worldrise.swamp.stream();var night=g.worldrise.swamp.entry_for(Fen.spec.enemies[1],true);g.player.position=Vector3(night.at[0],0,night.at[1]);g.worldrise.swamp.spawn(night)
	check(g.worldrise.swamp.live.has(night.id),"Night adds a second slime to ordinary encounters")
	g.worldrise.day_clock=250;g.worldrise.swamp.stream();check(not g.worldrise.swamp.live.has(night.id),"Dawn retires only night companions")
	var pursuer=Fen.spec.enemies[2];g.player.position=Vector3(pursuer.at[0],0,pursuer.at[1]);g.worldrise.swamp.spawn(pursuer)
	g.player.position=Vector3(Fen.arrival().x,.85,Fen.arrival().y)
	for mob in g.enemies:
		if is_instance_valid(mob) and mob.health>0:
			var previous=mob.position;mob.position=g.player.position+Vector3(3,0,0);mob.state="windup"
			check(not g.worldrise.swamp.travel_floor(1),"Pursuing enemies block floor travel even at the platform")
			mob.position=previous;mob.state="idle";break
	var unknown=Fen.spec.sites[1];g.player.position=Vector3(unknown.at[0],.85,unknown.at[1]);cp.discover();check(unknown.id in cp.current_unlocked(),"Floor Two checkpoint unlocks by visiting")
	g.worldrise.swamp.checkpoint=unknown.at.duplicate()
	# Test actual drowning and death-screen respawn in this disposable session.
	var deep=Vector3(225,Fen.height(Vector3(225,0,0)),0);g.player.position=deep;g.player.state="free";g.player.input_enabled=true;load("res://scripts/wading.gd").tick(g)
	check(g.player.health==0 and g.recovering,"Deep water drowns the player")
	g.respawn_player();g._refresh_simulation();check(g.map_id=="wr_floor_02" and g.player.health>0,"Death respawns on Floor Two")
	check(g.player.position.distance_to(Vector3(unknown.at[0],.85,unknown.at[1]))<1,"Respawn uses the Floor Two checkpoint")
	if not directory.is_empty():
		g.set_resolution(0);g.render_budget.select_quality("balanced",false);g.worldrise.day_clock=250;g.worldrise.swamp.lighting()
		await picture(g,directory,"arrival",Fen.arrival(),Fen.arrival()+Vector2(-20,-35))
		var node=Fen.spec.nodes[60];var at=Vector2(node.at[0],node.at[1]);await picture(g,directory,"island-network",at,at+Vector2(-25,-25))
		await picture(g,directory,"water-boundary",mid,mid+Vector2(20,10))
		var fast_at=Vector2(fast_mid.x,fast_mid.z);await picture(g,directory,"fast-shoal",fast_at,fast_at+Vector2(20,10))
		await picture(g,directory,"deep-mist",at,at+Vector2(40,5))
		g.worldrise.day_clock=800;g.worldrise.swamp.lighting();await picture(g,directory,"night-mist",at,at+Vector2(-25,-25))
		g.worldrise.day_clock=250;g.worldrise.swamp.lighting();g.player.position=Vector3(Fen.arrival().x,.85,Fen.arrival().y);g.toggle_inventory();g.inventory.show_page("map")
		await g.get_tree().create_timer(.3).timeout;await RenderingServer.frame_post_draw;g.get_viewport().get_texture().get_image().save_png(directory+"/swamp-map-travel.png");g.inventory.close();g._refresh_simulation()
	print("SWAMP_CHECKS ",checks," passed=",failures.is_empty()," failures=",failures)
	return failures.is_empty()
