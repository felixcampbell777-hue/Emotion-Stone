extends Node
## Screen-only accepted local-hurt feedback. Never creates world effects or changes gameplay.
const SETTINGS="user://blood.cfg"
const VIGNETTE_SECONDS=.30
const EVENT_LIMIT=256
var game:Node
var level="full"
var seen:Dictionary={}
var snapshot_tick=-1
var snapshot_ready=false
var vignette_remaining=0.0
var vignette_strength=0.0
var overlay:ColorRect
var material:ShaderMaterial
var accepted_hits=0

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
	clear_feedback()

func set_level(value:String) -> void:
	if value not in ["off","reduced","full"]:return
	level=value
	if value=="off":vignette_remaining=0;vignette_strength=0
	elif value=="reduced":vignette_strength=minf(vignette_strength,.144)
	_update_overlay();set_process(vignette_remaining>0)
	var config=ConfigFile.new();config.set_value("feedback","blood",level)
	var error=config.save(SETTINGS)
	if error!=OK:push_warning("Blood preference could not be saved: %s"%error_string(error))

func clear_feedback() -> void:
	seen.clear();snapshot_tick=-1;snapshot_ready=false
	vignette_remaining=0;vignette_strength=0
	_update_overlay();set_process(false)

func _exit_tree() -> void:
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
	return _hurt(float(event.get("amount",1)))

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
		if victim!=local_id or victim.is_empty() or not _remember("online:"+String(event.get("id",""))):continue
		if not play_events:continue
		_hurt(float(event.get("amount",1)))

func _hurt(amount:float) -> bool:
	if not is_finite(amount) or amount<=0:return false
	accepted_hits+=1
	if level=="off":return false
	var maximum=100.0
	var player=game.get("player") if is_instance_valid(game) else null
	if is_instance_valid(player):maximum=maxf(1,float(player.get("max_health")))
	vignette_strength=maxf(vignette_strength,clampf(.12+amount/maximum*.65,.14,.32)*(.45 if level=="reduced" else 1.0))
	vignette_remaining=VIGNETTE_SECONDS;_update_overlay();set_process(true)
	return true

func _update_overlay() -> void:
	if not is_instance_valid(overlay):return
	overlay.visible=level!="off" and vignette_remaining>0
	var envelope=clampf(vignette_remaining/VIGNETTE_SECONDS,0,1)
	material.set_shader_parameter("strength",vignette_strength*envelope*envelope)

func _process(delta:float) -> void:
	if is_instance_valid(game) and game.has_method("simulation_active") and not game.simulation_active():return
	vignette_remaining=maxf(0,vignette_remaining-delta);_update_overlay()
	set_process(vignette_remaining>0)
