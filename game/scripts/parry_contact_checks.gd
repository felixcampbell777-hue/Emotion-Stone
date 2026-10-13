extends RefCounted
func click(game:Control,pressed:bool) -> void:
	var event=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_RIGHT
	event.position=game.world_rect.get_center()
	event.global_position=event.position
	event.pressed=pressed
	Input.parse_input_event(event)
func run(test:RefCounted) -> void:
	var game=test.game
	game.start_new_game(false)
	game.load_map("slime_forest",Vector2(0,3),true)
	game.player.set_sword_drawn(true)
	game.player.visual.rotation.y=0
	var slime=game.enemies[0]
	slime.position=Vector3(0,0,4.7)
	slime.state="idle"
	slime.ai_enabled=true
	var contacts:Array=[]
	var listener=func(threat): contacts.append({"id":threat.get_instance_id(),"distance":threat.position.distance_to(game.player.position)})
	game.player.parry_succeeded.connect(listener)
	for i in range(100):
		await test.frames(1)
		if slime.state=="windup" and slime.state_time<=.20: break
	click(game,true)
	await test.frames(2)
	click(game,false)
	await test.frames(28)
	test.check(game.player.parry_resolved and game.player.health==100 and contacts.size()==1 and contacts[0].distance>.9,"Real right-click intercepts the natural slime lunge at guard reach, before body contact")
	var away=slime.position.distance_to(game.player.position)
	await test.frames(20)
	test.check(slime.position.distance_to(game.player.position)>away+.6 and slime.state=="recover","Guard interception actually sends the slime away and staggers it")
	game.load_map("herb_glade",Vector2(0,-11),true)
	game.player.set_sword_drawn(true)
	game.player.restore_health(100)
	game.player.restore_stamina(100)
	game.player.visual.rotation.y=0
	contacts.clear()
	var first=game.enemies[0]
	var second=game.enemies[1]
	var warden=game.enemies[2]
	warden.ai_enabled=false
	first.position=Vector3(-.6,0,-8)
	second.position=Vector3(.6,0,-8)
	for mob in [first,second]:
		mob.state="idle"
		mob.knockback=Vector3.ZERO
	for i in range(100):
		await test.frames(1)
		if first.state=="windup" and first.state_time<=.08: break
	click(game,true)
	await test.frames(2)
	click(game,false)
	await test.frames(30)
	test.check(contacts.size()==2 and game.player.health==100 and first.state=="recover" and second.state=="recover","One timed right-click deflects both naturally charging boars without a second hit")
	test.check(contacts.all(func(contact): return contact.distance>1.05),"Both boars are repelled at guard reach rather than after reaching the body")
	test.check(not game.player.try_parry(first) and not game.player.try_parry(second),"Distinct attackers can each resolve once; neither can resolve twice in that guard")
	await test.frames(20)
	test.check(first.position.z>-9 and second.position.z>-9,"Both parried boars visibly travel back along the trail")
	for mob in [first,second]: mob.ai_enabled=false
	game.player.set_sword_drawn(true)
	game.player.restore_stamina(100)
	game.player.restore_health(100)
	game.player.position=warden.position+Vector3(0,0,-4)
	game.player.visual.rotation.y=0
	contacts.clear()
	warden.state="idle"
	warden.ai_enabled=true
	var rock:Node3D
	for i in range(180):
		await test.frames(1)
		for projectile in game.projectiles:
			if is_instance_valid(projectile) and not projectile.reflected: rock=projectile
		if is_instance_valid(rock) and rock.position.distance_to(game.player.position)<=2.8: break
	test.check(is_instance_valid(rock),"Warden naturally releases a real incoming rock")
	if is_instance_valid(rock):
		click(game,true)
		await test.frames(2)
		click(game,false)
		await test.frames(20)
		test.check(is_instance_valid(rock) and rock.reflected and game.player.health==100 and contacts.size()==1 and contacts[0].distance>.65,"Right-click sends a natural rock back before it reaches the body")
		await test.frames(35)
		test.check(warden.armor_open>0 and warden.health==72,"Reflected rock reaches the warden, damages it and opens its armor")
	warden.ai_enabled=false
	game.player.set_sword_drawn(true)
	game.player.restore_stamina(100)
	game.player.begin_parry()
	await test.frames(14)
	first.position=game.player.position+Vector3(0,0,2.5)
	test.check(not game.player.try_parry(first),"A raised guard does not repel distant enemies")
	first.position=game.player.position+Vector3(0,0,-1.2)
	test.check(not game.player.try_parry(first),"Guard reach does not make rear attacks parryable")
	first.position=game.player.position+Vector3(0,0,1.2)
	var wall=StaticBody3D.new()
	wall.collision_layer=1
	var shape=CollisionShape3D.new()
	var box=BoxShape3D.new()
	box.size=Vector3(2,2,.1)
	shape.shape=box
	wall.add_child(shape)
	game.world_root.add_child(wall)
	wall.position=game.player.position+Vector3(0,.7,.6)
	await test.frames(2)
	test.check(not game.player.try_parry(first),"Walls block guard interception")
	wall.queue_free()
	game.player.parry_succeeded.disconnect(listener)
	game.player.set_sword_drawn(true)
