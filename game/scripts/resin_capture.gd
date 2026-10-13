extends RefCounted
func picture(game:Node,path:String) -> void:
 await game.get_tree().process_frame; await RenderingServer.frame_post_draw
 game.get_viewport().get_texture().get_image().save_png(path)
func run(game:Node,directory:String) -> void:
 game.start_new_game(false); game.load_map("menagery",Vector2(10,2),true); game.set_resolution(0); game.camera_driver.set_mode("follow"); game.camera_driver.yaw=.35; game.camera_driver.distance=7
 game.home_intro_complete=true; game.quest_stage="active"
 game.player.set_physics_process(false); game.player.visual.rotation.y=PI; game.player.set_sword_drawn(true)
 var resin=game.menagery.spawn("2E"); resin.position=Vector3(10,0,-4); resin.home=resin.position; resin.set_physics_process(false); resin.ai_enabled=false
 await game.get_tree().create_timer(.45).timeout
 resin._release_ability(); var gloop=game.get_tree().get_nodes_in_group("resin_gloop")[-1]; gloop.set_physics_process(false); gloop._physics_process(gloop.duration*.5)
 await picture(game,directory+"/resin-gloop-lob.png")
 gloop._physics_process(gloop.duration*.5)
 var patch=game.get_tree().get_nodes_in_group("menagery_effect").filter(func(node): return node.has_method("contains_player"))[-1]; patch.set_physics_process(false)
 patch._physics_process(.12); await picture(game,directory+"/resin-puddle-splash.png")
 resin.ai_enabled=true; patch._physics_process(.01); resin._physics_process(.6)
 await picture(game,directory+"/resin-dash-charge.png")
 resin._physics_process(.6)
 for i in range(15):
  await game.get_tree().physics_frame; resin._physics_process(1.0/60)
 await picture(game,directory+"/resin-dash-release.png")
 print("RESIN_CAPTURE_OK")
