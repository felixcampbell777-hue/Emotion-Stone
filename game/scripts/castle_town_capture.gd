extends RefCounted
func run(game:Control,directory:String) -> void:
	var actor=game.player;var home=actor.position
	actor.position=Vector3(49,0,-10);actor.set_physics_process(false)
	actor.visual.rotation.y=0
	game.camera_driver.set_mode("follow");game.camera_driver.yaw=PI;game.camera_driver.recenter()
	await game.get_tree().create_timer(.6).timeout;RenderingServer.force_draw()
	game.world_view.get_texture().get_image().save_png(directory+"/castle-town-follow.png")
	game.camera_driver.set_mode("first_person");game.camera_driver.yaw=PI;game.camera_driver.first_pitch=0
	await game.get_tree().create_timer(.3).timeout;RenderingServer.force_draw()
	game.world_view.get_texture().get_image().save_png(directory+"/castle-town-first-person.png")
	game.camera_driver.set_mode("follow")
	game.gallery_mode=true;game.set_process(false)
	actor.set_sword_drawn(false);actor.state="free";actor.play_clip("idle_loop",0)
	actor.animator.seek(0,true);actor.get_node("BetaHero").synchronize()
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	game.camera.far=160
	for view in [
		["castle-town-overview",Vector3(32,38,-36),Vector3(50,0,1),60],
		["castle-town-gate",Vector3(18,3,-10),Vector3(37,2,-10),65],
		["castle-town-market",Vector3(44,3.4,-14),Vector3(54,2,2),66],
		["castle-town-keep",Vector3(52,3,-1),Vector3(53,5,18),65],
		["castle-town-street-first-person",Vector3(34,1.58,-10),Vector3(65,1.58,-10),75]]:
		game.camera.fov=view[3];game.camera.position=view[1];game.camera.look_at(view[2])
		await game.get_tree().create_timer(.3).timeout;RenderingServer.force_draw()
		game.world_view.get_texture().get_image().save_png(directory+"/"+view[0]+".png")
	actor.position=home;game.gallery_mode=false;game.set_process(true);actor.set_physics_process(true)
	game.camera_driver.set_mode("follow");game.camera_driver.recenter()
