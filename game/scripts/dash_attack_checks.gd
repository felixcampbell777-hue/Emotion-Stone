extends RefCounted
func key(game:Control,pressed:bool) -> void:
	var event=InputEventKey.new();event.physical_keycode=KEY_T;event.pressed=pressed
	Input.parse_input_event(event);Input.flush_buffered_events()
func mouse(game:Control,pressed:bool) -> void:
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=game.world_rect.get_center();event.pressed=pressed
	Input.parse_input_event(event);Input.flush_buffered_events()
func prepare(actor:Node3D,drawn:bool=true) -> void:
	actor.set_sword_drawn(drawn);actor.position=Vector3(0,0,-5);actor.visual.rotation.y=0
	actor.restore_stamina(actor.max_stamina);actor.invulnerability=0;actor.knockback=Vector3.ZERO
func travel(actor:Node3D,hold:float) -> float:
	prepare(actor,false);actor.begin_dash_charge();actor.state_time=hold;actor.release_dash()
	var start=actor.position
	for i in range(120):
		await actor.get_tree().physics_frame
		actor._physics_process(1.0/60)
		if actor.state!="dash": break
	return actor.position.distance_to(start)
func run(test:RefCounted) -> void:
	var game=test.game;var actor=game.player
	game.load_map("coastal_path",Vector2(0,-5),true);await test.frames(4)
	game.camera_driver.set_mode("first_person");game.camera_driver.yaw=PI;game.camera_driver.first_pitch=0
	game.progression.restore({"tree_version":3,"xp":957383,"learned":["form","dash"],"passives":[]});game.apply_skill_stats();actor.dash_equipped=true
	actor.set_physics_process(false)
	var tap=await travel(actor,.05);var full=await travel(actor,1.5)
	game.learn_skill("dash_reach")
	test.check(is_equal_approx(actor.dash_distance_multiplier,1.25),"Dash Reach's first rank increases all dash distances by 25 percent")
	game.learn_skill("dash_reach");game.learn_skill("dash_reach");game.apply_skill_stats()
	var long_tap=await travel(actor,.05);var long_full=await travel(actor,1.5)
	test.check(absf(long_tap/tap-1.75)<.04 and absf(long_full/full-1.75)<.04 and absf(long_full-12.25)<.15,"Three Dash Reach ranks increase actual tap and full-charge travel, including the bounded 12.25m full charge")
	test.check(not game.progression.learn("dash_reach") and is_equal_approx(actor.dash_distance_multiplier,1.75) and is_equal_approx(actor.stamina,76),"Dash Reach caps at three ranks without stacking or increasing dash stamina cost")
	prepare(actor);key(game,true);await test.frames(2)
	actor.state_time=.5;mouse(game,true);await test.frames(2);mouse(game,false);await test.frames(2)
	test.check(actor.state=="dash_charge" and actor.dash_attack_queued and not game.mouse_attack_pending and actor.stamina==100,"Actual left-click while holding T queues a single dash swing without starting a heavy attack or spending its cost early")
	test.check(not actor.queue_dash_attack(),"Repeated clicks cannot queue multiple opening swings")
	actor._physics_process(.16);game.camera_driver.update_first_person()
	game.toggle_pause();var clock=actor.state_time;var held=actor.equipment.global_transform;await test.frames(4)
	key(game,false);await test.frames(2)
	test.check(actor.state=="dash_charge" and actor.dash_attack_queued and actor.dash_release_queued and actor.state_time==clock and actor.equipment.global_transform.is_equal_approx(held),"Pause freezes the loaded sword and queued swing; T release waits until gameplay resumes")
	game.pause_menu.close();actor._physics_process(0)
	var contacts=[];var on_contact=func(kind:String,_direction:Vector3,_ids:Dictionary): contacts.append([kind,actor.combo_stage])
	actor.attack_contact.connect(on_contact)
	var before=actor.equipment.transform
	for i in range(120):
		before=actor.equipment.transform;actor._physics_process(1.0/60)
		if actor.state!="dash": break
	test.check(actor.state=="light" and actor.combo_stage==1 and contacts.is_empty() and not actor.dash_attack_queued,"Dash exits directly into exactly one opening swing; charging and travel never deal sword damage")
	var gap=actor.equipment.position.distance_to(before.origin)
	var turn=actor.equipment.basis.get_rotation_quaternion().angle_to(before.basis.get_rotation_quaternion())
	test.check(actor.equipment.transform.is_equal_approx(actor.chain_weapon) and gap<.025 and turn<.06 and is_equal_approx(actor.state_time,float(actor.combat.light.duration)*actor.DASH_ATTACK_PHASE),"Loaded dash sword flows into the matching opening-cut phase without a ready-pose snap (%.3fm / %.3frad)"%[gap,turn])
	var expected=100-lerpf(12,24,clampf(clock/1.5,0,1))-float(actor.combat.light.stamina_cost)
	test.check(absf(actor.stamina-expected)<.001,"Dash attack pays the actual dash cost and exactly one normal opening-swing cost")
	for i in range(45):
		actor._physics_process(.01)
		if actor.attack_phase()>=.5: break
	test.check(not contacts.is_empty() and contacts.all(func(item): return item[0]=="light" and item[1]==1) and actor.queue_combo(),"Dash swing uses the existing real light-contact window and can queue the return cut")
	for i in range(100):
		actor._physics_process(.01)
		if actor.combo_stage==2: break
	test.check(actor.state=="light" and actor.combo_stage==2,"A queued dash swing links into the normal second attack")
	actor.attack_contact.disconnect(on_contact)
	prepare(actor);actor.begin_dash_charge();game._request_attack("light")
	test.check(actor.dash_attack_queued,"Keyboard light attack queues the same dash attack as left-click")
	game.get_window().focus_exited.emit()
	test.check(not actor.dash_attack_queued,"Losing focus clears the pending dash attack to avoid an unexpected swing")
	prepare(actor,false);actor.begin_dash_charge()
	test.check(not actor.queue_dash_attack(),"A sheathed sword cannot queue a dash attack")
	prepare(actor);actor.begin_dash_charge();actor.restore_stamina(12)
	test.check(not actor.queue_dash_attack() and actor.state=="dash_charge","Insufficient combined stamina rejects the dash swing without cancelling a usable dash")
	prepare(actor);actor.begin_dash_charge();actor.queue_dash_attack();actor.take_damage(1,Vector3.ZERO)
	test.check(not actor.dash_attack_queued,"Damage clears a queued dash swing without granting dash invulnerability")
	prepare(actor);actor.begin_dash_charge();actor.queue_dash_attack();actor.set_sword_drawn(false)
	test.check(not actor.dash_attack_queued and actor.dash_attack_blend==0,"Weapon reset clears every queued dash-attack pose")
	var path="user://dash-upgrade-private.json";var data=game.save_data()
	test.check(game.Save.write(data,path)==OK and game.apply_save(game.Save.read(path)) and game.progression.rank("dash_reach")==3 and is_equal_approx(actor.dash_distance_multiplier,1.75),"Dash distance ranks rebuild correctly through private save/load")
	DirAccess.remove_absolute(path)
	actor.set_sword_drawn(false);actor.set_physics_process(true)
