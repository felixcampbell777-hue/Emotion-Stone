extends SceneTree
## Actual input/physics and CPU-skinned palm markers, isolated user data only.
var metrics=[]
var markers={}
var checks=0
var failures=[]
var previous_wrist={}
var wrist_step=0.0
var surface_cache={}
var pose_cache={}
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize() -> void:call_deferred("run")
func marker(hero:Node3D,side:String) -> Dictionary:
	if markers.has(side):return markers[side]
	var bone=hero.gait.bone(hero,"forearm",side)
	var palm=Vector3(-.017 if side=="R" else .017,-.30,.012)
	var candidates=[];var fingers=[]
	for item in hero.dragon_grips:
		var part:MeshInstance3D=item[0];var mesh:Mesh=part.get_meta("body_grip_original_mesh",part.mesh);var source_skin:Skin=part.get_meta("body_grip_original_skin",part.skin)
		for surface in range(mesh.get_surface_count()):
			var arrays=mesh.surface_get_arrays(surface)
			if arrays[Mesh.ARRAY_BONES]==null:continue
			for v in range(arrays[Mesh.ARRAY_VERTEX].size()):
				for j in range(4):
					var bind=int(arrays[Mesh.ARRAY_BONES][v*4+j])
					var bound=source_skin.get_bind_bone(bind)
					if bound<0:bound=hero.rig.find_bone(source_skin.get_bind_name(bind))
					if bound!=bone or arrays[Mesh.ARRAY_WEIGHTS][v*4+j]<.85:continue
					var local=source_skin.get_bind_pose(bind)*arrays[Mesh.ARRAY_VERTEX][v]
					if local.y<-.345 and local.y>-.46:
						fingers.append({"part":part,"surface":surface,"index":v})
					if local.distance_to(palm)<.026:
						candidates.append({"part":part,"surface":surface,"index":v,"offset":local-palm})
					break
	markers[side]={"bone":bone,"palm":palm,"vertices":candidates,"fingers":fingers}
	return markers[side]
func skinned(hero:Node3D,entry:Dictionary) -> Vector3:
	var part:MeshInstance3D=entry.part
	var key=str(part.mesh.get_instance_id())+":"+str(entry.surface)
	if not surface_cache.has(key):
		var shapes=[]
		for mesh in part.mesh.get_meta("closed_shapes",[]):shapes.append(mesh.surface_get_arrays(entry.surface)[Mesh.ARRAY_VERTEX])
		surface_cache[key]={"arrays":part.mesh.surface_get_arrays(entry.surface),"shapes":shapes}
	var arrays=surface_cache[key].arrays;var shapes=surface_cache[key].shapes
	var vertex:Vector3=arrays[Mesh.ARRAY_VERTEX][entry.index];var original=vertex
	for index in range(shapes.size()):vertex+=(shapes[index][entry.index]-original)*part.get_blend_shape_value(index)
	var result=Vector3.ZERO
	for j in range(4):
		var at=int(entry.index)*4+j;var weight=float(arrays[Mesh.ARRAY_WEIGHTS][at]);var bind=int(arrays[Mesh.ARRAY_BONES][at])
		if weight<=0:continue
		var bone=part.skin.get_bind_bone(bind)
		if bone<0:bone=hero.rig.find_bone(part.skin.get_bind_name(bind))
		if not pose_cache.has(bone):pose_cache[bone]=hero.rig.get_bone_global_pose(bone)
		result+=pose_cache[bone]*part.skin.get_bind_pose(bind)*vertex*weight
	return hero.rig.global_transform*result
func measure(game:Node,label:String) -> void:
	pose_cache.clear()
	var actor=game.player;actor.set_meta("body_wrist_inspection",true);var hero=actor.get_node("BetaHero");hero.synchronize()
	var sample={"pose":label,"phase":actor.state_time/maxf(.001,actor.state_duration),"hands":{}}
	for side in ["L","R"]:
		var data=marker(hero,side);var transform=hero.rig.global_transform*hero.rig.get_bone_global_pose(data.bone)
		var body=hero.hands.body_wrist
		var expected:Vector3=body.hand_targets.get(side,actor.equipment.global_transform*Vector3(0,actor.BetaSwordMotion.GRIP if side=="R" else .20,0))
		var grasp=float(body.grasps[side]);var offset=Vector3(.009 if side=="R" else -.009,-.018,.012)*grasp
		var wrist=hero.rig.find_bone("view_hand."+side)
		if wrist>=0:transform=hero.rig.global_transform*hero.rig.get_bone_global_pose(wrist)
		var actual=transform*(data.palm+offset-Vector3(0,-.26,0)) if wrist>=0 else transform*data.palm
		var skin=Vector3.ZERO
		for entry in data.vertices:skin+=skinned(hero,entry)-transform.basis*(entry.offset-offset)
		if not data.vertices.is_empty():skin/=data.vertices.size()
		sample.hands[side]={"bone_error":actual.distance_to(expected),"skinned_error":skin.distance_to(expected),"skin_vertices":data.vertices.size(),"grasp":grasp}
		check(data.vertices.size()>20,label+" actual skinned palm patch exists "+side)
		if grasp>.99:
			check(actual.distance_to(expected)<.003 and skin.distance_to(expected)<.003,label+" actual wrist and rendered palm contact hilt "+side)
			var distances=[];var axis=actor.equipment.global_basis.y.normalized()
			for finger in data.fingers:
				var delta=skinned(hero,finger)-expected
				distances.append((delta-axis*delta.dot(axis)).length())
			distances.sort()
			var median=float(distances[distances.size()/2]) if not distances.is_empty() else INF
			sample.hands[side]["finger_axis_median"]=median
			check(distances.size()>100 and median<.055,label+" rendered curled fingertips surround physical hilt "+side)
		check(grasp>=0 and grasp<=1,label+" independent finger weight finite "+side)
	var before=actor.equipment.global_transform;var head=game.camera_driver.sample_first_person(0,false)
	hero.hands.body_wrist.apply(hero)
	check(before.is_equal_approx(actor.equipment.global_transform) and head.is_equal_approx(game.camera_driver.sample_first_person(0,false)),label+" wrist presentation cannot move canonical steel/head")
	metrics.append(sample)
func continuous(hero:Node3D) -> void:
	hero.synchronize()
	for side in ["L","R"]:
		var rotation=hero.rig.get_bone_global_pose(hero.rig.find_bone("view_hand."+side)).basis.get_rotation_quaternion()
		if previous_wrist.has(side):
			var step=rad_to_deg(previous_wrist[side].angle_to(rotation));wrist_step=maxf(wrist_step,step)
			if step>75:print("WRIST_STEP ",side," ",hero.actor.state," ",hero.actor.state_time/maxf(.001,hero.actor.state_duration)," ",step)
		previous_wrist[side]=rotation
func capture(game:Node,label:String) -> void:
	var directory=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--body-grip-capture-dir="):directory=arg.trim_prefix("--body-grip-capture-dir=")
	if directory.is_empty():return
	DirAccess.make_dir_recursive_absolute(directory)
	var driver=game.camera_driver;var frame=driver.sample_first_person(0,false)
	var target=game.player.equipment.global_transform*Vector3(0,.13,0)
	game.camera.global_position=target+frame.basis*Vector3(.65,.12,-.85);game.camera.look_at(target,Vector3.UP)
	game.camera.near=.03;game.camera.cull_mask=((1<<20)-1)&~driver.visuals.ARMS_LAYER;driver.crosshair.hide()
	await process_frame;await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide();game._refresh_simulation()
	game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
	for enemy in game.enemies:enemy.set_physics_process(false)
	var actor=game.player;actor.set_sword_drawn(true);actor.restore_stamina(actor.max_stamina)
	game.camera_driver.set_mode("third_person");measure(game,"ready");await capture(game,"ready-grip-close")
	var down=InputEventAction.new();down.action="light_attack";down.pressed=true;game._unhandled_key_input(down)
	var up=InputEventAction.new();up.action="light_attack";up.pressed=false;game._input(up)
	var sample=0
	for i in range(150):
		actor._physics_process(1.0/60);continuous(actor.get_node("BetaHero"))
		var phase=actor.state_time/maxf(.001,actor.state_duration)
		if actor.state=="light" and phase>=sample*.1:
			measure(game,"light-"+str(sample))
			if sample in [1,3,8]:await capture(game,"normal-light-"+str(sample)+"-grip-close")
			sample+=1
		if actor.state=="free":break
	check(wrist_step<45,"Normal-input light wrist roll remains continuous per physics frame: "+str(wrist_step))
	previous_wrist.clear();wrist_step=0
	actor.restore_stamina(actor.max_stamina);actor.begin_parry();sample=0
	for i in range(80):
		actor._physics_process(1.0/60);continuous(actor.get_node("BetaHero"))
		var phase=actor.state_time/maxf(.001,actor.state_duration)
		if actor.state=="parry" and phase>=sample*.1:
			measure(game,"parry-"+str(sample))
			if sample==4:await capture(game,"normal-parry-grip-close")
			sample+=1
		if actor.state=="free":break
	check(wrist_step<75,"Parry wrist roll remains continuous per physics frame: "+str(wrist_step))
	check(metrics.size()==21,"Normal-input light and parry cover ready plus ten phases each")
	actor.state="water";actor.state_duration=1;actor.state_time=.5;actor.play_clip("attack_water",0);actor.animator.seek(actor.animator.get_animation(actor.clips.attack_water).length*.5,true);actor._pose_sword("water",.5)
	measure(game,"water-support-release")
	check(actor.get_node("BetaHero").hands.body_wrist.grasps.L==0 and actor.get_node("BetaHero").hands.body_wrist.grasps.R==1,"Water support intentionally opens while actual gripping hand stays closed")
	check(metrics.filter(func(sample):return String(sample.pose).begins_with("parry") and float(sample.hands.L.grasp)==0).size()>=3,"Parry support hand intentionally opens during guard")
	print("VERIFICATION_BODY_GRIP ",JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics}))
	if game.audio!=null:await game.audio.shutdown_and_drain()
	if game.voice!=null:game.voice.configure_session(false)
	await create_timer(.15).timeout;game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
