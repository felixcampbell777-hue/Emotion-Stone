extends RefCounted
func run(game:Control,directory:String) -> void:
	var capture=load("res://scripts/alpha2_capture.gd").new()
	game.game_mode="alpha2";game.alpha2_import_path="user://no-facing-import.json";game.start_new_game(false);game.alpha2.mark("begun");game.set_resolution(0);game.player.set_sword_drawn(true)
	for fixture in [["a2_mill","library_crab"],["a2_mill","library_rat"],["a2_wood","library_boar"],["a2_wood","library_spider"],["a2_wood","library_wolf"],["a2_quarry","library_sentinel"],["a2_belfry","bellkeeper"]]:
		capture.view(game,fixture[0],Vector2(0,10),0,.12)
		for enemy in game.enemies:
			if enemy.definition.kind!=fixture[1]:enemy.visible=false;continue
			enemy.set_physics_process(false);enemy.ai_enabled=true;enemy.simulation_enabled=true
			game.player.position=enemy.position+Vector3(2,0,3);game.player.position.y=game.current_world.ground_height(game.player.position)
			game.camera_driver.yaw=atan2(2,3);game.camera_driver.first_pitch=.1;game.camera_driver.update_first_person()
			enemy.visual.rotation.y=-PI/2;enemy.state="cleave_tell" if fixture[1]=="bellkeeper" else "windup";enemy.state_time=.7;enemy._physics_process(.02)
			await capture.picture(game,directory+"/mob-facing-"+fixture[1]+"-windup.png")
			enemy.state="cleave" if fixture[1]=="bellkeeper" else "lunge";enemy.state_time=.4;enemy._physics_process(.001);enemy.art.animator.advance(.2);enemy.art.pose("attack",.6)
			await capture.picture(game,directory+"/mob-facing-"+fixture[1]+"-attack.png");break
	print("MOB_FACING_CAPTURE_COMPLETE");game.get_tree().quit()
