extends RefCounted
func run(game:Control,directory:String) -> void:
	var actor=game.player;var driver=game.camera_driver
	actor.set_physics_process(false);driver.yaw=PI;driver.first_pitch=0
	var shots=[]
	for action in ["ready","unarmed","walk","sprint","jump","dash","light","light2","light3","heavy","thrust_charge","thrust","water","lance_charge","lance_fire","parry","roll","stand","draw","sheathe"]:
		for group in ["thrust_gust","ground_slam"]:
			for effect in game.get_tree().get_nodes_in_group(group): effect.queue_free()
		for wave in game.water_waves:
			if is_instance_valid(wave): wave.queue_free()
		game.water_waves.clear()
		for projectile in game.projectiles:
			if is_instance_valid(projectile): projectile.queue_free()
		game.projectiles.clear()
		actor.position.y=game.current_world.ground_height(actor.position);actor.jump_active=false
		actor.set_sword_drawn(action!="unarmed");actor.restore_stamina(actor.max_stamina)
		actor.water_unlocked=true;actor.lance_unlocked=true;actor.thrust_unlocked=true;actor.roll_unlocked=true
		actor.combo_stage=0;actor.combo_remaining=0;actor.chain_blend=0;actor.action_transition_remaining=0
		if action in ["ready","unarmed","walk","sprint","jump","dash"]:
			actor.play_clip("drag_walk_loop" if action in ["walk","sprint"] else "drag_idle_loop" if actor.sword_drawn else "idle_loop",0)
			actor.animator.seek(.4,true);actor.sprinting=action=="sprint"
			if action=="jump": actor.position.y+=.8
			actor._pose_sword("drag",0)
		elif action.begins_with("light"):
			actor.combo_stage=0 if action=="light" else 1 if action=="light2" else 2;actor.combo_remaining=1
			actor.begin_attack("light")
		elif action=="heavy": actor.heavy_style="overhead";actor.begin_attack("heavy")
		elif action in ["thrust","thrust_charge"]: actor.heavy_style="charge_thrust";actor.begin_charge() if action=="thrust_charge" else actor.begin_attack("heavy",2,true)
		elif action=="water": actor.begin_water()
		elif action in ["lance_charge","lance_fire"]:
			actor.begin_water_lance()
			if action=="lance_fire": actor.state_time=actor.state_duration;actor._physics_process(0)
		elif action=="parry": actor.begin_parry()
		elif action in ["roll","stand"]:
			actor.begin_roll()
			if action=="stand": actor.state_time=actor.state_duration;actor._physics_process(0)
		elif action in ["draw","sheathe"]: actor.set_sword_drawn(action=="sheathe");actor.toggle_sword()
		actor.chain_blend=0;actor.action_transition_remaining=0
		var phases=[.2,.5,.9] if actor.state!="free" else [.5]
		for phase in phases:
			if actor.state!="free": actor.state_time=actor.state_duration*phase;actor._physics_process(0)
			driver.update_first_person()
			await game.get_tree().create_timer(.08).timeout;await RenderingServer.frame_post_draw
			var picture=game.get_viewport().get_texture().get_image()
			var name="first-person-%s-%02d.png"%[action,int(phase*100)]
			picture.save_png(directory+"/"+name)
			picture.resize(456,256,Image.INTERPOLATE_LANCZOS);picture.convert(Image.FORMAT_RGBA8);shots.append(picture)
	var sheet=Image.create(456*4,256*ceili(shots.size()/4.0),false,Image.FORMAT_RGBA8)
	for index in range(shots.size()): sheet.blit_rect(shots[index],Rect2i(0,0,456,256),Vector2i(index%4*456,index/4*256))
	sheet.save_png(directory+"/first-person-actions-sheet.png")
	actor.position.y=game.current_world.ground_height(actor.position);actor.set_sword_drawn(true);actor.set_physics_process(true)
