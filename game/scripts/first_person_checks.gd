extends RefCounted
func run(test:RefCounted) -> void:
	var game=test.game; var driver=game.camera_driver; var actor=game.player
	game.get_window().size=Vector2i(1280,720); await test.frames(3)
	driver.set_mode("first_person"); await test.frames(2)
	await game.get_tree().process_frame; await game.get_tree().process_frame
	test.check(game.camera_mode=="first_person" and game.camera.projection==Camera3D.PROJECTION_PERSPECTIVE and actor.camera_relative,"First person uses a perspective eye camera and camera-relative controls")
	var meshes=actor.find_children("*","MeshInstance3D",true,false)
	var arms=meshes.filter(func(mesh): return mesh.has_meta("first_person_arms"))
	test.check(not arms.is_empty() and arms.all(func(mesh): return mesh.mesh.get_surface_count()>0),"First person retains weighted human arm geometry")
	test.check((game.camera.cull_mask&driver.visuals.BODY_LAYER)==0 and (game.camera.cull_mask&driver.visuals.ARMS_LAYER)!=0,"First person excludes the head/body and includes the separate live arms")
	test.check(absf(game.camera.position.y-actor.position.y-1.52)<.01 and driver.crosshair.visible,"Beta camera sits at eye height with a centered aiming mark")
	var motion=InputEventMouseMotion.new(); motion.relative=Vector2(50,30); motion.position=game.world_rect.get_center()
	var yaw=driver.yaw; var pitch=driver.first_pitch
	var camera_basis=game.camera.global_basis
	Input.parse_input_event(motion.duplicate()); Input.flush_buffered_events(); await test.frames(3)
	await game.get_tree().process_frame
	var look=-game.camera.global_basis.z
	test.check(look.dot(camera_basis.x)>.2 and look.dot(camera_basis.y)<-.12,"Actual right/down mouse input turns the rendered camera right/down")
	test.check(absf(wrapf(driver.yaw-yaw,-PI,PI)+.3)<.002 and absf(driver.first_pitch-pitch-.18)<.002,"First-person horizontal yaw uses the same drag direction as follow")
	camera_basis=game.camera.global_basis
	motion.relative=Vector2(-50,-30)
	Input.parse_input_event(motion.duplicate()); Input.flush_buffered_events(); await test.frames(3)
	await game.get_tree().process_frame
	look=-game.camera.global_basis.z
	test.check(look.dot(camera_basis.x)<-.2 and look.dot(camera_basis.y)>.12,"Actual left/up mouse input turns the rendered camera left/up")
	test.check(actor.facing().distance_to(-Vector3(sin(driver.yaw),0,cos(driver.yaw)))<.002,"First-person weapon facing follows mouse look immediately")
	motion.relative=Vector2(0,10000); driver.handle_input(motion)
	test.check(driver.first_pitch==1.15,"First-person pitch stops before flipping the camera")
	driver.first_pitch=.25
	var button=InputEventMouseButton.new(); button.button_index=MOUSE_BUTTON_RIGHT; button.pressed=true; button.position=game.world_rect.get_center()
	test.check(not driver.handle_input(button),"First-person look leaves right-click available for timed parry")
	actor.set_sword_drawn(true); actor.restore_stamina(100)
	Input.parse_input_event(button.duplicate()); await test.frames(2)
	button.pressed=false; Input.parse_input_event(button.duplicate())
	test.check(actor.state=="parry","Actual right-click starts parry in first person")
	game.toggle_pause(); var clock=actor.state_time; var position=actor.position
	await test.frames(4)
	test.check(not driver.crosshair.visible and not driver.owns_pointer and actor.state_time==clock and actor.position.is_equal_approx(position),"First-person pause releases the mouse and freezes active combat")
	game.pause_menu.close(); await test.frames(80)
	game.toggle_inventory()
	test.check(not driver.crosshair.visible and not driver.handle_input(motion),"Inventory releases first-person aiming and blocks mouse look")
	game.inventory.close(); await test.frames(2)
	await locomotion_motion_checks(test)
	await parry_view_checks(test)
	await load("res://scripts/first_person_hold_checks.gd").new().run(test)
	await load("res://scripts/lance_control_checks.gd").new().run(test)
	await head_motion_checks(test)
	var path="user://first-person-verification.json"; var saved=game.save_data()
	game.Save.write(saved,path); driver.first_pitch=0
	test.check(game.apply_save(game.Save.read(path)) and game.camera_mode=="first_person" and absf(driver.first_pitch-.25)<.001,"Private save/load restores first-person view and look angle")
	var bad=saved.duplicate(true); bad.first_person_pitch=9; game.Save.write(bad,path)
	test.check(game.Save.read(path).is_empty(),"Invalid first-person save angles are rejected")
	DirAccess.remove_absolute(path)
	for enemy in game.enemies: enemy.ai_enabled=false
	var count=actor.find_children("*","MeshInstance3D",true,false).filter(func(mesh): return mesh.has_meta("first_person_arms")).size()
	game.load_map(game.map_id,Vector2(0,-12),true); await test.frames(2)
	test.check(actor.find_children("*","MeshInstance3D",true,false).filter(func(mesh): return mesh.has_meta("first_person_arms")).size()==count,"Map reload rebuilds first-person arms without duplicate layers")
	game.toggle_camera()
	test.check(game.camera_mode==("third_person" if game.game_mode=="world_rise" else "first_person") and actor.camera_relative and not InputMap.action_get_events("camera_mode").is_empty(),"C toggles World Rise perspective while legacy modes retain first person")
	if game.game_mode=="world_rise":game.toggle_camera()
	actor.set_sword_drawn(false)

func locomotion_motion_checks(test:RefCounted) -> void:
	var game=test.game;var actor=game.player;var driver=game.camera_driver;var hero=actor.get_node("BetaHero")
	actor.set_physics_process(false);hero.set_process(false)
	var tuning=driver.tuning.get("first_person_movement_motion",.5)
	driver.yaw=PI;driver.first_pitch=.25;actor.visual.rotation.y=0
	var position_error=0.0;var angle_error=0.0;var translation=0.0;var rotation=0.0
	for drawn in [false,true]:
		actor.set_sword_drawn(drawn);actor.state="free"
		for sprint in [false,true]:
			actor.sprinting=sprint
			var clip="drag_walk_loop" if drawn else "walk_loop";actor.play_clip(clip,0)
			for phase in [.12,.25,.50,.75]:
				actor.animator.seek(actor.animator.get_animation(actor.clips[clip]).length*phase,true)
				driver.tuning.first_person_movement_motion=1.0;driver.update_first_person()
				var full=game.camera.global_transform
				var neutral_basis=Basis(Vector3.UP,driver.yaw)*Basis(Vector3.RIGHT,-driver.first_pitch)
				var neutral_eye=actor.global_position+Vector3(0,1.52,0)-neutral_basis.z*.18
				driver.tuning.first_person_movement_motion=.5;driver.update_first_person()
				var reduced=game.camera.global_transform
				position_error=maxf(position_error,reduced.origin.distance_to(neutral_eye.lerp(full.origin,.5)))
				var raw_angle=neutral_basis.get_rotation_quaternion().angle_to(full.basis.get_rotation_quaternion())
				var half_angle=neutral_basis.get_rotation_quaternion().angle_to(reduced.basis.get_rotation_quaternion())
				angle_error=maxf(angle_error,absf(half_angle-raw_angle*.5))
				translation+=full.origin.distance_to(neutral_eye);rotation+=raw_angle
	test.check(position_error<.0002 and translation>.02,"Actual first-person eye bob/sway is halved across normal/drawn walking and sprinting")
	test.check(angle_error<.001 and rotation>.02,"Actual first-person gait rotation is halved without changing mouse-look angles")
	var view=game.camera.global_transform;var envelope=driver.locomotion_camera_blend
	game.toggle_pause();driver.update_first_person(.1)
	test.check(game.camera.global_transform.is_equal_approx(view) and driver.locomotion_camera_blend==envelope,"Pausing a reduced-shake gait freezes the view and its transition")
	game.pause_menu.close();driver.tuning.first_person_movement_motion=tuning
	actor.sprinting=false;actor.set_sword_drawn(true);actor.play_clip("drag_idle_loop",0)
	driver.locomotion_camera_blend=0;hero.set_process(true);actor.set_physics_process(true)

func parry_view_checks(test:RefCounted) -> void:
	var game=test.game;var actor=game.player;var driver=game.camera_driver
	actor.set_physics_process(false);actor.set_sword_drawn(true);actor.restore_stamina(100)
	driver.yaw=PI;driver.first_pitch=.25;actor.visual.rotation.y=0
	actor.begin_parry();actor.action_transition_remaining=0
	var tuning=driver.tuning.first_person_parry_motion
	var error=0.0;var largest=0.0;var raw_largest=0.0;var step=0.0;var previous=Quaternion.IDENTITY
	for frame in range(121):
		var phase=.99*frame/120.0
		actor.state_time=actor.state_duration*phase;actor._physics_process(0)
		driver.tuning.first_person_parry_motion=1;driver.update_first_person()
		var neutral=Basis(Vector3.UP,driver.yaw)*Basis(Vector3.RIGHT,-driver.first_pitch)
		var full=neutral.get_rotation_quaternion().angle_to(game.camera.global_basis.get_rotation_quaternion())
		driver.tuning.first_person_parry_motion=tuning;driver.update_first_person()
		var view=game.camera.global_basis.get_rotation_quaternion()
		var reduced=neutral.get_rotation_quaternion().angle_to(view)
		if phase>=.12 and phase<=.82:
			error=maxf(error,absf(reduced-full*tuning));largest=maxf(largest,reduced);raw_largest=maxf(raw_largest,full)
		if frame>0:step=maxf(step,previous.angle_to(view))
		previous=view
	test.check(error<.001 and raw_largest>.05 and largest<raw_largest*.21,"First-person parry retains only 20 percent of the real guard rotation, keeping the threat ahead")
	test.check(step<.06,"Forward-facing parry view enters and recovers smoothly across actual action frames")
	actor.state_time=actor.state_duration*.4;actor._physics_process(0)
	var motion=InputEventMouseMotion.new();motion.relative=Vector2(30,-10)
	var yaw=driver.yaw;var pitch=driver.first_pitch;var handled=driver.handle_input(motion)
	var neutral=Basis(Vector3.UP,driver.yaw)*Basis(Vector3.RIGHT,-driver.first_pitch)
	driver.tuning.first_person_parry_motion=1;driver.update_first_person()
	var full=neutral.get_rotation_quaternion().angle_to(game.camera.global_basis.get_rotation_quaternion())
	driver.tuning.first_person_parry_motion=tuning;driver.update_first_person()
	var reduced=neutral.get_rotation_quaternion().angle_to(game.camera.global_basis.get_rotation_quaternion())
	test.check(handled and absf(wrapf(driver.yaw-yaw,-PI,PI)+.18)<.001 and absf(driver.first_pitch-pitch+.06)<.001 and absf(reduced-full*tuning)<.001,"Mouse look remains responsive while the body holds its twisted parry guard")
	var pose=game.camera.global_transform;game.toggle_pause();await test.frames(3)
	test.check(game.camera.global_transform.is_equal_approx(pose),"Pause freezes the stabilized parry camera with the action")
	game.pause_menu.close();actor.state_time=actor.state_duration;actor._physics_process(0)
	driver.yaw=PI;driver.first_pitch=.25;actor.set_physics_process(true)

func head_motion_checks(test:RefCounted) -> void:
	var game=test.game;var actor=game.player;var driver=game.camera_driver
	actor.set_physics_process(false);actor.set_sword_drawn(true);actor.restore_stamina(100)
	driver.yaw=PI;driver.first_pitch=.25;actor.visual.rotation.y=0
	actor.combo_stage=2;actor.combo_remaining=1;actor.begin_attack("light")
	actor.chain_blend=0;actor.action_transition_remaining=0
	var last_angle=0.0;var travel=0.0;var low=99.0;var high=-99.0
	for frame in range(61):
		actor.state_time=actor.state_duration*.99*frame/60.0;actor._physics_process(0)
		driver.update_first_person()
		var forward=-game.camera.global_basis.z;var angle=atan2(forward.x,forward.z)
		if frame>0:travel+=wrapf(angle-last_angle,-PI,PI)
		last_angle=angle;low=minf(low,game.camera.position.y);high=maxf(high,game.camera.position.y)
	test.check(travel>5.9,"First-person camera follows the real full spin attack instead of looking straight ahead")
	test.check(high-low>.08,"First-person eye position follows the animated head height during combat")
	var yaw=driver.yaw;var pose=game.camera.global_transform
	game.toggle_pause();await test.frames(3)
	test.check(game.camera.global_transform.is_equal_approx(pose) and driver.yaw==yaw,"Pausing a head-following spin freezes the view and leaves saved mouse yaw unchanged")
	game.pause_menu.close();actor.state_time=actor.state_duration;actor._physics_process(0)
	actor.combo_remaining=0;actor.combo_stage=0;actor.set_physics_process(true)
