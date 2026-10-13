extends RefCounted
func run(test:RefCounted) -> void:
	var game=test.game
	var actor=game.player
	game.progression.restore({"tree_version":2,"xp":0,"learned":[]})
	game.apply_skill_stats()
	game.camera_driver.set_mode("overhead")
	game.load_map("coastal_path",Vector2(0,3),true)
	game.conversation.close()
	game.inventory.close()
	game.dialog.visible=false
	game._refresh_simulation()
	for key in ["move_left","move_right","move_up","move_down","sprint"]: Input.action_release(key)
	var distances=[]
	var impacts=[]
	var record_impact=func(at:Vector3, heavy:bool): impacts.append({"at":at,"heavy":heavy,"phase":actor.attack_phase()})
	actor.ground_slam.connect(record_impact)
	for stage in [1,2,3,3]:
		actor.set_sword_drawn(true)
		actor.position=Vector3(0,0,3)
		actor.visual.rotation.y=0
		actor.restore_stamina(100)
		actor.combo_queued=false
		actor.combo_stage=stage-1
		actor.combo_remaining=.1 if stage>1 else 0
		if distances.size()==3: Input.action_press("move_down")
		actor.begin_attack("light")
		await test.frames(30)
		if stage==3: test.check(actor.visual.rotation.y-actor.attack_yaw>5.0,"Fast spin completes most of its revolution within half a second")
		await test.frames(30)
		distances.append(actor.position.z-3)
		Input.action_release("move_down")
		if stage==3: await test.frames(50)
	print("COMBO_TRAVEL ",distances)
	test.check(distances[1]<distances[0]*.4 and distances[2]<distances[0]*.4,"Backhand and stationary spin travel far less than the opening cut")
	test.check(distances[3]>distances[2]+.3,"Forward movement input adds deliberate travel to the spin")
	actor.set_sword_drawn(true)
	actor.restore_stamina(100)
	actor.begin_attack("heavy")
	await test.frames(155)
	test.check(impacts.size()==3 and impacts[0].heavy==false and impacts[2].heavy,"Each spin finisher and heavy attack emits exactly one ground impact")
	var grounded=true
	for impact in impacts: grounded=grounded and impact.at.y<.20 and impact.phase>=.68 and impact.phase<.72
	test.check(grounded,"Crater impact fires when the visible blade reaches the ground")
	actor.ground_slam.disconnect(record_impact)
	var effects=game.get_tree().get_nodes_in_group("ground_slam")
	test.check(not effects.is_empty(),"Heavy hammer finish leaves visible crater geometry")
	if not effects.is_empty():
		var effect=effects.back()
		var age=effect.age
		actor.input_enabled=false
		effect._physics_process(.5)
		test.check(effect.age==age,"Crater and debris freeze with paused gameplay")
		actor.input_enabled=true
		effect._physics_process(4)
		test.check(effect.is_queued_for_deletion(),"Temporary crater cleans itself up after fading")
	actor.set_sword_drawn(true)
	actor.position=Vector3.ZERO
	actor.visual.rotation.y=0
	actor.set_physics_process(false)
	var fixture=game.Slime.new()
	fixture.configure({"id":"blade_fixture","kind":"slime","at":[0,0]},actor)
	game.world_root.add_child(fixture)
	fixture.ai_enabled=false
	actor._pose_sword("light2",.38)
	var blade=actor.blade_segment()
	var steel:Vector3=blade[0].lerp(blade[1],.75)
	fixture.position=Vector3(steel.x,0,steel.z)
	test.check(actor.blade_hits(fixture),"Backhand hit volume reaches a target under the visible steel")
	fixture.position=Vector3(1.7,0,1.2)
	test.check(not actor.blade_hits(fixture),"A target inside the former attack cone but away from steel is not hit")
	var joined=actor.motion_pose("light2",.74)
	var spin=actor.motion_pose("light3",0)
	test.check(joined.grip.distance_to(spin.grip)<.001 and joined.tip.distance_to(spin.tip)<.001 and joined.tip.y<.1,"Spin begins at the backhand's low buried blade without a reset")
	fixture.free()
	actor.set_sword_drawn(true)
	actor.set_physics_process(true)
	game.load_map("coastal_path",Vector2(0,3),true)
	shockwave_checks(test)
	await roll_attack_checks(test)

func shockwave_checks(test:RefCounted) -> void:
	var game=test.game
	var actor=game.player
	actor.set_physics_process(false)
	actor.position=Vector3(0,0,3)
	var fixtures=[]
	for size in ["small","medium","large","giant"]:
		var mob=game.Slime.new()
		mob.configure({"id":"shock_"+size,"kind":"slime","size":size,"at":[0,4]},actor)
		game.current_world.add_child(mob)
		mob.set_physics_process(false)
		mob.state="lunge"
		mob.velocity=Vector3(0,0,-4)
		fixtures.append(mob)
	var outside=game.ForestEnemy.new()
	outside.configure({"id":"shock_outside","kind":"boar","at":[0,6]},actor)
	game.current_world.add_child(outside)
	outside.set_physics_process(false)
	outside.state="windup"
	fixtures.append(outside)
	var original=game.enemies.duplicate()
	game.enemies.assign(fixtures)
	game._ground_slam(Vector3(0,0,3),true)
	var effect=game.get_tree().get_nodes_in_group("ground_slam").back()
	effect.set_physics_process(false)
	actor.input_enabled=false
	effect._physics_process(.3)
	test.check(effect.age==0 and fixtures[1].state=="lunge","Paused shockwave cannot interrupt enemies")
	actor.input_enabled=true
	effect._physics_process(.2)
	test.check(fixtures[1].state=="recover" and fixtures[1].lunge_hit and fixtures[1].velocity.is_zero_approx(),"Shockwave cancels an active charge before contact")
	test.check(fixtures[0].knockback.length()>fixtures[1].knockback.length() and fixtures[1].knockback.length()>fixtures[2].knockback.length(),"Shockwave recoil scales from Small through Large")
	test.check(fixtures[3].knockback.is_zero_approx() and fixtures[3].state=="lunge","Giant armor remains planted against a ground shockwave")
	test.check(outside.state=="windup","Enemies beyond the small shockwave radius keep charging")
	var recoil=fixtures[1].knockback
	fixtures[1].state="idle"
	effect._physics_process(.1)
	test.check(fixtures[1].state=="idle" and fixtures[1].knockback==recoil and fixtures[1].health==fixtures[1].max_health,"Each wave affects an enemy once without adding sword damage")
	outside.position=Vector3(1.8,0,3)
	outside.state="windup"
	effect._physics_process(.1)
	test.check(outside.state=="recover","Ground pressure also interrupts a boar's charge preparation")
	game.enemies.assign(original)
	for mob in fixtures: mob.free()
	effect.free()
	actor.set_physics_process(true)

func roll_attack_checks(test:RefCounted) -> void:
	var game=test.game
	var actor=game.player
	actor.roll_unlocked=true
	actor.set_sword_drawn(true)
	actor.restore_stamina(100)
	actor.position=Vector3(0,0,3)
	actor.visual.rotation.y=0
	actor.begin_roll()
	await test.frames(35)
	test.check(actor.begin_attack("light") and actor.state=="roll","Light input buffers during Dodge without interrupting its airborne turn")
	var entered=false
	for tick in range(50):
		await test.frames(1)
		if actor.state=="light": entered=true; break
	test.check(entered and actor.current_clip=="attack_light" and actor.combo_stage==1 and actor.chain_blend>0,"Dodge recovery enters the opener directly with captured body and blade poses")
	test.check(actor.stamina<65 and actor.stamina>60,"Roll and recovery swing each consume their normal stamina once")
	await test.frames(105)
	actor.set_sword_drawn(false)
	actor.restore_stamina(100)
	actor.begin_roll()
	test.check(not actor.begin_attack("light") and not actor.begin_charge(),"A sheathed roll cannot silently draw the sword to attack")
	await test.frames(90)
	actor.set_sword_drawn(true)
	actor.restore_stamina(18)
	actor.begin_roll()
	test.check(not actor.begin_attack("light"),"Insufficient stamina leaves Dodge recovery intact")
	await test.frames(90)
	actor.restore_stamina(100)
	actor.begin_roll()
	await test.frames(52)
	game._unhandled_input(mouse(true,game.world_rect.get_center()))
	game._input(mouse(false,game.world_rect.get_center()))
	test.check(actor.roll_attack_queued,"A real left-click tap buffers the recovery swing")
	await test.frames(115)
	actor.roll_unlocked=false
	actor.set_sword_drawn(true)

func mouse(pressed:bool,at:Vector2) -> InputEventMouseButton:
	var event=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=pressed
	event.position=at
	return event
