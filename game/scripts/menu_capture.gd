extends RefCounted
func picture(game:Control,path:String) -> void:
	await game.get_tree().create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
func run(game:Control,directory:String) -> void:
	game.start_new_game(false)
	game.set_resolution(0)
	game.camera_driver.set_mode("first_person")
	game.load_map("slime_forest",Vector2(0,-5),true)
	game.progression.restore({"tree_version":2,"xp":8200,"learned":["strength","efficient_swing","crushing_force","form","charge_thrust","belly_roll","mana","mana_lance","flowing_splash"]})
	game.apply_skill_stats()
	game.well_gift_stage="potion_owned"
	game.quest_stage="active"
	game.toggle_inventory()
	for page in ["equipment","skills","level","quests"]:
		game.inventory.show_page(page)
		await picture(game,directory+"/inventory-"+page+".png")
	game.inventory.close()
	game.toggle_pause()
	await picture(game,directory+"/pause-menu.png")
	DisplayServer.window_set_size(Vector2i(960,540))
	await picture(game,directory+"/pause-menu-small.png")
	game.pause_menu.close()
	game.toggle_skills()
	await picture(game,directory+"/inventory-level-small.png")
	for page in ["equipment","skills","quests"]:
		game.inventory.show_page(page)
		await picture(game,directory+"/inventory-"+page+"-small.png")
	game.inventory.close(); DisplayServer.window_set_size(Vector2i(1366,768))
	var Packs=game.WorldPacks; var old_directory=Packs.directory; Packs.directory="user://custom-world-capture"
	var pack=load("res://scripts/builder_document.gd").example(); pack.id="capture_world"; pack.name="My woodland world"; pack.maps[0].catalog_enemies=[{"id":"resin","code":"2E","at":[3,5]}]; Packs.install(pack)
	game.title_screen.show_menu("user://missing-custom-world-capture-save.json"); game.world_browser.open()
	await picture(game,directory+"/custom-world-browser.png")
	game.world_browser.play(false); game.set_resolution(0)
	for enemy in game.enemies: enemy.ai_enabled=false
	await picture(game,directory+"/custom-world-playable.png")
	DirAccess.remove_absolute(Packs.file_path(pack.id)); DirAccess.remove_absolute(Packs.directory); Packs.directory=old_directory
	print("CAPTURE_OK "+directory)
