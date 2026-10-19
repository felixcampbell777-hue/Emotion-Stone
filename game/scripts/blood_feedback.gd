extends Node
## Cosmetic accepted-human-hurt feedback. Never writes actor state or save profiles.
const SETTINGS="user://blood.cfg"
const VIGNETTE_SECONDS=.30
const SPLASH_SECONDS=.34
const BURST_LIMIT=8
const DROPLETS=6
const EVENT_LIMIT=256
const MAX_DISTANCE=30.0
var game:Node
var level="full"
var seen:Dictionary={}
var snapshot_tick=-1
var snapshot_ready=false
var vignette_remaining=0.0
var vignette_strength=0.0
var overlay:ColorRect
var material:ShaderMaterial
var splash:MultiMeshInstance3D
var bursts:Array=[]
var cursor=0
var accepted_hits=0
var emitted_bursts=0

func configure(owner_game:Node) -> void:
	game=owner_game;name="BloodFeedback"
	var config=ConfigFile.new()
	if config.load(SETTINGS)==OK:
		var stored=config.get_value("feedback","blood","full")
		if stored is String and stored in ["off","reduced","full"]:level=stored
	overlay=ColorRect.new();overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	game.add_child(overlay)
	# The world texture is followed by feedback, then the HUD and overlay controls.
	var world_image=game.get("image_view")
	if is_instance_valid(world_image) and world_image.get_parent()==game:
		game.move_child(overlay,world_image.get_index()+1)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	material=ShaderMaterial.new();material.shader=preload("res://shaders/blood_vignette.gdshader")
	overlay.material=material;overlay.visible=false
	splash=MultiMeshInstance3D.new();splash.name="HumanHitSplashes"
	var mesh=SphereMesh.new();mesh.radius=.022;mesh.height=.06;mesh.radial_segments=4;mesh.rings=2
	var ink=StandardMaterial3D.new();ink.albedo_color=Color(.30,.012,.018);ink.roughness=.9
	mesh.material=ink
	var multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.mesh=mesh
	multimesh.instance_count=BURST_LIMIT*DROPLETS;splash.multimesh=multimesh
	splash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var world=game.get("world_root")
	if is_instance_valid(world):world.add_child(splash)
	else:add_child(splash)
	for index in range(BURST_LIMIT):bursts.append({})
	clear_feedback()

func set_level(value:String) -> void:
	if value not in ["off","reduced","full"]:return
	level=value
	if value!="full":_clear_splashes()
	if value=="off":vignette_remaining=0;vignette_strength=0
	elif value=="reduced":vignette_strength=minf(vignette_strength,.144)
	_update_overlay();set_process(vignette_remaining>0 or _has_bursts())
	var config=ConfigFile.new();config.set_value("feedback","blood",level)
	var error=config.save(SETTINGS)
	if error!=OK:push_warning("Blood preference could not be saved: %s"%error_string(error))

func clear_feedback() -> void:
	seen.clear();snapshot_tick=-1;snapshot_ready=false
	vignette_remaining=0;vignette_strength=0;cursor=0
	_clear_splashes();_update_overlay();set_process(false)

func _clear_splashes() -> void:
	for index in range(bursts.size()):bursts[index]={}
	if is_instance_valid(splash):
		for index in range(BURST_LIMIT*DROPLETS):splash.multimesh.set_instance_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))
		splash.visible=false

func _exit_tree() -> void:
	if is_instance_valid(splash):splash.queue_free()
	if is_instance_valid(overlay):overlay.queue_free()

func _remember(identity:String) -> bool:
	if identity.is_empty() or seen.has(identity):return false
	seen[identity]=true
	if seen.size()>EVENT_LIMIT:seen.erase(seen.keys()[0])
	return true

func actor_event(event:Dictionary) -> bool:
	# Integration routes only the accepted offline local Actor here, never prediction replay.
	if is_instance_valid(game) and game.has_method("online_session_active") and game.online_session_active():return false
	if String(event.get("id",""))!="player.hurt":return false
	var identity="offline:%s:%s:%s"%[event.get("actor_id",""),event.get("action_id",""),event.get("event_index",-1)]
	if not _remember(identity):return false
	return _hurt(event.get("at",Vector3.ZERO),true,float(event.get("amount",1)))

func snapshot_events(events:Array,local_id:String,floor_id:String,tick:int) -> void:
	if tick<=snapshot_tick:return
	snapshot_tick=tick
	# Initial state is a baseline, never a replay of damage before joining/changing floors.
	var play_events=snapshot_ready;snapshot_ready=true
	for value in events:
		if not value is Dictionary:continue
		var event:Dictionary=value
		var kind=String(event.get("kind",""))
		if kind!="damage" and not (kind=="audio" and String(event.get("event",""))=="player.hurt"):continue
		if String(event.get("floor",""))!=floor_id:continue
		var victim=String(event.get("actor_id",event.get("owner","")))
		if victim.is_empty() or not _remember("online:"+String(event.get("id",""))):continue
		if not play_events:continue
		var at=_position(event.get("position",event.get("at",Vector3.ZERO)))
		_hurt(at,victim==local_id,float(event.get("amount",1)))

func _position(value:Variant) -> Vector3:
	if value is Vector3:return value
	if value is Array and value.size()==3:
		for component in value:
			if not (component is int or component is float) or not is_finite(float(component)):return Vector3.ZERO
		return Vector3(float(value[0]),float(value[1]),float(value[2]))
	return Vector3.ZERO

func _hurt(at:Vector3,local:bool,amount:float) -> bool:
	if not at.is_finite() or not is_finite(amount) or amount<=0:return false
	accepted_hits+=1
	if level=="off":return false
	if local:
		var maximum=100.0
		var player=game.get("player") if is_instance_valid(game) else null
		if is_instance_valid(player):maximum=maxf(1,float(player.get("max_health")))
		vignette_strength=maxf(vignette_strength,clampf(.12+amount/maximum*.65,.14,.32)*(.45 if level=="reduced" else 1.0))
		vignette_remaining=VIGNETTE_SECONDS;_update_overlay()
	if level=="full":_burst(at+Vector3.UP*.95,local)
	set_process(vignette_remaining>0 or _has_bursts())
	return true

func _camera() -> Camera3D:
	if not is_instance_valid(game):return null
	var camera=game.get("camera")
	if camera is Camera3D:return camera
	var viewport=game.get("world_view")
	return viewport.get_camera_3d() if viewport is Viewport else null

func _burst(at:Vector3,local:bool) -> void:
	if not is_instance_valid(splash):return
	var camera=_camera()
	if camera==null:return
	if camera.global_position.distance_squared_to(at)>MAX_DISTANCE*MAX_DISTANCE or not camera.is_position_in_frustum(at):return
	# Keep first-person droplets outside the near eye/body volume; the edge vignette carries hurt.
	if local and camera.global_position.distance_squared_to(at)<1.44:return
	# Start at the visible skin surface rather than burying tiny droplets in the torso.
	var toward_camera=(camera.global_position-at).normalized()
	bursts[cursor]={"at":at+toward_camera*.26,"remaining":SPLASH_SECONDS,"seed":accepted_hits}
	cursor=(cursor+1)%BURST_LIMIT;emitted_bursts+=1;splash.visible=true

func _has_bursts() -> bool:
	for burst in bursts:
		if not burst.is_empty():return true
	return false

func _update_overlay() -> void:
	if not is_instance_valid(overlay):return
	overlay.visible=level!="off" and vignette_remaining>0
	var envelope=clampf(vignette_remaining/VIGNETTE_SECONDS,0,1)
	material.set_shader_parameter("strength",vignette_strength*envelope*envelope)

func _process(delta:float) -> void:
	if is_instance_valid(game) and game.has_method("simulation_active") and not game.simulation_active():return
	vignette_remaining=maxf(0,vignette_remaining-delta);_update_overlay()
	for index in range(bursts.size()):
		var burst:Dictionary=bursts[index]
		if burst.is_empty():continue
		burst.remaining=maxf(0,float(burst.remaining)-delta)
		var elapsed=SPLASH_SECONDS-float(burst.remaining)
		for drop in range(DROPLETS):
			var transform=Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO)
			if burst.remaining>0:
				var angle=float(drop)*TAU/DROPLETS+float(burst.seed)*.73
				var velocity=Vector3(cos(angle)*.65,.7+float(drop%3)*.18,sin(angle)*.65)
				var at:Vector3=burst.at+velocity*elapsed+Vector3.DOWN*elapsed*elapsed*2.3
				var size=clampf(float(burst.remaining)/.10,0,1)
				transform=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),splash.to_local(at))
			splash.multimesh.set_instance_transform(index*DROPLETS+drop,transform)
		if burst.remaining<=0:bursts[index]={}
	var active=_has_bursts();splash.visible=active
	set_process(vignette_remaining>0 or active)
