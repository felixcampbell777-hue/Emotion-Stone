extends RefCounted
func picture(game:Node,path:String) -> void:
	await game.get_tree().create_timer(.35).timeout; await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
func freeze(game:Node) -> void:
	game.player.set_physics_process(false)
	for enemy in game.enemies: enemy.set_physics_process(false); enemy.ai_enabled=false
func run(game:Node,directory:String) -> void:
	game.start_new_game(false); game.home_intro_complete=true; game.load_map("menagery",Vector2(10,0),true); freeze(game)
	game.menagery.toggle(); game.menagery.tabs.current_tab=3
	await picture(game,directory+"/core-codex.png")
	game.menagery.close(); game.camera_driver.set_mode("follow"); game.camera_driver.distance=4
	game.monster_cores.defeated("resin_slime",game.player.position+Vector3(0,0,1),false,.1,.01)
	game.monster_cores.defeated("goblin_foreman",game.player.position+Vector3(1.2,0,1))
	await picture(game,directory+"/core-ground-pickups.png")
	for key in game.monster_cores.nodes.keys(): game.monster_cores.collect(key)
	game.monster_cores.give("slime_core",3); game.monster_cores.give("goblin_core",2); game.monster_cores.give("queen_core"); game.monster_cores.give("golem_core")
	game.quest_stage="active"; game.toggle_inventory(); game.inventory.selected_category="ingredients"; game.inventory.refresh(); await game.get_tree().process_frame; await game.get_tree().process_frame
	game.inventory.box.get_child(0).scroll_vertical=10000
	await picture(game,directory+"/core-inventory-stacks.png")
	game.monster_cores.consume("golem_core")
	await picture(game,directory+"/core-quest-lock.png")
	game.monster_cores.close_warning(); game.inventory.close()
	game.load_map("herb_glade",Vector2(0,14),true); freeze(game)
	var warden=game.enemies.filter(func(enemy): return enemy.definition.kind=="warden")[0]; warden.open_armor(); warden.take_damage(99999,Vector3.ZERO)
	game.player.position=game.warden_remains.position+Vector3(0,0,1.5); game._process(0)
	await picture(game,directory+"/core-warden-guaranteed.png")
	game.open_nearest(); game.toggle_inventory(); game.inventory.selected_category="ingredients"; game.inventory.refresh(); await game.get_tree().process_frame; game.inventory.box.get_child(0).scroll_vertical=10000
	await picture(game,directory+"/core-mother-quest-item.png")
	game.inventory.close(); game.load_map("home_downstairs",Vector2(-.1,-2.8),true); freeze(game); game._process(0); game.open_nearest()
	await picture(game,directory+"/core-mother-turn-in.png")
	game.conversation.complete_quest(); await picture(game,directory+"/core-mother-completed.png")
