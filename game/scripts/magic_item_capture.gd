extends RefCounted
func picture(game:Node,path:String) -> void:
	await game.get_tree().create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
func run(game:Node,directory:String) -> void:
	game.load_map("menagery",Vector2(10,0),true)
	game.menagery.toggle(); game.menagery.tabs.current_tab=2
	await picture(game,directory+"/magic-codex.png")
	for entry in game.magic_items.catalog.items: game.magic_items.claim(entry.id)
	game.menagery.codex.refresh()
	await picture(game,directory+"/magic-codex-owned.png")
	game.menagery.close()
	for variant in range(5):
		for type in ["ring","torso","leggings","boots","headwear","necklace"]:
			var matches=game.magic_items.catalog.items.filter(func(e): return e.category==type)
			game.magic_items.equip("ring1" if type=="ring" else type,matches[mini(variant,matches.size()-1)].id)
		game.magic_items.equip("ring2",game.magic_items.catalog.items[(variant+1)%4].id)
		game.toggle_inventory(); game.inventory.selected_slot=""; game.inventory.show_page("equipment")
		await picture(game,directory+"/magic-equipment-set-%d.png" % (variant+1))
		game.inventory.close()
	game.player.position=Vector3(10,0,0); game.camera_driver.set_mode("follow"); game.camera_driver.yaw=0; game.player.visual.rotation.y=PI
	await picture(game,directory+"/magic-equipped-gameplay.png")
	game.player.set_physics_process(false); game.player.visual.rotation.y=0; game.camera_driver.distance=3.5; game.camera_driver.pitch=.50
	game.player.set_sword_drawn(true)
	for action in [["drag_walk_loop","drag",.25],["parry_guard","parry",.38],["attack_heavy","heavy",.67],["dodge_roll","roll",.48]]:
		game.player.play_clip(action[0],0)
		game.player.animator.seek(float(action[2])*game.player.animator.get_animation(game.player.clips[action[0]]).length,true)
		game.player._pose_sword(action[1],action[2]); game.player.skeleton.force_update_all_bone_transforms()
		await picture(game,directory+"/magic-equipped-"+action[1]+".png")
	game.player.set_sword_drawn(false); game.player.play_clip("idle_loop",0); game.player.set_physics_process(true)
	game.toggle_inventory(); game.inventory.selected_slot="headwear"; game.inventory.refresh()
	await picture(game,directory+"/magic-equipment-choices.png")
