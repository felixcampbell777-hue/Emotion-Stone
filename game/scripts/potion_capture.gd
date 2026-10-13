extends RefCounted
func picture(game:Control,path:String) -> void:
	await game.get_tree().create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
func run(game:Control,directory:String) -> void:
	game.camera_driver.set_mode("first_person")
	game.well_gift_stage="not_started"
	game.load_map("village_green",Vector2(-2.9,1.5),true)
	await game.get_tree().create_timer(.2).timeout
	game.open_nearest()
	await picture(game,directory+"/wishing-coin-keeper.png")
	game.conversation.receive_coin()
	game.conversation.close()
	game.player.input_enabled=true
	game.player.position=Vector3(0,0,1)
	await game.get_tree().create_timer(.2).timeout
	game.open_nearest()
	await picture(game,directory+"/wishing-well.png")
	game.conversation.throw_coin()
	await picture(game,directory+"/everfull-potion-reward.png")
	game.conversation.close()
	game.toggle_inventory()
	game.inventory.drink_potion()
	await picture(game,directory+"/everfull-potion-inventory.png")

	game.inventory.close();game.game_mode="beta";game.start_new_game();game.set_resolution(0)
	game.camera_driver.set_mode("first_person")
	for enemy in game.enemies: enemy.ai_enabled=false
	await game.get_tree().create_timer(.2).timeout
	load("res://scripts/magicnow_checks.gd").new().type_keys("magicnow")
	await picture(game,directory+"/beta-magicnow-reward.png")
	game.toggle_inventory();game.inventory.selected_category="potions";game.inventory.refresh()
	var entries=game.inventory.listed_items()
	for entry in entries:
		if entry.id=="everfull": game.inventory.selected_item=entry
	game.inventory.refresh()
	await picture(game,directory+"/beta-magicnow-potion.png")
