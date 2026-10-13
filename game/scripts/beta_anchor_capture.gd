extends RefCounted
func run(game:Control,directory:String) -> void:
	var actor=game.player;var hero=actor.get_node("BetaHero");var base=actor.position
	actor.set_physics_process(false);hero.set_process(false);actor.visual.rotation.y=0
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;game.camera.fov=38
	var light=DirectionalLight3D.new();game.world_root.add_child(light)
	light.rotation_degrees=Vector3(-25,150,0);light.light_energy=1.7
	for item in [["idle_loop",0.0,false,"idle"],["walk_loop",.25,false,"walk"],["walk_loop",.50,true,"run"],["draw_sword",.30,false,"draw"],["sheathe_sword",.70,false,"sheathe"]]:
		actor.set_sword_drawn(item[0]=="sheathe_sword");actor.sprinting=item[2]
		actor.state="draw" if item[0]=="draw_sword" else "sheathe" if item[0]=="sheathe_sword" else "free"
		actor.play_clip(item[0],0);actor.action_transition_remaining=0
		actor.animator.seek(actor.animator.get_animation(actor.clips[item[0]]).length*item[1],true)
		if item[3] in ["draw","sheathe"]:
			if actor.equipment.get_parent()!=actor.visual:actor.equipment.reparent(actor.visual,true)
			actor._pose_sword("draw",item[1])
		hero.synchronize()
		for view in ["back","side"]:
			game.camera.position=base+(Vector3(1.1,1.4,-3.4) if view=="back" else Vector3(3.4,1.3,-.4))
			game.camera.look_at(base+Vector3(0,.95,0))
			await game.get_tree().create_timer(.12).timeout;RenderingServer.force_draw()
			game.world_view.get_texture().get_image().save_png(directory+"/back-anchor-%s-%s.png"%[item[3],view])
	actor.set_sword_drawn(false);actor.play_clip("idle_loop",0);actor.animator.seek(0,true);hero.synchronize()
	hero.sword.visible=false
	game.camera.position=base+Vector3(.5,1.36,-1.65);game.camera.look_at(base+Vector3(-.10,1.17,-.08))
	await game.get_tree().create_timer(.12).timeout;RenderingServer.force_draw()
	game.world_view.get_texture().get_image().save_png(directory+"/back-anchor-detail.png")
	actor.set_sword_drawn(true);hero.synchronize();hero.sword.visible=false
	await game.get_tree().create_timer(.12).timeout;RenderingServer.force_draw()
	game.world_view.get_texture().get_image().save_png(directory+"/back-anchor-released.png")
	actor.set_sword_drawn(false);hero.synchronize();actor.sprinting=false
	hero.set_process(true);light.queue_free()
