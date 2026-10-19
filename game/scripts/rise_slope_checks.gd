extends RefCounted
func travel(test:RefCounted,body:CharacterBody3D,start:Vector2,direction:Vector2,speed:float) -> Dictionary:
	var world=test.game.current_world
	body.position=Vector3(start.x,0,start.y);body.position.y=world.ground_height(body.position)
	var origin=body.position
	var mob=body!=test.game.player
	if mob:
		# Exercise active nearby AI. The previous player route ends far away,
		# so the real 60m sleep budget otherwise correctly skips this fixture.
		var observer=body.position+Vector3(-direction.y,0,direction.x).normalized()*8
		test.game.player.position=observer
		test.game.player.position.y=world.support_height(test.game.player,observer)
		body.ai_enabled=true;body.simulation_enabled=true;body.state="idle";body.encounter_goal=body.position+Vector3(direction.x,0,direction.y).normalized()*20;body.encounter_engaged=false
	for i in range(90):
		await test.frames(1)
		if mob:body._physics_process(1.0/60)
		else:body.velocity=Vector3(direction.x,0,direction.y).normalized()*speed;world.move_grounded(body,1.0/60)
	if mob:body.ai_enabled=false
	var toward=Vector3(direction.x,0,direction.y).normalized()
	return {"forward":(body.position-origin).dot(toward),"rise":body.position.y-origin.y,"at":body.position}
func run(test:RefCounted) -> void:
	var g=test.game;var player=g.player;var saved=player.position
	var boar=g.enemies.filter(func(e):return e.definition.kind=="library_boar")[0]
	var old=boar.position;var readings=[]
	for body in [player,boar]:
		for fixture in [[Vector2(18,-20),Vector2(1,-1)],[Vector2(92,80),Vector2(1,1)],[Vector2(-35,15),Vector2(-1,0)]]:
			var result=await travel(test,body,fixture[0],fixture[1],2.4 if body==player else 1.2);readings.append(result)
			test.check(result.forward>(2.0 if body==player else .9) and result.rise>.1,"Real physics uphill travel at walking speed: "+String(body.name)+" from "+str(fixture[0])+" "+str(result))
		var settled=body.position
		for i in range(30):
			await test.frames(1);body.velocity=Vector3.ZERO;g.current_world.move_grounded(body,1.0/60)
		test.check(Vector2(body.position.x-settled.x,body.position.z-settled.z).length()<.02,"Standing on a slope does not push "+String(body.name)+" downhill")
	# A genuine vertical obstacle must remain solid with the higher hill limit.
	player.position=Vector3(92,0,80);player.position.y=g.current_world.support_height(player,player.position)
	var wall=StaticBody3D.new();wall.collision_layer=1;var c=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(.4,5,5);c.shape=box;wall.add_child(c);g.current_world.add_child(wall);wall.position=player.position+Vector3(2,2,0)
	await test.frames(2)
	for i in range(75):
		await test.frames(1);player.velocity=Vector3(2.4,0,0);g.current_world.move_grounded(player,1.0/60)
	test.check(player.position.x<wall.position.x-.25,"Slope correction keeps actual walls impassable")
	wall.queue_free();await test.frames(2)
	player.position=saved;boar.position=old
	print("RISE_SLOPE ",readings)
