extends RefCounted
func key(code:int) -> void:
	for pressed in [true,false]:
		var event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed
		Input.parse_input_event(event);Input.flush_buffered_events()
func prepare(game:Control) -> void:
	game.cancel_sea_dragon();game.player.set_sword_drawn(true);game.player.invulnerability=0;game.player.knockback=Vector3.ZERO
	game.player.restore_health(game.player.max_health);game.player.restore_stamina(game.player.max_stamina);game.player.position=Vector3(0,0,-12)
	game.camera_driver.yaw=0;game.camera_driver.first_pitch=0;game.camera_driver.update_first_person(0)
func launch(game:Control) -> Node3D:
	game.begin_sea_dragon();var dragon=game.sea_dragon;dragon.set_physics_process(false)
	return dragon
func run(test:RefCounted) -> void:
	var game=test.game;var actor=game.player
	game.game_mode="beta";game.start_new_game();game.camera_driver.set_mode("first_person");await test.frames(3)
	for enemy in game.enemies: enemy.ai_enabled=false
	actor.set_physics_process(false)
	game.progression.restore({"tree_version":3,"xp":957383,"learned":["mana"],"passives":[]});game.apply_skill_stats();prepare(game)
	test.check(not game.progression.can_learn("sea_dragon") and not game.begin_sea_dragon(),"Sea Dragon cannot be learned or cast before Water Lance")
	game.learn_skill("mana_lance");test.check(game.progression.can_learn("sea_dragon"),"Mana Sea Dragon is the next active Mana unlock after Water Lance")
	game.learn_skill("sea_dragon");game.select_special_attack("sea_dragon")
	test.check(game.selected_special_attack=="sea_dragon" and actor.dragon_unlocked,"Learned Sea Dragon equips into the existing Q magic slot")
	actor.restore_stamina(44);test.check(not game.begin_sea_dragon() and game.sea_dragon==null,"Insufficient stamina cannot create a remote dragon")
	prepare(game);var gem=actor.sword_gem_position();key(KEY_Q);var dragon=game.sea_dragon
	test.check(is_instance_valid(dragon) and dragon.birth_origin.distance_to(gem)<.001 and actor.state=="dragon_channel" and is_equal_approx(actor.stamina,55),"Actual Q summons from the rendered gem and spends exactly 45 stamina")
	if not is_instance_valid(dragon): actor.set_physics_process(true);return
	dragon.set_physics_process(false)
	test.check(not game.begin_sea_dragon() and not actor.begin_attack("light") and not actor.begin_jump() and not actor.begin_parry(),"Remote control cannot duplicate casts, move the caster or start defensive attacks")
	var body=actor.position;var mouse=InputEventMouseMotion.new();mouse.relative=Vector2(180,-100)
	game._input(mouse);dragon.advance(.25)
	test.check(dragon.desired_yaw>0 and dragon.desired_pitch>0 and dragon.flight_yaw>0 and actor.position==body,"Real mouse motion steers the dragon independently of the caster")
	game.camera_driver.update_first_person(0)
	test.check(game.camera.global_transform.is_equal_approx(dragon.view_transform()) and not game.camera_driver.visuals.root.visible,"First-person view transfers to the dragon and hides human view hands")
	var clock=dragon.elapsed;var position=dragon.position;var health=actor.health
	game.toggle_pause();dragon._physics_process(.3);game.camera_driver.update_first_person(.3)
	test.check(dragon.elapsed==clock and dragon.position==position and not actor.take_damage(5,Vector3.ZERO),"Pause freezes flight, camera and caster damage consistently")
	game.pause_menu.close();game._refresh_simulation()
	test.check(actor.take_damage(10,Vector3.RIGHT) and actor.health==health-10 and dragon.active and actor.state=="dragon_channel","The stationary body takes real damage while the dragon remains steerable")
	test.check(game.enemies.all(func(enemy):return enemy.simulation_enabled),"Enemies remain simulated during remote dragon flight")
	dragon.finish(false,true);await test.frames(2)
	prepare(game);dragon=launch(game);dragon.tuning.speed=.05;dragon.global_position=Vector3(0,7,-12);dragon.elapsed=9.99;dragon.advance(.02)
	test.check(not dragon.active and dragon.reason=="timeout" and game.sea_dragon==null and actor.state=="free","Flight ends at exactly ten simulated seconds and releases the caster")
	test.check(actor.sword_energy_materials.is_empty() and game.camera.cull_mask&game.camera_driver.visuals.ARMS_LAYER!=0,"Timeout restores steel and the human first-person rendering layers")
	await test.frames(2);prepare(game);dragon=launch(game);dragon.global_position=Vector3(0,7,-12);dragon.elapsed=1;dragon.advance(.01)
	test.check(actor.sword_energy_materials.is_empty(),"Gem emergence stops glowing once the water dragon has formed")
	var path="user://sea-dragon-private.json";var saved=game.save_data();game.Save.write(saved,path)
	test.check(game.Save.read(path).special_attack=="sea_dragon" and game.apply_save(game.Save.read(path)) and game.sea_dragon==null and actor.state!="dragon_channel" and game.selected_special_attack=="sea_dragon","Private save/load retains the learned equipped skill but never restores a flying projectile or remote camera")
	DirAccess.remove_absolute(path);await test.frames(3)
	for enemy in game.enemies: enemy.ai_enabled=false
	prepare(game);var victim=game.enemies[0];victim.health=1000;victim.max_health=1000;victim.position=Vector3(0,0,-18)
	var others=game.enemies.filter(func(enemy):return enemy!=victim)
	for enemy in others: enemy.position.x+=20
	await test.frames(3)
	dragon=launch(game);dragon.global_position=Vector3(0,.65,-12);dragon.flight_yaw=0;dragon.desired_yaw=0;dragon.flight_pitch=0;dragon.desired_pitch=0;dragon.elapsed=1
	for tick in range(90):
		dragon.advance(1.0/60)
		if not dragon.active: break
	test.check(not dragon.active and dragon.reason=="impact" and dragon.impact_count==1 and victim.health==860,"Swept dragon collision hits the actual enemy capsule once for direct damage")
	dragon.finish(true);test.check(victim.health==860,"Repeated finish cannot duplicate the Sea Dragon explosion")
	await test.frames(2);prepare(game)
	var wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0;game.world_root.add_child(wall)
	var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(5,4,.5);wall.add_child(shape);wall.position=Vector3(0,2,-15)
	await test.frames(3);dragon=launch(game);dragon.global_position=Vector3(0,.65,-12);dragon.flight_yaw=0;dragon.desired_yaw=0;dragon.flight_pitch=0;dragon.desired_pitch=0;dragon.elapsed=1
	for tick in range(60):
		dragon.advance(1.0/60)
		if not dragon.active: break
	test.check(not dragon.active and dragon.position.z>-15 and victim.health==860,"Scenery stops the dragon and shields an enemy behind the wall")
	wall.queue_free();await test.frames(2);prepare(game);dragon=launch(game);var previous=victim.health
	actor.invulnerability=0;actor.take_damage(9999,Vector3.ZERO)
	test.check(game.recovering and game.sea_dragon==null and not dragon.active and victim.health==previous and game.camera_driver.remote_return==0,"Caster death immediately cuts remote control without firing an explosion")
	game.respawn_player();await test.frames(3)
	for enemy in game.enemies: enemy.ai_enabled=false
	prepare(game);dragon=launch(game);game.load_map("beta_meadow",Vector2(0,-12),true)
	test.check(game.sea_dragon==null and not dragon.active and actor.state=="free","Replacing an area cancels its remote dragon safely")
	game.progression.restore({"tree_version":3,"xp":0,"learned":[],"passives":[]});game.apply_skill_stats()
	test.check(game.selected_special_attack=="water_sweep" and not actor.dragon_unlocked,"Removing the unlock restores the default magic slot without granting free Sea Dragon")
	actor.set_physics_process(true)
