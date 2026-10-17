extends RefCounted
func picture(g:Node,directory:String,label:String,at:Vector3,target:Vector3) -> void:
	g.player.position=at;g.camera_driver.yaw=atan2(-(target-at).x,-(target-at).z)
	var eye=at+Vector3.UP*1.6;var toward=target-eye;g.camera_driver.first_pitch=-atan2(toward.y,Vector2(toward.x,toward.z).length());g.camera_driver.update_first_person()
	g.toast.hide();g.toast_time=0
	await g.get_tree().create_timer(.5).timeout;await RenderingServer.frame_post_draw
	g.get_viewport().get_texture().get_image().save_png(directory+"/vault-"+label+".png")
func run(g:Node,directory:String) -> void:
	g.game_mode="world_rise";g.start_new_game(false);g.title_screen.hide();g._refresh_simulation();g.set_resolution(0);g.player.set_physics_process(false);g.set_process(false);g.set_physics_process(false);g.camera_driver.set_mode("first_person")
	var chamber=preload("res://scripts/rise_chamber.gd");var at=chamber.return_point()
	g.load_map("wr_floor_01",at,true)
	for i in range(60):g.current_world.update_details(g.player.position)
	for e in g.enemies:e.ai_enabled=false;e.set_physics_process(false)
	var entry=g.current_world.get_node("HiddenVaultEntrance")
	var approach=entry.to_global(Vector3(0,0,11));approach.y=g.current_world.ground_height(approach)
	await picture(g,directory,"hidden-entrance",approach,entry.global_position+Vector3.UP*3)
	g.worldrise.interact({"wr_chamber":"enter"})
	await picture(g,directory,"arrival",Vector3(0,0,35),Vector3(0,3,0))
	await picture(g,directory,"arena",Vector3(0,0,16),Vector3(0,5,-20))
	await picture(g,directory,"ceiling",Vector3(-10,0,5),Vector3(6,20,-16))
	await picture(g,directory,"edge",Vector3(20,0,0),Vector3(38,-5,0))
	await picture(g,directory,"return",Vector3(0,0,20),Vector3(0,3,38))
