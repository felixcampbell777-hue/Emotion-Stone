extends RefCounted
func picture(game:Control,path:String) -> void:
	await game.get_tree().create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
func run(game:Control,directory:String) -> void:
	game.start_new_game(false);game.set_resolution(0)
	game.camera_driver.set_mode("first_person");game.camera_driver.yaw=PI;game.camera_driver.first_pitch=.08
	game.load_map("coastal_path",Vector2(0,-5),true)
	game.progression.restore({"tree_version":2,"xp":957383,"learned":["strength","form","mana","charge_thrust","mana_lance","efficient_swing","crushing_force","flowing_splash"]})
	game.apply_skill_stats()
	for id in ["opening_cut","return_cut","spinning_cut","heavy_mastery","thrust_power","thrust_control","water_power","lance_power","lance_control","endurance","dash","jump"]: game.learn_skill(id)
	game.learn_skill("dash_reach")
	game.toggle_inventory();game.inventory.show_page("level")
	game.skill_tree.category="active";game.skill_tree.selected_id="lance_control";game.skill_tree.refresh()
	await picture(game,directory+"/skills-lance-control.png")
	game.skill_tree.selected_id="dash_reach";game.skill_tree.refresh()
	await picture(game,directory+"/skills-dash-reach.png")
	for category in ["active","passive","capacity"]:
		game.skill_tree.category=category;game.skill_tree.refresh()
		await picture(game,directory+"/skills-upgrades-"+category+".png")
	game.inventory.show_page("skills");await picture(game,directory+"/skills-active-passive-slots.png")
	game.inventory.close();game.player.set_sword_drawn(false)
	game.player.begin_jump();game.player.set_physics_process(false)
	for i in range(12): game.player._physics_process(1.0/60)
	await picture(game,directory+"/skills-first-person-jump.png")
	for i in range(45): game.player._physics_process(1.0/60)
	game.player.position=Vector3(0,0,-5);game.player.restore_stamina(100)
	game.player.begin_dash_charge();game.player.state_time=1.5;game.player.release_dash()
	for i in range(12): game.player._physics_process(1.0/60)
	await picture(game,directory+"/skills-first-person-dash.png")
	for i in range(35): game.player._physics_process(1.0/60)
	await load("res://scripts/dash_attack_capture.gd").new().run(game,directory)
	game.player.set_physics_process(true)
	DisplayServer.window_set_size(Vector2i(960,540));game.toggle_inventory();game.inventory.show_page("level");game.skill_tree.category="active";game.skill_tree.refresh()
	await picture(game,directory+"/skills-upgrades-small.png")
	game.inventory.close();DisplayServer.window_set_size(Vector2i(1366,768))
	print("CAPTURE_OK "+directory)
