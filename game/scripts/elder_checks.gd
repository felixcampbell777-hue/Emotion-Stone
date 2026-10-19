extends RefCounted
func tick(boss:Node,seconds:float) -> void:
	for i in range(ceili(seconds*60)):boss._physics_process(1.0/60)
func run(test:RefCounted) -> void:
	var g=test.game
	g.title_screen.hide();g._refresh_simulation();g.load_map("wr_boss_chamber",Vector2(0,36),true);g.player.set_physics_process(false);g.set_process(false);g.set_physics_process(false)
	var chamber=g.current_world;chamber.set_physics_process(false)
	test.check(chamber.encounter=="waiting" and g.enemies.is_empty() and chamber.bridge_open,"Elder waits until the player commits to the fighting island")
	g.player.position=Vector3(0,0,24);chamber.tick(.016)
	test.check(chamber.encounter=="waiting","Player is safely on the island before its entrance ramp is removed")
	g.player.position=Vector3(0,0,22);chamber.tick(.016)
	var boss=chamber.boss;boss.set_physics_process(false)
	test.check(chamber.encounter=="forming" and not chamber.bridge_open and not chamber.bridge_mesh.visible and chamber.bridge_body.collision_layer==0,"Stepping onto the island removes both ramp rendering and collision")
	test.check(not chamber.safe_position(Vector3(0,0,34)) and not chamber.interactions.any(func(t):return t.has("wr_chamber")),"Removed ramp is unsupported and the return interaction cannot bypass the fight")
	g.worldrise.interact({"wr_chamber":"leave"})
	test.check(g.map_id=="wr_boss_chamber","Return travel cannot bypass the sealed encounter")
	var hp=boss.health;boss.take_damage(500,Vector3.ZERO)
	test.check(boss.health==hp and boss.visual.position.y<0,"Elder assembles from stone before becoming damageable")
	g.player.input_enabled=false;tick(boss,.5);chamber.tick(.5)
	test.check(boss.state_time==3.0,"Menus freeze the Elder formation and arena trigger clocks")
	g.player.input_enabled=true;tick(boss,3.1);chamber.tick(.016)
	test.check(chamber.encounter=="fighting" and boss.collision_layer==4 and boss.visual.position.y==0,"Formation finishes into a colliding active boss using the saved forest creature")
	var all_edges=true
	for point in [Vector3(21,0,0),Vector3(-21,0,0),Vector3(0,0,-23),Vector3(0,0,23)]:
		boss.position=Vector3.ZERO;boss.state="idle";boss.attacks=0;boss.pursuit_time=0;g.player.position=point
		var before=boss.position.distance_to(point);tick(boss,1)
		if boss.position.distance_to(point)>=before-2.0:all_edges=false
	test.check(all_edges,"Elder pursues at every far rim position beyond ordinary monster aggro range")
	boss.position=Vector3.ZERO;boss.state="idle";boss.attacks=0;boss.pursuit_time=0;g.player.position=Vector3(0,0,23);tick(boss,1.5)
	test.check(boss.state=="windup" and boss.attack_kind=="stone","Even the opening pursuit pressures a permanently distant target with a stone")
	boss.position=Vector3(0,0,-18);boss.state="idle";boss.attacks=2;g.player.position=Vector3(0,0,20);tick(boss,.016)
	test.check(boss.state=="windup" and boss.attack_kind=="stone","Across-platform targets provoke ranged pressure instead of disengagement")
	var count=g.projectiles.size()
	# Stone releases at 28% of the committed strike after the 1.7s windup.
	boss._physics_process(boss.state_time+.001)
	boss._physics_process(boss.duration*.27)
	test.check(g.projectiles.size()==count and boss.rock.visible,"Elder stone remains held before the authored strike release marker")
	boss._physics_process(boss.duration*.02)
	test.check(g.projectiles.size()>count and not boss.rock.visible,"Elder lifts a visible stone then releases a real projectile")
	var projectile=g.projectiles[-1];projectile.set_physics_process(false);g.player.restore_health(100);g.player.invulnerability=0
	for i in range(300):
		if projectile.is_queued_for_deletion():break
		projectile._physics_process(1.0/60)
	test.check(g.player.health<100,"A thrown stone reaches and damages a player across the entire fighting platform")
	boss.position=Vector3(0,0,-19);boss.state="idle";boss.attacks=1;tick(boss,.016)
	test.check(boss.attack_kind=="rush","Distant targets also provoke a closing rush")
	g.player.position=Vector3(0,0,0);g.player.restore_health(100);g.player.invulnerability=0;boss.position=Vector3(0,0,-3);boss.begin_attack("slam")
	boss._physics_process(boss.state_time+.001)
	boss._physics_process(boss.duration*.39)
	test.check(g.player.health==100,"Elder slam cannot damage before its authored 40-percent contact marker")
	boss._physics_process(boss.duration*.02)
	test.check(g.player.health<100,"Telegraphed Elder slam deals actual damage on the island")
	boss.repel(Vector3.FORWARD,5,1.5)
	test.check(boss.state=="recover" and boss.exposed>0,"Successful parry staggers and exposes the Elder")
	boss.position=Vector3(0,0,0);boss.state="idle";boss.attacks=0;g.player.position=Vector3(22,0,0);tick(boss,9)
	test.check(Vector2(boss.position.x/20.5,boss.position.z/22.5).length()<=1.01 and boss.health==boss.max_health,"Boss stays inside the lethal rim without resetting health while chasing edge targets")
	var xp=g.progression.xp;var first_bonus=1000 if "elder_first_kill_bonus" not in g.worldrise.flags else 0;boss.state="idle";boss.take_damage(99999,Vector3.ZERO)
	test.check(chamber.encounter=="cleared" and chamber.bridge_open and chamber.bridge_body.collision_layer==1,"Victory restores the escape ramp")
	test.check(g.progression.xp==xp+500+first_bonus and g.monster_cores.pending.any(func(d):return d.id=="elder_core"),"Elder awards 500 repeatable XP plus only an unpaid 1000 XP first-victory bonus and a guaranteed core")
	var saved=g.save_data();var path="user://elder-verification.json"
	test.check(g.Save.write(saved,path)==OK and not g.Save.read(path).is_empty() and g.apply_save(g.Save.read(path)),"Elder victory passes strict private save/load validation")
	g.current_world.set_physics_process(false);g.current_world.tick(.016)
	test.check(g.current_world.encounter=="cleared" and g.current_world.bridge_open and g.enemies.is_empty(),"Saved victory keeps the Elder defeated without retriggering or duplicate rewards")
	g.defeated_enemies.erase("wr_boss_chamber/vault_elder");g.load_map("wr_boss_chamber",Vector2(0,22),true);g.current_world.set_physics_process(false);g.current_world.tick(.016);g.current_world.boss.set_physics_process(false)
	test.check(g.current_world.encounter=="forming" and g.current_world.boss.health==1100,"A failed attempt can start a fresh full-health Elder encounter")
	g.player.invulnerability=0;g.player.take_damage(99999,Vector3.ZERO);g.respawn_player();g.player.set_physics_process(false)
	test.check(g.map_id=="wr_floor_01" and g.player.health>0,"Death during the sealed fight respawns on Floor One without a softlock")
	if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
