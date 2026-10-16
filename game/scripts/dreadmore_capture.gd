extends RefCounted
func picture(g:Node,path:String) -> void:
	await g.get_tree().create_timer(.12).timeout;await RenderingServer.frame_post_draw
	g.get_viewport().get_texture().get_image().save_png(path)
func view(g:Node,id:String,at:Vector2,yaw:float,pitch:float=0) -> void:
	g.load_map(id,at,true);g.player.set_physics_process(false)
	for e in g.enemies:e.ai_enabled=false;e.set_physics_process(false)
	g.camera_driver.yaw=yaw;g.camera_driver.first_pitch=pitch;g.camera_driver.update_first_person();g.toast_time=0
func run(g:Node,directory:String) -> void:
	g.game_mode="alpha2";g.alpha2_import_path="user://dreadmore-capture-no-import.json";g.start_new_game(false);g.alpha2.mark("begun");g.title_screen.visible=false;g.set_resolution(0);g.camera_driver.set_mode("first_person");g.player.set_sword_drawn(true)
	view(g,"a2_crossroads",Vector2(0,-21),0,-.12);await picture(g,directory+"/dreadmore-approach.png")
	var route=g.current_world.definition.exits.filter(func(e):return e.target=="a2_canyon")[0];g.dreadmore.request(route);await picture(g,directory+"/dreadmore-confirmation.png");g.dreadmore.confirmation.hide();g._refresh_simulation()
	for fixture in [[Vector2(0,49),0,-.15,"mouth"],[Vector2(-18,39),0,-.08,"ambush"],[Vector2(-14,24),-PI/2,-.08,"switchback"],[Vector2(12,-25),-.7,-.7,"clinging"]]:
		view(g,"a2_canyon",fixture[0],fixture[1],fixture[2]);await picture(g,directory+"/dreadmore-"+fixture[3]+".png")
	view(g,"a2_canyon",Vector2(-18,1),0,-.1);g.player.set_sword_drawn(false);await picture(g,directory+"/dreadmore-campfire-hidden.png")
	var pack=g.enemies.filter(func(e):return e.has_method("begin_tree_drop") and e.ambush_group=="dreadmore_sluice" and not e.canyon_support)
	pack[0].ai_enabled=true;pack[0]._drop_tick(.01);await picture(g,directory+"/dreadmore-campfire-warning.png")
	for e in pack:e.ai_enabled=true;e._drop_tick(.66);e._drop_tick(.4)
	g.camera_driver.first_pitch=-.9;g.camera_driver.update_first_person();await picture(g,directory+"/dreadmore-campfire-drop.png");g.player.set_sword_drawn(true)
	view(g,"a2_canyon",Vector2(18,-26),0,-.1)
	var boss=g.enemies.filter(func(e):return e.definition.kind=="canyon_fiend")[0]
	boss.ai_enabled=true;boss.simulation_enabled=true;boss._physics_process(.01);await picture(g,directory+"/dreadmore-drop-tell.png")
	boss._physics_process(1.5);boss._physics_process(.8);boss.animate();g.player.position=Vector3(18,0,-21);g.player.health=g.player.max_health;g.player.state="free";g.player.play_clip("drag_idle_loop",0);g.player.animator.seek(0,true);g.player._pose_sword("drag",0);g.camera_driver.first_pitch=-.08;g.camera_driver.update_first_person();g.toast_time=0;await picture(g,directory+"/dreadmore-fiend-ground.png")
	boss.state="cleave";boss.state_time=.35;boss.animate();await picture(g,directory+"/dreadmore-fiend-cleave.png")
	boss.take_lance_damage(100000,Vector3.ZERO);g.dreadmore.tick()
	view(g,"a2_grove",Vector2(0,11),0,-.05);await picture(g,directory+"/dreadmore-attunement-grove.png")
	g.player.position=Vector3(0,0,1);g.camera_driver.update_first_person();await picture(g,directory+"/dreadmore-attunement-stone.png")
