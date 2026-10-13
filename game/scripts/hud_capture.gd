extends RefCounted
func picture(game:Node,path:String) -> void:
	await game.get_tree().create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
func run(game:Node,directory:String) -> void:
	game.start_new_game(false); game.load_map("menagery",Vector2(10,0),true); game.camera_driver.set_mode("follow")
	game.player.set_physics_process(false)
	for hp in [100,25,12,2]:
		game.player.restore_health(hp); game.hud_feedback.update(0)
		await picture(game,directory+"/hud-health-%d.png" % hp)
	game.player.restore_stamina(0); game.hud_feedback.denied()
	await picture(game,directory+"/hud-stamina-denied.png")
	game.player.restore_health(40); game.player.restore_stamina(100)
	game.menagery.toggle(); game.menagery.tabs.current_tab=2; game.menagery.codex.filter="consumable"; game.menagery.codex.refresh(); game.menagery.codex.get_child(2).get_child(0).select(7)
	await picture(game,directory+"/hud-healing-codex.png")
	for entry in game.magic_items.catalog.items:
		if entry.category=="consumable":
			for dose in range(3): game.magic_items.claim(entry.id)
	game.menagery.close(); game.toggle_inventory(); game.inventory.selected_category="potions"; game.inventory.refresh()
	await game.get_tree().process_frame; await game.get_tree().process_frame
	game.inventory.box.get_child(0).scroll_vertical=10000
	await picture(game,directory+"/hud-healing-inventory.png")
	game.inventory.close(); game.magic_items.drink("renewal_draught"); game.magic_items.drink("renewal_draught"); game.magic_items.drink("mending_tonic"); game.magic_items.tick(3)
	await picture(game,directory+"/hud-healing-active.png")
	game.toggle_inventory(); game.inventory.selected_category="potions"; game.inventory.refresh(); await game.get_tree().process_frame; await game.get_tree().process_frame
	game.inventory.box.get_child(0).scroll_vertical=10000
	await picture(game,directory+"/hud-healing-stacks.png"); game.inventory.close()
	DisplayServer.window_set_size(Vector2i(960,540)); game.player.restore_health(12)
	await picture(game,directory+"/hud-small.png")
