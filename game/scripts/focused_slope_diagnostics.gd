extends SceneTree
## Independent diagnostic: retain the historical fixture, then test clean support placement.
## Must run through platform check-script with disposable user data.
var game:Node
var failures:Array=[]
var checks:Array=[]
func _initialize() -> void:call_deferred("run")
func frames(count:int) -> void:
	for i in range(count):await physics_frame
func check(condition:bool,description:String) -> void:
	checks.append({"check":description,"passed":condition})
	if not condition:failures.append(description)
func sample(body:CharacterBody3D) -> Dictionary:
	var contacts=[]
	for i in range(body.get_slide_collision_count()):
		var c=body.get_slide_collision(i)
		contacts.append({"normal":str(c.get_normal()),"collider":str(c.get_collider())})
	return {"at":str(body.position),"finite":body.position.is_finite(),"velocity":str(body.velocity),"on_floor":body.is_on_floor(),"support":game.current_world.support_height(body,body.position),"contacts":contacts}
func clean_player_path(start:Vector2,direction:Vector2) -> Dictionary:
	var body=game.player;var world=game.current_world
	body.velocity=Vector3.ZERO;body.knockback=Vector3.ZERO;body.jump_active=false;body.jump_velocity=0;body.state="free"
	body.position=Vector3(start.x,0,start.y);body.position.y=world.support_height(body,body.position)
	for i in range(4):
		await frames(1);body.velocity=Vector3.ZERO;world.move_grounded(body,1.0/60)
	var origin=body.position;var initial=sample(body);var toward=Vector3(direction.x,0,direction.y).normalized();var first_invalid=-1
	for i in range(90):
		await frames(1);body.velocity=toward*2.4;world.move_grounded(body,1.0/60)
		if not body.position.is_finite():first_invalid=i;break
	var finish=sample(body);var travelled=(body.position-origin).dot(toward);var rise=body.position.y-origin.y
	var settled=body.position
	for i in range(30):
		await frames(1);body.velocity=Vector3.ZERO;world.move_grounded(body,1.0/60)
	var drift=Vector2(body.position.x-settled.x,body.position.z-settled.z).length()
	return {"start":str(start),"initial":initial,"finish":finish,"first_invalid_tick":first_invalid,"forward":travelled,"rise":rise,"standing_drift":drift,"after_stand":sample(body)}
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;await process_frame
	game.set_process(false);game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide();game._refresh_simulation()
	for i in range(30):game.worldrise.tick(1.0/60)
	load("res://scripts/rise_checks.gd").new().freeze(game);await frames(2)
	print("SLOPE_READY enemies=",game.enemies.size())
	var historical=load("res://scripts/verification.gd").new();historical.game=game
	await load("res://scripts/rise_slope_checks.gd").new().run(historical)
	print("SLOPE_HISTORICAL ",JSON.stringify({"checks":historical.checks,"failures":historical.failures}))
	for fixture in [[Vector2(18,-20),Vector2(1,-1)],[Vector2(92,80),Vector2(1,1)],[Vector2(-35,15),Vector2(-1,0)]]:
		print("SLOPE_CLEAN ",JSON.stringify(await clean_player_path(fixture[0],fixture[1])))
	print("SLOPE_DIAGNOSTIC_COMPLETE")
	quit(0)
