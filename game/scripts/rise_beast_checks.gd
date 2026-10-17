extends RefCounted
func settle(g:Node,enemy:Node3D,at:Vector3,state:String) -> void:
	enemy.position=at;enemy.position.y=g.current_world.support_height(enemy,at);enemy.state=state;enemy.state_time=0;enemy.knockback=Vector3.ZERO;enemy.health=enemy.max_health;enemy.ai_enabled=true;enemy.simulation_enabled=true;enemy.set_physics_process(false)
func run(test:RefCounted) -> void:
	var g=test.game;var actor=g.player;var old_position=actor.position;var old_health=actor.health;var clock=g.worldrise.clock;g.worldrise.clock=-1000
	for enemy in g.enemies:enemy.ai_enabled=false;enemy.set_physics_process(false)
	actor.position=Vector3(0,26,0);actor.state="free";actor.invulnerability=0;actor.health=100;actor.input_enabled=true
	var herd=g.worldrise.packs.values().filter(func(p):return p.active and p.spec.kind=="library_boar" and p.members.size()>=2)[0]
	var original=herd.spec;herd.spec=original.duplicate(true);herd.spec.at=[0,0];herd.engaged=false;herd.attack=0;herd.cursor=0
	var boars=herd.members.slice(0,2);var positions=boars.map(func(e):return e.position)
	for i in range(boars.size()):settle(g,boars[i],Vector3(-4 if i==0 else 4,26,0),"idle")
	await test.frames(2)
	var attackers={};var hurt=false;var charges=0
	for frame in range(720):
		actor.invulnerability=maxf(0,actor.invulnerability-1.0/60)
		if actor.health<30:actor.health=100
		g.worldrise.tick(1.0/60)
		for boar in boars:
			var before=boar.state;var hp=actor.health;boar._physics_process(1.0/60)
			if boar.state=="windup" and before!="windup":attackers[boar.name]=true;charges+=1
			hurt=hurt or actor.health<hp
		if frame%20==0:await test.frames(1)
	test.check(herd.engaged and attackers.size()==2 and charges>=4,"Both boars repeatedly enter real windups/lunges instead of missing one-frame attack tickets")
	test.check(hurt,"Unresisted boar charges actually damage a nearby player")
	herd.spec.at=[92,80];herd.engaged=false;herd.attack=0
	for boar in boars:boar.state="idle"
	actor.position=Vector3(94,0,82);actor.position.y=g.current_world.ground_height(actor.position)
	settle(g,boars[0],Vector3(92,0,80),"idle");await test.frames(2);g.worldrise.tick(.01);boars[0]._physics_process(.01)
	if not (herd.engaged and boars[0].state=="windup"):print("HILL_ATTACK ",herd.engaged," ",boars[0].state," ",g.worldrise.can_see(boars[0])," ",boars[0].position," ",actor.position," ",boars[0].encounter_attack_allowed)
	test.check(herd.engaged and boars[0].state=="windup","Boars detect and start attacks on the actual steep hillside without mistaking its ground for a wall")
	for i in range(boars.size()):boars[i].ai_enabled=false;boars[i].position=positions[i];boars[i].state="idle"
	herd.spec=original;herd.engaged=false
	var wolf_record=g.worldrise.packs.values().filter(func(p):return p.spec.kind=="beta_wolf")[0]
	if not wolf_record.active:g.worldrise.spawn_pack(wolf_record)
	var wolves=wolf_record.members;var pack=g.wolf_packs.packs.filter(func(p):return p.id==wolf_record.spec.id)[0]
	pack.home=Vector3(0,26,0);pack.engaged=false;pack.next_attack=0;pack.wave=0;pack.cursor=0
	for i in range(wolves.size()):
		var angle=i*TAU/wolves.size();settle(g,wolves[i],Vector3(sin(angle)*2.8,26,cos(angle)*2.8),"patrol")
	settle(g,wolves[0],Vector3(0,26,-.7),"circle");actor.position=Vector3(0,26,0);actor.health=100;actor.invulnerability=0
	await test.frames(2);g.wolf_packs.tick(.01);pack.next_attack=0;g.wolf_packs.tick(.01)
	test.check(pack.engaged and wolves[0].state=="windup","Wolves detect the player and can attack at point-blank range")
	var single=false;var pair=false;var maximum=0;hurt=false;var angle=pack.angle
	for frame in range(720):
		actor.invulnerability=maxf(0,actor.invulnerability-1.0/60)
		if actor.health<30:actor.health=100
		g.wolf_packs.tick(1.0/60)
		var occupied=wolves.filter(func(w):return w.state in ["windup","lunge"]).size();single=single or occupied==1;pair=pair or occupied==2;maximum=maxi(maximum,occupied)
		for wolf in wolves:
			var hp=actor.health;wolf._physics_process(1.0/60);hurt=hurt or actor.health<hp
		if frame%20==0:await test.frames(1)
	test.check(single and pair and maximum<=2 and pack.wave>=4 and pack.angle>angle,"World Rise wolves continue circling with repeated alternating single/pair attack waves, capped at two")
	test.check(hurt,"Circling wolves actually reach and damage an unresisting player")
	# Detection remains blocked by real scenery, even with wider notice ranges.
	var wall=StaticBody3D.new();wall.collision_layer=1;var c=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(14,4,.3);c.shape=shape;wall.add_child(c);g.current_world.add_child(wall);wall.position=Vector3(0,28,-1.5)
	for i in range(wolves.size()):settle(g,wolves[i],Vector3(-2+i,26,-3),"patrol")
	g.wolf_packs.disengage(pack);await test.frames(2);g.wolf_packs.tick(.01)
	test.check(not pack.engaged,"Solid scenery still blocks beast detection rather than allowing attacks through walls")
	wall.queue_free();await test.frames(2)
	for enemy in g.enemies:enemy.ai_enabled=false;enemy.set_physics_process(false)
	g.worldrise.clock=clock;actor.position=old_position;actor.health=old_health;actor.invulnerability=0;actor.state="free";g.wolf_packs.build(g)
