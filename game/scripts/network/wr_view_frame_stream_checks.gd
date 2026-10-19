extends SceneTree
## Two independently simulated playable Actors use the real client driver and
## camera-free authority driver. No received transform is copied between them.
const Actor=preload("res://scripts/actor.gd")
const ViewFrame=preload("res://scripts/network/wr_view_frame.gd")
const Follow=preload("res://scripts/follow_camera.gd")
class Context:
	extends Control
	var player:Node3D
	var game_mode="world_rise"
	var environment_profile="darkwood"
	var character_profile="game"
class Ground:
	extends Node3D
	func ground_height(at:Vector3) -> float:return .1*at.x
	func move_grounded(actor:Node3D,delta:float) -> void:
		actor.position+=actor.velocity*delta
		var height=ground_height(actor.position)
		if actor.position.y<=height:
			actor.position.y=height
			if actor.jump_active:actor.finish_jump()
var failures=0
var samples=0
var max_frame=0.0
var max_steel=0.0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
	if not ok:
		failures+=1
		if failures<6:push_error(message)
func run() -> void:
	var config=JSON.parse_string(FileAccess.get_file_as_string("res://content/platform.json"))
	var ground=Ground.new();root.add_child(ground)
	var context=Context.new();root.add_child(context)
	var actors=[]
	for index in range(2):
		var actor=Actor.new();ground.add_child(actor)
		actor.configure(JSON.parse_string(FileAccess.get_file_as_string("res://content/characters/hero.json")))
		actor.set_meta("canonical_manual_step",true);actor.set_physics_process(false);actor.set_process_input(false)
		actor.controllable=true;actor.input_enabled=true;actor.online_mode=true;actor.ground_world=ground
		actor.max_stamina=10000;actor.stamina=10000;actor.roll_unlocked=true;actor.dash_unlocked=true;actor.dash_equipped=true;actor.thrust_unlocked=true
		preload("res://scripts/beta_hero.gd").apply(actor,true);actor.get_node("BetaHero").set_process(false)
		actors.append(actor)
	context.player=actors[0]
	var client=Follow.new();client.game=context;client.tuning=config.follow_camera;client.collision_query=ViewFrame.collision_query();actors[0].first_person_driver=client
	var server=ViewFrame.new();server.bind(actors[1],config.follow_camera)
	var drivers=[client,server]
	await physics_frame
	for render_hz in [30,60,120]:
		for scenario in ["walk","light","heavy","thrust","dash","roll","parry","draw","sheathe","jump"]:
			for actor in actors:
				actor.set_sword_drawn(true);actor.state="free";actor.position=Vector3.ZERO;actor.velocity=Vector3.ZERO;actor.stamina=10000
				actor.clear_dash_attack();actor.combo_stage=1;actor.combo_queued=false;actor.current_clip="";actor.play_clip("drag_idle_loop",0)
				match scenario:
					"light":actor.begin_attack("light")
					"heavy":actor.begin_attack("heavy")
					"thrust":actor.heavy_style="charge_thrust";actor.begin_charge()
					"dash":actor.begin_dash_charge();actor.queue_dash_attack()
					"roll":actor.request_dodge()
					"parry":actor.begin_parry()
					"draw":actor.set_sword_drawn(false);actor.toggle_sword()
					"sheathe":actor.toggle_sword()
					"jump":actor.begin_jump()
			for tick in range(240):
				var yaw=.4+sin(tick*.013)*.6
				var pitch=sin(tick*.023)*1.15
				for index in range(2):
					var actor=actors[index];var driver=drivers[index]
					driver.yaw=yaw;driver.first_pitch=pitch
					actor.set_network_input(Vector2(.15,-.7) if scenario=="walk" else Vector2.ZERO,tick>80 and tick<160)
					if scenario=="light" and actor.state=="light":actor.queue_combo()
					if scenario=="thrust" and tick==60:actor.release_charge("heavy")
					if scenario=="dash" and tick==60:actor.release_dash()
					actor._physics_process(1.0/60)
					if index==1:driver.sample_first_person(1.0/60,true)
					elif render_hz==30 and tick%2==0:
						actor.get_node("BetaHero").synchronize(1.0/30)
						driver.sample_first_person(1.0/30,true)
					elif render_hz==60:
						actor.get_node("BetaHero").synchronize(1.0/60)
						driver.sample_first_person(1.0/60,true)
					elif render_hz==120:
						for render_pass in range(2):
							actor.get_node("BetaHero").synchronize(1.0/120)
							driver.sample_first_person(1.0/120,true)
				var a=client.sample_first_person(0,false);var b=server.sample_first_person(0,false)
				var frame_error=maxf(a.origin.distance_to(b.origin),maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))
				var steel_a=actors[0].blade_segment();var steel_b=actors[1].blade_segment()
				var steel_error=maxf(steel_a[0].distance_to(steel_b[0]),steel_a[1].distance_to(steel_b[1]))
				max_frame=maxf(max_frame,frame_error);max_steel=maxf(max_steel,steel_error);samples+=1
				check(frame_error<.00001,scenario+" independent accepted stream frame differs")
				check(steel_error<.00001,scenario+" independent accepted stream steel differs")
				check(actors[0].equipment.global_basis.x.distance_to(actors[1].equipment.global_basis.x)<.00001,scenario+" steel world width/edge basis differs")
				check(actors[0].state==actors[1].state and is_equal_approx(actors[0].state_time,actors[1].state_time),scenario+" canonical clocks differ")
	print("View frame stream: samples=",samples," max_frame=",max_frame," max_steel=",max_steel," failures=",failures)
	ground.queue_free();context.queue_free();await process_frame
	quit(1 if failures else 0)
