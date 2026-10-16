extends RefCounted
func run(test:RefCounted) -> void:
	var g=test.game;g.game_mode="alpha2";g.alpha2_import_path="user://dreadmore-no-import.json";g.start_new_game(false);g.alpha2.mark("begun")
	g.title_screen.visible=false;g.conversation.close();g.dialog.visible=false;g._refresh_simulation()
	g.load_map("a2_crossroads",Vector2(0,-26),true)
	var route=g.current_world.definition.exits.filter(func(e):return e.target=="a2_canyon")[0]
	test.check(g.dreadmore.request(route) and g.dreadmore.confirmation.dialog_text=="Enter Dreadmore Canyon?" and not g.player.input_enabled,"Canyon entry asks the requested question and pauses combat")
	g.dreadmore.confirmation.hide();g.dreadmore.confirmation.canceled.emit();g._refresh_simulation()
	test.check(g.map_id=="a2_crossroads" and g.player.input_enabled,"Declining entry leaves the character on the existing road")
	g.load_map("a2_canyon",Vector2(0,54),true);g.player.set_physics_process(false)
	for e in g.enemies:e.ai_enabled=false
	await test.frames(2)
	test.check(g.enemies.filter(func(e):return e.has_method("begin_tree_drop")).size()==12,"Canyon contains eight dropping slimes plus four ranged support slimes")
	var waiting=g.enemies.filter(func(e):return e.has_method("begin_tree_drop") and e.state=="tree_wait")
	test.check(waiting.size()==8 and waiting.all(func(e):return not e.visual.visible and not e.get_node("Shadow").visible),"All eight drop-slimes and shadows are invisible before their ambush")
	var support=g.enemies.filter(func(e):return e.has_method("begin_tree_drop") and e.canyon_support)
	test.check(support.size()==4 and support.filter(func(e):return e.style=="resin_slime").size()==2 and support.filter(func(e):return e.style=="moss_slime").size()==2,"Campfire approach has four melee drops and sticky/moss ranged pairs ahead and behind")
	test.check(support.all(func(e):return e.state=="canyon_wait" and not e.visual.visible),"Ranged reinforcements stay concealed until the melee pack triggers")
	g.player.position=Vector3(-18,0,-3)
	var pack=waiting.filter(func(e):return e.ambush_group=="dreadmore_sluice")
	pack[0].ai_enabled=true;pack[0]._drop_tick(.01)
	test.check(pack.size()==4 and pack.all(func(e):return e.state=="tree_warn") and support.all(func(e):return e.state=="idle" and e.visual.visible),"One real proximity trigger warns all four melee drops and reveals both ranged pairs together")
	var separated=true
	for i in range(pack.size()):
		for j in range(i):
			if pack[i].drop_target.distance_to(pack[j].drop_target)<1.8:separated=false
	test.check(separated,"Four melee slimes have separate landing spots instead of overlapping into one blob")
	for e in pack:e.ai_enabled=true;e._drop_tick(.66)
	test.check(pack.all(func(e):return e.state=="tree_fall" and e.visual.visible),"Drop-slimes become visible only as the falling attack begins")
	var shots=g.projectiles.size()
	for e in support:e.direction=(g.player.position-e.position).normalized();e._release_ability()
	test.check(g.projectiles.size()==shots+4,"Both moss shooters and sticky shooters release actual ranged projectiles")
	g.load_map("a2_canyon",Vector2(0,54),true);g.player.set_physics_process(false)
	for e in g.enemies:e.ai_enabled=false
	var cliffs=g.current_world.get_node("ContinuousCanyonCliffs")
	test.check(cliffs.mesh.get_surface_count()==1 and cliffs.material_override.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and cliffs.material_override.cull_mode==BaseMaterial3D.CULL_DISABLED,"Canyon uses one continuous opaque two-sided cliff surface without separate slab seams")
	test.check(cliffs.material_override.albedo_texture!=null and cliffs.material_override.normal_enabled and g.environment_settings.fog_density>=.06,"Stone albedo/normal textures remain while thick distance fog obscures corridor ends")
	var boss=g.enemies.filter(func(e):return e.definition.kind=="canyon_fiend")[0]
	test.check(boss.state=="perched" and boss.position.y>7 and boss.joints.size()>=10 and not boss.art.visible,"Orchid Stalker has four articulated arms and waits concealed on a high ledge")
	test.check(not g.alpha2.can_travel({"target":"a2_grove"}),"Living Fiend prevents entry into the attunement grove")
	var clear=true
	for line in g.dreadmore.spec.routes:
		for i in range(1,line.size()):
			var a=Vector3(line[i-1][0],0,line[i-1][1]);var b=Vector3(line[i][0],0,line[i][1])
			if a.z< -48 or b.z< -48:continue
			g.player.position=a
			for n in range(ceili(a.distance_to(b)/.3)):
				var step=(b-g.player.position).limit_length(.3);var collision=g.player.move_and_collide(step)
				if collision!=null:clear=false;break
	test.check(clear,"Actual player capsule traverses the canyon turns and optional branches without corner snags")
	g.player.position=Vector3(-18,1,-5);var before=g.player.position;g.player.move_and_collide(Vector3(8,0,0))
	test.check(g.player.position.distance_to(before)<7,"Raised bluff physically blocks a direct corner-cut at jump height")
	g.player.position=Vector3(18,0,-35);boss.ai_enabled=true;boss._physics_process(.01)
	test.check(boss.state=="drop_tell" and boss.tell.visible and boss.state_time>=1,"Approaching the arena starts a telegraphed wall-drop rather than instant damage")
	var clock=boss.state_time;boss.simulation_enabled=false;boss._physics_process(1)
	test.check(boss.state_time==clock,"Menus freeze the boss drop tell and body motion")
	boss.simulation_enabled=true;boss._physics_process(1.5);boss._physics_process(.8)
	test.check(boss.state=="recover" and boss.position.y<.01 and boss.sword_weakspot_open(),"Fiend lands on the marked ground and offers a real recovery opening")
	boss.position=Vector3(30.8,8,-36);boss.state="wall_tell";boss.face(boss.aim());boss.animate();boss.shoot()
	var thorn=g.projectiles[-1];var start=thorn.global_position;var life=thorn.life
	g.toggle_inventory();g._refresh_simulation();thorn._physics_process(.5)
	test.check(thorn.global_position==start and thorn.life==life and start.distance_to(boss.joints["Fore_R_0"].global_position)<.01,"Wall thorns originate at an actual claw and freeze with inventory")
	g.inventory.close();g._refresh_simulation();thorn.global_position=g.player.position+Vector3.UP*.9;thorn.repel(Vector3.ZERO,0,0)
	test.check(thorn.reflected and thorn.direction.y>0,"Parried wall thorns return upward toward the clinging Fiend in 3D")
	thorn.queue_free();boss.open_armor()
	test.check(boss.state=="drop" and boss.safe_drop,"Reflected thorns knock the wall-clinging Fiend down into a safe punish window")
	boss.position=Vector3(18,0,-35);boss.state="recover";var xp=g.progression.xp;boss.take_lance_damage(100000,Vector3.ZERO);g.dreadmore.tick()
	test.check("a2_canyon/orchid_stalker" in g.defeated_enemies and g.progression.xp==xp+1050,"Fiend defeat persists and grants its 350 XP plus 700 boss bonus once")
	test.check(g.monster_cores.pending.any(func(c):return c.id=="orchid_core") and g.dreadmore.gate==null,"Fiend guarantees its consumable core and removes the physical grove gate")
	g.load_map("a2_grove",Vector2(0,13),true);await test.frames(2)
	var stone=g.current_world.interactions.filter(func(t):return t.get("a2_action","")=="wood_ward")[0]
	xp=g.progression.xp;g.alpha2.interact(stone)
	test.check("wood_ward" in g.alpha2.flags and g.progression.xp==xp+250 and not g.enemies.size(),"Quiet grove contains the real woodland attunement objective and awards it once")
	test.check(not g.current_world.safe_position(Vector3(19,0,0)),"Grove tree-and-bush ring is an inaccessible boundary rather than pass-through decoration")
	var snapshot=g.save_data();test.check(g.apply_save(snapshot) and "wood_ward" in g.alpha2.flags and "a2_canyon/orchid_stalker" in g.defeated_enemies,"New maps and boss/attunement progress survive the existing save validation")
	g.load_map("a2_canyon",Vector2(0,54),true)
	test.check(g.enemies.filter(func(e):return e.definition.kind=="canyon_fiend")[0].health==0 and g.dreadmore.gate==null,"Re-entering a defeated Fiend arena retains its cleared passage")
	var legacy=g.save_data();legacy.alpha2.layout_revision=3;legacy.defeated_enemies.erase("a2_canyon/orchid_stalker")
	test.check(g.apply_save(legacy) and "wood_ward" in g.alpha2.flags and "wood_ward_legacy" in g.alpha2.flags,"Previously earned woodland attunement remains valid without retroactively requiring the new boss")
	test.check(g.alpha2.valid_save(g.alpha2.snapshot(),g.defeated_enemies),"Grandfathered woodland attunement can be saved again under the current layout")
	var wall_world=g.World.new();wall_world.definition=g.WorldPacks.definition("a2_grove").duplicate(true);wall_world.bounds=Rect2(-22,-22,44,44)
	wall_world.definition.props=[{"id":"test_bluff","kind":"catalog_feature","catalog_code":"1H","at":[0,0],"rotation":45,"scale":1.0}]
	test.check(not wall_world.safe_position(Vector3(0,0,0)),"Reusable builder bluff rejects a start/save inside its rotated solid footprint")
	wall_world.free()
	g.load_map("a2_canyon",Vector2(0,54),true)
	var slime=g.enemies.filter(func(e):return e.has_method("begin_tree_drop"))[0];var id="a2_canyon/"+slime.definition.id
	slime.take_damage(99999,Vector3.ZERO)
	test.check(id in g.defeated_enemies,"Canyon slain slime stays defeated during the current run")
	g.enemies.filter(func(e):return e.definition.kind=="canyon_fiend")[0].take_lance_damage(99999,Vector3.ZERO)
	g._player_defeated();g.respawn_player();g.load_map("a2_canyon",Vector2(0,54),true)
	test.check(id not in g.defeated_enemies and g.enemies.filter(func(e):return e.has_method("begin_tree_drop") and e.state=="tree_wait" and e.health>0).size()==8,"Actual death/respawn resets all canyon ambushes to concealed living drop-slimes")
	test.check("a2_canyon/orchid_stalker" in g.defeated_enemies and g.enemies.filter(func(e):return e.definition.kind=="canyon_fiend")[0].health==0,"Death reset never revives a defeated boss")
	g.player.set_physics_process(true)
