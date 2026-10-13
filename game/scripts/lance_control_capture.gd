extends RefCounted
func run(game:Control,directory:String) -> void:
	var actor=game.player;var driver=game.camera_driver;var stability=actor.lance_stability
	var destination=directory+"/lance-control";DirAccess.make_dir_recursive_absolute(destination)
	var phases=[0,.08,.16,.18,.19,.20,.24,.30,.34,.35,.36,.40,.48,.51,.52,.53,.59,.65,.66,.67,.74,.80,.81,.82,.88,.93,.94,.95,.98,.985,.99,.995]
	var samples=[];actor.set_physics_process(false);driver.yaw=PI;driver.first_pitch=0
	for control in [0.0,.75]:
		actor.set_sword_drawn(true);actor.restore_stamina(actor.max_stamina);actor.lance_unlocked=true
		actor.lance_stability=control;actor.begin_water_lance();actor.action_transition_remaining=0
		for index in range(phases.size()):
			var phase=phases[index];actor.state_time=actor.state_duration*phase;actor._physics_process(0);driver.update_first_person()
			await game.get_tree().create_timer(.04).timeout;await RenderingServer.frame_post_draw
			var name=("trained" if control>0 else "untrained")+"-%02d.png"%index
			game.get_viewport().get_texture().get_image().save_png(destination+"/"+name)
			var kick=driver.lance_view_offset();var forward=-game.camera.global_basis.z
			samples.append({"frame":name,"phase":phase,"control":control,"yaw_degrees":rad_to_deg(kick.x),"pitch_degrees":rad_to_deg(kick.y),"forward":[forward.x,forward.y,forward.z]})
	var file=FileAccess.open(destination+"/motion.json",FileAccess.WRITE);file.store_string(JSON.stringify(samples,"\t"));file.close()
	actor.set_sword_drawn(true);actor.lance_stability=stability;actor._pose_sword("drag",0);driver.update_first_person();actor.set_physics_process(true)
