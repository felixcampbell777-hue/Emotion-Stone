extends RefCounted
func run(test:RefCounted) -> void:
	var game=test.game
	game.load_map("menagery",Vector2(-11,-16.1),true)
	game.player.set_sword_drawn(false)
	game.player.set_physics_process(false)
	await test.frames(2)
	var world=game.current_world
	test.check(world.ground_height(Vector3(-11,0,-21))>1.7,"1F is a genuine elevated knoll, not a flat prop")
	test.check(world.ground_height(Vector3(1.5,0,-21))>2.1,"2F has two continuous rolling summit/saddle surfaces")
	var top=world.get_node("feature_1f").get_children().filter(func(node): return node is MeshInstance3D)[0]
	var normals=top.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	test.check(normals[0].y>.9,"Terrain surface normals face upward and render the walkable mesh")
	test.check(world.ground_height(Vector3(4,0,-21))<1 and world.ground_height(Vector3(6.5,0,-21))>2.1,"Twin ridge has two distinct peaks with a lower traversable saddle")
	game.camera_driver.set_mode("overhead")
	var bounded=true
	for corner in [world.bounds.position,world.bounds.end,Vector2(world.bounds.position.x,world.bounds.end.y),Vector2(world.bounds.end.x,world.bounds.position.y)]:
		var focus=game.bounded_camera_target(Vector3(corner.x,3,corner.y))
		game.camera.position=focus+game.camera_offset; game.camera.look_at(focus,Vector3.UP)
		for sx in [0,game.world_view.size.x]:
			for sy in [0,game.world_view.size.y]:
				var origin=game.camera.project_ray_origin(Vector2(sx,sy))
				var ray=game.camera.project_ray_normal(Vector2(sx,sy))
				var ground=origin-ray*(origin.y/ray.y)
				bounded=bounded and world.bounds.has_point(Vector2(ground.x,ground.z))
	test.check(bounded,"Raised-ground overhead camera still keeps every projected corner on the map")
	var terrace=world.terrain_features.filter(func(prop): return prop.catalog_code=="4F")[0]
	var terrace_node=world.get_node("feature_4f")
	terrace.rotation=90; terrace.scale=1.5; terrace_node.rotation.y=PI/2; terrace_node.scale=Vector3.ONE*1.5
	var on_ramp=terrace_node.to_global(Vector3(0,0,3))
	test.check(is_equal_approx(world.ground_height(on_ramp),.675),"Rotated and scaled terrain height follows the actual Godot feature transform")
	terrace.rotation=0; terrace.scale=1; terrace_node.rotation.y=0; terrace_node.scale=Vector3.ONE
	# Exercise actual CharacterBody movement, collision and terrain height, not only formulas.
	for i in range(240):
		game.player.velocity=Vector3(0,0,-2)
		world.move_grounded(game.player,1.0/60)
	test.check(game.player.position.z< -23 and game.player.position.y>.3,"Character actually ascends and descends a rolling hill")
	test.check(absf(game.player.position.y-world.ground_height(game.player.position))<.0001,"Walking feet remain attached to the rendered triangular ground")
	game.player.position=Vector3(-11,0,-29.3)
	for i in range(220):
		game.player.velocity=Vector3(0,0,-2)
		world.move_grounded(game.player,1.0/60)
	test.check(game.player.position.y>2.7 and game.player.position.z< -35,"3F southern walk-up reaches the bluff top without jumping")
	game.player.position=Vector3(-16,0,-35)
	for i in range(140):
		game.player.velocity=Vector3(3,0,0)
		world.move_grounded(game.player,1.0/60)
	test.check(game.player.position.x< -14.2 and game.player.position.y<.1,"3F exposed rock face blocks horizontal movement")
	game.player.position=Vector3(-11,2.8,-35)
	for i in range(140):
		game.player.velocity=Vector3(-3,0,0)
		world.move_grounded(game.player,1.0/60)
	test.check(game.player.position.x> -14.1 and game.player.position.y>2.7,"Cliff edge prevents walking off the top and teleporting to ground")
	game.player.position=Vector3(4,0,-29.3)
	for i in range(220):
		game.player.velocity=Vector3(0,0,-2)
		world.move_grounded(game.player,1.0/60)
	test.check(game.player.position.y>2.3,"4F walk-up crosses both shelves continuously")
	# Elevation derives from X/Z on load; no incompatible save-height field.
	game.player.state="free"; game.player.restore_health(100)
	var path="user://terrain-verification.json"
	game.Save.write(game.save_data(),path)
	var data=game.Save.read(path)
	var ok=game.apply_save(data)
	test.check(not data.is_empty() and ok and game.player.position.y>2.3,"Private save restores a plateau position and derives its height")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.player.position=Vector3(-11,1.8,-21)
	game._ground_slam(game.player.position,true)
	var impacts=game.get_tree().get_nodes_in_group("ground_slam")
	test.check(impacts[-1].position.y>1.7,"Sword impact effects land on raised terrain instead of the old ground plane")
	var entry=world.definition.exits.filter(func(exit): return exit.id=="cave_door")
	test.check(entry.size()==1 and entry[0].interact,"1G cave mouth has an actual E entrance")
	game.load_map("menagery_cave",Vector2(0,5.5),true)
	await test.frames(2)
	world=game.current_world
	test.check(world.definition.get("cave",false) and world.safe_position(game.player.position),"Cave opens in a playable private-save-safe entry chamber")
	var route=[Vector3(0,0,1.2),Vector3(-.4,0,-2.3),Vector3(0,0,-4.5)]
	for goal in route:
		for i in range(240):
			var direction=(goal-game.player.position)*Vector3(1,0,1)
			if direction.length()<.15: break
			game.player.velocity=direction.normalized()*2.2
			world.move_grounded(game.player,1.0/60)
	test.check(game.player.position.z< -4,"Character traverses the cave arch and winding passage to the crystal chamber")
	game.Save.write(game.save_data(),path)
	test.check(not game.Save.read(path).is_empty(),"Cave location passes private save validation")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	test.check(world.definition.exits[0].target=="menagery" and world.definition.exits[0].interact,"Cave has a working return doorway")
	game.load_map("coastal_path",Vector2(0,3),true)
	game.player.set_physics_process(true)
	test.check(game.player.position.y==0 and game.player.ground_world==game.current_world,"Map travel restores flat-world grounding and removes cave ownership")
