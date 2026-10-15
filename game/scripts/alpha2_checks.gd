extends RefCounted
func disable_enemies(game:Node) -> void:
	for e in game.enemies: e.ai_enabled=false
func interaction(game:Node,id:String) -> Dictionary:
	for target in game.current_world.interactions:
		if target.get("a2_action","")==id: return target
	return {}
func press(ui:Control,contains_text:String) -> bool:
	for button in ui.choices.get_children():
		if contains_text in button.text: button.pressed.emit();return true
	return false
func talk(game:Node,id:String) -> void:
	for target in game.current_world.interactions:
		if target.id==id: game.conversation.show_character(target);game._refresh_simulation();return
func slay(game:Node) -> void:
	for e in game.enemies:
		if e.health>0: e.take_lance_damage(100000,Vector3.FORWARD)
func use(game:Node,id:String) -> bool:
	var target=interaction(game,id)
	if target.is_empty(): return false
	game.player.position=target.position;return game.alpha2.interact(target)
func accessible_targets(g:Node) -> Array:
	# Flood the actual static physics world; this catches blocked cave turns, water and scenery.
	var bounds:Rect2=g.current_world.bounds
	var query=PhysicsShapeQueryParameters3D.new();var shape=SphereShape3D.new();shape.radius=.27;query.shape=shape;query.collision_mask=1
	var cells={};var start=Vector2i(roundi(g.player.position.x),roundi(g.player.position.z));var queue=[start];cells[start]=true
	var seen={start:true};var cursor=0
	while cursor<queue.size():
		var here:Vector2i=queue[cursor];cursor+=1
		for step in [Vector2i(0,1),Vector2i(0,-1),Vector2i(1,0),Vector2i(-1,0)]:
			var next=here+step
			if seen.has(next): continue
			seen[next]=true
			var at=Vector3(next.x,0,next.y)
			if not bounds.grow(-.5).has_point(Vector2(at.x,at.z)) or not g.current_world.safe_position(at): continue
			at.y=g.current_world.ground_height(at)+.7;query.transform=Transform3D(Basis.IDENTITY,at)
			if not g.player.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): continue
			cells[next]=true;queue.append(next)
	var blocked=[]
	for target in g.current_world.interactions:
		var point=Vector2(target.position.x,target.position.z);var found=false
		for x in range(floori(point.x)-2,ceili(point.x)+3):
			for z in range(floori(point.y)-2,ceili(point.y)+3):
				if cells.has(Vector2i(x,z)) and Vector2(x,z).distance_to(point)<1.65: found=true
		if not found: blocked.append(target.id)
	return blocked
func run(test:RefCounted) -> void:
	var g=test.game;var path="user://alpha2-verification.json";var import_path="user://alpha2-import-verification.json"
	var originals={}
	for real_path in ["user://save-v1.json","user://beta-save-v1.json","user://alpha2-save-v1.json"]:
		originals[real_path]=FileAccess.get_file_as_bytes(real_path) if FileAccess.file_exists(real_path) else PackedByteArray()
	# Use a private, real Alpha-format save for an actual import; no real saves are loaded by fixtures.
	g.game_mode="alpha";g.start_new_game(false);g.conversation.close();g.dialog.visible=false
	g.progression.restore({"tree_version":3,"xp":1400,"learned":["strength","form","mana","mana_lance"],"passives":[]})
	g.magic_items.owned=["windstep","bloodbloom","spring_elixir"];g.magic_items.quantities={"spring_elixir":2};g.magic_items.slots={"ring1":"bloodbloom","necklace":"windstep"}
	g.selected_special_attack="water_lance";g.apply_skill_stats();g.player.restore_health(g.player.max_health);g.load_map("village_green",Vector2(0,3.5),true)
	g.Save.write(g.save_data(),import_path);var original=FileAccess.get_file_as_bytes(import_path)
	test.check(not g.Save.read(import_path).is_empty(),"Import fixture is a validated legacy Alpha save")
	g.alpha2_import_path=import_path;g.alpha2_import_mode="alpha";g.game_mode="alpha2";g.start_new_game(false)
	await test.frames(3)
	test.check(g.map_id=="a2_haven" and g.camera_mode=="first_person" and g.environment_profile=="darkwood" and g.graphics_preset==0,"Alpha 2 starts in its village in native-resolution advanced first person")
	test.check(g.progression.xp==1400 and g.progression.has("mana_lance") and g.selected_special_attack=="water_lance","Import preserves XP, learned skills and selected spell")
	test.check(g.magic_items.slots.get("necklace")=="windstep" and g.magic_items.slots.get("ring1")=="bloodbloom" and g.magic_items.quantities.spring_elixir==5,"Import preserves equipped items and stacks campaign remedies")
	test.check(g.current_save_path()=="user://alpha2-save-v1.json" and g.defeated_enemies.is_empty() and g.alpha2.flags.is_empty(),"New campaign has separate save and story while retaining character")
	test.check(g.alpha2.valid_save(g.alpha2.snapshot(),g.defeated_enemies),"Direct campaign snapshots accept integer and JSON numeric checkpoints equally")
	test.check(g.alpha2.valid_save({},[]),"Legacy saves without an Alpha 2 section accept default checkpoint coordinates")
	test.check(FileAccess.get_file_as_bytes(import_path)==original,"Starting Alpha 2 never modifies its import save")
	test.check(not g.alpha2.can_travel({"target":"a2_crossroads"}) and not g.alpha2.can_travel({"target":"a2_belfry"}),"Opening conversation and all three wards gate intended routes")
	talk(g,"mother");test.check(g.conversation.visible and not g.player.input_enabled,"Authored Mother conversation pauses gameplay")
	test.check(press(g.conversation,"What do I need"),"Mother offers the opening expedition")
	test.check("begun" in g.alpha2.flags and g.alpha2.can_travel({"target":"a2_crossroads"}),"Accepting expedition opens all three pilgrim roads")
	g.conversation.close();g._refresh_simulation()
	# Every map, spawn and travel destination is inspected in the real world implementation.
	for id in g.alpha2.definition.maps:
		g.load_map(id,Vector2(INF,INF),true);disable_enemies(g);await test.frames(2)
		test.check(g.current_world.safe_position(g.player.position),id+": map spawn is walkable")
		if id in ["a2_mill","a2_wood","a2_quarry","a2_belfry"]:
			test.check(g.enemies.all(func(e):return e.has_meta("library_creature") and e.art.animator!=null and e.art.clips.has("attack") and e.art.surfaces.any(func(m):return m[0].albedo_texture!=null)),id+": creatures retain imported rigs, attack clips and real texture maps")
		if id in ["a2_mill","a2_wood","a2_quarry","a2_belfry"]:
			var fitted=true
			for e in g.enemies:
				for clip in ["idle","attack"]:
					for phase in [0.0,.5,1.0]:
						e.art.pose(clip,phase)
						for rig in e.art.find_children("*","Skeleton3D",true,false):
							for bone in range(rig.get_bone_count()):
								if (rig.global_transform*rig.get_bone_global_pose(bone).origin).distance_to(e.position)>float(e.definition.combat_height)*9:fitted=false
			test.check(fitted,id+": sampled imported poses retain finite body-sized skeletons")
			var moving=true
			for e in g.enemies:
				e.art.pose("attack",.2)
				var rigs=e.art.find_children("*","Skeleton3D",true,false);var before=[]
				for rig in rigs:
					for bone in range(rig.get_bone_count()):before.append(rig.get_bone_pose(bone))
				e.art.pose("attack",.7);var index=0;var motion=0.0
				for rig in rigs:
					for bone in range(rig.get_bone_count()):
						var after=rig.get_bone_pose(bone);motion+=after.origin.distance_to(before[index].origin)+after.basis.get_rotation_quaternion().angle_to(before[index].basis.get_rotation_quaternion());index+=1
				if motion<.02:moving=false
			test.check(moving,id+": imported attacks actually change bone poses rather than freezing in idle")
		var blocked=accessible_targets(g)
		test.check(blocked.is_empty(),id+": collision-aware navigation reaches every interaction: "+str(blocked))
		for exit in g.current_world.definition.exits:
			var world=g.World.new();world.definition=g.WorldPacks.definition(exit.target);var b=world.definition.bounds;world.bounds=Rect2(b[0],b[1],b[2]-b[0],b[3]-b[1])
			test.check(world.safe_position(Vector3(exit.spawn[0],0,exit.spawn[1])),id+" → "+exit.target+": arrival position is clear");world.free()
		var before=g.alpha2.played_seconds;g.toggle_inventory();g._refresh_simulation();await test.frames(3)
		test.check(is_equal_approx(before,g.alpha2.played_seconds) and g.enemies.all(func(e): return not e.simulation_enabled),id+": menu freezes campaign and enemies")
		g.inventory.close();g._refresh_simulation()
	g.load_map("a2_mill",Vector2(17,17),true);disable_enemies(g)
	var xp=g.progression.xp;use(g,"mill_ward");test.check("mill_ward" not in g.alpha2.flags and g.progression.xp==xp,"Ward cannot be claimed while its protectors live")
	slay(g);use(g,"tide_chime");test.check("tide_chime" not in g.alpha2.flags,"Chime stays trapped until salvage winch is worked")
	use(g,"wreck_winch");use(g,"tide_chime");use(g,"mill_ward");test.check("mill_ward" in g.alpha2.flags,"Shore ward unlocks through actual salvage and recovered chime")
	use(g,"medicine");var loot_xp=g.progression.xp;use(g,"mill_cache");var after=g.progression.xp
	test.check("lanternglass" in g.magic_items.owned and after==loot_xp+75 and not use(g,"mill_cache"),"Hidden reliquary grants a real magic item and discovery XP once")
	use(g,"mill_fire");g.player.take_damage(99999,Vector3.ZERO);g.respawn_player();await test.frames(2)
	test.check(g.map_id=="a2_mill" and g.player.position.distance_to(Vector3(17,0,17))<.1 and g.player.health==g.player.max_health,"Death returns to selected pilgrim fire with full health")
	test.check("mill_ward" in g.alpha2.flags and "medicine" in g.alpha2.flags,"Quest discoveries survive death")
	g.load_map("a2_haven",Vector2(0,5),true);talk(g,"mara");press(g.conversation,"I'll help");g.conversation.menu();xp=g.progression.xp;press(g.conversation,"Complete:");var reward=g.progression.xp;g.conversation.menu();press(g.conversation,"Complete:")
	test.check(reward==xp+240 and g.progression.xp==reward and "medicine_returned" in g.alpha2.flags,"Mara quest supports early discovery and awards its reward exactly once")
	g.conversation.close();g._refresh_simulation()
	# Complete the other exploration branches through real interactions and authored NPC choices.
	g.load_map("a2_fen",Vector2(0,20),true);disable_enemies(g);slay(g);talk(g,"jun");press(g.conversation,"The road is clear");g.conversation.close();g._refresh_simulation()
	test.check("courier_safe" in g.alpha2.flags,"Courier rescue checks threats and records the survivor")
	g.load_map("a2_watch",Vector2(0,5),true);disable_enemies(g);slay(g);use(g,"ledger")
	g.load_map("a2_quarry",Vector2(0,20),true);disable_enemies(g);slay(g);use(g,"quarry_ward")
	g.load_map("a2_wood",Vector2(0,24),true);disable_enemies(g);slay(g);use(g,"wood_ward")
	test.check(g.conversation.visible and not g.player.input_enabled,"Forest bell puzzle pauses gameplay over the blurred scene")
	test.check(not g.alpha2.ring_note("HIGH") and g.alpha2.bell_notes.is_empty(),"Wrong forest note resets harmony without rewarding the ward")
	for note in ["LOW","HIGH","MIDDLE"]:g.alpha2.ring_note(note)
	test.check("forest_tuned" in g.alpha2.flags,"Distinct forest exploration puzzle resolves its carved clue")
	g.conversation.close();g._refresh_simulation();use(g,"root_memory");g.dialog.visible=false;g._refresh_simulation()
	test.check(g.alpha2.wards()==3 and g.alpha2.can_travel({"target":"a2_belfry"}),"Independent regions reconnect and all three attuned wards open final vault")
	g.load_map("a2_haven",Vector2(0,5),true)
	for pair in [["ada","courier_returned"],["ada","ledger_returned"],["oren","memory_returned"]]:
		talk(g,pair[0]);press(g.conversation,"I'll help");g.conversation.menu();press(g.conversation,"Complete:");g.conversation.close();g._refresh_simulation()
		test.check(pair[1] in g.alpha2.flags,"Companion quest completed: "+pair[1])
	# New boss, weakspot, reflected projectile, warning ring and pause use live implementations.
	g.load_map("a2_belfry",Vector2(0,13),true);var boss=g.enemies[0];boss.ai_enabled=false;await test.frames(2)
	var hp=boss.health;boss.take_damage(100,Vector3.FORWARD);var guarded=hp-boss.health;boss.open_armor();hp=boss.health;boss.take_damage(100,Vector3.FORWARD)
	test.check(guarded==22 and hp-boss.health==100 and boss.sword_weakspot_open(),"Bellkeeper armor softens blows; reflected-stone opening permits full sword damage")
	boss.armor_open=0;var rock=load("res://scripts/rock_projectile.gd").new();g.world_root.add_child(rock);rock.configure(g,boss,Vector3.BACK);g.projectiles.append(rock)
	g.player.position=boss.position+Vector3(0,0,2);g.player.visual.rotation.y=PI;g.player.set_sword_drawn(true);g.player.state="parry";g.player.state_time=.3;g.camera_driver.yaw=0;rock.position=g.player.position+Vector3(0,.7,-.8)
	test.check(g.player.try_parry(rock) and rock.reflected,"Timed player parry reflects the Bellkeeper's actual rock")
	rock.position=boss.position+Vector3(0,.7,.1);rock._physics_process(.001)
	test.check(boss.armor_open>0,"Returned Bellkeeper rock opens the new boss weakspot")
	g.player.state="free";g.player.state_time=0;g.player.invulnerability=0;g.player.position=boss.position+Vector3(0,0,3)
	boss.begin_ring();hp=g.player.health;boss.update_ring(.45)
	test.check(g.player.health<hp,"Visible shockwave damages a grounded player")
	g.player.invulnerability=0;g.player.position.y=boss.position.y+1.2;boss.begin_ring();hp=g.player.health;boss.update_ring(.45)
	test.check(g.player.health==hp,"Jump clears low Bellkeeper shockwave; no roll invulnerability added")
	g.player.position=Vector3(0,0,14);boss.state="slam_tell";boss.state_time=.01;boss.health=int(boss.max_health*.4);boss.ai_enabled=true;boss.set_physics_process(false);boss._physics_process(.02);boss.ai_enabled=false
	test.check(boss.ring_second and boss.ring_radius>=0,"Below half health Bellkeeper adds a delayed second ring")
	g.toggle_inventory();g._refresh_simulation();var radius=boss.ring_radius;var timer=boss.state_time;boss._physics_process(.5)
	test.check(is_equal_approx(boss.ring_radius,radius) and is_equal_approx(boss.state_time,timer),"Pausing freezes new boss tell, ring and attack clocks")
	g.inventory.close();g._refresh_simulation();boss.take_lance_damage(100000,Vector3.ZERO)
	test.check("a2_belfry/bellkeeper" in g.defeated_enemies and not interaction(g,"bellheart").is_empty(),"Boss defeat creates a real heart interaction")
	test.check(g.monster_cores.pending.any(func(drop): return drop.id=="bellkeeper_core"),"New boss guarantees its consumable core")
	use(g,"bellheart");g.load_map("a2_haven",Vector2(0,5),true);talk(g,"mother");xp=g.progression.xp
	test.check(press(g.conversation,"Reveal the lost roads"),"Final conversation offers the exploration ending")
	test.check(g.alpha2.ending=="release" and g.progression.xp==xp+650,"Ending delivers its story, keepsake and final XP reward")
	g.alpha2.finish("renew");test.check(g.alpha2.ending=="release" and g.progression.xp==xp+650,"Ending cannot be changed or farmed for duplicate rewards")
	g.conversation.close();g._refresh_simulation();g.player.position=Vector3(0,0,5);g.player.state="free";g.player.restore_health(g.player.max_health)
	test.check(g.Save.write(g.save_data(),path)==OK and not g.Save.read(path).is_empty(),"Completed campaign serializes into a private validated save")
	var data=g.Save.read(path)
	var legacy=data.duplicate(true);legacy.alpha2.erase("layout_revision");legacy.alpha2.flags.erase("forest_tuned");legacy.alpha2.flags.erase("tide_chime");legacy.alpha2.flags.erase("wreck_winch");legacy.map="a2_mill";legacy.position=[25,10]
	test.check(g.apply_save(legacy) and g.current_world.safe_position(g.player.position) and g.alpha2.wards()==3 and "tide_chime" in g.alpha2.flags,"Old campaign migrates earned wards and relocates obsolete positions safely")
	g.alpha2.reset();test.check(g.apply_save(data) and g.alpha2.ending=="release" and "medicine_returned" in g.alpha2.flags,"Private save round trip restores ending, optional quests, equipment and checkpoint")
	var bad=data.duplicate(true);bad.alpha2.flags.append("unknown_reward");test.check(not g.apply_save(bad),"Corrupt campaign flags are rejected")
	bad=data.duplicate(true);bad.game_mode="alpha";test.check(not g.apply_save(bad),"Alpha 2 map cannot load as original Alpha")
	bad=data.duplicate(true);bad.alpha2.checkpoint_at=[99,99];test.check(not g.apply_save(bad),"Only authored checkpoint destinations can be restored")
	g.game_mode="alpha";g.start_new_game(false);g.dialog.visible=false;g.load_map("village_green",Vector2(0,3.5),true);g.player.restore_health(g.player.max_health);g.Save.write(g.save_data(),path)
	test.check(not g.Save.read(path).is_empty() and g.apply_save(g.Save.read(path)),"Legacy Alpha still starts, saves and loads")
	g.game_mode="beta";g.start_new_game(false);g.player.restore_health(g.player.max_health);g.Save.write(g.save_data(),path)
	test.check(g.map_id=="beta_meadow" and not g.Save.read(path).is_empty() and g.apply_save(g.Save.read(path)),"Beta still starts, saves and loads independently")
	g.alpha2_import_path=path;g.alpha2_import_mode="beta";g.game_mode="alpha2";g.start_new_game(false)
	test.check(g.map_id=="a2_haven" and g.progression.xp==0,"Beta save can also import into a fresh Alpha 2 story")
	g.title_screen.show_menu("user://alpha2-title-verification.json")
	test.check(g.title_screen.mode_choice.selected==2 and g.title_screen.import_choice.visible and g.title_screen.import_choice.selected==1,"Title exposes Alpha 2 and the chosen character import source")
	var body_at=g.player.position
	# Container sorting happens on idle frames, not physics ticks (several may share one frame).
	for i in range(4): await g.get_tree().process_frame
	test.check(not g.player.input_enabled and g.player.position.distance_to(body_at)<.01,"Alpha 2 title freezes gameplay while choosing a campaign")
	test.check(g.title_screen.box.position.y+g.title_screen.box.size.y<=g.get_viewport_rect().size.y,"Alpha 2 title content fits 1280×720")
	g.get_window().size=Vector2i(960,540)
	for i in range(4): await g.get_tree().process_frame
	test.check(g.title_screen.box.position.y+g.title_screen.box.size.y<=g.get_viewport_rect().size.y,"Import selector and title actions fit minimum 960×540 window")
	g.get_window().size=Vector2i(1280,720);await test.frames(2)
	g.title_screen.visible=false;g._refresh_simulation()
	g.game_mode="alpha"
	await load("res://scripts/title_checks.gd").new().run(test)
	await load("res://scripts/alpha2_region_checks.gd").new().run(test)
	for real_path in originals:
		test.check((FileAccess.get_file_as_bytes(real_path) if FileAccess.file_exists(real_path) else PackedByteArray())==originals[real_path],"Player save remains untouched: "+real_path)
	DirAccess.remove_absolute(path);DirAccess.remove_absolute(import_path);g.alpha2_import_path=""
