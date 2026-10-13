extends RefCounted
func picture(game:Control,path:String) -> void:
	await game.get_tree().create_timer(.7).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
func run(game:Control,directory:String) -> void:
	game.goblin_campaign.reset()
	game.home_intro_complete=true
	game.load_map("lark_farm",Vector2(0,6),true)
	game.camera_mode="overhead"
	await picture(game,directory+"/goblin-farm.png")
	var rowan=game.current_world.interactions.filter(func(t): return t.id=="rowan")[0]
	game.conversation.show_character(rowan)
	game._refresh_simulation()
	await picture(game,directory+"/goblin-farm-dialogue.png")
	game.conversation.close()
	game.goblin_campaign.stage="active"
	game.load_map("goblin_approach",Vector2(0,3),true)
	for enemy in game.enemies: enemy.ai_enabled=false
	await picture(game,directory+"/goblin-palisade.png")
	game.goblin_campaign.interact({"campaign_action":"gate_lever"})
	game.player.position=Vector3(0,0,-4)
	game.goblin_campaign.tick()
	await picture(game,directory+"/goblin-road-ambush.png")
	game.load_map("goblin_cave",Vector2(3,4),true)
	for enemy in game.enemies: enemy.ai_enabled=false
	await picture(game,directory+"/goblin-cave-fortifications.png")
	game.load_map("goblin_depths",Vector2(0,-3),true)
	for enemy in game.enemies: enemy.ai_enabled=false
	await picture(game,directory+"/goblin-foreman-vault.png")
	game.goblin_campaign.interact({"campaign_action":"secret_wall"})
	game.camera_driver.set_mode("follow"); game.camera_driver.yaw=0; game.camera_driver.pitch=.55; game.camera_driver.distance=3.2
	game.player.position=Vector3(-5,0,-4); game.player.visual.rotation.y=PI
	await picture(game,directory+"/goblin-secret-shrine.png")
	game.goblin_campaign.interact({"campaign_action":"windstep"})
	game.camera_mode="follow"; game.camera_driver.yaw=.4
	game.player.position=Vector3(0,0,-2)
	await picture(game,directory+"/goblin-follow-combat.png")
	game.toggle_inventory()
	await picture(game,directory+"/goblin-windstep-inventory.png")
	game.inventory.show_page("quests")
	await picture(game,directory+"/goblin-quest-journal.png")
