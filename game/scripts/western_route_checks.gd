extends RefCounted
const West=preload("res://scripts/west_islands.gd")
func run(test:RefCounted) -> void:
	var g=test.game;g.game_mode="world_rise";g.start_new_game(false);g.title_screen.hide();g.set_process(false);g.set_physics_process(false);g.player.set_physics_process(false);g._refresh_simulation()
	for e in g.enemies:e.set_physics_process(false);e.ai_enabled=false
	await test.frames(2)
	var world=g.current_world;var connected=true
	for link in West.links():
		var a:Vector3=link[0];var b:Vector3=link[1];g.player.position=a
		if g.player.has_meta("rise_fall"):g.player.remove_meta("rise_fall")
		for frame in range(1800):
			var toward=(b-g.player.position)*Vector3(1,0,1)
			if toward.length()<.3:break
			g.player.velocity=toward.normalized()*5;world.move_grounded(g.player,1.0/60)
		connected=connected and Vector2(g.player.position.x-b.x,g.player.position.z-b.z).length()<.4 and not g.player.has_meta("rise_fall")
		print("WEST_BRIDGE ",a," -> ",b," actual ",g.player.position," fall ",g.player.has_meta("rise_fall")," collisions ",g.player.get_slide_collision_count())
	test.check(connected,"Actual player capsule walks all four level bridges from the central island to the grove")
	test.check(West.links().all(func(link):return absf(link[0].y-link[1].y)<.001 and absf(link[0].y-West.bridge_level())<.001),"All bridge decks share the western main-island landing elevation")
	test.check(West.ISLANDS[1].center.z<West.ISLANDS[0].center.z-20 and West.ISLANDS[2].center.z>West.ISLANDS[1].center.z+40,"Western route bends north then south rather than forming a line")
	var hill=West.ISLANDS[0];test.check(West.island_height(hill,hill.center)-West.bridge_level()>=4.99,"Small islands have significant walkable hill relief and matching ground materials")
	var air=Vector3(-310,40,110);test.check(not world.safe_position(air) and not world.island_walkable(air),"Empty sky between the islands has no invisible support")
	g.player.position=West.GROVE;g.player.position.y=world.ground_height(g.player.position)
	var file="user://western-route-verification.json";var save=g.save_data();g.Save.write(save,file);var readback=g.Save.read(file)
	test.check(not readback.is_empty() and g.apply_save(readback) and g.player.position.x< -430,"Private save/load retains an outer-island position rather than moving it to the arrival crystal")
	g.set_process(false);g.set_physics_process(false);g.player.set_physics_process(false);g._refresh_simulation();world=g.current_world
	g.worldrise.day_clock=800;g.worldrise.spawn_ashfang();await test.frames(2)
	var boss=g.enemies.filter(func(e):return e.definition.id=="ashfang")[0];boss.set_physics_process(false);boss.simulation_enabled=true;boss.ai_enabled=true
	test.check(absf(boss.position.y-world.ground_height(boss.position))<.1 and boss.mob_category=="canine","Ashfang spawns grounded in the relocated grove with Canine classification")
	boss.engaged=true;boss.state="windup";boss.state_time=.2;boss.direction=Vector3.RIGHT;g.player.position=boss.position+Vector3(0,0,8);boss._physics_process(.05)
	test.check(boss.direction.dot(Vector3.RIGHT)>.99,"Final Ashfang windup locks aim so a dodge can escape the lunge")
	boss.state="gnash";boss.state_time=1.0;var at=boss.position;boss._physics_process(.5)
	test.check(boss.state=="gnash" and boss.position.distance_to(at)<.1,"Missed lunge leaves a stationary one-second gnashing counter window")
	boss.state="recover";boss.state_time=.1;boss._physics_process(.2);test.check(boss.state=="circle","Parry or hit recoil recovers back to circling without freezing the boss")
	boss.health=180;boss._physics_process(.01)
	var helpers=g.enemies.filter(func(e):return e.definition.get("pack","")=="ashfang_aid")
	for e in helpers:e.set_physics_process(false);e.ai_enabled=true;e.simulation_enabled=true
	var packs=g.wolf_packs.packs.filter(func(p):return p.id=="ashfang_aid")
	test.check(helpers.size()==3 and packs.size()==1 and packs[0].engaged and helpers.all(func(e):return absf(e.position.y-world.ground_height(e.position))<.1),"Half-health howl creates exactly three grounded wolves in an engaged attack pack")
	boss._physics_process(.01);test.check(g.enemies.filter(func(e):return e.definition.get("pack","")=="ashfang_aid").size()==3,"Half-health reinforcement howl triggers only once")
	var ashfang_xp=g.progression.xp;var ashfang_base=g.enemy_xp_reward("ashfang");boss.take_damage(9999,Vector3.ZERO);var xp=g.progression.xp;g.Save.write(g.save_data(),file)
	test.check(xp==ashfang_xp+ashfang_base+200 and "ashfang_first_kill_bonus" in g.worldrise.flags,"First Ashfang victory grants its normal reward plus a one-time 200 XP bonus")
	test.check(g.worldrise.ashfang_respawn==1080 and not g.Save.read(file).is_empty(),"Ashfang kill starts a saved eighteen-minute cooldown and valid boss loot/defeat record")
	g.worldrise.ashfang_respawn=.05;g.worldrise.tick(.1)
	test.check(g.enemies.any(func(e):return e.definition.id=="ashfang" and e.health>0) and g.progression.xp==xp,"Cooldown expiry can replace the dead Ashfang during night without duplicate XP")
	g.worldrise.day_clock=100;g.worldrise.tick(.01);test.check(not g.enemies.any(func(e):return e.definition.id=="ashfang" and e.health>0),"Dawn retires Ashfang while preserving the night-only appearance rule")
	DirAccess.remove_absolute(file)
