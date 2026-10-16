extends RefCounted
## Actual capsule traversal and bounded encounter checks; no player saves.
func run(test:RefCounted) -> void:
	var g=test.game;g.game_mode="alpha2";g.title_screen.visible=false;g.alpha2.mark("begun")
	var plans=JSON.parse_string(FileAccess.get_file_as_string("res://content/alpha2_regions.json"))
	g.player.set_physics_process(false);var mask=g.player.collision_mask;g.player.collision_mask=1
	for id in plans:
		g.load_map(id,Vector2(INF,INF),true);await test.frames(2)
		for e in g.enemies:e.ai_enabled=false
		g._refresh_simulation();var world=g.current_world;var failed=[]
		for route in plans[id].routes:
			g.player.position=Vector3(route[0][0],0,route[0][1]);g.player.position.y=world.ground_height(g.player.position)
			for index in range(1,route.size()):
				var goal=Vector3(route[index][0],0,route[index][1]);var budget=int(g.player.position.distance_to(goal)*14)+50
				for tick in range(budget):
					var toward=(goal-g.player.position)*Vector3(1,0,1)
					if toward.length()<.35:break
					g.player.velocity=toward.normalized()*6;world.move_grounded(g.player,1.0/60)
					# move_and_slide uses the real physics step. Yield periodically to
					# update broadphase contacts, but never teleport past obstructions.
					if tick%30==0:await test.frames(1)
				if Vector2(g.player.position.x,g.player.position.z).distance_to(Vector2(goal.x,goal.z))>.5:failed.append([route[index],g.player.position]);break
		g.player.velocity=Vector3.ZERO
		test.check(failed.is_empty(),id+": actual capsule traverses authored routes and spurs: "+str(failed))
		var director=g.alpha2.encounters;director.create_navigation()
		var reachable=true
		for group in director.groups:
			for e in group.actors:
				var start=director.nearest(e.position);var finish=director.nearest(director.point(group.center))
				if director.navigation.get_id_path(start,finish).is_empty():reachable=false
		test.check(reachable,id+": encounter members navigate their actual terrain pocket")
		if id=="a2_wood":
			director.build(g)
			var pack=director.groups[0];var ambush=director.groups[1]
			g.player.position=Vector3(0,0,27)
			for e in pack.actors:e.ai_enabled=true
			director.tick(.1);test.check(not pack.awake and ambush.actors.all(func(e):return e.encounter_hidden and not e.visible),"Distant packs stay in their territory; nest remains concealed")
			g.player.position=director.point(pack.center);director.tick(.1)
			test.check(pack.awake and pack.actors.filter(func(e):return e.encounter_attack_allowed).size()==1,"Pack coordinates one lunge while its other members flank")
			for e in pack.actors:e._physics_process(.01)
			test.check(pack.actors.filter(func(e):return e.state=="windup").size()==1,"Only the permitted pack attacker actually begins a strike")
			var goals=pack.actors.map(func(e):return e.encounter_goal)
			test.check(goals[0].distance_to(goals[1])>1,"Flanking pack members receive distinct navigable approach goals")
			g.player.position=Vector3(0,0,27);director.tick(.1);test.check(not pack.awake,"Retreat beyond the pocket breaks pursuit instead of pulling the whole map")
			for e in ambush.actors:e.ai_enabled=true
			g.player.position=director.point(ambush.center);director.tick(.1)
			test.check(ambush.triggered and ambush.actors.all(func(e):return e.visible and e.encounter_emerge>0 and e.collision_layer==4),"Entering a warned nest actually reveals its concealed attackers")
			g.toggle_inventory();g._refresh_simulation();var clock=director.clock;director.tick(1)
			test.check(director.clock==clock,"Inventory freezes group clocks, emergence and attack turns");g.inventory.close();g._refresh_simulation()
			g.player.position=Vector3(12,1,0);g.player.jump_active=true;g.player.jump_velocity=0
			for i in range(25):g.player.velocity=Vector3(-6,0,0);world.move_grounded(g.player,1.0/60)
			test.check(g.player.position.x>10.5 and g.player.position.y<3.8,"A jumping capsule cannot pass through the forest spine's steep face: "+str(g.player.position))
			g.player.jump_active=false;g.player.jump_velocity=0
		if id=="a2_fen":test.check(load("res://scripts/wading.gd").depth(world,Vector3(12,0,-4))==0,"Marsh causeway overrides flooded beds and keeps full movement speed")
	g.player.collision_mask=mask;g.player.set_physics_process(true)
