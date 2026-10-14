extends RefCounted
const Vertical=preload("res://scripts/vertical_water_wave.gd")
func run(test:RefCounted) -> void:
	var game=test.game;var actor=game.player
	game.load_map("coastal_path",Vector2(0,-5),true);await test.frames(3)
	for enemy in game.enemies: enemy.ai_enabled=false;enemy.position.x+=25
	actor.set_physics_process(false);game.camera_driver.set_mode("first_person");game.camera_driver.yaw=PI;game.camera_driver.first_pitch=0
	game.progression.restore({"tree_version":3,"xp":957383,"learned":["form","dash","mana","flowing_splash"],"passives":["flowing_splash"]});game.apply_skill_stats();actor.dash_equipped=true
	var helper=load("res://scripts/mana_dash_checks.gd").new();await helper.launch(actor)
	test.check(actor.dash_uppercut and actor.combo_stage==1,"Dash exit selects its dedicated uppercut without replacing normal combo attacks")
	var low=actor.first_person_sword.sample("dash_uppercut",.28);var high=actor.first_person_sword.sample("dash_uppercut",.68)
	test.check(high.direction.y-low.direction.y>1.4 and high.grip.y-low.grip.y>.5 and absf(high.grip.x-low.grip.x)<.05,"Authored dash swing rises straight upward instead of cutting sideways")
	var min_tip=INF;var good_basis=true
	for i in range(49):
		await test.frames(1);actor.state_time=lerpf(.28,.73,i/48.0)*actor.state_duration;actor._physics_process(0)
		min_tip=minf(min_tip,actor.sword_tip().y-game.current_world.ground_height(actor.sword_tip()))
		good_basis=good_basis and absf(actor.equipment.global_basis.determinant())>.1
	test.check(min_tip>.01 and good_basis,"Uppercut steel stays above ground with full blade basis (minimum %.3f, basis %s)"%[min_tip,good_basis])
	actor.set_sword_drawn(true);actor.begin_attack("light")
	test.check(not actor.dash_uppercut,"Ordinary light attacks retain the normal opening cut")
	var at=Vector3(0,0,-5);var toward=Vector3(0,0,1)
	var center=load("res://scripts/slime.gd").new();game.world_root.add_child(center);center.configure({"id":"uppercut_center","kind":"slime","at":[0,-3]},actor);center.set_physics_process(false);game.enemies.append(center)
	var side=load("res://scripts/slime.gd").new();game.world_root.add_child(side);side.configure({"id":"uppercut_side","kind":"slime","at":[1.7,-3]},actor);side.set_physics_process(false);game.enemies.append(side)
	var wave=Vertical.new();game.world_root.add_child(wave);wave.configure(game,at,toward,actor.combat.water);wave.set_physics_process(false)
	var original=center.health;await test.frames(2);wave.advance(.3)
	test.check(center.health<original and side.health==side.max_health,"Straight vertical wave damages a centerline enemy and misses an enemy outside its narrow width")
	var once=center.health;wave.advance(.02)
	test.check(center.health==once and wave.damage_at(1)>wave.damage_at(5),"The vertical wave hits once and retains distance damage falloff")
	game.toggle_pause();var held=wave.radius;wave._physics_process(.2)
	test.check(wave.radius==held,"Vertical water motion and fade freeze in overlays")
	game.pause_menu.close();game._refresh_simulation();wave.queue_free()
	center.health=center.max_health
	var wall=StaticBody3D.new();game.world_root.add_child(wall);wall.position=Vector3(0,1,-4);wall.collision_layer=1
	var collider=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(3,3,.2);collider.shape=shape;wall.add_child(collider)
	wave=Vertical.new();game.world_root.add_child(wave);wave.configure(game,at,toward,actor.combat.water);wave.set_physics_process(false)
	await test.frames(2);wave.advance(.4)
	test.check(wave.blocked_at<INF and wave.is_queued_for_deletion() and center.health==center.max_health,"Swept vertical wave stops at solid scenery and cannot damage enemies behind it")
	wall.queue_free();await test.frames(2)
	actor.undertow_cast=false;var count=game.water_waves.size();game._water_cast(at,toward)
	test.check(game.water_waves.size()==count+1 and not game.water_waves[-1] is Vertical,"The equipped Q Water Slash remains its existing horizontal fan")
	actor.set_sword_drawn(true);game.learn_skill("flowing_counter");center.health=1000;center.max_health=1000
	game.combat_skills.parried(center);await helper.launch(actor)
	test.check(actor.dash_uppercut and actor.combo_stage==1 and not actor.counter_active and actor.counter_remaining==0,"A queued dash uppercut takes priority over a pending Flowing Counter")
	actor.set_sword_drawn(true);actor.set_physics_process(true)
