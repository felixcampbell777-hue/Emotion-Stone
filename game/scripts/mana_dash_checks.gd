extends RefCounted
var helper=preload("res://scripts/dash_attack_checks.gd").new()
func launch(actor:Node3D) -> void:
	helper.prepare(actor);actor.begin_dash_charge();actor.state_time=.3;actor.queue_dash_attack();actor.release_dash()
	for i in range(100):
		await actor.get_tree().physics_frame;actor._physics_process(1.0/60)
		if actor.state!="dash": break
func advance(actor:Node3D,phase:float) -> void:
	for i in range(160):
		await actor.get_tree().physics_frame;actor._physics_process(1.0/60)
		if actor.state!="light" or actor.combo_stage!=1 or actor.attack_phase()>=phase: break
func run(test:RefCounted) -> void:
	var game=test.game;var actor=game.player
	game.load_map("coastal_path",Vector2(0,-5),true);await test.frames(4)
	game.camera_driver.set_mode("first_person");game.camera_driver.yaw=PI;game.camera_driver.first_pitch=0
	game.progression.restore({"tree_version":3,"xp":957383,"learned":["form","dash"],"passives":[]});game.apply_skill_stats();actor.dash_equipped=true;actor.set_physics_process(false)
	test.check(not actor.dash_water_unlocked,"Form/Dash alone does not unlock the mana dash slash")
	game.learn_skill("mana")
	test.check(actor.water_unlocked and not actor.dash_water_unlocked,"Water Slash alone still requires its Flowing Splash stamina upgrade for mana dash attacks")
	game.learn_skill("flowing_splash");game.learn_skill("mana_lance");game.learn_skill("water_power");game.select_special_attack("water_lance")
	test.check(actor.dash_water_unlocked and is_equal_approx(actor.combat.water.stamina_cost,9.6),"Learning Flowing Splash unlocks mana dash slashes and its equipped passive supplies the real discount")
	var casts=[]
	var listener=func(origin:Vector3,direction:Vector3):
		var view=-game.camera_driver.sample_first_person(0,false).basis.z
		casts.append({"origin":origin,"direction":direction,"aim":Vector3(view.x,0,view.z).normalized(),"stamina":actor.stamina,"wave":game.water_waves[-1]})
	actor.water_cast.connect(listener)
	await launch(actor);var after_swing_cost=actor.stamina
	test.check(actor.dash_water_pending and casts.is_empty(),"Mana enhancement waits for the physical dash swing instead of firing during charge or travel")
	await advance(actor,.60)
	test.check(not actor.sword_material_backup.is_empty() and casts.is_empty(),"The real blade accumulates blue energy during the dash swing before releasing the mana slash")
	game.toggle_pause();var clock=actor.state_time;await test.frames(4)
	test.check(actor.dash_water_pending and casts.is_empty() and actor.state_time==clock,"Pause freezes a pending empowered dash slash without spending or firing")
	game.pause_menu.close();actor.queue_combo();await advance(actor,.76)
	test.check(casts.size()==1 and actor.state=="light" and actor.combo_stage==2,"Exactly one mana slash leaves the dash swing's follow-through and the queued normal return cut remains linked")
	test.check(absf(casts[0].stamina-(after_swing_cost-float(actor.combat.water.stamina_cost)))<.001,"The automatic mana slash spends its current upgraded Water Slash stamina cost exactly once")
	var wave=casts[0].wave
	test.check(is_instance_valid(wave) and wave.tuning.damage==actor.combat.water.damage and wave.damage_at(1)>0 and casts[0].direction.dot(casts[0].aim)>.999,"The follow-up creates a real view-aimed Water Slash with upgraded damage and existing distance falloff")
	test.check(not actor.dash_water_pending and actor.sword_material_backup.is_empty() and game.selected_special_attack=="water_lance","Steel is restored after release and the independently equipped Q special stays Water Lance")
	helper.prepare(actor);casts.clear();actor.begin_attack("light");await advance(actor,.95)
	test.check(casts.is_empty(),"Ordinary light attacks never gain the dash-only automatic mana slash")
	await launch(actor);actor.restore_stamina(5);await advance(actor,.85)
	test.check(casts.is_empty() and not actor.dash_water_pending and actor.sword_material_backup.is_empty() and actor.stamina==5,"Insufficient mana-slash stamina safely skips it, restores steel and never grants a free projectile")
	await launch(actor);await advance(actor,.60);actor.take_damage(1,Vector3.ZERO);await advance(actor,.85)
	test.check(casts.is_empty() and not actor.dash_water_pending and actor.sword_material_backup.is_empty(),"Damage cancels the pending mana follow-up and its blue energy")
	await launch(actor);await advance(actor,.60);game.get_window().focus_exited.emit()
	test.check(not actor.dash_water_pending and actor.sword_material_backup.is_empty(),"Focus loss cancels a pending mana dash slash and restores steel")
	game.toggle_passive("flowing_splash")
	test.check(actor.dash_water_unlocked and is_equal_approx(actor.combat.water.stamina_cost,24),"Learning owns the dash unlock; unequipping the passive removes only its stamina discount")
	helper.prepare(actor);var path="user://mana-dash-private.json"
	test.check(game.Save.write(game.save_data(),path)==OK and game.apply_save(game.Save.read(path)) and actor.dash_water_unlocked and not actor.dash_water_pending,"Mana dash eligibility rebuilds from learned skills through private saves; pending attacks never persist")
	DirAccess.remove_absolute(path);actor.water_cast.disconnect(listener)
	actor.set_sword_drawn(false);actor.set_physics_process(true)
