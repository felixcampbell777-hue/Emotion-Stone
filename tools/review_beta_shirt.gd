extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	game.game_mode="beta"; game.start_new_game(false)
	game.gallery_mode=true; game.set_process(false); game.player.set_physics_process(false)
	game.current_world.visible=false
	for enemy in game.enemies:enemy.visible=false;enemy.ai_enabled=false
	var actor=game.player; var avatar=actor.get_node("BetaHero")
	var light=OmniLight3D.new();light.position=Vector3(0,1.6,-2);light.light_energy=1.6;light.omni_range=5;game.world_root.add_child(light)
	actor.position=Vector3.ZERO; actor.visual.rotation.y=0
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=35
	game.camera.position=Vector3(.45,1.38,-2.7); game.camera.look_at(Vector3(0,1.12,0))
	var directory="C:/Games/CoastalFoundation/art/character/shirt-review";DirAccess.make_dir_recursive_absolute(directory)
	for item in [["idle_loop","drag",0.0],["draw_sword","draw",.545],["attack_heavy","heavy",.53],["attack_lance","lance",.7],["parry_guard","parry",.3],["drag_walk_loop","drag",.25]]:
		actor.set_sword_drawn(item[0]!="idle_loop");actor.state="draw" if item[0]=="draw_sword" else "free"
		actor.play_clip(item[0],0);actor.action_transition_remaining=0
		actor.animator.seek(actor.animator.get_animation(actor.clips[item[0]]).length*item[2],true)
		if actor.sword_drawn:actor._pose_sword(item[1],item[2])
		avatar.synchronize()
		await create_timer(.2).timeout;await RenderingServer.frame_post_draw
		game.world_view.get_texture().get_image().save_png(directory+"/back-"+item[0]+".png")
	print("SHIRT_REVIEW_OK")
	quit()
