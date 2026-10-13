extends RefCounted
func run(test:RefCounted) -> void:
	var game=test.game
	game.start_new_game(false)
	game.load_map("village_green",Vector2(0,3.5),true)
	game.camera_driver.set_mode("follow")
	game.camera_driver.recenter()
	game.camera_target=game.player.position+Vector3(0,1.05,0)
	await test.frames(8)
	test.check(game.camera.projection==Camera3D.PROJECTION_PERSPECTIVE and game.player.camera_relative,"Follow mode uses perspective and camera-relative movement")
	var offset=game.camera.position-game.camera_target
	test.check(offset.dot(game.player.facing())<0 and offset.y<offset.length()*.6,"Follow camera sits behind the heroine instead of overhead")
	var button=InputEventMouseButton.new()
	button.position=game.world_rect.get_center()
	button.button_index=MOUSE_BUTTON_MIDDLE
	button.pressed=true
	Input.parse_input_event(button.duplicate())
	await test.frames(1)
	var yaw=game.camera_driver.yaw
	var motion=InputEventMouseMotion.new()
	motion.position=button.position
	motion.relative=Vector2(90,20)
	Input.parse_input_event(motion)
	await test.frames(1)
	button.pressed=false
	Input.parse_input_event(button.duplicate())
	await test.frames(1)
	test.check(absf(game.camera_driver.yaw-yaw)>.4 and not game.camera_driver.orbiting,"Actual middle-mouse input rotates the camera and release stops orbiting")
	game.player.movement_camera_yaw=PI/2
	test.check(game.player.movement_vector(Vector2(0,-1)).distance_to(Vector3(-1,0,0))<.001,"Forward follows the rotated camera direction")
	test.check(absf(game.player.movement_vector(Vector2(1,-1).normalized()).length()-1)<.001,"Camera-relative diagonals retain normalized movement speed")
	button.button_index=MOUSE_BUTTON_WHEEL_UP
	button.pressed=true
	for i in range(30): game.camera_driver.handle_input(button)
	test.check(game.camera_driver.distance==3,"Zoom stops at the close limit")
	button.button_index=MOUSE_BUTTON_WHEEL_DOWN
	for i in range(30): game.camera_driver.handle_input(button)
	test.check(game.camera_driver.distance==8,"Zoom stops at the far limit")
	game.camera_driver.distance=5.5
	game.camera_driver.yaw=PI
	game.camera_driver.pitch=.32
	game.camera_target=game.player.position+Vector3(0,1.05,0)
	game.camera_driver.actual_distance=5.5
	var wall=StaticBody3D.new()
	wall.collision_layer=8
	var collider=CollisionShape3D.new()
	var box=BoxShape3D.new()
	box.size=Vector3(2,12,.2)
	collider.shape=box
	wall.add_child(collider)
	game.world_root.add_child(wall)
	wall.position=game.camera_target+Vector3(0,0,-2)
	await test.frames(3)
	test.check(game.camera.position.z>wall.position.z+.1,"Scenery collision brings the camera forward before crossing a wall")
	wall.queue_free()
	await test.frames(35)
	test.check(game.camera.position.distance_to(game.camera_target)>3,"Camera eases back out after an obstruction clears")
	var path="user://camera-verification.json"
	var saved=game.save_data()
	game.Save.write(saved,path)
	game.toggle_camera()
	test.check(game.camera_mode=="first_person" and game.player.camera_relative,"C cycle includes first person before overhead")
	game.toggle_camera()
	test.check(game.camera_mode=="overhead" and not game.player.camera_relative,"Overhead remains available with its original movement")
	test.check(game.apply_save(game.Save.read(path)) and game.camera_mode=="follow" and absf(game.camera_driver.distance-5.5)<.001,"Saved game restores follow view and zoom")
	saved.camera_pitch=9
	game.Save.write(saved,path)
	test.check(game.Save.read(path).is_empty(),"Invalid saved camera angles are rejected")
	DirAccess.remove_absolute(path)
	for map in ["coastal_path","village_green","slime_forest","herb_glade"]:
		game.load_map(map,Vector2.ZERO,true)
		var bounds=game.current_world.bounds
		for corner in [bounds.position+Vector2(.6,.6),Vector2(bounds.end.x-.6,bounds.position.y+.6),bounds.end-Vector2(.6,.6),Vector2(bounds.position.x+.6,bounds.end.y-.6)]:
			game.player.position=Vector3(corner.x,0,corner.y)
			game.camera_target=game.player.position+Vector3(0,1.05,0)
			await test.frames(2)
			test.check(bounds.has_point(Vector2(game.camera.position.x,game.camera.position.z)),"Follow camera stays inside %s corner %s" % [map,corner])
	game.load_map("village_green",Vector2(0,3.5),true)
	var key=InputEventKey.new()
	key.physical_keycode=KEY_C
	key.pressed=true
	Input.parse_input_event(key.duplicate())
	await test.frames(2)
	key.pressed=false
	Input.parse_input_event(key.duplicate())
	test.check(game.camera_mode=="first_person","Actual C input switches to first person")
	game.toggle_camera()
	game.toggle_camera()
	game.camera_driver.yaw=.5
	key.physical_keycode=KEY_V
	key.pressed=true
	var facing_at_recenter=game.player.visual.rotation.y
	Input.parse_input_event(key.duplicate())
	await test.frames(2)
	key.pressed=false
	Input.parse_input_event(key.duplicate())
	# Recenter uses facing at the key press; smooth turning may continue during these frames.
	test.check(absf(wrapf(game.camera_driver.yaw-facing_at_recenter-PI,-PI,PI))<.001,"Actual V input recenters behind the heroine at key press")
	game.toggle_inventory()
	button.button_index=MOUSE_BUTTON_MIDDLE
	test.check(not game.camera_driver.handle_input(button) and not game.camera_driver.orbiting,"Inventory blocks camera orbit input")
	game.inventory.close()
	await test.frames(2)
	# Exercise the natural lunges and reflected warden rock in the new view too.
	await load("res://scripts/parry_contact_checks.gd").new().run(test)
	game.camera_driver.set_mode("overhead")
