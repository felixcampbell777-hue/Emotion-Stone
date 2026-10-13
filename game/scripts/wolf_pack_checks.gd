extends RefCounted

func step(game:Control,members:Array,count:int) -> void:
	for i in range(count):
		game.wolf_packs.tick(1.0/60)
		for wolf in members: wolf._physics_process(1.0/60)
		if i%30==0: await game.get_tree().physics_frame

func run(test:RefCounted) -> void:
	var game=test.game; var actor=game.player; var director=game.wolf_packs
	test.check(director.packs.size()==2 and director.packs.all(func(p): return p.members.size()==4),"Two stable woodland territories each own four wolves")
	var saved_actor=actor.position; var saved_health=actor.health; var saved_invulnerability=actor.invulnerability
	game.set_physics_process(false); actor.set_physics_process(false)
	var snapshots=[]
	for enemy in game.enemies:
		snapshots.append([enemy,enemy.position,enemy.state,enemy.state_time,enemy.health])
		enemy.ai_enabled=false; enemy.set_physics_process(false)
	var pack=director.packs[0]; var members=pack.members; var original_home=pack.home
	pack.home=Vector3(0,0,-10); var center:Vector3=pack.home
	for i in range(members.size()):
		members[i].position=center+Vector3((i%2)*2-1,0,(i/2)*2-1)
		members[i].ai_enabled=true; members[i].simulation_enabled=true; members[i].state="patrol"; members[i].knockback=Vector3.ZERO
	actor.position=Vector3(0,0,-30); actor.invulnerability=1000
	await test.frames(2)
	var start=members[0].position; var inside=true
	for i in range(12):
		await step(game,members,30)
		inside=inside and members.all(func(w): return (w.position-center).length()<pack.radius+.7)
	test.check(members[0].position.distance_to(start)>1 and inside and not pack.engaged,"Pack patrol moves together and stays inside its territory")
	# One visible member shares the detection with every living member.
	actor.position=center; members[0].position=center+Vector3(0,0,-3)
	for i in range(1,members.size()): members[i].position=center+Vector3(4,0,-3+i*2)
	await test.frames(2); director.tick(.01)
	test.check(pack.engaged and members.all(func(w): return w.pack_engaged),"A patrol wolf spotting the player alerts its whole pack")
	var targets=members.map(func(w): return w.pack_target)
	var separated=true
	for i in range(targets.size()):
		for j in range(i): separated=separated and targets[i].distance_to(targets[j])>3
	test.check(separated and targets.all(func(p): return absf((p-actor.position).length()-3.1)<.25),"Wolves receive separate rotating positions all around the player")
	var angle=pack.angle; await step(game,members,30)
	test.check(pack.angle>angle,"The surrounding ring keeps rotating instead of standing still")
	# Start from an unobstructed ring and observe real windups/leaps, not just tickets.
	for i in range(members.size()):
		var a=TAU*float(i)/members.size()
		members[i].position=center+Vector3(sin(a),0,cos(a))*3.1
		members[i].state="circle"; members[i].state_time=0
	pack.next_attack=0.0; pack.wave=0; pack.cursor=0
	await test.frames(2)
	var maximum=0; var single=false; var pair=false; var leap=false; var recovered=false
	for frame in range(510):
		director.tick(1.0/60)
		for wolf in members: wolf._physics_process(1.0/60)
		var active=members.filter(func(w): return w.state in ["windup","lunge"])
		maximum=maxi(maximum,active.size()); single=single or active.size()==1; pair=pair or active.size()==2
		leap=leap or members.any(func(w): return w.state=="lunge" and w.visual.position.y>.12)
		recovered=recovered or members.any(func(w): return w.state=="recover")
		if frame%30==0: await test.frames(1)
	test.check(single and pair and maximum<=2,"Attack waves alternate single and paired wolves with at most two committed at once")
	test.check(leap and recovered,"Committed wolves visibly leap, then recover before rejoining the circle")
	# Menus must freeze both the director clock and all animal motion/action clocks.
	game.toggle_pause(); var paused_angle=pack.angle; var positions=members.map(func(w): return w.position); var wave=pack.wave
	await step(game,members,60)
	var frozen=true
	for i in range(members.size()): frozen=frozen and members[i].position.is_equal_approx(positions[i])
	test.check(frozen and pack.angle==paused_angle and pack.wave==wave,"Pause freezes pack routing, attack scheduling and wolf movement")
	game.pause_menu.close(); game._refresh_simulation()
	# A real scenery collider interrupts sight/contact rather than allowing a wall bite.
	var wall=StaticBody3D.new(); wall.collision_layer=1
	var shape=CollisionShape3D.new(); var box=BoxShape3D.new(); box.size=Vector3(8,3,.3); shape.shape=box; wall.add_child(shape)
	game.current_world.add_child(wall); wall.position=center+Vector3(0,1.5,-1.5)
	for wolf in members: wolf.position=center+Vector3(0,0,-3); wolf.state="patrol"
	director.disengage(pack); actor.position=center
	await test.frames(3); director.tick(.1)
	test.check(not pack.engaged,"Scenery blocks pack detection through a solid wall")
	var wolf=members[0]; wolf.position=center+Vector3(0,0,-1.85); wolf.state="lunge"; wolf.state_time=.3; wolf.direction=Vector3.FORWARD
	actor.position=center+Vector3(0,0,-1.1); actor.invulnerability=0; var hp=actor.health
	await test.frames(2); wolf._physics_process(.01)
	test.check(actor.health==hp,"A lunge cannot deal contact damage through scenery")
	wall.queue_free(); await test.frames(3)
	# Existing contact and parry resolve each leap once.
	wolf.position=center+Vector3(0,0,-.7); actor.position=center; wolf.state="lunge"; wolf.state_time=.3; wolf.direction=Vector3.BACK; wolf.lunge_hit=false
	actor.state="free"; actor.invulnerability=0; hp=actor.health
	wolf._physics_process(.001); actor.invulnerability=0; wolf._physics_process(.001)
	test.check(actor.health==hp-12 and wolf.lunge_hit,"A wolf leap deals its configured 12 damage only once")
	actor.set_sword_drawn(true); actor.restore_stamina(100); actor.state="free"; actor.visual.rotation.y=PI
	if actor.first_person_driver!=null: game.camera_driver.recenter()
	actor.begin_parry(); actor.state_time=.30
	wolf.position=actor.position+Vector3(0,0,-1.1); wolf.state="lunge"; wolf.state_time=.3; wolf.lunge_hit=false; actor.invulnerability=0; hp=actor.health
	await test.frames(2); wolf._physics_process(.001)
	test.check(actor.health==hp and wolf.state=="recover" and wolf.parry_flash>0,"A natural active parry stops a committed pack wolf")
	actor.state="free"; actor.set_sword_drawn(false)
	# Leash prevents chasing into the safe meadow indefinitely.
	director.engage(pack); actor.position=center+Vector3(0,0,-13); director.tick(.01)
	test.check(not pack.engaged and members.all(func(w): return not w.pack_engaged),"Leaving the territory leash disengages the entire pack")
	await step(game,members,120)
	test.check(members.all(func(w): return w.pack_target.distance_to(center)<=pack.radius+.01),"Disengaged wolves return to bounded patrol destinations")
	var full=wolf.health; wolf.health=0
	test.check(director.live_members(pack).size()==3,"Dead pack members never receive movement or attack assignments")
	wolf.health=full
	actor.position=center; director.engage(pack); pack.next_attack=0.0
	for member in members: member.state="circle"
	var other_pack=director.packs[1]
	other_pack.members[0].state="windup"; other_pack.members[1].state="lunge"
	var previous_wave=pack.wave; director.tick(.01)
	test.check(pack.wave==previous_wave and members.all(func(w): return w.state not in ["windup","lunge"]),"Two wolves committed in another pack block any extra attackers")
	var coat=false; var cards=false; var skins=true
	for mesh in wolf.animal.find_children("*","MeshInstance3D",true,false):
		skins=skins and mesh.skin!=null
		for surface in range(mesh.mesh.get_surface_count()):
			var mat=mesh.get_active_material(surface)
			if mat is StandardMaterial3D:
				if mat.resource_name.begins_with("Main"): coat=coat or (mat.albedo_texture!=null and mat.normal_enabled and mat.normal_texture!=null)
				if mat.resource_name.begins_with("Fur"): cards=cards or mat.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	test.check(coat and cards and skins,"Wolf coat textures, normal detail and fur tufts remain attached to the animated skin")
	for snapshot in snapshots:
		var enemy=snapshot[0]; enemy.position=snapshot[1]; enemy.state=snapshot[2]; enemy.state_time=snapshot[3]; enemy.health=snapshot[4]
		enemy.ai_enabled=false; enemy.knockback=Vector3.ZERO; enemy.visual.position.y=0; enemy.set_physics_process(true)
	pack.home=original_home; director.build(game)
	actor.position=saved_actor; actor.health=saved_health; actor.invulnerability=saved_invulnerability; actor.knockback=Vector3.ZERO
	actor.set_physics_process(true); game.set_physics_process(true)
