extends RefCounted
func run(test: RefCounted) -> void:
	var game=test.game
	game.conversation.close()
	game.inventory.close()
	game.skill_tree.close()
	game.recovering=false
	game.dialog.visible=false
	game.help_panel.visible=false
	game.well_gift_stage="not_started"
	game.progression.restore({"tree_version":2,"xp":0,"learned":[]})
	game.apply_skill_stats()
	game.load_map("village_green",Vector2(-2.9,1.5),true)
	game.player.input_enabled=true
	await test.frames(3)
	game._process(0)
	game.open_nearest()
	test.check(game.conversation.target.get("id")=="keeper_green","Nearby male keeper opens the coin conversation")
	game.conversation.choices.get_child(0).pressed.emit()
	test.check(game.well_gift_stage=="coin_ready","Keeper dialogue gives one wishing coin")
	test.check(not game.receive_wishing_coin() and game.drink_experience_potion()==0,"Coin cannot be duplicated or drunk as a potion")
	var path="user://potion-verification.json"
	game.Save.write(game.save_data(),path)
	test.check(game.apply_save(game.Save.read(path)) and game.well_gift_stage=="coin_ready","Unspent wishing coin survives save/load")
	game.conversation.close()
	game.player.input_enabled=true
	game.player.position=Vector3(0,0,1)
	await test.frames(3)
	game._process(0)
	game.open_nearest()
	test.check(game.conversation.target.get("role")=="well" and not game.conversation.portrait_frame.visible,"Existing well opens a wish menu rather than a villager portrait")
	game.conversation.choices.get_child(0).pressed.emit()
	test.check(game.well_gift_stage=="potion_owned" and not game.throw_wishing_coin(),"Well spends the coin once and grants the everfull potion")
	game.conversation.close()
	game.toggle_inventory(); game.inventory.selected_category="potions"; game.inventory.refresh()
	var potion_button:Button
	for child in game.inventory.slots.find_children("*","Button",true,false):
		if child.has_meta("inventory_entry") and child.get_meta("inventory_entry").get("id","")=="everfull":
			potion_button=child; break
	test.check(is_instance_valid(potion_button),"Potion is available as an inventory action")
	if is_instance_valid(potion_button):
		potion_button.pressed.emit()
		for action in game.inventory.detail.get_children():
			if action is Button and action.text.begins_with("Drink"): action.pressed.emit(); break
	test.check(game.progression.xp==1040 and game.well_gift_stage=="potion_owned","Inventory drink grants 1,000 XP without consuming the potion")
	test.check(game.drink_experience_potion()==1000 and game.progression.xp==2040 and game.progression.points()>0,"Repeated drinks fund the existing skill tree")
	game.inventory.close()
	game.Save.write(game.save_data(),path)
	test.check(game.apply_save(game.Save.read(path)) and game.well_gift_stage=="potion_owned" and game.progression.xp==2040,"Potion ownership and gained XP survive save/load")
	game.recovering=true
	game.respawn_player()
	test.check(game.well_gift_stage=="potion_owned" and game.progression.xp==2040,"Village respawn retains the potion and experience")
	var legacy=game.save_data()
	legacy.erase("well_gift_stage")
	game.Save.write(legacy,path)
	test.check(game.apply_save(game.Save.read(path)) and game.well_gift_stage=="not_started","Old saves can start the new well gift")
	legacy.well_gift_stage="counterfeit"
	game.Save.write(legacy,path)
	test.check(game.Save.read(path).is_empty() and not game.apply_save(legacy),"Invalid well gift stages are rejected")
	game.well_gift_stage="potion_owned"
	game.progression.xp=game.Progression.MAX_XP-500
	test.check(game.drink_experience_potion()==500 and game.drink_experience_potion()==0,"Unlimited drinks safely respect the existing XP limit")
	game.gain_xp(120)
	test.check(game.Progression.valid(game.progression.snapshot()),"Later combat XP at the cap remains saveable")
	game.Save.write(game.save_data(),path)
	test.check(not game.Save.read(path).is_empty(),"Max XP potion save passes validation")
	DirAccess.remove_absolute(path)
