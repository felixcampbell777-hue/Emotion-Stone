extends RefCounted
func picture(game:Control,path:String) -> void:
	await game.get_tree().process_frame
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
func click(game:Control,pressed:bool) -> void:
	var event=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_RIGHT
	event.position=game.world_rect.get_center()
	event.global_position=event.position
	event.pressed=pressed
	Input.parse_input_event(event)
func run(game:Control,directory:String) -> void:
	game.start_new_game(false)
	game.load_map("herb_glade",Vector2(0,-11),true)
	game.player.set_sword_drawn(true)
	game.player.visual.rotation.y=0
	var first=game.enemies[0]
	var second=game.enemies[1]
	var warden=game.enemies[2]
	warden.ai_enabled=false
	first.position=Vector3(-.6,0,-8)
	second.position=Vector3(.6,0,-8)
	for i in range(120):
		await game.get_tree().physics_frame
		if first.state=="windup" and first.state_time<=.08: break
	click(game,true)
	await game.get_tree().physics_frame
	click(game,false)
	for i in range(80):
		await game.get_tree().physics_frame
		if game.player.parried_threats.size()==2: break
	if game.player.parried_threats.size()!=2: push_error("Rendered right-click did not repel both boars")
	await picture(game,directory+"/parry-both-boars.png")
	for i in range(16): await game.get_tree().physics_frame
	await picture(game,directory+"/parry-boars-knocked-back.png")
	first.ai_enabled=false
	second.ai_enabled=false
	game.player.set_sword_drawn(true)
	game.player.restore_stamina(100)
	game.player.position=warden.position+Vector3(0,0,-4)
	game.player.visual.rotation.y=0
	warden.ai_enabled=true
	var rock:Node3D
	for i in range(180):
		await game.get_tree().physics_frame
		for item in game.projectiles:
			if is_instance_valid(item) and not item.reflected: rock=item
		if is_instance_valid(rock) and rock.position.distance_to(game.player.position)<=2.8: break
	if not is_instance_valid(rock):
		push_error("Warden did not throw the rendered rock")
		return
	await picture(game,directory+"/parry-rock-incoming.png")
	click(game,true)
	await game.get_tree().physics_frame
	click(game,false)
	for i in range(60):
		await game.get_tree().physics_frame
		if not is_instance_valid(rock) or rock.reflected: break
	if not is_instance_valid(rock) or not rock.reflected:
		push_error("Rendered right-click did not reflect the rock")
		return
	await picture(game,directory+"/parry-rock-reflected.png")
	for i in range(60):
		await game.get_tree().physics_frame
		if warden.armor_open>0: break
	if warden.armor_open<=0 or game.player.health!=100: push_error("Reflected rock did not open warden armor safely")
	await picture(game,directory+"/parry-warden-armor-open.png")
