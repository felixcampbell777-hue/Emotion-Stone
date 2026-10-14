extends RefCounted
func picture(game:Control,path:String) -> void:
	await game.get_tree().create_timer(.15).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
func run(game:Control,directory:String) -> void:
	game.game_mode="beta";game.start_new_game();game.set_resolution(0);game.camera_driver.set_mode("first_person")
	game.camera_driver.yaw=-PI/2;game.camera_driver.first_pitch=0
	game.progression.restore({"tree_version":3,"xp":957383,"learned":["mana","mana_lance","sea_dragon"],"passives":[]});game.apply_skill_stats();game.update_progression_ui();game.select_special_attack("sea_dragon")
	for enemy in game.enemies: enemy.ai_enabled=false;enemy.position.x+=25
	game.toggle_inventory();game.inventory.show_page("level");game.skill_tree.category="active";game.skill_tree.selected_id="sea_dragon";game.skill_tree.refresh()
	await picture(game,directory+"/sea-dragon-unlock.png")
	game.inventory.show_page("skills");await picture(game,directory+"/sea-dragon-equipped.png");game.inventory.close()
	game.player.set_sword_drawn(true);game.player.restore_stamina(100);game.player.invulnerability=0
	game.camera_driver.update_first_person(0);game.begin_sea_dragon();var dragon=game.sea_dragon;dragon.set_physics_process(false)
	# First-person caster view for a close model/material review, then actual remote flight.
	game.sea_dragon=null;dragon.elapsed=1;dragon.position=Vector3(5,1.7,-13);dragon.flight_yaw=.9;dragon.desired_yaw=.9
	dragon.trail.clear()
	for i in range(28): dragon.trail.append(dragon.position+Vector3(-.15,.06,1).normalized()*i*.20)
	dragon._update_visual();game.camera_driver.end_remote_view(true)
	await picture(game,directory+"/sea-dragon-model-review.png")
	game.sea_dragon=dragon;dragon.position=dragon.birth_origin;dragon.elapsed=0;dragon.flight_yaw=PI/2;dragon.desired_yaw=PI/2;dragon.flight_pitch=0;dragon.desired_pitch=0
	dragon.trail.clear()
	for i in range(28): dragon.trail.append(dragon.birth_origin+Vector3.LEFT*.04*i)
	game.player.set_physics_process(false);game.set_process(false)
	var body_position_before=game.player.position;game.player.position=Vector3(12,0,-12)
	dragon.dragon.visible=false;dragon.counter.visible=false
	var view_before=game.camera.global_transform;var fov_before=game.camera.fov
	for phase in [.25,.5,1.0]:
		game.player.state_time=phase*.8
		await game.get_tree().physics_frame
		game.player._physics_process(0);game.player.get_node("BetaHero").synchronize()
		var body_frame=game.player.dragon_pose.frame(game.player)
		game.camera.fov=38;game.camera.cull_mask=((1<<20)-1)&~game.camera_driver.visuals.ARMS_LAYER
		game.camera.position=body_frame*Vector3(-2.5,1.7,4.0);game.camera.look_at(body_frame*Vector3(-.1,.8,.15),Vector3.UP)
		await picture(game,directory+"/sea-dragon-caster-front-%02d.png"%roundi(phase*100))
		game.camera.position=body_frame*Vector3(-4,1.5,.4);game.camera.look_at(body_frame*Vector3(-.1,.8,.15),Vector3.UP)
		await picture(game,directory+"/sea-dragon-caster-side-%02d.png"%roundi(phase*100))
	game.player.position=body_position_before;dragon.dragon.visible=true;dragon.counter.visible=true
	game.player.state_time=0;game.player._physics_process(0);game.player.set_physics_process(true);game.set_process(true);game.camera.fov=fov_before;game.camera.global_transform=view_before
	var folder=directory+"/sea-dragon";DirAccess.make_dir_recursive_absolute(folder)
	var records=[]
	for frame in range(75):
		for tick in range(2):
			await game.get_tree().physics_frame
			if dragon.active: dragon.advance(1.0/60)
		game.camera_driver.update_first_person(0)
		await RenderingServer.frame_post_draw
		game.get_viewport().get_texture().get_image().save_png(folder+"/frame-%03d.png"%frame)
		records.append({"frame":frame,"elapsed":dragon.elapsed,"position":[dragon.position.x,dragon.position.y,dragon.position.z],"active":dragon.active,"health":game.player.health,"body_position":[game.player.position.x,game.player.position.y,game.player.position.z]})
		if frame==18:
			game.get_viewport().get_texture().get_image().save_png(directory+"/sea-dragon-emergence.png")
		if frame==36:
			dragon.steer(Vector2(.22,-.06))
		if frame==60:
			game.player.take_damage(10,Vector3.ZERO)
			game.get_viewport().get_texture().get_image().save_png(directory+"/sea-dragon-body-hit.png")
		if not dragon.active: break
	var file=FileAccess.open(folder+"/motion.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"	"));file.close()
	if dragon.active:
		await picture(game,directory+"/sea-dragon-first-person.png")
		var enemy=game.enemies[0];enemy.position=Vector3(12,0,-12);enemy.health=enemy.max_health
		dragon.position=Vector3(8,.65,-12);dragon.flight_yaw=PI/2;dragon.desired_yaw=PI/2;dragon.flight_pitch=0;dragon.desired_pitch=0
		await game.get_tree().physics_frame
		for tick in range(50):
			await game.get_tree().physics_frame
			dragon.advance(1.0/60)
			if not dragon.active: break
		dragon.advance(.22)
		game.camera_driver.update_first_person(.3)
		await picture(game,directory+"/sea-dragon-impact.png")
		if is_instance_valid(dragon): dragon.advance(.1)
	game.player.restore_stamina(100);game.player.set_sword_drawn(true);game.begin_sea_dragon()
	if is_instance_valid(game.sea_dragon): game.sea_dragon.set_physics_process(false)
	game.player.invulnerability=0;game.player.take_damage(9999,Vector3.ZERO)
	await picture(game,directory+"/sea-dragon-caster-death.png")
	print("CAPTURE_OK "+directory)
