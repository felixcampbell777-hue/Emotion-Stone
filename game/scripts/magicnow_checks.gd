extends RefCounted
func type_keys(text:String) -> void:
	for letter in text.to_upper():
		for pressed in [true,false]:
			var event=InputEventKey.new();event.keycode=letter.unicode_at(0);event.physical_keycode=event.keycode;event.pressed=pressed
			Input.parse_input_event(event);Input.flush_buffered_events()
func run(test:RefCounted) -> void:
	var game=test.game
	game.game_mode="beta";game.start_new_game();await test.frames(3)
	for enemy in game.enemies: enemy.ai_enabled=false
	type_keys("magixnow")
	test.check(game.well_gift_stage=="not_started","Wrong-order MAGICNOW letters cannot grant the Beta potion")
	type_keys("mag");game.magicnow_deadline=0;type_keys("icnow")
	test.check(game.well_gift_stage=="not_started","Expired MAGICNOW prefix cannot grant the potion")
	game.inventory.close();game._refresh_simulation()
	type_keys("mag");game.toggle_pause();game.pause_menu.close();game._refresh_simulation();type_keys("icnow")
	test.check(game.well_gift_stage=="not_started","Opening pause clears an incomplete Beta code")
	game.inventory.close();game._refresh_simulation()
	type_keys("magicnow")
	test.check(game.well_gift_stage=="potion_owned" and not game.inventory.visible and not game.menagery.opened and game.progression.xp==0,"Real MAGICNOW key presses grant Beta's existing potion without opening menus or awarding quest XP")
	type_keys("magicnow");type_keys("i")
	game.inventory.selected_category="potions";game.inventory.refresh()
	var potions=game.inventory.listed_items()
	test.check(game.inventory.visible and potions.filter(func(entry):return entry.id=="everfull").size()==1,"Inventory I still works afterward and repeated codes retain exactly one unlimited potion")
	game.inventory.drink_potion()
	test.check(game.progression.xp==1000 and game.well_gift_stage=="potion_owned","Code-granted potion uses the existing inventory drink and remains full")
	game.inventory.close()
	var path="user://magicnow-verification.json"
	game.Save.write(game.save_data(),path);game.well_gift_stage="not_started"
	test.check(game.apply_save(game.Save.read(path)) and game.well_gift_stage=="potion_owned" and game.progression.xp==1000,"Beta code potion and XP survive a private save/load")
	DirAccess.remove_absolute(path)
	game.well_gift_stage="not_started";game.toggle_inventory();type_keys("magicnow")
	test.check(game.well_gift_stage=="not_started","Inventory overlays cannot activate the Beta code")
	game.inventory.close();game._refresh_simulation();game.game_mode="alpha";type_keys("magicnow")
	test.check(game.well_gift_stage=="not_started","Alpha does not grant the MAGICNOW potion")
	game.inventory.close();game._refresh_simulation()
