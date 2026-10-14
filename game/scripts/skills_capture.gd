extends RefCounted
func picture(game:Control,path:String) -> void:
	await game.get_tree().create_timer(.15).timeout;await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
func run(game:Control,directory:String) -> void:
	game.game_mode="beta";game.start_new_game();game.set_resolution(0);game.camera_driver.set_mode("first_person")
	game.progression.award(957383)
	for id in ["form","strength","mana","flowing_counter","measured_recovery","breaker","undertow"]: game.learn_skill(id)
	game.update_progression_ui();game.select_special_attack("undertow")
	for enemy in game.enemies: enemy.ai_enabled=false;enemy.position.x+=30
	game.toggle_inventory();game.inventory.show_page("skills")
	await picture(game,directory+"/combat-skills-equipped.png")
	game.inventory.slots.get_parent().scroll_vertical=10000
	await picture(game,directory+"/combat-skills-passives.png")
	game.inventory.show_page("level");game.skill_tree.category="all";game.skill_tree.selected_id="undertow";game.skill_tree.refresh()
	game.skill_tree.scroll.scroll_vertical=10000;await picture(game,directory+"/combat-skills-upgrades.png");game.inventory.close()
	game.player.position=Vector3(12,0,-12);game.player.visual.rotation.y=0;game.camera_driver.yaw=PI;game.camera_driver.first_pitch=-.13
	game.player.set_sword_drawn(true);game.player.restore_stamina(100);game.player.set_physics_process(false)
	var target=game.enemies.filter(func(enemy): return enemy.definition.kind=="slime")[0]
	target.position=game.player.position+Vector3(0,0,3);target.set_physics_process(false)
	game.player.begin_water(true);game.player.state_time=.7*game.player.state_duration
	await game.get_tree().physics_frame;game.player._physics_process(0);game.camera_driver.update_first_person(0)
	var wave=game.projectiles[-1];wave.set_physics_process(false);wave.advance(.5);wave.advance(.18)
	await picture(game,directory+"/undertow-pull.png")
	game.player.set_sword_drawn(true);game.player.begin_parry();game.player.state_time=.3;target.position=game.player.position+Vector3(0,0,1.4)
	game.player.try_parry(target);game.player.begin_counter();game.player.state_time=.25*game.player.state_duration
	await game.get_tree().physics_frame;game.player._physics_process(.17);game.camera_driver.update_first_person(0)
	await picture(game,directory+"/flowing-counter.png")
