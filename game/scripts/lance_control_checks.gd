extends RefCounted
func run(test:RefCounted) -> void:
	var game=test.game;var actor=game.player;var driver=game.camera_driver
	var stability=actor.lance_stability;var yaw=driver.yaw;var pitch=driver.first_pitch
	actor.set_physics_process(false);actor.set_sword_drawn(true);actor.restore_stamina(actor.max_stamina)
	actor.lance_unlocked=true;actor.begin_water_lance();actor.action_transition_remaining=0
	var largest=0.0;var fastest=0.0;var reduction_error=0.0;var previous=Vector2.ZERO;var peak_phase=0.0
	for index in range(301):
		var phase=float(index)/300;actor.state_time=actor.state_duration*phase
		actor.lance_stability=0;var raw=driver.lance_view_offset()
		if raw.length()>largest: largest=raw.length();peak_phase=phase
		fastest=maxf(fastest,raw.distance_to(previous));previous=raw
		actor.lance_stability=.75;var controlled=driver.lance_view_offset()
		reduction_error=maxf(reduction_error,controlled.distance_to(raw*.25))
	test.check(largest>deg_to_rad(3) and fastest>deg_to_rad(.7),"Untrained Mana Lance builds noticeable, sharply rising yaw/pitch kicks instead of steady cosmetic sway")
	test.check(reduction_error<.00001,"Maximum Lance Control reduces every charge kick by 75 percent")
	actor.lance_stability=0;actor.state_time=actor.state_duration*peak_phase;actor._physics_process(0);driver.update_first_person()
	var view=game.camera.global_transform;var sampled=driver.sample_first_person(0,false)
	test.check(view.is_equal_approx(sampled) and driver.yaw==yaw and driver.first_pitch==pitch,"View sampling is idempotent and never permanently changes saved mouse-look angles")
	var offset=driver.lance_view_offset();var neutral=sampled.basis*Basis(Vector3.RIGHT,-offset.y)*Basis(Vector3.UP,-offset.x)
	test.check(neutral.get_rotation_quaternion().angle_to(view.basis.get_rotation_quaternion())>deg_to_rad(2),"Charge instability rotates the actual rendered first-person camera")
	var motion=InputEventMouseMotion.new();motion.relative=Vector2(15,-8)
	driver.handle_input(motion);actor._physics_process(0);driver.update_first_person()
	test.check(absf(wrapf(driver.yaw-yaw,-PI,PI)+.09)<.001 and absf(driver.first_pitch-pitch+.048)<.001,"Player mouse input remains available to counter the lance's aim kicks")
	view=game.camera.global_transform;var weapon=actor.equipment.global_transform;var clock=actor.state_time
	game.toggle_pause();await test.frames(3)
	test.check(actor.state_time==clock and game.camera.global_transform.is_equal_approx(view) and actor.equipment.global_transform.is_equal_approx(weapon),"Pause freezes charged-lance view kicks, hands and real steel together")
	game.pause_menu.close();actor.state_time=actor.state_duration;var charged=driver.lance_view_offset()
	actor._physics_process(0);driver.update_first_person();var beam=game.projectiles[-1]
	test.check(actor.state=="lance_fire" and driver.lance_view_offset().distance_to(charged)<.00001 and beam.direction.dot(-game.camera.global_basis.z)>.999,"Release keeps the final kicked aim continuous and fires the real beam along that view")
	actor.state_time=actor.state_duration*.4;actor._physics_process(0)
	test.check(driver.lance_view_offset().is_zero_approx(),"Lance recovery settles the view without residual shaking")
	actor.set_sword_drawn(true);actor.restore_stamina(actor.max_stamina);actor.begin_water_lance()
	actor.state_time=actor.state_duration*.8;actor.invulnerability=0;actor.restore_health(actor.max_health)
	actor.take_damage(1,Vector3.ZERO)
	test.check(actor.state=="stagger" and driver.lance_view_offset().is_zero_approx() and actor.lance_charge_fx==null,"Damage interruption immediately stops lance instability and aura without firing")
	actor.set_sword_drawn(true);actor.lance_stability=stability;actor.invulnerability=0;actor.restore_health(actor.max_health)
	driver.yaw=yaw;driver.first_pitch=pitch;driver.update_first_person();actor.set_physics_process(true)
