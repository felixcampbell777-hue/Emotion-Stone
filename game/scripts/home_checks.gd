extends RefCounted
func run(test:RefCounted) -> void:
	var game=test.game
	game.start_new_game()
	test.check(game.map_id=="home_upstairs" and game.dialog.visible and not game.player.input_enabled and not game.home_intro_complete,"New game wakes in the second-floor bedroom before Mother farewell")
	game.advance_dialogue()
	game._refresh_simulation()
	test.check(game.player.input_enabled and game.current_world.safe_position(game.player.position),"Waking leaves the heroine beside her bed in a walkable position")
	game.player.position=Vector3(3,0,1.6)
	game.exit_cooldown=0
	await test.frames(4)
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	test.check(game.map_id=="home_downstairs" and game.npcs.size()==1,"Bedroom stairs lead to Mother in the hearth room")
	game.player.position=Vector3(0,0,4.1)
	game.exit_cooldown=0
	await test.frames(4)
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	game.open_nearest()
	test.check(game.map_id=="home_downstairs" and not game.home_intro_complete,"Front door blocks leaving before the morning conversation")
	game.player.position=Vector3(-.1,0,-2.8)
	await test.frames(4)
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	game.open_nearest()
	test.check(game.conversation.visible and game.conversation.text.text.contains("Good morning"),"Mother opens the illustrated morning conversation")
	game.conversation.choices.get_child(0).pressed.emit()
	test.check(game.home_intro_complete and game.quest_stage=="not_started","Mother farewell opens the door without automatically accepting the forest quest")
	game.conversation.close()
	var path="user://home-verification.json"
	game.Save.write(game.save_data(),path)
	game.home_intro_complete=false
	test.check(game.apply_save(game.Save.read(path)) and game.home_intro_complete and game.map_id=="home_downstairs","Home location and completed farewell survive private save/load")
	game.player.position=Vector3(0,0,4.1)
	game.exit_cooldown=0
	await test.frames(4)
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	game.open_nearest()
	test.check(game.map_id=="coastal_path" and game.current_world.safe_position(game.player.position),"Farewell allows the front door to reach a safe coastal doorstep")
	test.check(game.npcs.all(func(npc): return npc.definition.id!="mother"),"Mother stays in the home instead of duplicating outdoors")
	game.player.position=Vector3(-5.8,0,-2.8)
	await test.frames(4)
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	game.open_nearest()
	test.check(game.map_id=="home_downstairs","Coastal cottage door allows returning home")
	game.player.position=Vector3(3,0,1.6)
	game.exit_cooldown=0
	await test.frames(4)
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	test.check(game.map_id=="home_upstairs","Hearth-room stairs return to the upstairs bedroom")
	test.check(game.current_world.find_child("DescendingStairwell",true,false)!=null and not game.current_world.safe_position(Vector3(3,0,3)),"Upstairs stairwell descends below a guarded floor opening")
	test.check(not game.current_world.safe_position(Vector3(4.7,0,0)) and not game.current_world.safe_position(Vector3(0,0,-4.7)),"Full-height home wall footprints reject invalid saved positions")
	var old_home=game.save_data()
	old_home.erase("home_layout")
	old_home.position=[-5.7,3]
	test.check(game.apply_save(old_home) and game.current_world.safe_position(game.player.position),"Old larger-home saves relocate safely without resetting progress")
	var legacy=game.save_data()
	legacy.erase("home_intro_complete")
	test.check(game.apply_save(legacy) and game.home_intro_complete,"Existing saves bypass the new introduction without losing progress")
	legacy.home_intro_complete="yes"
	game.Save.write(legacy,path)
	test.check(game.Save.read(path).is_empty(),"Invalid morning progress flag is rejected")
	DirAccess.remove_absolute(path)
	game.load_map("coastal_path",Vector2(0,3),true)
