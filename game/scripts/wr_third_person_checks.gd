extends SceneTree
## Run only with disposable user data. Camera presentation cannot alter Actor authority.
var checks=0
var failures:Array=[]
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize() -> void:
	create_timer(60).timeout.connect(func():push_error("Third-person fixture watchdog");quit(2))
	call_deferred("run")
func capture(game:Node,label:String,side_angle:float=0.0) -> void:
	var directory=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--camera-capture-dir="):directory=arg.trim_prefix("--camera-capture-dir=")
	if directory.is_empty():return
	DirAccess.make_dir_recursive_absolute(directory)
	game._layout();game.camera_driver.refresh_pointer();game.camera_driver.update_third_person(0)
	if side_angle!=0:
		var driver=game.camera_driver
		game.camera.global_transform=driver.third_person.sample(game.player,driver.sample_first_person(0,false),driver.yaw+side_angle,driver.first_pitch,game.current_world.bounds,0)
	await process_frame;await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))

func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide();game._refresh_simulation()
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.player.set_physics_process(false)
	for enemy in game.enemies:enemy.set_physics_process(false)
	var actor=game.player;actor.set_meta("body_wrist_inspection",true);var driver=game.camera_driver
	game.magic_items.owned.append("wooden_arrows");game.magic_items.quantities.wooden_arrows=5
	DirAccess.remove_absolute(driver.PREFERENCE_PATH)
	check(driver.preferred_mode()=="first_person","Fresh local camera preference defaults to first person")
	driver.set_mode("first_person")
	var head=driver.sample_first_person(0,false)
	var health=actor.health;var stamina=actor.stamina
	game.toggle_camera()
	check(game.camera_mode=="third_person" and actor.first_person_driver==driver,"C toggles to third person without replacing canonical driver")
	check(driver.preferred_mode()=="third_person","Local third-person preference persists separately from character save")
	check(game.save_data().camera_mode=="first_person","Third-person character snapshot retains legacy strict camera value")
	check(driver.sample_first_person(0,false).is_equal_approx(head),"Switching camera leaves canonical animated head frame unchanged")
	check(actor.health==health and actor.stamina==stamina,"Camera toggle spends no Actor resources")
	for weapon in ["standard_greatsword","field_spear","duelist_rapier","hunting_bow"]:
		if weapon not in game.magic_items.owned:game.magic_items.owned.append(weapon)
		game.magic_items.equip_weapon(weapon);actor.set_sword_equipped(true);actor.set_sword_drawn(true)
		for phase in [0.0,.25,.5,.74,1.0]:
			driver.set_mode("first_person")
			actor._pose_sword("attack" if actor.weapon_runtime.enabled() else "light",phase)
			var steel=actor.equipment.global_transform
			var pose_time=actor.state_time
			driver.set_mode("third_person");driver.update_third_person(0)
			check(actor.equipment.global_transform.is_equal_approx(steel) and actor.state_time==pose_time,weapon+" camera preserves steel/action at "+str(phase))
		actor._pose_sword("drag",0)
		await capture(game,weapon+"-ready")
		if weapon=="standard_greatsword":
			var hero=actor.get_node("BetaHero");hero.synchronize()
			for side in ["L","R"]:
				var lower=hero.gait.bone(hero,"forearm",side)
				var palm=Vector3(-.017 if side=="R" else .017,-.30,.012)
				var wrist=hero.rig.find_bone("view_hand."+side)
				var actual=hero.rig.global_transform*hero.rig.get_bone_global_pose(wrist)*(palm+Vector3(.009 if side=="R" else -.009,-.018,.012)-Vector3(0,-.26,0))
				var target=actor.equipment.global_transform*Vector3(0,actor.BetaSwordMotion.GRIP if side=="R" else .20,0)
				check(actual.distance_to(target)<.025,"Full-body "+side+" palm reaches physical ready hilt; error="+str(actual.distance_to(target)))
			await capture(game,"greatsword-grip-side",.8)
			actor.state="light";actor.combo_stage=1;actor.state_duration=1.55;actor.state_time=.465
			actor.play_clip("attack_light",0);actor.animator.seek(actor.animator.get_animation(actor.clips.attack_light).length*.30,true)
			actor._pose_sword("light",.30)
			await capture(game,"greatsword-light-contact")
			actor.state="free";actor.play_clip("drag_idle_loop",0)
		check(actor.has_node("BetaHero") and actor.get_node("BetaHero").visible,"Third-person shows current native full body for "+weapon)
		if weapon=="hunting_bow":
			driver.first_pitch=.18
			actor.weapon_runtime.begin_primary();actor.state_time=.8;actor.weapon_runtime.pose("ready",0)
			actor.weapon_runtime.update_preview()
			var nock=actor.weapon_runtime.model.get_node_or_null("NockedArrow")
			var physical=actor.weapon_runtime.model.global_transform
			driver.update_third_person(0)
			check(nock!=null and nock.visible and physical.is_equal_approx(actor.weapon_runtime.model.global_transform),"Third-person bow retains real nock and launch geometry")
			await capture(game,"bow-drawn")
			await capture(game,"bow-nock-side",.8)
			var front=StaticBody3D.new();front.collision_layer=1
			var front_shape=CollisionShape3D.new();var front_box=BoxShape3D.new();front_box.size=Vector3(8,8,.1);front_shape.shape=front_box;front.add_child(front_shape)
			game.world_root.add_child(front)
			var aim=driver.sample_first_person(0,false)
			front.global_position=aim.origin-aim.basis.z*.35
			await physics_frame;await physics_frame
			driver.set_mode("first_person");var first_launch=actor.weapon_runtime.launch_spec()
			driver.set_mode("third_person");driver.update_third_person(0)
			check(not first_launch.valid and not actor.weapon_runtime.launch_spec().valid,"Both camera modes block bow muzzle behind actual wall")
			var arrows=int(game.magic_items.quantities.wooden_arrows);var resource=actor.stamina
			check(not actor.weapon_runtime.release_primary() and int(game.magic_items.quantities.wooden_arrows)==arrows and actor.stamina==resource,"Third-person blocked bow cannot spend resources or launch through wall")
			front.queue_free();await physics_frame
			actor.weapon_runtime.cancel()
	driver.yaw=PI;driver.first_pitch=0
	var eye=driver.sample_first_person(0,false)
	var wall=StaticBody3D.new();wall.collision_layer=8
	var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(8,8,.2);shape.shape=box;wall.add_child(shape)
	game.world_root.add_child(wall);wall.global_position=eye.origin+Vector3(0,0,-1.4)
	await physics_frame;await physics_frame
	driver.update_third_person(0)
	check(game.camera.position.z>wall.position.z+.2,"Boom sphere stops before near wall")
	check(game.camera.near<=driver.third_person.RADIUS,"Boom radius contains camera near plane")
	wall.global_position=eye.origin+Vector3(0,0,-.35)
	await physics_frame;await physics_frame
	driver.update_third_person(0)
	check(driver.third_person.close_view and (game.camera.cull_mask & driver.visuals.BODY_LAYER)==0,"Tight obstacle restores head-safe first-person fallback")
	wall.queue_free();await physics_frame
	# Looking up lowers the boom toward terrain: the camera still cannot pass ground.
	driver.first_pitch=-1.0;driver.third_person.reset();driver.update_third_person(0)
	check(game.camera.position.y>=game.current_world.ground_height(game.camera.position)+.10 or driver.third_person.close_view,"Camera boom respects native terrain collision")
	driver.first_pitch=0.0
	var motion=InputEventMouseMotion.new();motion.relative=Vector2(22,12)
	var yaw=driver.yaw;var pitch=driver.first_pitch
	driver.handle_input(motion)
	check(driver.yaw<yaw and driver.first_pitch>pitch,"Third-person captured mouse uses canonical yaw and pitch signs")
	actor.input_enabled=false;var before=game.camera_mode;game.toggle_camera()
	check(game.camera_mode==before,"Overlay-disabled controls cannot toggle camera")
	actor.input_enabled=true;driver.set_mode("first_person");DirAccess.remove_absolute(driver.PREFERENCE_PATH)
	print("VERIFICATION_THIRD_PERSON ",JSON.stringify({"checks":checks,"failures":failures}))
	if game.audio!=null:await game.audio.shutdown_and_drain()
	if game.voice!=null:game.voice.configure_session(false)
	await create_timer(.15).timeout
	game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
