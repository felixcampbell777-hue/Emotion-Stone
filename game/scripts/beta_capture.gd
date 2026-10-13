extends RefCounted
func picture(game:Control,path:String,window:bool=false) -> void:
	await game.get_tree().create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	var viewport=game.get_viewport() if window else game.world_view
	viewport.get_texture().get_image().save_png(path)
func run(game:Control,directory:String) -> void:
	directory+="/beta"; DirAccess.make_dir_recursive_absolute(directory)
	game.title_screen.show_menu("user://beta-capture-missing.json"); game.title_screen.select_mode(1)
	await picture(game,directory+"/mode-selection.png",true)
	game.start_new_game(false)
	for enemy in game.enemies: enemy.ai_enabled=false
	game.camera_driver.set_mode("follow"); game.camera_driver.yaw=PI; game.camera_driver.recenter()
	await picture(game,directory+"/meadow.png",true)
	game.player.position=Vector3(0,0,6)
	await picture(game,directory+"/woodland.png",true)
	await load("res://scripts/castle_town_capture.gd").new().run(game,directory)
	await load("res://scripts/wolf_pack_capture.gd").new().run(game,directory)
	# Actual combat evidence: the low rat takes one normal opening cut.
	var rat=game.enemies.filter(func(enemy): return enemy.definition.kind=="beta_rat")[0]
	var rat_home=rat.position
	game.player.position=Vector3(0,0,-12); game.player.visual.rotation.y=0
	game.player.set_sword_drawn(true); game.player.restore_stamina(100)
	game.player.combo_remaining=0; game.player.combo_queued=false
	rat.position=Vector3(0,0,-10.8); rat.set_physics_process(false)
	await picture(game,directory+"/rat-before-hit.png",true)
	game.player.begin_attack("light")
	await game.get_tree().create_timer(1.8).timeout
	await picture(game,directory+"/rat-after-hit.png",true)
	rat.health=rat.max_health; rat.position=rat_home; rat.knockback=Vector3.ZERO; rat.state="idle"
	rat.set_physics_process(true); game.player.set_sword_drawn(false)
	game.gallery_mode=true; game.set_process(false); game.player.set_physics_process(false)
	game.player.position=Vector3(0,0,-12)
	for enemy in game.enemies: enemy.visible=false
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=38
	var base=game.player.position
	game.player.visual.rotation.y=0
	game.camera.position=base+Vector3(1.8,1.1,3.5); game.camera.look_at(base+Vector3(0,.9,0))
	await picture(game,directory+"/heroine-idle.png")
	for action in ["walk_loop","draw_sword","attack_light","parry_guard"]:
		game.player.set_sword_drawn(action!="walk_loop")
		for phase in [.25,.55,.8]:
			game.player.state="draw" if action=="draw_sword" else "free"
			game.player.play_clip(action,0); game.player.action_transition_remaining=0
			game.player.animator.seek(game.player.animator.get_animation(game.player.clips[action]).length*phase,true)
			if action!="walk_loop": game.player._pose_sword("light" if action=="attack_light" else "parry" if action=="parry_guard" else "draw",phase)
			await picture(game,directory+"/"+action+"-"+str(phase)+".png")
	game.camera.position=base+Vector3(2.8,1.1,-2.4); game.camera.look_at(base+Vector3(0,.95,0))
	game.player.set_sword_drawn(false)
	await picture(game,directory+"/longsword-back-carry.png")
	game.player.set_sword_drawn(true); game.player.play_clip("attack_heavy",0)
	game.player.animator.seek(game.player.animator.get_animation(game.player.clips.attack_heavy).length*.68,true)
	game.player._pose_sword("heavy",.68); game.player.get_node("BetaHero").synchronize()
	game.camera.position=base+Vector3(2.8,1.05,3.4); game.camera.look_at(base+Vector3(0,.65,.8))
	await picture(game,directory+"/longsword-ground-impact.png")
	game.player.play_clip("attack_lance",0)
	game.player.animator.seek(game.player.animator.get_animation(game.player.clips.attack_lance).length*.70,true)
	game.player._pose_sword("lance",.70); game.player.get_node("BetaHero").synchronize()
	game.camera.position=base+Vector3(2.2,2.5,3.6); game.camera.look_at(base+Vector3(0,.85,.45))
	game.player.set_sword_glow(true)
	for progress in [.84,1.0]:
		game.player.update_sword_energy(progress)
		await picture(game,directory+"/longsword-energy-"+str(progress)+".png")
	game.player.set_sword_glow(false)
	await picture(game,directory+"/longsword-restored-steel.png")
	game.player.play_clip("drag_idle_loop",0);game.player.animator.seek(0,true);game.player._pose_sword("drag",0)
	game.player.get_node("BetaHero").synchronize()
	game.camera.position=base+Vector3(3.2,1.5,-3.8);game.camera.look_at(base+Vector3(0,.65,-.65))
	await picture(game,directory+"/war-sword-ground-drag.png")
	await load("res://scripts/beta_anchor_capture.gd").new().run(game,directory)
	await load("res://scripts/beta_locomotion_capture.gd").new().run(game,directory)
	await load("res://scripts/beta_shirt_capture.gd").new().run(game,directory)
	for kind in ["beta_wolf","beta_rat","resin_slime","slime"]:
		for enemy in game.enemies:
			if enemy.definition.kind!=kind and enemy.get("style")!=kind: continue
			enemy.set_physics_process(false); enemy.visual.rotation.y=0
			enemy.visible=true
			# Move into the same clear patch for an unobstructed model/attack review.
			enemy.position=Vector3(5,0,-10)
			var focus=enemy.position+Vector3(0,.35,0)
			game.camera.position=focus+Vector3(1.7,1.0,2.6); game.camera.look_at(focus)
			await picture(game,directory+"/"+kind+".png")
			if kind.begins_with("beta_"):
				enemy.state="windup"; enemy.state_time=.25; enemy._physics_process(.01)
				await picture(game,directory+"/"+kind+"-attack.png")
			enemy.visible=false
			break
	game.gallery_mode=false; game.set_process(true); game.player.set_physics_process(true)
	game.player.set_sword_drawn(false); game.player.position=Vector3(0,0,-12)
	game.camera_driver.set_mode("follow")
	game.toggle_inventory(); game.inventory.show_page("equipment")
	await picture(game,directory+"/inventory.png",true)
	game.inventory.close(); game.toggle_pause()
	await picture(game,directory+"/pause.png",true)
	game.pause_menu.close()
	DirAccess.make_dir_recursive_absolute(directory+"/motion")
	await load("res://scripts/animation_capture.gd").new().run(game,directory+"/motion")
	print("CAPTURE_OK "+directory)
