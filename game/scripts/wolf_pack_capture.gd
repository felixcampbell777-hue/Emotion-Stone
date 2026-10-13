extends RefCounted
## Native evidence uses real territory, director decisions and animal clocks.
func run(game:Control,directory:String) -> void:
	var director=game.wolf_packs; var pack=director.packs[0]; var members=pack.members
	var actor=game.player; var original_position=actor.position; var original_health=actor.health
	var snapshots=[]
	game.set_process(false); game.set_physics_process(false); actor.set_physics_process(false)
	for enemy in game.enemies:
		snapshots.append([enemy,enemy.position,enemy.state,enemy.health,enemy.visible])
		enemy.ai_enabled=false; enemy.set_physics_process(false); enemy.visible=false
	for wolf in members: wolf.ai_enabled=true; wolf.visible=true; wolf.simulation_enabled=true; wolf.state="patrol"
	# Hold immunity at a visible blink phase while the actor clock is frozen.
	actor.position=Vector3(0,0,-12); actor.invulnerability=1000.04
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; game.camera.fov=45
	game.camera.position=pack.home+Vector3(11,11,-12); game.camera.look_at(pack.home+Vector3(0,.3,0))
	for i in range(120):
		director.tick(1.0/60)
		for wolf in members: wolf._physics_process(1.0/60)
		if i%6==0: await game.get_tree().process_frame
	await picture(game,directory+"/wolves-patrol.png")
	actor.position=pack.home+Vector3(4.5,0,-5.0)
	actor.visual.rotation.y=0; actor.set_sword_drawn(true)
	# Give the pack time to settle into its full ring for this visual fixture.
	director.engage(pack); pack.next_attack=5.7; pack.wave=0
	game.camera.position=actor.position+Vector3(6,8,-8); game.camera.look_at(actor.position+Vector3(0,.3,0))
	for i in range(310):
		director.tick(1.0/60)
		for wolf in members: wolf._physics_process(1.0/60)
		if i%6==0: await game.get_tree().process_frame
	await picture(game,directory+"/wolves-circle.png")
	# Capture actual single and pair decisions, their windup and moving leaps.
	var captured={}; var log=[]
	for i in range(620):
		director.tick(1.0/60)
		for wolf in members: wolf._physics_process(1.0/60)
		var winding=members.filter(func(w): return w.state=="windup")
		var leaping=members.filter(func(w): return w.state=="lunge" and w.visual.position.y>.22)
		var key=""
		if winding.size()==1: key="single-windup"
		elif winding.size()==2: key="pair-windup"
		if leaping.size()==1 and members.filter(func(w): return w.state in ["windup","lunge"]).size()==1: key="single-leap"
		elif leaping.size()==2: key="pair-leap"
		if not key.is_empty() and not captured.has(key):
			captured[key]=true
			await picture(game,directory+"/wolves-"+key+".png")
			log.append({"phase":key,"wave":pack.wave,"members":members.map(func(w): return {"id":w.definition.id,"state":w.state,"position":[w.position.x,w.position.z],"lift":w.visual.position.y})})
		if captured.size()==4: break
		if i%6==0: await game.get_tree().process_frame
	var file=FileAccess.open(directory+"/wolves-capture.json",FileAccess.WRITE); file.store_string(JSON.stringify(log,"\t"));file.close()
	for snapshot in snapshots:
		var enemy=snapshot[0]; enemy.position=snapshot[1]; enemy.state=snapshot[2]; enemy.health=snapshot[3]; enemy.visible=snapshot[4]
		enemy.knockback=Vector3.ZERO; enemy.visual.position.y=0; enemy.ai_enabled=false; enemy.set_physics_process(true)
	director.build(game)
	actor.position=original_position; actor.health=original_health; actor.invulnerability=0; actor.knockback=Vector3.ZERO
	actor.set_sword_drawn(false); actor.set_physics_process(true); game.set_process(true); game.set_physics_process(true)
	print("WOLF_PACK_CAPTURE ",captured)

func picture(game:Control,path:String) -> void:
	await game.get_tree().create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	game.world_view.get_texture().get_image().save_png(path)
