extends RefCounted
func picture(game:Node,path:String) -> void:
	await game.get_tree().process_frame; await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
func freeze(game:Node) -> void:
	game.player.set_physics_process(false)
	for enemy in game.enemies: enemy.set_physics_process(false)
func tick(game:Node,queen:Node,seconds:float) -> void:
	for i in range(ceili(seconds*60)):
		await game.get_tree().physics_frame
		queen._physics_process(1.0/60)
func run(game:Node,directory:String) -> void:
	game.start_new_game(false); game.home_intro_complete=true; game.quest_stage="active"; game.set_resolution(0)
	game.load_map("jungle_approach",Vector2(10,0),true); freeze(game); game.camera_driver.set_mode("follow"); game.camera_driver.yaw=PI/2; game.camera_driver.pitch=.45; game.camera_driver.distance=8
	await game.get_tree().create_timer(.4).timeout
	await picture(game,directory+"/jungle-canopy-path.png")
	var first=game.enemies[0]; first._physics_process(.01)
	await picture(game,directory+"/jungle-four-drop-warnings.png")
	for enemy in game.enemies: enemy._physics_process(.65); enemy._physics_process(.4)
	await picture(game,directory+"/jungle-slimes-descending.png")
	game.load_map("queen_arena",Vector2(4,2),true); freeze(game); game.player.set_sword_drawn(true); game.camera_driver.distance=11; game.camera_driver.yaw=1.25; game.player.visual.rotation.y=-1.85
	var queen=game.enemies[0]; queen.ai_enabled=true
	queen.visual.rotation.y=atan2(game.player.position.x-queen.position.x,game.player.position.z-queen.position.z)
	await game.get_tree().create_timer(.4).timeout
	await picture(game,directory+"/queen-sloped-arena.png")
	queen._splash_brood(); var flights=game.get_tree().get_nodes_in_group("queen_brood").duplicate()
	for flight in flights: flight.set_physics_process(false); flight._physics_process(flight.duration*.5)
	await picture(game,directory+"/queen-four-color-gloop.png")
	for flight in flights: flight._physics_process(flight.duration*.5)
	var cores=game.get_tree().get_nodes_in_group("queen_brood").filter(func(node): return node.has_method("setup_core"))
	for core in cores: core.set_physics_process(false); core._physics_process(.1)
	await picture(game,directory+"/queen-core-splashes.png")
	for core in cores: core._physics_process(2.5)
	await picture(game,directory+"/queen-goop-gathering.png")
	for core in cores: core._physics_process(2.3)
	await picture(game,directory+"/queen-slimes-forming.png")
	for core in cores: core._physics_process(.15)
	for enemy in game.enemies: enemy.set_physics_process(false)
	await picture(game,directory+"/queen-hatched-brood.png")
	queen.attack_index=1; queen._start_attack()
	await picture(game,directory+"/queen-landing-warning.png")
	await tick(game,queen,1.92)
	await picture(game,directory+"/queen-airborne-slam.png")
	await tick(game,queen,.61)
	await picture(game,directory+"/queen-slam-impact.png")
	queen.attack_index=2; queen._start_attack()
	await picture(game,directory+"/queen-charge-warning.png")
	print("QUEEN_CAPTURE_OK")
