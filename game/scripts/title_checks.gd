extends RefCounted
func run(test:RefCounted) -> void:
	var game=test.game
	game.start_new_game(false)
	var path="user://title-verification.json"
	DirAccess.remove_absolute(path)
	game.title_screen.show_menu(path)
	test.check(game.title_screen.visible and game.title_screen.load_button.disabled,"Title disables Load Saved Game when no save exists")
	var at=game.player.position
	Input.action_press("move_right")
	var key=InputEventKey.new()
	key.physical_keycode=KEY_R
	key.pressed=true
	Input.parse_input_event(key.duplicate())
	await test.frames(6)
	Input.action_release("move_right")
	key.pressed=false
	Input.parse_input_event(key.duplicate())
	test.check(game.player.position.distance_to(at)<.01 and not game.player.sword_drawn and not game.player.input_enabled,"Title blocks movement and gameplay keys")
	game.title_screen.new_button.pressed.emit()
	test.check(not game.title_screen.visible and game.dialog.visible and not game.player.input_enabled and game.map_id==game.config.start_map,"Start New Game wakes upstairs with movement gated by morning text")
	game.advance_dialogue()
	game._refresh_simulation()
	game.progression.restore({"tree_version":2,"xp":1400,"learned":["strength","form","belly_roll","mana"]})
	game.apply_skill_stats()
	game.quest_stage="active"
	game.well_gift_stage="potion_owned"
	game.mother_unwrapped=true
	game.defeated_enemies=["slime_forest/forest_slime"]
	game.selected_special_attack="water_sweep"
	game.load_map("village_green",Vector2(0,3.5),true)
	game.player.restore_health(90)
	game.player.restore_stamina(72)
	game.player.set_sword_drawn(true)
	game.Save.write(game.save_data(),path)
	var saved=FileAccess.get_file_as_string(path)
	game.title_screen.show_menu(path)
	test.check(not game.title_screen.load_button.disabled,"Title enables Load Saved Game for a validated save")
	game.title_screen.new_button.pressed.emit()
	game.advance_dialogue()
	game._refresh_simulation()
	test.check(game.progression.xp==0 and game.progression.learned.is_empty() and game.quest_stage=="not_started" and game.well_gift_stage=="not_started" and not game.mother_unwrapped and game.defeated_enemies.is_empty(),"New Game resets skills, quest, potion and permanent encounter progress")
	test.check(game.enemy_states.is_empty() and game.player.health==100 and game.player.stamina==100 and game.player.sword_equipped and not game.player.sword_drawn and not game.player.roll_unlocked,"New Game resets resources, equipment, cached encounters and ability unlocks")
	test.check(FileAccess.get_file_as_string(path)==saved,"New Game leaves the existing saved file untouched")
	game.title_screen.show_menu(path)
	game.title_screen.load_button.pressed.emit()
	test.check(not game.title_screen.visible and game.player.input_enabled and game.map_id=="village_green" and game.player.position.distance_to(Vector3(0,0,3.5))<.01,"Title Load button restores saved map and position")
	test.check(game.progression.xp==1400 and game.player.roll_unlocked and game.player.max_health==110 and game.player.health==90 and is_equal_approx(game.player.stamina,72),"Title loading restores XP, learned skills and resources")
	test.check(game.quest_stage=="active" and game.well_gift_stage=="potion_owned" and game.mother_unwrapped and game.defeated_enemies==["slime_forest/forest_slime"] and game.player.sword_drawn,"Title loading restores story, items, defeated mobs and weapon stance")
	var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	game.title_screen.show_menu(path)
	test.check(game.title_screen.load_button.disabled and not game.start_saved_game(path) and game.title_screen.visible,"Malformed save remains safely on the title screen")
	test.check(FileAccess.get_file_as_string(path)=="{broken","Rejected load never overwrites a saved file")
	DirAccess.remove_absolute(path)
	game.start_new_game(false)
