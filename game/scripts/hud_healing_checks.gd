extends RefCounted
func run(test:RefCounted) -> void:
	var game=test.game; var p=game.player; var hud=game.hud_feedback; var gear=game.magic_items
	game.start_new_game(false); game.load_map("menagery",Vector2(10,0),true); p.set_physics_process(false)
	test.check(game.health_bar.custom_minimum_size.y>=30 and game.stamina_bar.custom_minimum_size.y>=24,"Resource HUD uses thicker high-contrast bars")
	test.check(not game.weapon_label.visible and not game.quest_label.visible,"Action-state and quest prose are removed from resource HUD")
	p.health=100; hud.damage_flash_remaining=0; hud.damage_flash_strength=0
	hud.damaged(6); hud.update(0)
	var light_flash=hud.damage_veil.color.a
	hud.damaged(30); hud.update(0)
	test.check(light_flash>0 and hud.damage_veil.color.a>light_flash,"Damage flash scales with incoming damage")
	hud.damage_flash_remaining=0; hud.update(0)
	test.check(not hud.damage_veil.visible,"Damage flash clears after its brief duration")
	for value in [100,25,12,1]:
		p.restore_health(value); hud.update(0)
		test.check(is_equal_approx(hud.intensity,clampf((25-value)/25.0,0,1)),"Low-health edge tint uses progressive 25%% threshold at HP %d" % value)
	p.max_health=200; p.restore_health(50); hud.update(0)
	test.check(hud.intensity==0,"Low-health threshold scales with equipment maximum HP")
	game.apply_skill_stats(); p.restore_health(100); p.set_sword_drawn(true); p.restore_stamina(0); p.state="free"
	hud.pulse_remaining=0; p.begin_attack("light"); hud.update(0)
	test.check(hud.pulse_remaining>0 and game.stamina_bar.get_theme_stylebox("background").bg_color.r>.2,"An unaffordable light attack flashes even an empty stamina track")
	hud.pulse_remaining=0; p.begin_parry()
	test.check(hud.pulse_remaining>0,"An unaffordable parry triggers the same stamina pulse")
	p.roll_unlocked=true; hud.pulse_remaining=0; p.request_dodge()
	test.check(hud.pulse_remaining>0,"An unaffordable Dodge triggers visual stamina feedback")
	p.water_unlocked=true; hud.pulse_remaining=0; p.begin_water()
	test.check(hud.pulse_remaining>0,"An unaffordable water attack triggers stamina feedback")
	hud.update(1)
	test.check(hud.pulse_remaining==0,"Stamina feedback returns to normal after its brief pulse")
	game.toast_time=0; game.notify("Not enough stamina for this attack.")
	test.check(game.toast_time==0 and hud.pulse_remaining>0,"Stamina failure has no redundant text toast")
	p.restore_health(12); game.toggle_inventory(); hud.update(0)
	test.check(not hud.veil.visible,"Danger vignette stays behind menus and cannot obscure inventory")
	for id in ["mending_tonic","renewal_draught","spring_elixir"]: gear.claim(id)
	gear.claim("mending_tonic"); gear.claim("mending_tonic")
	test.check(gear.quantities.mending_tonic==3 and gear.owned.count("mending_tonic")==1,"Healing bottles stack in inventory without duplicating wearable ownership")
	p.restore_health(20); game.inventory.selected_category="potions"; game.inventory.refresh()
	var bottles=game.inventory.slots.find_children("*","Button",true,false).filter(func(node): return node.has_meta("inventory_entry") and node.get_meta("inventory_entry").get("id","")=="mending_tonic")
	test.check(bottles.size()==1 and int(bottles[0].get_meta("inventory_entry").count)==3,"Inventory renders one potion card with a quantity label rather than duplicate instances")
	for child in game.inventory.slots.find_children("*","Button",true,false):
		if child.has_meta("inventory_entry") and child.get_meta("inventory_entry").get("id","")=="spring_elixir":
			child.pressed.emit()
			for action in game.inventory.detail.get_children():
				if action is Button and action.text.begins_with("Drink"): action.pressed.emit(); break
			break
	test.check(p.health==45 and gear.healing[0].id=="spring_elixir" and "spring_elixir" not in gear.owned,"Actual inventory healing item button consumes the elixir and applies its immediate heal")
	var remaining=gear.healing[0].remaining; gear.tick(2)
	test.check(p.health==45 and gear.healing[0].remaining==remaining,"Open inventory freezes timed potion regeneration")
	game.inventory.close(); gear.tick(2)
	test.check(p.health==51 and gear.healing[0].remaining==8,"Potion regeneration heals and expires on the gameplay clock")
	gear.drink("renewal_draught"); gear.tick(1)
	test.check(p.health==60 and gear.healing.size()==2,"Different healing draughts stack their HP per second")
	gear.claim("renewal_draught"); gear.drink("renewal_draught"); gear.tick(1)
	test.check(p.health==75 and gear.healing.size()==3 and gear.healing[1].remaining==6 and gear.healing[2].remaining==7,"Repeated doses stack healing while retaining independent timers")
	var path="user://verification-hud-healing.json"; var saved=game.save_data()
	test.check(game.Save.write(saved,path)==OK and not game.Save.read(path).is_empty(),"Private save accepts an active healing potion")
	gear.healing.clear(); game.apply_save(game.Save.read(path))
	test.check(gear.healing.size()==3 and gear.healing[2].remaining==7 and gear.quantities.mending_tonic==3,"Loading restores potion identity and remaining duration")
	var bad=saved.duplicate(true); bad.magic_items.healing[0].remaining=999
	test.check(not game.apply_save(bad),"Malformed potion duration is rejected before changing state")
	bad=saved.duplicate(true); bad.magic_items.quantities.mending_tonic=-1
	test.check(not game.apply_save(bad),"Malformed bottle counts are rejected without changing inventory")
	gear.tick(6)
	test.check(gear.healing.size()==1 and gear.healing[0].remaining==1 and p.health==100,"Earlier doses expire independently and stacked healing caps at maximum HP")
	gear.tick(1)
	test.check(gear.healing.is_empty(),"The last stacked dose expires on its own timer")
	var legacy=gear.get_script().new(); legacy.restore({"owned":["mending_tonic"],"healing":{"id":"mending_tonic","remaining":10,"clock":.5}})
	test.check(legacy.quantities.mending_tonic==1 and legacy.healing.size()==1,"Legacy single-bottle potion state migrates into quantity and timer stacks")
	gear.drink("mending_tonic"); p.health=0; gear.tick(1)
	test.check(p.health==0,"Healing potions never revive a defeated player")
	game._player_defeated()
	test.check(gear.healing.is_empty(),"Death clears the active potion without returning its consumed bottle")
	game.respawn_player(); game.start_new_game(false); game.load_map("coastal_path",Vector2(0,3),true); p.set_physics_process(true)
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
