extends RefCounted
## Capture the actual imported poses and runtime weapon transform at matching phases.
func picture(game: Node, path: String, world_only: bool=false) -> void:
	await game.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var viewport=game.world_view if world_only else game.get_viewport()
	viewport.get_texture().get_image().save_png(path)

func run(game: Node, directory: String) -> void:
	game.load_map("slime_forest",Vector2(0,3.6))
	game.player.restore_health(100)
	game.player.set_sword_drawn(true)
	game.player.visual.rotation.y=PI
	game.enemies[0].ai_enabled=false
	await game.get_tree().create_timer(.8).timeout
	await picture(game,directory+"/forest-game.png")
	game.player.set_sword_drawn(false)
	game.player.position=Vector3(-2.2,0,4.8)
	game.player.restore_stamina(100)
	Input.action_press("sprint")
	Input.action_press("move_right")
	await game.get_tree().create_timer(.7).timeout
	await picture(game,directory+"/sprint-game.png")
	Input.action_release("move_right")
	Input.action_release("sprint")
	game.toggle_help()
	await game.get_tree().create_timer(.1).timeout
	await picture(game,directory+"/help-game.png")
	game.toggle_help()
	# Capture a real telegraphed lunge, guard window, and successful repel.
	DirAccess.make_dir_recursive_absolute(directory+"/parry-cycle")
	game.player.set_sword_drawn(true)
	game.player.restore_stamina(100)
	game.player.position=Vector3(0,0,3)
	game.player.visual.rotation.y=0
	var enemy=game.enemies[0]
	enemy.position=Vector3(0,0,4.4)
	enemy.state="idle"
	enemy.ai_enabled=true
	for tick in range(120):
		await game.get_tree().physics_frame
		if enemy.state=="windup" and enemy.state_time<=.07:
			break
	game.player.begin_parry()
	var parry_samples=[]
	var parry_start=Time.get_ticks_msec()
	var parry_captured=false
	for sample in range(42):
		await game.get_tree().physics_frame
		await game.get_tree().physics_frame
		await picture(game,directory+"/parry-cycle/frame-%03d.png" % sample,true)
		parry_samples.append(Time.get_ticks_msec()-parry_start)
		if game.player.parry_resolved and not parry_captured:
			await game.get_tree().physics_frame
			await game.get_tree().physics_frame
			await picture(game,directory+"/parry-game.png")
			parry_captured=true
	if not parry_captured or game.player.health!=100:
		push_error("Rendered parry did not repel the actual slime lunge")
	var parry_timings=FileAccess.open(directory+"/parry-cycle/timings.json",FileAccess.WRITE)
	parry_timings.store_string(JSON.stringify(parry_samples))
	parry_timings.close()
	enemy.ai_enabled=false
	# Record a real heavy swing, including its collision-limited forward movement.
	DirAccess.make_dir_recursive_absolute(directory+"/heavy-cycle")
	game.player.position=Vector3(-2.2,0,4.8)
	game.player.visual.rotation.y=PI
	game.player.restore_stamina(100)
	game.enemies[0].position=Vector3(3,0,1.8)
	await game.get_tree().create_timer(.5).timeout
	game.player.begin_attack("heavy")
	var samples=[]
	var cycle_start=Time.get_ticks_msec()
	var index=0
	while game.player.state=="heavy":
		await game.get_tree().physics_frame
		await game.get_tree().physics_frame
		await picture(game,directory+"/heavy-cycle/frame-%03d.png" % index,true)
		samples.append(Time.get_ticks_msec()-cycle_start)
		index+=1
	var timings=FileAccess.open(directory+"/heavy-cycle/timings.json",FileAccess.WRITE)
	timings.store_string(JSON.stringify(samples))
	timings.close()
	await picture(game,directory+"/heavy-crater.png")
	# Record the real queued three-hit sequence, with per-strike stamina costs.
	DirAccess.make_dir_recursive_absolute(directory+"/combo-cycle")
	game.player.position=Vector3(-2.2,0,4.8)
	game.player.visual.rotation.y=PI
	game.player.combo_remaining=0
	game.player.restore_stamina(100)
	game.player.begin_attack("light")
	var combo_samples=[]
	var combo_start=Time.get_ticks_msec()
	var combo_index=0
	while game.player.state=="light":
		if game.player.combo_stage<3 and not game.player.combo_queued and game.player.state_time/game.player.state_duration>.55:
			game.player.queue_combo()
		await game.get_tree().physics_frame
		await game.get_tree().physics_frame
		await picture(game,directory+"/combo-cycle/frame-%03d.png" % combo_index,true)
		combo_samples.append(Time.get_ticks_msec()-combo_start)
		if game.player.state=="light" and game.player.combo_stage==3 and game.player.state_time/game.player.state_duration>.5 and game.player.state_time/game.player.state_duration<.56:
			await picture(game,directory+"/combo-spin-game.png")
		combo_index+=1
	var combo_timings=FileAccess.open(directory+"/combo-cycle/timings.json",FileAccess.WRITE)
	combo_timings.store_string(JSON.stringify(combo_samples))
	combo_timings.close()
	await picture(game,directory+"/spin-crater.png")
	if game.player.combo_stage!=3:
		push_error("Rendered combo did not reach the spinning third strike")
	# Water is recorded from the real Q input and actual projectile simulation.
	DirAccess.make_dir_recursive_absolute(directory+"/water-cycle")
	game.player.position=Vector3(0,0,4.8)
	game.player.visual.rotation.y=PI
	game.player.set_sword_drawn(true)
	game.player.restore_stamina(100)
	game.enemies[0].position=Vector3(0,0,.8)
	game.enemies[0].health=60
	game.enemies[0].knockback=Vector3.ZERO
	var water_key=InputEventKey.new()
	water_key.physical_keycode=KEY_Q
	water_key.pressed=true
	Input.parse_input_event(water_key.duplicate())
	await game.get_tree().physics_frame
	water_key.pressed=false
	Input.parse_input_event(water_key.duplicate())
	var water_samples=[]
	var water_started=Time.get_ticks_msec()
	for sample in range(51):
		await game.get_tree().physics_frame
		await game.get_tree().physics_frame
		await picture(game,directory+"/water-cycle/frame-%03d.png" % sample,true)
		water_samples.append(Time.get_ticks_msec()-water_started)
		if sample==24:
			await picture(game,directory+"/water-sweep-game.png")
	var water_timings=FileAccess.open(directory+"/water-cycle/timings.json",FileAccess.WRITE)
	water_timings.store_string(JSON.stringify(water_samples))
	water_timings.close()
	if game.enemies[0].health>=60:
		push_error("Rendered water sweep did not damage the forest slime")
	# Show a drawn sprint diagonally into a shortened heavy wind-up.
	game.player.position=Vector3(-2,0,5)
	game.player.visual.rotation.y=PI
	game.player.set_sword_drawn(true)
	game.player.restore_stamina(100)
	game.enemies[0].position=Vector3(4,0,1.5)
	Input.action_press("move_up")
	Input.action_press("move_right")
	Input.action_press("sprint")
	await game.get_tree().create_timer(.5).timeout
	await picture(game,directory+"/sword-rush-game.png")
	game.player.begin_attack("heavy")
	Input.action_release("move_up")
	Input.action_release("move_right")
	Input.action_release("sprint")
	await game.get_tree().create_timer(.65).timeout
	await picture(game,directory+"/rushing-heavy-game.png")
	if not game.player.attack_rushing:
		push_error("Rendered forward rush did not accelerate the heavy attack")
	# Show the sustained pommel charge, forward two-hand pose, piercing beam and impact.
	game.load_map("herb_glade",Vector2(0,8.5))
	game.player.position=Vector3(0,0,8.5)
	game.player.visual.rotation.y=0
	game.camera.size=6.2
	game.camera_offset=Vector3(0,8,10)
	game.player.set_sword_drawn(true)
	game.player.restore_stamina(100)
	game.selected_special_attack="water_lance"
	for mob in game.enemies:
		mob.ai_enabled=false
	var warden=game.enemies.filter(func(candidate): return candidate.definition.kind=="warden")[0]
	game.player.begin_water_lance()
	var early_samples=0
	var halfway=false
	var final_charge=false
	var blade_half=false
	var blade_full=false
	while game.player.state=="lance_charge":
		await game.get_tree().physics_frame
		if early_samples<4 and game.player.state_time>=.28*float(early_samples+1):
			await picture(game,directory+"/lance-entry-"+str(early_samples)+".png")
			early_samples+=1
		if not halfway and game.player.state_time>=1.45:
			await picture(game,directory+"/water-lance-charge.png")
			halfway=true
		if not final_charge and game.player.state_time>=2.72:
			await picture(game,directory+"/water-lance-charge-final.png")
			final_charge=true
		if not blade_half and game.player.state_time>=2.65:
			await picture(game,directory+"/lance-energy-half.png")
			blade_half=true
		if not blade_full and game.player.state_time>=2.95:
			await picture(game,directory+"/lance-energy-full.png")
			blade_full=true
	await game.get_tree().physics_frame
	await game.get_tree().physics_frame
	await picture(game,directory+"/water-lance-beam.png")
	for sample in range(16):
		await game.get_tree().physics_frame
		if warden.health<=0:
			await picture(game,directory+"/water-lance-impact.png")
			break
	var recovery_samples=0
	while game.player.state=="lance_fire":
		await game.get_tree().physics_frame
		if game.player.state_time>=.14*float(recovery_samples+1):
			await picture(game,directory+"/lance-recovery-"+str(recovery_samples)+".png")
			recovery_samples+=1
	await picture(game,directory+"/lance-restored-steel.png")
	game.player.set_sword_drawn(true)
	game.toggle_inventory()
	await picture(game,directory+"/water-lance-inventory.png")
	game.toggle_inventory()
	game.toggle_skills()
	await picture(game,directory+"/water-lance-skills.png")
	game.toggle_skills()
	game.player.set_physics_process(false)
	game.enemies[0].set_physics_process(false)
	game.gallery_mode=true
	game.camera.size=5.8
	game.camera_offset=Vector3(0,7,13)
	game.current_world.visible=false
	game.enemies[0].visible=false
	game.player.position=Vector3(-.7,0,0)
	game.player.visual.rotation.y=PI/2
	game.player.play_clip("drag_walk_loop",0)
	game.player.animator.seek(.33,true)
	game.player._pose_sword("drag",0)
	await game.get_tree().create_timer(.5).timeout
	await picture(game,directory+"/sword-drag.png",true)
	game.player.visual.rotation.y=0
	game.player.play_clip("drag_walk_loop",0)
	game.player.animator.seek(game.player.animator.get_animation(game.player.clips.drag_walk_loop).length*.23,true)
	game.player._pose_sword("drag",0)
	game.player.begin_action_transition(.18)
	game.player.play_clip("parry_guard",0)
	for sample in range(13):
		var elapsed=float(sample)/60.0
		var phase=elapsed/float(game.player.combat.parry.duration)
		game.player.animator.seek(game.player.animator.get_animation(game.player.clips.parry_guard).length*phase,true)
		game.player._pose_sword("parry",phase)
		game.player.blend_action_transition(1.0/60.0)
		if sample in [0,4,8,12]:
			await picture(game,directory+"/parry-transition-"+str(sample)+".png",true)
	for phase in [.08,.18,.30,.50,.78,.90]:
		game.player.visual.rotation.y=0
		game.player.play_clip("parry_guard",0)
		game.player.animator.seek(game.player.animator.get_animation(game.player.clips.parry_guard).length*phase,true)
		game.player._pose_sword("parry",phase)
		await picture(game,directory+"/parry-right-side-"+str(int(phase*100))+".png",true)
	game.player.play_clip("drag_walk_loop",0)
	game.player.visual.rotation.y=PI/2
	for phase in [.25,.65]:
		game.player.animator.seek(game.player.animator.get_animation(game.player.clips.drag_walk_loop).length*phase,true)
		game.player._pose_sword("drag",0)
		await picture(game,directory+"/sword-burden-walk-"+str(int(phase*100))+".png",true)
	for attack in [{"kind":"light","phase":.49},{"kind":"heavy","phase":.50},{"kind":"heavy","phase":.68}]:
		game.player.state=attack.kind
		game.player.state_duration=float(game.player.combat[attack.kind].duration)
		game.player.state_time=game.player.state_duration*attack.phase
		game.player.visual.rotation.y=0
		game.player.play_clip("attack_"+attack.kind,0)
		game.player.animator.seek(game.player.animator.get_animation(game.player.clips["attack_"+attack.kind]).length*attack.phase,true)
		game.player._pose_sword(attack.kind,attack.phase)
		await picture(game,directory+"/sword-"+attack.kind+"-"+str(int(attack.phase*100))+".png",true)
	game.player.state="free"
	for pose in [{"name":"guard","clip":"parry_guard","motion":"parry","phase":.25},{"name":"water-windup","clip":"attack_water","motion":"water","phase":.25},{"name":"water-release","clip":"attack_water","motion":"water","phase":.55}]:
		game.player.visual.rotation.y=0
		game.player.play_clip(pose.clip,0)
		game.player.animator.seek(game.player.animator.get_animation(game.player.clips[pose.clip]).length*pose.phase,true)
		game.player._pose_sword(pose.motion,pose.phase)
		await picture(game,directory+"/pose-"+pose.name+".png",true)
	game.player.set_sword_glow(true,2.2)
	game.player.update_sword_energy(1.0)
	for phase in [.08,.20,.34,.72]:
		game.player.visual.rotation.y=0
		game.player.play_clip("attack_lance",0)
		game.player.animator.seek(game.player.animator.get_animation(game.player.clips.attack_lance).length*phase,true)
		game.player._pose_sword("lance",phase)
		await picture(game,directory+"/pose-lance-"+str(int(phase*100))+".png",true)
	game.player.set_sword_glow(false)
	game.player.visual.rotation.y=PI/2
	game.player.play_clip("attack_lance",0)
	game.player.animator.seek(game.player.animator.get_animation(game.player.clips.attack_lance).length*.65,true)
	game.player._pose_sword("lance",.65)
	game.player.set_sword_glow(true,2.2)
	for charge in [.55,.87,.99]:
		game.player.update_sword_energy(charge)
		await picture(game,directory+"/blade-energy-"+str(int(charge*100))+".png",true)
	game.player.set_sword_glow(false)
	game.player.set_sword_drawn(false)
	game.player.visual.rotation.y=0
	game.camera.size=4.5
	var mother=game.Actor.new()
	mother.configure(game.read_data("res://content/characters/mother.json"))
	mother.position=Vector3(1.15,0,0)
	game.world_root.add_child(mother)
	await picture(game,directory+"/mother-wrapped.png",true)
	mother.set_arm_wrapped(false)
	await picture(game,directory+"/mother-revealed.png",true)
	mother.queue_free()
	game.gallery_mode=false
	game.camera.size=game.config.camera_size
	game.camera_offset=Vector3(game.config.camera_offset[0],game.config.camera_offset[1],game.config.camera_offset[2])
	game.player.set_physics_process(true)
	game.load_map("home_downstairs",Vector2(-.1,-2.8))
	game.mother_unwrapped=false
	await game.get_tree().create_timer(.5).timeout
	game.open_nearest()
	game.advance_dialogue()
	await picture(game,directory+"/mother-dialogue.png")
	game.conversation.reveal_arm()
	await picture(game,directory+"/mother-reveal-dialogue.png")
	game.dialog.visible=false

	game.conversation.close()
	await capture_slam_and_roll(game,directory)
	await capture_thrust(game,directory)
	await load("res://scripts/animation_capture.gd").new().run(game,directory)

func capture_slam_and_roll(game:Node,directory:String) -> void:
	var saved_focus=game.config.camera_focus_offset.duplicate()
	# Earlier fixture strikes may permanently defeat these actors. Reset only this capture session.
	game.defeated_enemies.clear()
	game.config.camera_focus_offset=[0,0,0]
	game.set_resolution(640)
	game.conversation.close()
	game.camera_driver.set_mode("overhead")
	game.load_map("herb_glade",Vector2(0,14),true)
	game.camera.size=5.8
	game.camera_offset=Vector3(0,6,8)
	game.player.set_physics_process(false)
	game.player.input_enabled=true
	game.player.set_sword_drawn(true)
	game.player.visual.rotation.y=PI
	for enemy in game.enemies:
		enemy.respawn()
		enemy.set_physics_process(false)
	game.player.play_clip("attack_heavy",0)
	game.player.animator.seek(game.player.animator.get_animation(game.player.clips.attack_heavy).length*.68,true)
	game.player._pose_sword("heavy",.68)
	var at=game.player.sword_tip()
	game.enemies[0].position=Vector3(at.x+.8,0,at.z)
	game.enemies[1].position=Vector3(at.x-1.6,0,at.z)
	game.enemies[2].position=Vector3(at.x,0,at.z-2)
	for enemy in game.enemies:
		enemy.state="lunge"
	game._ground_slam(at,true)
	var effect=game.get_tree().get_nodes_in_group("ground_slam").back()
	effect.set_physics_process(false)
	for tick in [0.08,0.14,0.14]:
		effect._physics_process(tick)
		await picture(game,directory+"/slam-shockwave-%03d.png" % roundi(effect.age*100),true)
	game.load_map("coastal_path",Vector2(0,3),true)
	game.camera.size=4.6
	game.camera_offset=Vector3(0,3,8)
	game.player.set_physics_process(true)
	game.player.set_sword_drawn(true)
	game.player.visual.rotation.y=0
	game.player.roll_unlocked=true
	game.player.restore_stamina(100)
	game.player.begin_roll()
	for tick in range(35): await game.get_tree().physics_frame
	game.player.begin_attack("light")
	while game.player.state=="roll": await game.get_tree().physics_frame
	DirAccess.make_dir_recursive_absolute(directory+"/roll-light-cycle")
	for tick in range(20):
		await game.get_tree().physics_frame
		await picture(game,directory+"/roll-light-cycle/frame-%03d.png" % tick,true)
	while game.player.state=="light": await game.get_tree().physics_frame
	game.player.roll_unlocked=false
	game.config.camera_focus_offset=saved_focus

func capture_thrust(game:Node,directory:String) -> void:
	game.load_map("coastal_path",Vector2(-5,0),true)
	game.camera_driver.set_mode("overhead")
	game.config.camera_focus_offset=[0,0,0]
	game.camera.size=5.5
	game.camera_offset=Vector3(0,3,8)
	game.set_resolution(640)
	game.current_world.visible=false
	for npc in game.npcs: npc.visible=false
	var inspection_floor=load("res://scripts/props.gd").box(game.world_root,Vector3(0,-.12,0),Vector3(60,.08,60),"#7c8c81")
	var actor=game.player
	actor.set_sword_drawn(true)
	actor.thrust_unlocked=true
	actor.heavy_style="charge_thrust"
	actor.restore_stamina(100)
	actor.restore_health(100)
	actor.visual.rotation.y=PI/2
	var down=InputEventMouseButton.new()
	down.button_index=MOUSE_BUTTON_LEFT
	down.pressed=true
	down.position=game.world_rect.get_center()
	game._unhandled_input(down)
	for tick in range(240):
		await game.get_tree().physics_frame
		if tick in [42,120,239]: await picture(game,directory+"/thrust-charge-%03d.png" % tick,true)
	var up=down.duplicate()
	up.pressed=false
	game._input(up)
	DirAccess.make_dir_recursive_absolute(directory+"/thrust-release-cycle")
	var tick=0
	while actor.state=="thrust" and tick<360:
		await game.get_tree().physics_frame
		if tick in [0,6,12,24,36,54,72,90,120,150,180,210,240]:
			await picture(game,directory+"/thrust-release-cycle/frame-%03d.png" % tick,true)
		tick+=1
	actor.set_sword_drawn(true)
	actor.restore_stamina(100)
	actor.invulnerability=0
	actor.begin_charge()
	for frame in range(45): await game.get_tree().physics_frame
	actor.take_damage(10,Vector3.ZERO)
	for frame in range(10): await game.get_tree().physics_frame
	await picture(game,directory+"/thrust-interrupted.png",true)
	while actor.state=="stagger": await game.get_tree().physics_frame
	# Pressure fan in the real forest, with the new extended pose and targets.
	inspection_floor.queue_free()
	game.current_world.visible=true
	game.load_map("herb_glade",Vector2(0,14),true)
	game.current_world.visible=false
	var gust_floor=load("res://scripts/props.gd").box(game.world_root,Vector3(0,-.12,0),Vector3(60,.08,60),"#7c8c81")
	game.camera.size=5.5
	game.camera_offset=Vector3(8,4,4)
	actor.set_physics_process(false)
	actor.set_sword_drawn(true)
	actor.visual.rotation.y=0
	actor.attack_direction=Vector3.BACK
	actor.state="thrust"
	actor.state_time=actor.thrust_windup_seconds+actor.thrust_launch_seconds+.08
	actor.play_clip("attack_thrust",0)
	actor.animator.seek(actor.animator.get_animation(actor.clips.attack_thrust).length*.64,true)
	actor._pose_sword("thrust",.64)
	actor.thrust_wind_fx.update_wind(actor,.08)
	for enemy in game.enemies:
		enemy.respawn()
		enemy.set_physics_process(false)
	game.enemies[0].position=Vector3(0,0,16.1)
	game.enemies[1].position=Vector3(1.1,0,16.7)
	game.enemies[2].visible=false
	game._thrust_stopped(actor.position+Vector3.BACK*.9,Vector3.BACK)
	var gust=game.get_tree().get_nodes_in_group("thrust_gust").back()
	gust.set_physics_process(false)
	gust._physics_process(.28)
	await picture(game,directory+"/thrust-stop-gust.png",true)
	gust_floor.queue_free()
	actor.heavy_style="overhead"
	actor.thrust_unlocked=false
	game.config.camera_focus_offset=game.read_data("res://content/platform.json").camera_focus_offset
	game.current_world.visible=true
