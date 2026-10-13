extends RefCounted
func run(test:RefCounted) -> void:
	var game=test.game
	var actor=game.player
	game.load_map("coastal_path",Vector2(0,3),true)
	game.progression.restore({"tree_version":2,"xp":8200,"learned":["form","charge_thrust"]})
	game.apply_skill_stats()
	game.select_heavy_attack("charge_thrust")
	game.conversation.close()
	game.inventory.close()
	game._refresh_simulation()
	actor.set_sword_drawn(true)
	actor.restore_stamina(100)
	actor.restore_health(100)
	actor.set_physics_process(false)
	actor.begin_charge()
	actor._physics_process(.5)
	test.check(is_equal_approx(actor.stamina,96),"Driving Thrust charge spends eight stamina per second")
	var charged_stamina=actor.stamina
	var wind_clock=actor.thrust_wind_fx.clock
	actor.input_enabled=false
	actor._physics_process(.5)
	test.check(actor.stamina==charged_stamina and actor.thrust_wind_fx.clock==wind_clock,"Menus freeze charge stamina and wind")
	actor.input_enabled=true
	actor.set_sword_drawn(true)
	actor.restore_stamina(44)
	actor.begin_charge()
	actor._physics_process(.5)
	actor._physics_process(.5)
	test.check(actor.state=="thrust" and is_zero_approx(actor.stamina) and is_equal_approx(actor.thrust_charge_seconds,1),"Charge exhaustion releases once while retaining its launch stamina")
	actor.set_sword_drawn(true)
	actor.restore_stamina(35)
	test.check(actor.begin_charge() and not actor.thrust_charging and not actor.release_charge("heavy"),"Insufficient launch stamina cannot start a thrust charge")
	actor.restore_stamina(35)
	actor.begin_charge()
	test.check(actor.release_charge("light") and actor.state=="light","Low stamina still allows light taps with Driving Thrust equipped")
	actor.set_sword_drawn(true)
	actor.restore_stamina(36)
	actor.begin_charge()
	actor._physics_process(.1)
	test.check(actor.state=="charge" and actor.release_charge("light") and actor.state=="light","Exhausted charge reserve never forces a heavy attack before the tap/hold threshold")
	actor.set_physics_process(true)
	var damage=[]
	var distance=[]
	var hold=[]
	for seconds in [0.5,2.0,4.0,8.0]:
		actor.set_sword_drawn(true)
		actor.restore_stamina(100)
		actor.begin_charge()
		actor.state_time=seconds
		actor.animator.seek(actor.thrust_prepare_phase()*actor.animator.get_animation(actor.clips.attack_thrust).length,true)
		actor._pose_sword("thrust",actor.thrust_prepare_phase())
		var previous=actor.equipment.transform
		test.check(actor.release_charge("heavy") and actor.state=="thrust" and actor.equipment.transform.is_equal_approx(previous),"Thrust release preserves the charged blade at %.1fs" % seconds)
		damage.append(actor.attack_tuning().damage)
		distance.append(actor.thrust_distance)
		hold.append(actor.thrust_hold_seconds)
	test.check(damage[0]<damage[1] and damage[1]<damage[2] and damage[2]<damage[3] and is_equal_approx((distance[2]-distance[1])/2,(distance[3]-distance[2])/4),"Thrust damage and distance grow linearly with charge")
	test.check(is_equal_approx(hold[2],2) and hold[0]>hold[1] and hold[1]>hold[2] and hold[2]>hold[3],"Inverse-log extended recovery gives exactly two seconds for four seconds charged")
	actor.set_sword_drawn(true)
	actor.restore_stamina(100)
	actor.begin_charge()
	actor.state_time=4
	actor.release_charge("heavy")
	actor.set_physics_process(false)
	actor.chain_blend=0
	actor.action_transition_remaining=0
	actor.state_time=actor.thrust_windup_seconds+actor.thrust_launch_seconds+.1
	actor._physics_process(1.0/60)
	var steel=actor.equipment.transform
	var at=actor.position
	actor._physics_process(.5)
	test.check(actor.attack_phase()==.64 and actor.velocity.is_zero_approx() and actor.position.is_equal_approx(at) and actor.equipment.transform.is_equal_approx(steel),"Stopped thrust stays fully extended throughout its recovery hold")
	actor.input_enabled=false
	var time=actor.state_time
	actor._physics_process(.5)
	test.check(actor.state_time==time,"Menus freeze the extended thrust recovery clock")
	actor.input_enabled=true
	actor.set_physics_process(true)
	actor.set_sword_drawn(true)
	actor.restore_stamina(100)
	actor.invulnerability=0
	actor.begin_charge()
	await test.frames(45)
	test.check(actor.take_damage(10,Vector3.ZERO) and actor.state=="stagger" and actor.stagger_motion=="thrust" and not actor.release_charge("heavy"),"Being hit during thrust charge staggers and prevents release")
	await test.frames(55)
	test.check(actor.state=="free","Interrupted thrust returns along its existing blade path to control")
	actor.restore_stamina(100)
	actor.invulnerability=0
	actor.begin_charge()
	actor.state_time=4
	actor.release_charge("heavy")
	test.check(actor.take_damage(10,Vector3.ZERO) and actor.state=="stagger","A hit also interrupts a launched thrust")
	await test.frames(55)
	actor.restore_stamina(100)
	var down=InputEventMouseButton.new()
	down.button_index=MOUSE_BUTTON_LEFT
	down.pressed=true
	down.position=game.world_rect.get_center()
	game._unhandled_input(down)
	await test.frames(45)
	test.check(game.mouse_attack_pending and actor.state=="charge" and actor.state_time>.6,"Held mouse Driving Thrust never auto-fires at the ordinary heavy threshold")
	var up=down.duplicate()
	up.pressed=false
	game._input(up)
	test.check(actor.state=="thrust" and actor.thrust_charge_seconds>.6,"Releasing the held mouse launches the accumulated thrust")
	actor.set_sword_drawn(true)
	actor.restore_stamina(100)
	var key=InputEventKey.new()
	key.physical_keycode=KEY_K
	key.pressed=true
	game._unhandled_key_input(key)
	await test.frames(45)
	key=key.duplicate()
	key.pressed=false
	game._input(key)
	test.check(actor.state=="thrust" and actor.thrust_charge_seconds>.6 and not game.keyboard_thrust_pending,"Keyboard K holds and releases the same charge")
	actor.set_sword_drawn(true)
	game.progression.restore({"tree_version":2,"xp":0,"learned":[]})
	game.apply_skill_stats()
	game.select_heavy_attack("overhead")
	actor.restore_health(100)
	actor.invulnerability=0
	await check_gust(test)

func check_gust(test:RefCounted) -> void:
	var game=test.game
	var actor=game.player
	game.load_map("herb_glade",Vector2(0,14),true)
	for enemy in game.enemies:
		enemy.respawn()
		enemy.set_physics_process(false)
	var slime=game.enemies[0]
	var boar=game.enemies[1]
	slime.position=Vector3(0,0,16.1)
	boar.position=Vector3(1.0,0,16.7)
	actor.set_sword_drawn(true)
	actor.visual.rotation.y=0
	actor.thrust_unlocked=true
	actor.heavy_style="charge_thrust"
	actor.restore_stamina(100)
	actor.begin_charge()
	actor.state_time=1
	actor.release_charge("heavy")
	actor.set_physics_process(false)
	actor.chain_blend=0
	slime.health=200
	actor._pose_sword("thrust",.38)
	actor.blade_sweep_previous.clear()
	game._attack_contact("thrust",Vector3.BACK,{})
	test.check(slime.health<200 and is_equal_approx(slime.knockback.length(),20),"Actual thrust blade contacts dispatch the 2.5x strong recoil")
	slime.health=60
	slime.knockback=Vector3.ZERO
	actor.state_time=actor.thrust_windup_seconds+actor.thrust_launch_seconds-.005
	actor._physics_process(.01)
	var gust=game.get_tree().get_nodes_in_group("thrust_gust").back()
	gust.set_physics_process(false)
	var count=game.get_tree().get_nodes_in_group("thrust_gust").size()
	actor._physics_process(.01)
	test.check(game.get_tree().get_nodes_in_group("thrust_gust").size()==count,"Sliding stop emits one pressure gust per thrust")
	slime.state="lunge"
	boar.state="windup"
	var hp=slime.health
	gust._physics_process(.35)
	test.check(is_equal_approx(slime.knockback.length(),20) and is_equal_approx(boar.knockback.length(),20) and slime.state=="recover" and boar.state=="recover" and slime.health==hp,"Stopping gust interrupts charges with 2.5x Medium strong recoil and no repeated damage")
	var age=gust.age
	actor.input_enabled=false
	gust._physics_process(.15)
	test.check(gust.age==age,"Menus freeze the pressure fan")
	actor.input_enabled=true
	gust.free()
	boar.position=Vector3(0,0,17)
	boar.knockback=Vector3.ZERO
	boar.state="windup"
	var wall=StaticBody3D.new()
	wall.collision_layer=1
	wall.collision_mask=0
	var collider=CollisionShape3D.new()
	var box=BoxShape3D.new()
	box.size=Vector3(2,1.5,.2)
	collider.shape=box
	wall.add_child(collider)
	game.current_world.add_child(wall)
	wall.position=Vector3(0,.75,16.3)
	await test.frames(2)
	game._thrust_stopped(actor.position+Vector3.BACK*.9,Vector3.BACK)
	gust=game.get_tree().get_nodes_in_group("thrust_gust").back()
	gust.set_physics_process(false)
	gust._physics_process(.50)
	test.check(boar.knockback.is_zero_approx() and boar.state=="windup","Solid scenery blocks the stopping gust")
	wall.free()
	for size in ["small","medium","large","giant"]:
		var specimen=game.Slime.new()
		specimen.configure({"id":"thrust_force_fixture","kind":"slime","at":[0,1],"size":size},actor)
		game.world_root.add_child(specimen)
		specimen.set_physics_process(false)
		specimen.take_sword_damage(1,Vector3.BACK,true,2.5)
		test.check(is_equal_approx(specimen.knockback.length(),specimen.sword_recoil_force(true)*2.5),"Direct thrust size recoil multiplier for "+size)
		specimen.free()
	actor.set_sword_drawn(true)
	actor.set_physics_process(true)
	game.load_map("herb_glade",Vector2(0,14),true)
	var warden=game.enemies[2]
	warden.respawn()
	warden.set_physics_process(false)
	warden.take_thrust_gust(Vector3.BACK,2.5,.85)
	test.check(warden.knockback.is_zero_approx(),"Pressure gust preserves Giant armor resistance")
	warden.armor_open=5
	warden.take_thrust_gust(Vector3.BACK,2.5,.85)
	test.check(is_equal_approx(warden.knockback.length(),5.5),"Exposed Giant weakspot receives the same 2.5x gust multiplier")
	game.load_map("coastal_path",Vector2(0,3),true)
	test.check(game.get_tree().get_nodes_in_group("thrust_gust").is_empty(),"Map replacement clears thrust pressure effects")
	game.progression.restore({"tree_version":2,"xp":0,"learned":[]})
	game.apply_skill_stats()
