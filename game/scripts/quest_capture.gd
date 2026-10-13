extends RefCounted
func picture(game: Control, path: String) -> void:
	await game.get_tree().create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)

func run(game: Control, directory: String) -> void:
	game.load_map("home_downstairs",Vector2(-.1,-2.8))
	await game.get_tree().create_timer(.5).timeout
	game.open_nearest()
	await picture(game,directory+"/conversation-mother.png")
	game.conversation.accept_quest()
	await picture(game,directory+"/conversation-quest.png")
	game.conversation.reveal_arm()
	await picture(game,directory+"/conversation-revealed.png")
	game.conversation.close()
	game.load_map("coastal_path",Vector2(2,1.55))
	await game.get_tree().create_timer(.3).timeout
	game.open_nearest()
	await picture(game,directory+"/conversation-villager.png")
	game.conversation.close()
	game.toggle_inventory()
	await picture(game,directory+"/inventory-equipped.png")
	game.inventory.toggle_weapon()
	await picture(game,directory+"/inventory-unequipped.png")
	game.inventory.toggle_weapon()
	game.inventory.close()
	game.defeated_enemies=["slime_forest/forest_slime"]
	game.load_map("herb_glade",Vector2(0,-12.5))
	for enemy in game.enemies:
		enemy.ai_enabled=false
	game.player.set_sword_drawn(true)
	await picture(game,directory+"/quest-boar.png")
	game.player.position=Vector3(0,0,-1.5)
	await game.get_tree().create_timer(.8).timeout
	await picture(game,directory+"/quest-dense-forest.png")
	game.player.position=Vector3(0,0,14)
	game.player.visual.rotation.y=PI
	await game.get_tree().create_timer(.8).timeout
	game.enemies[2].ai_enabled=true
	await picture(game,directory+"/quest-warden.png")
	await game.get_tree().create_timer(.7).timeout
	await picture(game,directory+"/quest-rock.png")
	for enemy in game.enemies:
		enemy.ai_enabled=false
	for projectile in game.projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	game.projectiles.clear()
	game.player.restore_stamina(game.player.max_stamina)
	game.player.set_sword_drawn(true)
	game.player.begin_water_lance()
	await game.get_tree().create_timer(.8).timeout
	game.player.invulnerability=0
	game.player.take_damage(12,Vector3(0,0,1))
	game.player.invulnerability=0
	await picture(game,directory+"/lance-interrupted.png")
	await game.get_tree().create_timer(.7).timeout
	var warden=game.enemies[2]
	warden.open_armor()
	warden.take_damage(999,Vector3.ZERO)
	game.player.position=game.warden_remains.position+Vector3(1.35,0,1.1)
	await picture(game,directory+"/warden-corpse-core.png")
	game.open_nearest()
	await picture(game,directory+"/warden-corpse-looted.png")
	game.toggle_inventory()
	await picture(game,directory+"/alchemy-core-inventory.png")
	game.toggle_inventory()
	game.player.invulnerability=0
	game.player.take_damage(100,Vector3.ZERO)
	await picture(game,directory+"/death-screen.png")
	game.respawn_player()
	await game.get_tree().create_timer(.8).timeout
	await picture(game,directory+"/village-respawn.png")
