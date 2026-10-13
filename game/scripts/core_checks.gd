extends RefCounted
func freeze(game:Node) -> void:
	game.player.set_physics_process(false)
	for enemy in game.enemies: enemy.set_physics_process(false); enemy.ai_enabled=false
func run(test:RefCounted) -> void:
	var game=test.game; var loot=game.monster_cores
	game.start_new_game(false); game.home_intro_complete=true; game.load_map("menagery",Vector2(10,0),true); freeze(game)
	for kind in loot.catalog.beasts+ ["rabbit","unknown"]:
		test.check(loot.roll(kind,0,0).is_empty(),kind+" receives no monster-core roll")
	for kind in ["slime","moss_slime","resin_slime","bramble_slime","green_slime"]:
		test.check(loot.roll(kind,.5,0).is_empty() and not loot.roll(kind,.499,.999).is_empty(),kind+" has an exact fifty-percent core threshold")
	test.check(loot.roll("resin_slime",.49,.049)=="sticky_core" and loot.roll("resin_slime",.49,.05)=="slime_core","Sticky special chance is five percent of successful drops, with correct threshold")
	var generic=0; var sticky=0
	for a in range(100):
		for b in range(100):
			var result=loot.roll("resin_slime",(a+.5)/100,(b+.5)/100)
			if result=="slime_core": generic+=1
			elif result=="sticky_core": sticky+=1
	test.check(generic==4750 and sticky==250,"Two-stage sticky probability yields 47.5% generic and 2.5% special overall")
	for kind in ["warden","queen_slime","goblin_foreman"]:
		test.check(not loot.roll(kind,.999,.999).is_empty() and not loot.roll(kind,1.0,1.0).is_empty() and loot.boss_bonus(kind)>=250,kind+" guarantees its core even at the random upper bound and a large extra XP reward")
	test.check(loot.roll("goblin_raider",.4,0).is_empty() and not loot.roll("goblin_guard",.64,.999).is_empty(),"Goblin toughness profiles have varied drop rates")
	loot.defeated("resin_slime",game.player.position,false,.1,.01)
	test.check(loot.pending.size()==1 and loot.nodes.size()==1 and loot.pending[0].id=="sticky_core","Successful kill roll produces a visible collectible special core")
	game._process(0); game.open_nearest()
	test.check(loot.pending.is_empty() and loot.quantities.sticky_core==1,"Actual nearest-interaction route collects a dropped core exactly once")
	loot.give("slime_core",2); game.toggle_inventory(); game.inventory.selected_category="ingredients"; game.inventory.refresh()
	var buttons=game.inventory.slots.find_children("*","Button",true,false).filter(func(node): return node.has_meta("inventory_entry") and node.get_meta("inventory_entry").get("id","")=="slime_core")
	test.check(buttons.size()==1 and int(buttons[0].get_meta("inventory_entry").count)==2,"Monster cores use one inventory card per type with a stack count")
	game.player.max_health=200; game.player.restore_health(50); buttons[0].pressed.emit()
	for action in game.inventory.detail.get_children():
		if action is Button and action.text=="Consume": action.pressed.emit(); break
	test.check(game.player.health==70 and loot.quantities.slime_core==1,"Inventory core consumption heals ten percent of current maximum HP and spends one")
	game.inventory.close(); game.apply_skill_stats(); game.player.restore_health(95); loot.consume("sticky_core")
	test.check(game.player.health==100 and not loot.quantities.has("sticky_core"),"Tougher special core percentage caps at maximum HP")
	game.quest_stage="active"; loot.give("golem_core"); game.player.restore_health(40); game.toggle_inventory(); game.inventory.selected_category="ingredients"; game.inventory.refresh()
	var core_button=game.inventory.slots.find_children("*","Button",true,false).filter(func(node): return node.has_meta("inventory_entry") and node.get_meta("inventory_entry").get("id","")=="golem_core")[0]
	core_button.pressed.emit()
	for action in game.inventory.detail.get_children():
		if action is Button and action.text.begins_with("Quest locked"): action.pressed.emit(); break
	test.check(loot.warning.visible and game.player.health==40 and loot.quantities.golem_core==1 and not game.player.input_enabled,"Consuming a quest core opens This may be useful without spending or healing")
	loot.close_warning(); game.inventory.close()
	game.quest_stage="completed"; loot.consume("golem_core")
	test.check(game.player.health==80 and not loot.quantities.has("golem_core"),"After Mother's quest, spare golem cores can heal forty percent")
	game.quest_stage="active"
	loot.defeated("queen_slime",game.player.position,false,.99,.99)
	var saved=game.save_data(); var path="user://verification-monster-cores.json"
	test.check(game.Save.write(saved,path)==OK and not game.Save.read(path).is_empty(),"Pending core pickups and stacked counts pass private save validation")
	loot.reset(); game.apply_save(game.Save.read(path)); freeze(game)
	test.check(loot.pending.size()==1 and loot.nodes.size()==1 and loot.quantities.slime_core==1,"Loading recreates uncollected ground cores without rerolling them")
	game.load_map("coastal_path",Vector2(0,3),true); freeze(game)
	test.check(loot.nodes.is_empty() and loot.pending.size()==1,"Map travel removes local visuals while retaining an uncollected drop")
	game.load_map("menagery",Vector2(10,0),true); freeze(game)
	test.check(loot.nodes.size()==1,"Returning to the area restores its original drop")
	for mode in ["unknown","count","duplicate","map","position"]:
		var bad=saved.duplicate(true)
		match mode:
			"unknown": bad.monster_cores.quantities.fake=1
			"count": bad.monster_cores.quantities.slime_core=-1
			"duplicate": bad.monster_cores.pending.append(bad.monster_cores.pending[0].duplicate(true))
			"map": bad.monster_cores.pending[0].map="missing"
			"position": bad.monster_cores.pending[0].at=[9999,0,0]
		game.Save.write(bad,path)
		test.check(game.Save.read(path).is_empty() and not game.apply_save(bad),"Malformed "+mode+" core save is rejected before applying")
	game.start_new_game(false); game.home_intro_complete=true; game.quest_stage="active"; game.load_map("herb_glade",Vector2(0,14),true); freeze(game)
	var warden=game.enemies.filter(func(enemy): return enemy.definition.kind=="warden")[0]
	var xp=game.progression.xp; warden.open_armor(); warden.take_damage(99999,Vector3.ZERO)
	test.check(game.progression.xp==xp+420 and is_instance_valid(game.warden_remains) and loot.pending.is_empty(),"Actual Warden kill gives base plus boss XP and one authored guaranteed corpse core")
	game.player.position=game.warden_remains.position; game._process(0); game.open_nearest()
	test.check(game.quest_stage=="component_ready" and loot.quantities.golem_core==1,"Mother's actual corpse-loot interaction grants the canonical locked golem core")
	game.conversation.complete_quest(); game.conversation.complete_quest()
	test.check(game.quest_stage=="completed" and not loot.quantities.has("golem_core") and game.progression.xp==xp+500,"Mother consumes the required core and gives quest XP only once")
	var legacy=game.save_data(); legacy.erase("monster_cores"); legacy.quest_stage="component_ready"
	test.check(game.apply_save(legacy) and loot.quantities.golem_core==1,"Legacy component-ready saves migrate the required core into inventory")
	game.start_new_game(false); game.load_map("menagery",Vector2(10,0),true); freeze(game)
	var boss=game.menagery.spawn("10E"); boss.set_physics_process(false); xp=game.progression.xp; boss.take_damage(99999,Vector3.ZERO)
	test.check(game.progression.xp==xp+1200 and loot.pending.size()==1 and loot.pending[0].id=="queen_core","Actual Menagerie Queen death guarantees a royal core and 800 bonus XP")
	boss.take_damage(99999,Vector3.ZERO)
	test.check(game.progression.xp==xp+1200 and loot.pending.size()==1,"Repeated damage cannot duplicate boss XP or core drops")
	game.menagery.spawn("4E").take_damage(99999,Vector3.ZERO)
	test.check(loot.pending.size()==1,"Actual Menagerie beast death gives XP without dropping a core")
	game.menagery.clear()
	test.check(loot.pending.size()==1,"Clearing practice monsters cannot create drops or erase an earned core")
	game.start_new_game(false); game.load_map("coastal_path",Vector2(0,3),true); game.player.set_physics_process(true)
	test.check(loot.quantities.is_empty() and loot.pending.is_empty(),"New Game resets core inventory and drops without touching player saves")
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
