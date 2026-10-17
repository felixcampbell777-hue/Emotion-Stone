extends RefCounted
## Root-window input, perspective orbit and scenery collision share one owner.
var game:Control
var tuning:Dictionary
var yaw=PI
var pitch=.32
var distance=5.5
var actual_distance=5.5
var orbiting=false
var obstruction_pitch=.32
var collision_query=PhysicsShapeQueryParameters3D.new()
var first_pitch=0.0
var owns_pointer=false
var locomotion_camera_blend=0.0
var remote_return=0.0
var remote_last=Transform3D.IDENTITY
var visuals=preload("res://scripts/first_person_visuals.gd").new()
var crosshair:Label

func configure(owner_game:Control) -> void:
	game=owner_game
	tuning=game.config.follow_camera
	pitch=float(tuning.pitch)
	distance=float(tuning.distance)
	actual_distance=distance
	var shape=SphereShape3D.new()
	shape.radius=.18
	collision_query.shape=shape
	collision_query.collision_mask=1|8
	crosshair=game.label("+",20,Color("#e2e9df")); crosshair.mouse_filter=Control.MOUSE_FILTER_IGNORE
	game.add_child(crosshair); crosshair.visible=false

func set_mode(mode:String) -> void:
	# Legacy modes are only retained as isolated physics fixtures, never gameplay.
	if DisplayServer.get_name()!="headless" and "--verify" not in OS.get_cmdline_user_args() and "--capture" not in OS.get_cmdline_user_args(): mode="first_person"
	game.camera_mode=mode
	orbiting=false
	game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL if mode=="overhead" else Camera3D.PROJECTION_PERSPECTIVE
	game.camera.fov=float(tuning.get("first_person_fov",75) if mode=="first_person" else tuning.fov)
	game.camera.near=.04 if mode=="first_person" else .08 if mode=="follow" else .05
	game.camera.far=160 if mode=="overhead" else 90 if mode=="first_person" else 55
	game.environment_settings.fog_enabled=mode!="overhead"
	game.environment_settings.fog_light_color=Color("#223638" if game.current_world!=null and game.current_world.definition.get("cave",false) else "#a1b8b7")
	game.environment_settings.fog_density=.035
	if game.environment_profile=="darkwood" and game.current_world!=null:
		game.EnvironmentArt.configure_lighting(game,game.current_world.definition)
	if game.game_mode=="world_rise":game.worldrise.lighting()
	if game.player!=null:
		game.player.camera_relative=mode!="overhead"
		game.player.movement_camera_yaw=yaw
		game.player.first_person_driver=self if mode=="first_person" else null
		if mode=="first_person": visuals.prepare(game.player)
		elif game.player.has_meta("standalone_static"): game.player.visual.visible=false
	game.camera.cull_mask=((1<<20)-1)&~(visuals.BODY_LAYER if mode=="first_person" else visuals.ARMS_LAYER)
	if game.camera_button!=null:
		game.camera_button.text={"follow":"Follow [C]","first_person":"First person [C]","overhead":"Top [C]"}[mode]
	refresh_pointer()

func recenter() -> void:
	yaw=wrapf(game.player.visual.rotation.y+PI,-PI,PI)
	game.player.movement_camera_yaw=yaw

func handle_input(event:InputEvent) -> bool:
	if is_instance_valid(game.sea_dragon) and game.sea_dragon.active and game.player.input_enabled:
		if event is InputEventMouseMotion:
			game.sea_dragon.steer(event.relative*float(tuning.sensitivity));return true
		if event is InputEventMouseButton: return true
	if game.camera_mode=="first_person" and game.player.input_enabled:
		if event is InputEventMouseMotion:
			yaw=wrapf(yaw-event.relative.x*float(tuning.sensitivity),-PI,PI)
			first_pitch=clampf(first_pitch+event.relative.y*float(tuning.sensitivity),-1.15,1.15)
			game.player.movement_camera_yaw=yaw
			if game.player.state=="free": game.player.visual.rotation.y=wrapf(yaw-PI,-PI,PI)
			return true
		return false
	if game.camera_mode!="follow" or not game.player.input_enabled:
		orbiting=false
		return false
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_MIDDLE:
			orbiting=event.pressed and game.world_rect.has_point(event.position)
			return true
		if event.pressed and game.world_rect.has_point(event.position):
			if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
				distance=clampf(distance+(-.45 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .45),float(tuning.min_distance),float(tuning.max_distance))
				return true
	if event is InputEventMouseMotion and orbiting:
		yaw=wrapf(yaw-event.relative.x*float(tuning.sensitivity),-PI,PI)
		pitch=clampf(pitch+event.relative.y*float(tuning.sensitivity),float(tuning.min_pitch),float(tuning.max_pitch))
		game.player.movement_camera_yaw=yaw
		return true
	return false

func update(delta:float) -> void:
	refresh_pointer()
	if game.camera_mode=="first_person":
		update_first_person(delta)
		return
	game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	game.player.camera_relative=true
	game.player.movement_camera_yaw=yaw
	var focus=game.player.position+Vector3(0,float(tuning.focus_height),0)
	game.camera_target=game.camera_target.lerp(focus,1-exp(-delta*float(tuning.follow_response)))
	var selected_pitch=pitch
	var travel=bounded_travel(selected_pitch)
	var safe_distance=clear_distance(travel)
	# Rise over low foreground scenery before resorting to a close camera.
	if safe_distance<2.5:
		for extra in [.18,.36,.54,.72]:
			var candidate_pitch=minf(1.1,pitch+extra)
			var candidate=bounded_travel(candidate_pitch)
			var clearance=clear_distance(candidate)
			if clearance>safe_distance:
				selected_pitch=candidate_pitch
				safe_distance=clearance
			if safe_distance>=2.5: break
	obstruction_pitch=selected_pitch if selected_pitch>obstruction_pitch else lerpf(obstruction_pitch,selected_pitch,1-exp(-delta*5))
	travel=bounded_travel(obstruction_pitch)
	safe_distance=clear_distance(travel)
	actual_distance=safe_distance if safe_distance<actual_distance else lerpf(actual_distance,safe_distance,1-exp(-delta*5))
	game.camera.position=game.camera_target+travel.normalized()*minf(actual_distance,safe_distance)
	game.camera.look_at(game.camera_target,Vector3.UP)

func refresh_pointer() -> void:
	if game.player==null: return
	var active=game.camera_mode=="first_person" and game.player.input_enabled and not game.gallery_mode
	crosshair.visible=active
	crosshair.position=game.world_rect.get_center()-Vector2(6,14)
	var args=OS.get_cmdline_user_args()
	var capture=active and game.get_window().has_focus() and DisplayServer.get_name()!="headless" and "--verify" not in args and "--capture" not in args
	if capture and not owns_pointer:
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED; owns_pointer=true
	elif not capture and owns_pointer:
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE; owns_pointer=false

func end_remote_view(immediate:bool=false) -> void:
	remote_last=game.camera.global_transform;remote_return=0.0 if immediate else .3
	game.camera.cull_mask=((1<<20)-1)&~visuals.BODY_LAYER
	if is_instance_valid(visuals.root): visuals.root.visible=true
	if immediate: update_first_person(0)

func update_first_person(delta:float=0.0) -> void:
	if is_instance_valid(game.sea_dragon) and game.sea_dragon.active:
		game.camera.global_transform=game.sea_dragon.view_transform()
		game.camera_target=game.camera.position-game.camera.basis.z
		var entering=game.sea_dragon.elapsed<float(game.sea_dragon.tuning.formation_seconds)*.3
		game.camera.cull_mask=((1<<20)-1)&~(visuals.BODY_LAYER if entering else visuals.ARMS_LAYER)
		if entering: visuals.update(game.player,game.camera.global_transform)
		if is_instance_valid(visuals.root): visuals.root.visible=entering
		return
	var view=sample_first_person(delta)
	if remote_return>0:
		if game.player.input_enabled: remote_return=maxf(0,remote_return-delta)
		view=remote_last.interpolate_with(view,smoothstep(0,1,1-remote_return/.3))
	game.camera.global_transform=view
	game.camera_target=view.origin-view.basis.z
	visuals.update(game.player,view)

func sample_first_person(delta:float=0.0,advance_gait:bool=true) -> Transform3D:
	game.player.camera_relative=true; game.player.movement_camera_yaw=yaw
	if game.player.input_enabled and game.player.state=="free": game.player.visual.rotation.y=wrapf(yaw-PI,-PI,PI)
	var eye=float(tuning.get("first_person_eye_height",1.52))
	if game.game_mode=="alpha" and game.environment_profile=="original" and game.character_profile=="game": eye=float(tuning.get("original_eye_height",1.65))
	var actor=game.player
	var rig:Skeleton3D=actor.skeleton
	if actor.has_node("BetaHero"):
		var hero=actor.get_node("BetaHero");hero.synchronize();rig=hero.rig
	rig.force_update_all_bone_transforms()
	var head=rig.find_bone("head")
	var rest=rig.get_bone_global_rest(head);var pose=rig.get_bone_global_pose(head)
	# The eye is authored in bind space, then follows the animated head/root.
	var eye_bind=rig.global_transform.affine_inverse()*(actor.global_position+Vector3(0,eye,0))
	# Remove root facing from the calibration point (its X/Z are zero).
	var eye_local=rest.affine_inverse()*eye_bind
	var head_world=rig.global_transform*pose
	var spinning=actor.state=="light" and actor.combo_stage==3
	var base_facing=actor.attack_yaw if spinning else actor.visual.rotation.y
	var mouse_offset=wrapf(yaw-base_facing-PI,-PI,PI)
	var orientation=(rig.global_basis*pose.basis*rest.basis.inverse()*Basis(Vector3.UP,PI+mouse_offset)*Basis(Vector3.RIGHT,-first_pitch)).orthonormalized()
	var chest=game.player.position+Vector3(0,.65,0)
	var forward=-orientation.z
	var desired_eye=head_world*eye_local+forward*.18
	# Attenuate gait-induced eye translation/rotation around the player's current
	# look pose. Attacks keep the full authored head/root motion, including spins.
	var walking=actor.state=="free" and actor.current_clip in ["walk_loop","drag_walk_loop"]
	if actor.state!="free": locomotion_camera_blend=0.0
	elif actor.input_enabled and advance_gait:
		var target=1.0 if walking else 0.0
		locomotion_camera_blend=move_toward(locomotion_camera_blend,target,delta/.16) if delta>0 else target
	var motion_scale=lerpf(1.0,float(tuning.get("first_person_movement_motion",.5)),locomotion_camera_blend)
	if motion_scale<1.0:
		var look_basis=Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,-first_pitch)
		var neutral_eye=actor.global_position+Vector3(0,eye,0)-look_basis.z*.18
		var view_pose=Transform3D(look_basis,neutral_eye).interpolate_with(Transform3D(orientation,desired_eye),motion_scale)
		orientation=view_pose.basis;desired_eye=view_pose.origin;forward=-orientation.z
	# Keep the guard's physical twist, but let the player keep sight of the threat.
	# The authored action clock also freezes this smooth entry/recovery in menus.
	if actor.state=="parry":
		var phase=clampf(actor.state_time/actor.state_duration,0,1)
		var guard=smoothstep(0,.12,phase)*(1-smoothstep(.82,1,phase))
		var parry_scale=lerpf(1.0,float(tuning.get("first_person_parry_motion",.2)),guard)
		var look_basis=Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,-first_pitch)
		orientation=Basis(look_basis.get_rotation_quaternion().slerp(orientation.get_rotation_quaternion(),parry_scale))
		forward=-orientation.z
		desired_eye=head_world*eye_local+forward*.18
	var lance_kick=lance_view_offset()
	if not lance_kick.is_zero_approx():
		orientation=(orientation*Basis(Vector3.UP,lance_kick.x)*Basis(Vector3.RIGHT,lance_kick.y)).orthonormalized()
		forward=-orientation.z;desired_eye=head_world*eye_local+forward*.18
	collision_query.transform=Transform3D(Basis.IDENTITY,chest); collision_query.motion=desired_eye-chest
	var fractions=game.player.get_world_3d().direct_space_state.cast_motion(collision_query)
	return Transform3D(orientation,chest+collision_query.motion*fractions[0])

func lance_view_offset() -> Vector2:
	# Read only the actor's charge clock: sword, view and beam share an aim,
	# repeated sampling cannot add kicks, and overlays freeze the motion.
	var actor=game.player
	if actor.state=="lance_charge":
		return lance_charge_offset(clampf(actor.state_time/actor.state_duration,0,1))
	if actor.state=="lance_fire":
		return lance_charge_offset(1)*(1-smoothstep(0,.38,actor.state_time/actor.state_duration))
	return Vector2.ZERO

func lance_charge_offset(progress:float) -> Vector2:
	var seconds=progress*3.0
	var motion=Vector2(sin(seconds*8.3+sin(seconds*3.1))*.23,sin(seconds*11.9+.8)*.20)
	var impulses=[Vector2(-1,.5),Vector2(.85,-.8),Vector2(-.6,-1),Vector2(1,.65),Vector2(-.95,.4),Vector2(.7,-.9),Vector2(-.85,-.7)]
	var times=[.18,.34,.51,.65,.80,.93,.985]
	for index in range(times.size()):
		var elapsed=(progress-times[index])*3.0
		if elapsed>0: motion+=impulses[index]*smoothstep(0,.035,elapsed)*exp(-elapsed*11)
	motion.x=clampf(motion.x,-1,1);motion.y=clampf(motion.y,-1,1)
	var buildup=smoothstep(0,.12,progress)*lerpf(.35,1,progress)
	var control=1-clampf(game.player.lance_stability,0,.75)
	return motion*Vector2(deg_to_rad(float(tuning.get("first_person_lance_yaw_degrees",6))),deg_to_rad(float(tuning.get("first_person_lance_pitch_degrees",4))))*buildup*control

func bounded_travel(angle:float) -> Vector3:
	var direction=Vector3(sin(yaw)*cos(angle),sin(angle),cos(yaw)*cos(angle))
	var desired=game.camera_target+direction*distance
	var bounds=game.current_world.bounds
	desired.x=clampf(desired.x,bounds.position.x+.35,bounds.end.x-.35)
	desired.z=clampf(desired.z,bounds.position.y+.35,bounds.end.y-.35)
	return desired-game.camera_target

func clear_distance(travel:Vector3) -> float:
	collision_query.transform=Transform3D(Basis.IDENTITY,game.camera_target)
	collision_query.motion=travel
	var fractions=game.player.get_world_3d().direct_space_state.cast_motion(collision_query)
	return maxf(.12,travel.length()*fractions[0]-.10) if fractions[0]<1 else travel.length()

func restore(data:Dictionary) -> void:
	yaw=wrapf(float(data.get("camera_yaw",game.player.visual.rotation.y+PI)),-PI,PI)
	pitch=float(data.get("camera_pitch",tuning.pitch))
	distance=float(data.get("camera_distance",tuning.distance))
	first_pitch=float(data.get("first_person_pitch",0))
	actual_distance=distance
	set_mode(data.get("camera_mode","first_person") if "--verify" in OS.get_cmdline_user_args() else "first_person")
	if game.camera_mode=="follow":
		game.camera_target=game.player.position+Vector3(0,float(tuning.focus_height),0)
