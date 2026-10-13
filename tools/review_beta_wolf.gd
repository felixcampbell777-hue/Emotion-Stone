extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	game.game_mode="beta"; game.start_new_game(false)
	game.gallery_mode=true; game.set_process(false); game.player.set_physics_process(false)
	for enemy in game.enemies: enemy.visible=false; enemy.ai_enabled=false; enemy.set_physics_process(false)
	game.player.visible=false
	var wolf=game.enemies.filter(func(w): return w.definition.kind=="beta_wolf")[0]
	wolf.visible=true; wolf.position=Vector3(5,0,-10); wolf.visual.rotation.y=0
	wolf.animator.play(wolf.animation_names.idle); wolf.animator.seek(0,true)
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=38
	var focus=wolf.position+Vector3(0,.45,0)
	var dir="C:/Games/CoastalFoundation/art/character/wolf-review"; DirAccess.make_dir_recursive_absolute(dir)
	for item in [["coat",Vector3(1.7,1,2.6)],["side",Vector3(2.5,.55,.3)]]:
		game.camera.position=focus+item[1]; game.camera.look_at(focus)
		await create_timer(.3).timeout; await RenderingServer.frame_post_draw
		game.world_view.get_texture().get_image().save_png(dir+"/native-"+item[0]+".png")
	print("WOLF_REVIEW_OK ",wolf.animation_names)
	quit()
