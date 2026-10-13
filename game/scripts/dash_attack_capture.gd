extends RefCounted
func run(game:Control,directory:String) -> void:
	var actor=game.player;var driver=game.camera_driver
	var folder=directory+"/dash-attack";DirAccess.make_dir_recursive_absolute(folder)
	actor.set_physics_process(false);actor.position=Vector3(0,0,-5);actor.set_sword_drawn(true);actor.restore_stamina(actor.max_stamina)
	driver.yaw=PI;driver.first_pitch=0;actor.begin_dash_charge();actor.queue_dash_attack()
	var records=[]
	for index in range(74):
		if index==20: actor.release_dash()
		# move_and_slide uses the engine's current timestep: sample in real physics ticks.
		for tick in range(2):
			await game.get_tree().physics_frame
			actor._physics_process(1.0/60)
		driver.update_first_person()
		await game.get_tree().create_timer(.02).timeout;await RenderingServer.frame_post_draw
		game.get_viewport().get_texture().get_image().save_png(folder+"/frame-%02d.png"%index)
		records.append({"frame":index,"state":actor.state,"phase":actor.attack_phase() if actor.state=="light" else actor.state_time/maxf(.001,actor.state_duration),"queued":actor.dash_attack_queued,"blend":actor.dash_attack_blend,"stamina":actor.stamina,"position":[actor.position.x,actor.position.y,actor.position.z]})
	var file=FileAccess.open(folder+"/motion.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"  "));file.close()
	actor.set_sword_drawn(true);actor.set_physics_process(true)
