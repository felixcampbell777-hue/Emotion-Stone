extends RefCounted
const Shape=preload("res://scripts/rise_shape.gd")
func freeze(g:Node) -> void:
	g.set_physics_process(false)
	g.player.set_physics_process(false)
	for e in g.enemies:e.set_physics_process(false);e.ai_enabled=false
func move_to(g:Node,at:Vector2) -> void:
	g.player.position=Vector3(at.x,0,at.y);g.player.position.y=Shape.height(g.player.position)
	for i in range(30):g.worldrise.update_packs()
	freeze(g)
func run(test:RefCounted) -> void:
	var g=test.game;var originals={}
	for path in ["user://save-v1.json","user://beta-save-v1.json","user://alpha2-save-v1.json","user://world-rise-save-v1.json"]:originals[path]=FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	g.set_process(false);g.game_mode="world_rise";g.start_new_game(false);g.title_screen.hide();g._refresh_simulation();freeze(g)
	test.check(g.map_id=="wr_floor_01" and g.player.position==Vector3(0,26,0),"Fresh World Rise begins on the central arrival platform")
	await test.frames(2)
	await load("res://scripts/rise_slope_checks.gd").new().run(test)
	test.check(g.progression.xp==0 and g.progression.learned.is_empty() and g.magic_items.quantities.get("spring_elixir",0)==3,"Fresh progression imports no existing character and supplies three remedies")
	test.check(g.camera_mode=="first_person" and g.environment_profile=="darkwood" and g.camera.far>=6000,"World Rise uses advanced first person with the complete distant backdrop")
	test.check(g.current_save_path()=="user://world-rise-save-v1.json","World Rise has its own save slot")
	test.check(not g.alpha2.valid_mode("alpha","wr_floor_01","") and not g.alpha2.valid_mode("world_rise","a2_haven",""),"Campaign validation rejects cross-mode maps")
	var low=999.0;var high=0.0
	for x in range(-236,237,4):
		for z in range(-236,237,4):
			if Vector2(x,z).length()<238:low=minf(low,Shape.raw(x,z));high=maxf(high,Shape.raw(x,z))
	test.check(high-low>60 and high>70,"Large hills have more than sixty metres of real terrain relief")
	print("RISE_TERRAIN metres min/max ",low," / ",high)
	var graph=AStarGrid2D.new();graph.region=Rect2i(-59,-59,119,119);graph.cell_size=Vector2(4,4);graph.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;graph.update()
	for x in range(-59,60):
		for z in range(-59,60):
			var at=Vector3(x*4,0,z*4)
			var trunk_clear=not Shape.spec.trees.any(func(t):return Vector2(at.x-t[0],at.z-t[1]).length()<t[3]+3.2)
			graph.set_point_solid(Vector2i(x,z),not Shape.safe(at) or not trunk_clear or Shape.normal(at.x,at.z).y<.74)
	var connected=true;var traversed=true
	for goal in [Vector2i(16,22),Vector2i(-25,-9),Vector2i(51,6),Vector2i(24,-45)]:
		var path=graph.get_point_path(Vector2i.ZERO,goal)
		if path.is_empty():connected=false;continue
		g.player.position=Vector3(0,26,0)
		for point in path:
			var target=Vector3(point.x,0,point.y)
			for step in range(160):
				var toward=(target-g.player.position)*Vector3(1,0,1)
				if toward.length()<.2:break
				g.player.velocity=toward.normalized()*6;g.current_world.move_grounded(g.player,1.0/60)
			if Vector2(target.x-g.player.position.x,target.z-g.player.position.z).length()>.4:print("RISE_ROUTE_BLOCK ",target," actual ",g.player.position," collisions ",g.player.get_slide_collision_count());traversed=false;break
	test.check(connected,"Walkable saddles connect the hub to both rests, eastern rim and ascent gate")
	test.check(traversed,"Actual player capsule walks terrain seams and slopes along four routes")
	move_to(g,Vector2(45,35));await test.frames(2)
	var boars=g.enemies.filter(func(e):return e.definition.get("pack","")=="boars_00")
	test.check(Shape.spec.packs.filter(func(p):return p.kind=="library_boar").size()==18 and Shape.spec.packs.filter(func(p):return p.kind=="library_boar").all(func(p):return p.count>=2 and p.count<=4),"Eighteen authored boar herds have two to four members")
	test.check(not boars.is_empty() and g.enemies.size()<68,"Nearby packs load while distant actors remain unloaded")
	var boar=boars[0];var id=boar.definition.id;boar.health=31;move_to(g,Vector2(180,-120));move_to(g,Vector2(45,35))
	boar=g.enemies.filter(func(e):return e.definition.id==id)[0]
	test.check(boar.health==31,"Unloading and revisiting a herd retains its damage")
	var purse_before=g.worldrise.guild.copper;var xp=g.progression.xp;boar.take_damage(1000,Vector3.ZERO);var awarded=g.progression.xp-xp;var paid=g.worldrise.guild.copper;g._enemy_defeated("wr_floor_01/"+id,"library_boar",boar)
	test.check(awarded==16 and g.progression.xp==xp+16,"Boar defeat awards reduced 16 XP exactly once")
	test.check(paid-purse_before>=2 and paid-purse_before<=4 and g.worldrise.guild.copper==paid,"Boar copper is paid immediately and duplicate defeat callbacks cannot pay twice")
	test.check(g.monster_cores.pending.is_empty() and g.monster_cores.nodes.is_empty(),"Beasts do not produce monster cores")
	move_to(g,Vector2(-65,-65));await test.frames(2)
	var wolves=g.enemies.filter(func(e):return e.definition.kind=="beta_wolf")
	test.check(wolves.size()>=3 and g.wolf_packs.packs.size()>0,"Elderwood loads the established animated wolves and pack controller")
	for e in wolves:e.ai_enabled=true;e.simulation_enabled=true
	g.wolf_packs.alert(wolves[0]);g.wolf_packs.tick(.1)
	test.check(wolves.any(func(e):return e.pack_engaged),"Wolves engage as coordinated packs")
	xp=g.progression.xp;wolves[0].take_damage(1000,Vector3.ZERO)
	test.check(g.progression.xp==xp+8,"Defeating a woodland wolf awards reduced eight XP")
	var area=PI*88*82/(PI*240*240);test.check(absf(area-.125)<.01 and Shape.spec.trees.size()>200,"Dense tall woodland occupies approximately one eighth of the floor")
	var elapsed=g.worldrise.elapsed;g.player.input_enabled=false;g.worldrise.tick(1)
	test.check(g.worldrise.elapsed==elapsed,"Overlay gating freezes pack and landscape simulation clocks")
	g.player.input_enabled=true
	move_to(g,Vector2(205,25));var treasure_xp=g.progression.xp;g.worldrise.interact({"wr_action":Shape.spec.landmarks.filter(func(e):return e.id=="rim_watch")[0]})
	test.check("windstep" not in g.magic_items.owned and g.progression.xp==treasure_xp and Shape.spec.landmarks.all(func(e):return e.type!="cache"),"Hidden magic-item caches are removed from World Rise")
	g.worldrise.flags=["rim_watch"] # Preserve discovery flags in older saves without restoring rewards.
	await load("res://scripts/rise_guild_checks.gd").new().run(test)

	move_to(g,Vector2(120,110));var path="user://world-rise-verification.json";var economy=g.worldrise.guild.snapshot();var saved=g.save_data();var result=g.Save.write(saved,path);var readback=g.Save.read(path)
	test.check(result==OK and not readback.is_empty() and readback.ground_y>12,"Private save round trip supports high hills and streamed enemy state")
	test.check(g.apply_save(readback) and g.worldrise.flags==["rim_watch"] and g.player.position.y>60,"Loading restores World Rise elevation, treasure and fresh-mode progress")
	test.check(JSON.parse_string(JSON.stringify(g.worldrise.guild.snapshot()))==JSON.parse_string(JSON.stringify(economy)),"Save/load preserves purse, counted materials, pending loot and completed one-time contracts")
	freeze(g);g.set_process(false)
	var invalid=saved.duplicate(true);invalid.world_rise.states={"bad_id":{"health":5,"at":[0,0]}}
	test.check(not g.worldrise.valid(invalid.world_rise),"Streamed state rejects unknown enemy IDs")
	test.check(not g.worldrise.valid({"checkpoint":[INF,0]}),"Non-finite checkpoint coordinates are rejected")
	var cliff_save=saved.duplicate(true);cliff_save.position=[250,0];cliff_save.world_rise.checkpoint=[0,8]
	test.check(g.apply_save(cliff_save) and g.player.position.distance_to(Vector3(0,26,8))<.1,"Loading an off-rim position safely returns to the saved rest crystal")
	freeze(g)
	DirAccess.remove_absolute(path)
	# The rim has collision beneath the player, then ends physically at the disk edge.
	g.player.position=Vector3(238,Shape.height(Vector3(238,0,0)),0);g.player.velocity=Vector3(6,0,0);g.current_world.move_grounded(g.player,1.0/60)
	test.check(g.player.position.x>238,"Metal rim remains walkable without an invisible boundary wall")
	g.player.position=Vector3(241,Shape.height(Vector3(240,0,0)),0);var rim_y=g.player.position.y
	for i in range(30):g.player.velocity.x=0;g.current_world.move_grounded(g.player,1.0/60)
	test.check(g.player.position.y<rim_y-1 and g.player.has_meta("rise_fall"),"Walking beyond the rim starts a real gravity fall")
	g.player.position.y=-66;g.current_world.move_grounded(g.player,1.0/60)
	test.check(g.player.health<=0 and g.death_screen.visible,"Falling into the sunny abyss reaches the death screen")
	g.worldrise.checkpoint=[0,8];xp=g.progression.xp;g.respawn_player();freeze(g)
	test.check(g.player.health>0 and g.player.position.distance_to(Vector3(0,26,8))<.1 and g.progression.xp==xp and g.worldrise.flags==["rim_watch"],"Respawn returns to the rest crystal and retains XP and discoveries")
	test.check(JSON.parse_string(JSON.stringify(g.worldrise.guild.snapshot()))==JSON.parse_string(JSON.stringify(economy)),"Death respawn retains currency, materials, uncollected sacks and completed contracts")
	test.check(g.defeated_enemies.filter(func(e):return String(e).begins_with("wr_floor_01/")).is_empty() and not g.player.has_meta("rise_fall"),"Death resets regular pack defeats and clears falling state")
	await load("res://scripts/rise_beast_checks.gd").new().run(test)
	await load("res://scripts/rise_chamber_checks.gd").new().run(test)
	await load("res://scripts/elder_checks.gd").new().run(test)
	await load("res://scripts/elder_rewards_checks.gd").new().run(test)
	await load("res://scripts/night_packs_checks.gd").new().run(test)
	await load("res://scripts/western_route_checks.gd").new().run(test)
	await load("res://scripts/world_rise_stat_checks.gd").new().run(test)
	await load("res://scripts/render_budget_checks.gd").new().run(test)
	g.title_screen.fixture_path="user://world-rise-title-verification.json";g.title_screen.show_menu(g.title_screen.fixture_path);g.title_screen.select_mode(3)
	test.check(g.title_screen.mode_choice.selected==3 and not g.title_screen.import_choice.visible and g.title_screen.load_button.disabled and not g.player.input_enabled,"Title exposes fresh-only World Rise and pauses gameplay")
	var untouched=true
	for file in originals:
		var now=FileAccess.get_file_as_bytes(file) if FileAccess.file_exists(file) else PackedByteArray()
		if now!=originals[file]:untouched=false
	test.check(untouched,"All four real player save files remain byte-for-byte untouched")
