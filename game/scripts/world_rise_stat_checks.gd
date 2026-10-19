extends RefCounted
const Stats=preload("res://scripts/world_rise_stats.gd")
func run(test:Object) -> void:
	load("res://scripts/world_rise_progression_checks.gd").new().run(test)
	var g=test.game;g.game_mode="world_rise";g.start_new_game(false);g.title_screen.hide();g.set_process(false);g.set_physics_process(false);g.player.set_physics_process(false);g._refresh_simulation()
	var s=g.progression;var a=g.player;var base=g.read_data("res://content/combat.json")
	test.check(s.world_rise and not s.has("mana") and not a.water_unlocked and not a.lance_unlocked and not a.dragon_unlocked,"World Rise tree5 keeps Mana actions disabled")
	s.xp=int(s.definition.level_thresholds[9]);g.apply_skill_stats()
	test.check(a.max_health==109 and is_equal_approx(a.max_stamina,109),"Unallocated level ten retains nine one-percent health/stamina increases")
	s.xp=int(s.definition.level_thresholds[49])
	for i in range(12):s.increase_attribute("body")
	for id in ["iron_body","iron_body","iron_body","honed_arms","stonewall"]:test.check(s.learn(id),"Bounded Body perk can be purchased: "+id)
	a.health=53;a.stamina=47;g.apply_skill_stats();var hp=a.max_health;var damage=a.combat.light.damage;var cost=a.combat.light.stamina_cost
	test.check(is_equal_approx(g.magic_items.incoming_damage(100),90) and damage==base.light.damage and is_equal_approx(cost,base.light.stamina_cost*.95),"Body defense is ten percent, Honed Arms saves five percent, and Body does not silently increase weapon damage")
	g.apply_skill_stats();test.check(a.max_health==hp and a.combat.light.damage==damage and is_equal_approx(a.combat.light.stamina_cost,cost) and a.health==53 and is_equal_approx(a.stamina,47),"Refreshing tree5 stats neither stacks numeric bonuses nor heals/refills")
	a.set_meta("rise_fall",-20);test.check(g.magic_items.incoming_damage(999999)==999999,"Abyss death continues to bypass progression defense");a.remove_meta("rise_fall")
	s.restore({"profile":"world_rise","tree_version":4,"xp":957383,"learned":[],"passives":[],"greatsword_kills":0})
	for i in range(12):s.increase_attribute("reflexes")
	for i in range(12):s.increase_attribute("endurance")
	for id in ["swiftfoot","dash","streaming_dash","streaming_dash","streaming_dash","deep_reserve","lightstep","lightstep","lightstep","long_march","belly_roll","roly_poly","roly_poly","roly_poly"]:test.check(s.learn(id),"Bounded mobility perk can be purchased: "+id)
	g.apply_skill_stats()
	test.check(is_equal_approx(a.dash_distance_multiplier,1.45) and is_equal_approx(a.dash_stamina_multiplier,.7),"Dash bonuses stop at forty-five percent distance and thirty percent stamina savings")
	test.check(is_equal_approx(a.walk_speed,2.4*1.08) and is_equal_approx(a.combat.sprint_drain,base.sprint_drain*.95),"Reflexes and Swiftfoot add their speed bonuses; Long March independently saves sprint stamina")
	test.check(is_equal_approx(a.combat.dodge.duration,base.dodge.duration) and is_equal_approx(a.combat.dodge.speed*a.combat.dodge.duration,base.dodge.speed*base.dodge.duration*1.3),"Roly-Poly extends roll distance without retiming animation or granting immunity")
	s.award_practice("greatsword",400);g.apply_skill_stats()
	var path="user://world-rise-stats-verification.json";var saved=g.save_data();g.Save.write(saved,path);var back=g.Save.read(path)
	if back.is_empty():print("PROGRESSION_SAVE_DIAGNOSTIC ",JSON.stringify({"growth":g.Progression.valid(saved.progression),"world":preload("res://scripts/world_rise.gd").valid(saved.world_rise),"loadout":saved.skill_loadout,"health":saved.health,"stamina":saved.stamina,"map":saved.map,"growth_data":saved.progression}))
	test.check(not back.is_empty() and g.apply_save(back) and g.progression.greatsword_kills==400 and g.progression.has("dash"),"Tree5 attributes, bounded perks, practice and current resources survive the strict offline save roundtrip")
	s=g.progression;a=g.player;a.state="free";g.recovering=false;a.health=53;a.stamina=47
	g.reset_attributes();test.check(a.health==53 and is_equal_approx(a.stamina,47) and not a.dash_equipped and a.heavy_style=="overhead","Total reset preserves current resources and safely clears refunded active loadouts")
	g.toggle_inventory();g.inventory.show_page("level")
	test.check(g.skill_tree.rise_menu!=null and g.skill_tree.rise_menu.categories.get_child_count()==5 and not a.input_enabled,"Five attribute tiles open inside inventory and preserve offline pause gating")
	g.skill_tree.rise_menu.selected="mastery";g.skill_tree.refresh()
	test.check(g.skill_tree.rise_menu.grid.get_child_count()==6,"Mastery cards expose all six actual perks and their requirements")
	var menu=g.skill_tree.rise_menu
	g.progression.migration_notice=false
	for window_size in [Vector2i(960,540),Vector2i(1366,768)]:
		g.get_window().size=window_size;menu.selected="body";menu.practice_expanded=false;menu.refresh();menu.scroll.scroll_vertical=0
		for frame in range(6):await g.get_tree().process_frame
		test.check(menu.categories.get_child_count()==5 and menu.scroll.position.y>=menu.categories.position.y+menu.categories.size.y,"All five attributes remain accessible above scroll content at "+str(window_size))
		test.check(menu.scroll.get_global_rect().encloses(menu.grid.get_child(0).get_global_rect()),"The first complete perk card and its controls fit without scrolling at "+str(window_size))
		var collapsed=menu.content.get_child(0).get_combined_minimum_size().y
		menu.practice_expanded=true;menu.refresh()
		for frame in range(3):await g.get_tree().process_frame
		test.check(menu.content.get_child(0).get_combined_minimum_size().y>collapsed,"Weapon practice details expand on demand at "+str(window_size))
	menu.practice_expanded=false
	g.inventory.close();DirAccess.remove_absolute(path)
