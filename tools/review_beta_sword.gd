extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame; await process_frame
	game.game_mode="beta";game.start_new_game(false)
	game.gallery_mode=true; game.set_process(false); game.player.set_physics_process(false)
	for enemy in game.enemies:enemy.visible=false;enemy.ai_enabled=false
	var actor=game.player;var avatar=actor.get_node("BetaHero")
	actor.position=Vector3(0,0,-12);actor.visual.rotation.y=0
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=38
	game.camera.position=actor.position+Vector3(2.2,2.2,3.2);game.camera.look_at(actor.position+Vector3(0,.85,.45))
	var dir="C:/Games/CoastalFoundation/art/character/beta-sword-review";DirAccess.make_dir_recursive_absolute(dir)
	for item in [["drag_idle_loop","drag",0.0],["attack_heavy","heavy",.68],["attack_lance","lance",.7]]:
		actor.set_sword_drawn(true);actor.play_clip(item[0],0);actor.action_transition_remaining=0
		actor.animator.seek(actor.animator.get_animation(actor.clips[item[0]]).length*item[2],true)
		actor._pose_sword(item[1],item[2]);avatar.synchronize()
		await create_timer(.25).timeout;await RenderingServer.frame_post_draw
		game.world_view.get_texture().get_image().save_png(dir+"/native-"+item[1]+".png")
		if item[1]=="drag":
			game.camera.position=actor.position+Vector3(3.2,1.5,-3.8);game.camera.look_at(actor.position+Vector3(0,.65,-.65))
			await create_timer(.25).timeout;await RenderingServer.frame_post_draw
			game.world_view.get_texture().get_image().save_png(dir+"/native-drag-side.png")
			game.camera.position=actor.position+Vector3(2.2,2.2,3.2);game.camera.look_at(actor.position+Vector3(0,.85,.45))
	actor.set_sword_glow(true);actor.update_sword_energy(1.0);avatar.synchronize()
	await create_timer(.25).timeout;await RenderingServer.frame_post_draw
	game.world_view.get_texture().get_image().save_png(dir+"/native-energy.png")
	for part in actor.equipment.find_children("SwordBlade","MeshInstance3D",true,false):print("SOURCE_ENERGY ",part.get_active_material(0)," front ",part.get_active_material(0).get_shader_parameter("energy_front"))
	for part in avatar.sword.find_children("SwordBlade","MeshInstance3D",true,false):print("COPY_ENERGY ",part.get_active_material(0)," front ",part.get_active_material(0).get_shader_parameter("energy_front"))
	actor.set_sword_glow(false)
	await load("res://scripts/beta_locomotion_capture.gd").new().run(game,dir)
	quit()
