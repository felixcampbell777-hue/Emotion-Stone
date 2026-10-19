extends RefCounted
const ViewFrame=preload("res://scripts/network/wr_view_frame.gd")
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
var third_person=preload("res://scripts/wr_third_person_camera.gd").new()
const PREFERENCE_PATH="user://world-rise-camera.cfg"
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
	# World Rise third person shares the same canonical actor/steel simulation.
	if mode=="third_person" and game.game_mode!="world_rise":mode="first_person"
	if mode not in ["first_person","third_person","follow","overhead"]:mode="first_person"
	if mode!="third_person" and DisplayServer.get_name()!="headless" and "--verify" not in OS.get_cmdline_user_args() and "--capture" not in OS.get_cmdline_user_args(): mode="first_person"
	game.camera_mode=mode
	third_person.reset()
	orbiting=false
	game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL if mode=="overhead" else Camera3D.PROJECTION_PERSPECTIVE
	game.camera.fov=float(tuning.get("first_person_fov",75) if mode=="first_person" else tuning.fov)
	game.camera.near=.04 if mode=="first_person" else .08 if mode=="follow" else .05
	game.camera.far=160 if mode=="overhead" else 90 if mode in ["first_person","third_person"] else 55
	game.environment_settings.fog_enabled=mode!="overhead"
	game.environment_settings.fog_light_color=Color("#223638" if game.current_world!=null and game.current_world.definition.get("cave",false) else "#a1b8b7")
	game.environment_settings.fog_density=.035
	if game.environment_profile=="darkwood" and game.current_world!=null:
		game.EnvironmentArt.configure_lighting(game,game.current_world.definition)
	if game.game_mode=="world_rise":game.worldrise.lighting()
	if game.player!=null:
		game.player.camera_relative=mode!="overhead"
		game.player.movement_camera_yaw=yaw
		game.player.first_person_driver=self if mode in ["first_person","third_person"] else null
		if mode in ["first_person","third_person"]: visuals.prepare(game.player)
		elif game.player.has_meta("standalone_static"): game.player.visual.visible=false
	game.camera.cull_mask=((1<<20)-1)&~(visuals.BODY_LAYER if mode=="first_person" else visuals.ARMS_LAYER)
	if game.camera_button!=null:
		game.camera_button.text={"follow":"Follow [C]","first_person":"First person [C]","third_person":"Third person [C]","overhead":"Top [C]"}[mode]
	refresh_pointer()

func recenter() -> void:
	yaw=wrapf(game.player.visual.rotation.y+PI,-PI,PI)
	game.player.movement_camera_yaw=yaw

func reset_motion() -> void:
	if game.player==null:return
	visuals.unarmed.reset(game.player)
	game.player.first_person_sword.reset_gait(game.player)
	locomotion_camera_blend=0.0
	game.player.set_meta("canonical_view_blend",0.0)

func handle_input(event:InputEvent) -> bool:
	if is_instance_valid(game.sea_dragon) and game.sea_dragon.active and game.player.input_enabled:
		if event is InputEventMouseMotion:
			game.sea_dragon.steer(event.relative*float(tuning.sensitivity));return true
		if event is InputEventMouseButton: return true
	if game.camera_mode in ["first_person","third_person"] and game.player.input_enabled:
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
	if game.camera_mode=="third_person":
		update_third_person(delta)
		return
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
	var active=game.camera_mode in ["first_person","third_person"] and game.player.input_enabled and not game.gallery_mode
	crosshair.visible=active
	crosshair.position=game.world_rect.get_center()-Vector2(6,14)
	var args=OS.get_cmdline_user_args()
	var capture=active and game.get_window().has_focus() and DisplayServer.get_name()!="headless" and "--verify" not in args and "--capture" not in args and "--weapon-render" not in args
	if capture and not owns_pointer:
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED; owns_pointer=true
	elif not capture and owns_pointer:
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE; owns_pointer=false

func end_remote_view(immediate:bool=false) -> void:
	remote_last=game.camera.global_transform;remote_return=0.0 if immediate or game.camera_mode=="third_person" else .3
	game.camera.cull_mask=((1<<20)-1)&~(visuals.ARMS_LAYER if game.camera_mode=="third_person" else visuals.BODY_LAYER)
	if is_instance_valid(visuals.root): visuals.root.visible=true
	if immediate:
		if game.camera_mode=="third_person":update_third_person(0)
		else:update_first_person(0)

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
	locomotion_camera_blend=ViewFrame.locomotion_blend(actor,locomotion_camera_blend,delta,advance_gait)
	return ViewFrame.from_actor(actor,tuning,yaw,first_pitch,locomotion_camera_blend,actor.get_world_3d().direct_space_state,collision_query,eye)

func lance_view_offset() -> Vector2:
	return ViewFrame.lance_offset(game.player,tuning)

func lance_charge_offset(progress:float) -> Vector2:
	return ViewFrame.lance_charge_offset(progress,game.player.lance_stability,tuning)

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
	set_mode(preferred_mode() if game.game_mode=="world_rise" else data.get("camera_mode","first_person") if "--verify" in OS.get_cmdline_user_args() else "first_person")
	if game.camera_mode=="follow":
		game.camera_target=game.player.position+Vector3(0,float(tuning.focus_height),0)

func preferred_mode() -> String:
	var preferences=ConfigFile.new()
	if preferences.load(PREFERENCE_PATH)!=OK:return "first_person"
	var mode=String(preferences.get_value("camera","mode","first_person"))
	return mode if mode in ["first_person","third_person"] else "first_person"

func toggle_mode() -> void:
	if game.game_mode!="world_rise" or not game.player.input_enabled:return
	if is_instance_valid(game.sea_dragon) and game.sea_dragon.active:return
	set_mode("first_person" if game.camera_mode=="third_person" else "third_person")
	var preferences=ConfigFile.new()
	preferences.set_value("camera","mode",game.camera_mode)
	var error=preferences.save(PREFERENCE_PATH)
	if error!=OK:push_warning("Camera preference could not be saved: "+error_string(error))

func update_third_person(delta:float=0.0) -> void:
	if is_instance_valid(game.sea_dragon) and game.sea_dragon.active:
		update_first_person(delta)
		return
	var head=sample_first_person(delta)
	game.camera.global_transform=third_person.sample(game.player,head,yaw,first_pitch,game.current_world.bounds,delta)
	game.camera_target=head.origin-head.basis.z
	game.camera.fov=float(tuning.get("first_person_fov",75) if third_person.close_view else tuning.fov)
	game.camera.near=.04 if third_person.close_view else .05
	# Keep accepted view arm fitting ready for tight spaces, but show the existing
	# full body and its actual actor-owned weapon whenever the boom is clear.
	visuals.update(game.player,head)
	game.camera.cull_mask=((1<<20)-1)&~(visuals.BODY_LAYER if third_person.close_view else visuals.ARMS_LAYER)
	if is_instance_valid(visuals.root):visuals.root.visible=third_person.close_view and visuals.root.visible
	var target=third_person.aim_point(game.player,head)
	crosshair.visible=crosshair.visible and not game.camera.is_position_behind(target)
	if crosshair.visible:
		var viewport_size=Vector2(game.world_view.size)
		var point=game.camera.unproject_position(target)/viewport_size*game.world_rect.size+game.world_rect.position
		crosshair.position=point-Vector2(6,14)
