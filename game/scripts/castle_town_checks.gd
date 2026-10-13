extends RefCounted
func run(test:RefCounted) -> void:
	var game=test.game;var world=game.current_world;var start=game.player.position
	var safe=true
	for x in range(1,68): safe=safe and world.safe_position(Vector3(x,0,-10))
	for z in range(-10,13): safe=safe and world.safe_position(Vector3(53,0,z))
	test.check(safe,"Castle road, five-metre west gate, market avenue and keep approach are continuously walkable")
	var blocked=true
	for at in [Vector3(40,0,-22),Vector3(70,0,0),Vector3(30,0,10),Vector3(53,0,18),Vector3(37,0,-17),Vector3(46,0,-3)]: blocked=blocked and not world.safe_position(at)
	test.check(blocked,"Castle walls, keep, houses and market counters reject unsafe save/spawn positions")
	game.player.position=Vector3(27,0,-10);game.camera_driver.set_mode("overhead")
	Input.action_press("move_right");await test.frames(180);Input.action_release("move_right")
	test.check(game.player.position.x>31 and absf(game.player.position.z+10)<.15,"Real heroine collision passes through the open castle gate")
	game.player.position=Vector3(68,0,0)
	Input.action_press("move_right");await test.frames(100);Input.action_release("move_right")
	test.check(game.player.position.x<69.2,"Real heroine collision blocks the town perimeter wall")
	game.player.position=Vector3(53,0,-10)
	var path="user://castle-town-verification.json";var save=game.save_data()
	test.check(game.Save.write(save,path)==OK and game.apply_save(game.Save.read(path)) and game.player.position.distance_to(Vector3(53,0,-10))<.1,"Private Beta save round trip restores castle-town street position")
	DirAccess.remove_absolute(path)
	world=game.current_world
	var masks=true
	for body in world.find_children("*","StaticBody3D",true,false):
		if String(body.name).begins_with("CameraOccluder"): masks=masks and body.collision_layer==8
	test.check(masks and game.enemies.size()==14,"Town roof camera masks and the fourteen existing forest encounters are preserved")
	game.player.position=start
	for enemy in game.enemies:enemy.ai_enabled=false
