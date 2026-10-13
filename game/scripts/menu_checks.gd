extends RefCounted
func key(test:RefCounted,code:int) -> void:
	var event=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	Input.parse_input_event(event.duplicate())
	await test.game.get_tree().process_frame
	await test.frames(2)
	event.pressed=false
	Input.parse_input_event(event.duplicate())
	await test.game.get_tree().process_frame
func run(test:RefCounted) -> void:
	var game=test.game
	game.start_new_game(false)
	game.home_intro_complete=true
	# Previous camera/contact fixtures may leave focus on a hidden menu control.
	game.get_viewport().gui_release_focus()
	game.load_map("slime_forest",Vector2(0,-8.2),true)
	await test.frames(4)
	await key(test,KEY_I)
	test.check(game.inventory.visible and game.inventory.page=="equipment" and not game.player.input_enabled,"Actual I opens equipment and inventory and pauses combat")
	game.inventory.toggle_weapon()
	test.check(not game.player.sword_equipped,"Equipment page unequips the sword into carried items")
	game.inventory.show_page("skills")
	test.check(game.inventory.page=="skills" and not game.skill_tree.visible,"Skills equipment has its own inventory tab")
	game.inventory.show_page("level")
	game.gain_xp(1000)
	game.learn_skill("strength")
	test.check(game.skill_tree.visible and game.progression.rank("strength")==1 and game.player.max_health==110,"Inventory Level Up uses the real skill tree and applies learned stats")
	for id in ["mana","mana_lance","form","charge_thrust"]: game.learn_skill(id)
	game.inventory.tabs.get_child(1).pressed.emit()
	for section in game.inventory.slots.get_children():
		if section is HBoxContainer:
			for button in section.get_children():
				if button is Button and (button.text.contains("Water Lance") or button.text.contains("Driving Thrust")): button.pressed.emit()
	test.check(game.selected_special_attack=="water_lance" and game.player.heavy_style=="charge_thrust" and game.inventory.page=="skills","Skills tab buttons equip unlocked special and heavy attacks")
	var original_size=game.get_window().size
	game.get_window().size=Vector2i(960,540)
	await test.frames(3)
	game.inventory.refresh()
	await test.frames(3)
	test.check(game.inventory.box.get_global_rect().end.x<=game.get_viewport_rect().size.x,"Compact skill equipment stays within the supported window")
	game.get_window().size=original_size
	await test.frames(3)
	game.quest_stage="component_ready"
	game.defeated_enemies=["herb_glade/stone_warden"]
	game.inventory.show_page("quests")
	var journal=""
	for child in game.inventory.slots.get_children():
		if child is Label: journal+=child.text
	test.check(journal.contains("Return the calcified aether core") and not game.skill_tree.visible,"Quest tab reports current objective and hides the level tree")
	await key(test,KEY_ESCAPE)
	test.check(not game.inventory.visible and not game.pause_menu.visible,"Escape closes inventory before opening pause")
	await key(test,KEY_P)
	test.check(game.inventory.visible and game.skill_tree.visible and game.inventory.page=="level","P opens Level Up inside inventory")
	await key(test,KEY_ESCAPE)
	await key(test,KEY_ESCAPE)
	test.check(game.pause_menu.visible and not game.player.input_enabled,"Actual Escape opens pause and blocks gameplay")
	var at=game.player.position
	Input.action_press("move_right")
	await test.frames(8)
	Input.action_release("move_right")
	test.check(game.player.position.distance_to(at)<.001,"Pause freezes player movement")
	test.check(not game.enemy_bars.is_empty() and game.enemy_bars.all(func(item): return not item.root.visible),"Enemy health bars stay hidden over the pause menu")
	var rock=game.RockProjectile.new()
	rock.configure(game,game.player,Vector3.FORWARD)
	game.world_root.add_child(rock)
	var rock_at=rock.position
	await test.frames(5)
	test.check(rock.position==rock_at and rock.life==3.5,"Pause freezes incoming rock movement and lifetime")
	rock.queue_free()
	game.set_resolution(0)
	game.toggle_camera()
	test.check(game.graphics_preset==0 and game.camera_mode=="first_person" and game.pause_menu.visible,"Graphics settings preserve first-person view while paused")
	var path="user://menu-verification.json"
	game.pause_menu.save_current(path)
	game.quest_stage="not_started"
	game.pause_menu.load_saved(path)
	test.check(game.quest_stage=="component_ready" and not game.pause_menu.visible,"Pause save/load restores progress and resumes using a separate fixture save")
	DirAccess.remove_absolute(path)
	game.toggle_pause()
	game.pause_menu.load_saved(path)
	test.check(game.pause_menu.visible and game.pause_menu.status.text.contains("No valid"),"Missing pause-menu save leaves current game paused and intact")
	game.pause_menu.close()
	game.player.set_sword_equipped(true)
	game.player.set_sword_drawn(true)
	game.player.begin_attack("heavy")
	game.toggle_pause()
	var elapsed=game.player.state_time
	await test.frames(10)
	test.check(game.player.state_time==elapsed,"Pause freezes an attack in progress")
	game.pause_menu.close()
	await test.frames(4)
	test.check(game.player.state_time>elapsed,"Resume continues the paused attack")
	game.player.set_sword_drawn(false)
	game.camera_driver.set_mode("overhead")
