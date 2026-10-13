extends RefCounted
func run(game:Control,directory:String) -> void:
	var actor=game.player;var avatar=actor.get_node("BetaHero")
	var light=OmniLight3D.new();light.position=actor.position+Vector3(0,1.6,-2)
	light.omni_range=5;light.light_energy=1.6;game.world_root.add_child(light)
	var world_visible=game.current_world.visible;game.current_world.visible=false
	avatar.set_process(false)
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;game.camera.fov=35
	game.camera.position=actor.position+Vector3(.4,1.35,-2.7);game.camera.look_at(actor.position+Vector3(0,1.12,0))
	for item in [["idle_loop","drag",0.0],["draw_sword","draw",.545],["attack_heavy","heavy",.53],["attack_lance","lance",.7],["parry_guard","parry",.3],["drag_walk_loop","drag",.25]]:
		actor.set_sword_drawn(item[0]!="idle_loop");actor.state="draw" if item[0]=="draw_sword" else "free"
		actor.play_clip(item[0],0);actor.action_transition_remaining=0
		actor.animator.seek(actor.animator.get_animation(actor.clips[item[0]]).length*item[2],true)
		if actor.sword_drawn:actor._pose_sword(item[1],item[2])
		avatar.synchronize();avatar.sword.visible=false;avatar.harness.visible=false
		await game.get_tree().create_timer(.2).timeout;await RenderingServer.frame_post_draw
		game.world_view.get_texture().get_image().save_png(directory+"/shirt-back-"+item[0]+".png")
	light.queue_free();game.current_world.visible=world_visible;avatar.set_process(true)
	print("SHIRT_CAPTURE_OK")
