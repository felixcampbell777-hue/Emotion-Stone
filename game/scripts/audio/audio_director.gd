extends Node
## Local presentation only. Gameplay/authority must never depend on audible playback.
signal caption_requested(text:String, at:Vector3)
signal event_played(id:String, identity:String)
const CATALOG="res://content/world_rise/audio_events.json"
const Surface=preload("res://scripts/audio/audio_surface_resolver.gd")
const SETTINGS="user://audio.cfg"
const WORLD_LIMIT=32
const UI_LIMIT=8
const LOOP_LIMIT=8
var game:Node
var events:Dictionary={}
var streams:Dictionary={}
# Weak observations never retain playback; engine stop completes across audio/main ticks.
var playback_watch:Dictionary={}
var voices:Array=[]
var ui_voices:Array=[]
var loops:Dictionary={}
var dedup:Dictionary={}
var cooldowns:Dictionary={}
var last_variants:Dictionary={}
var prefs={"Master":.8,"Music":.65,"Ambience":.75,"SFX":.85,"UI":.75,"Voice":1.0,"quiet":false,"mono":false,"captions":true,"background_mute":true,"reduced_footsteps":false}
var generation=0
var map_key=""
var paused=false
var online=false
var focused=true
var initialized=false
var previous_position=Vector3.ZERO
var have_position=false
var stride=0.0
var last_gait_phase=-1.0
var wet=false
var underwater=false
var zone_clock=0.0
var occlusion_clock=0.0
var occlusion_cursor=0
var combat_until=0.0
var duck=1.0
var speech_until=0.0
var voice_active=false
var clock=0.0
var stats={"played":0,"deduplicated":0,"culled":0,"stolen":0,"missing":0,"peak_world":0}
var caption_label:Label
var caption_until=0.0
var rng=RandomNumberGenerator.new()

func configure(owner_game:Node) -> void:
	game=owner_game
	name="AudioDirector"
	rng.randomize()
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if parsed is Dictionary:events=parsed.get("events",{})
	var layout=load("res://default_bus_layout.tres")
	if layout is AudioBusLayout:AudioServer.set_bus_layout(layout)
	var world_view=game.get("world_view")
	if world_view is SubViewport:world_view.audio_listener_enable_3d=true
	load_preferences()
	for index in range(WORLD_LIMIT):
		var voice=AudioStreamPlayer3D.new()
		voice.name="WorldVoice%d"%index;voice.max_db=0;voice.max_polyphony=1
		voice.attenuation_filter_cutoff_hz=12000
		var world_parent=game.get("world_root")
		if is_instance_valid(world_parent):world_parent.add_child(voice)
		else:add_child(voice)
		voices.append({"player":voice,"priority":0,"started":0.0,"id":"","owner":""})
	for index in range(UI_LIMIT):
		var voice=AudioStreamPlayer.new();voice.name="LocalVoice%d"%index;add_child(voice)
		ui_voices.append({"player":voice,"priority":0,"started":0.0,"id":"","owner":""})
	for key in ["music_a","music_b","bed_a","bed_b","detail_a","detail_b","night_a","night_b"]:
		var voice=AudioStreamPlayer.new();voice.name=key;add_child(voice)
		loops[key]={"player":voice,"id":"","gain":0.0,"target":0.0}
	var layer=CanvasLayer.new();layer.layer=65;add_child(layer)
	caption_label=Label.new();caption_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption_label.add_theme_font_size_override("font_size",17)
	caption_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	caption_label.add_theme_constant_override("shadow_outline_size",4)
	caption_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(caption_label)
	if get_window()!=null:
		get_window().focus_exited.connect(_focus_lost)
		get_window().focus_entered.connect(_focus_gained)
	initialized=true
	apply_preferences()

func _focus_lost() -> void:
	focused=false
	apply_preferences()
func _focus_gained() -> void:
	focused=true
	apply_preferences()
func load_preferences() -> void:
	var config=ConfigFile.new()
	if config.load(SETTINGS)!=OK:return
	for key in prefs:
		var value=config.get_value("audio",key,prefs[key])
		if prefs[key] is bool:
			if value is bool:prefs[key]=value
		elif (value is float or value is int) and is_finite(float(value)):prefs[key]=clampf(float(value),0,1)
func save_preferences() -> void:
	var config=ConfigFile.new()
	for key in prefs:config.set_value("audio",key,prefs[key])
	var error=config.save(SETTINGS)
	if error!=OK:push_warning("Audio preferences could not be saved: %s"%error_string(error))
func set_preference(key:String,value:Variant) -> void:
	if not prefs.has(key):return
	if prefs[key] is bool:
		if not value is bool:return
		prefs[key]=value
	else:
		if not (value is float or value is int) or not is_finite(float(value)):return
		prefs[key]=clampf(float(value),0,1)
	apply_preferences();save_preferences()
func apply_preferences() -> void:
	for key in ["Master","Music","Ambience","SFX","UI","Voice"]:
		var index=AudioServer.get_bus_index(key)
		if index<0:continue
		var amount=float(prefs[key])
		if key=="Master":amount*=.8 if prefs.quiet else 1.0
		if key in ["Music","Ambience"]:amount*=duck
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(amount,.0001)))
		AudioServer.set_bus_mute(index,amount<=0 or (not focused and prefs.background_mute))
	for entry in voices:entry.player.panning_strength=0.0 if prefs.mono else .65
	# Downmix the complete master, including future voice, without platform-dependent output changes.
	var master=AudioServer.get_bus_index("Master")
	if master>=0:
		var stereo_index=-1
		for index in range(AudioServer.get_bus_effect_count(master)):
			if AudioServer.get_bus_effect(master,index) is AudioEffectStereoEnhance:stereo_index=index
		if stereo_index<0:
			var stereo=AudioEffectStereoEnhance.new();stereo.pan_pullout=0.0;AudioServer.add_bus_effect(master,stereo)
			stereo_index=AudioServer.get_bus_effect_count(master)-1
		AudioServer.set_bus_effect_enabled(master,stereo_index,prefs.mono)

func set_voice_activity(speaking:bool) -> void:
	# Voice renderer supplies this; no microphone capture/loopback is created here.
	voice_active=speaking
	if not speaking:speech_until=clock+.25
func voice_bus() -> StringName:return &"Voice"
func world_generation() -> int:return generation
func emit_event(event:Dictionary) -> bool:
	var id=String(event.get("event_id",event.get("id","")))
	if id.begins_with("action."):
		var action=id.trim_prefix("action.")
		var mapping={"draw":"player.draw","sheathe":"player.sheathe","light":"","heavy":"","thrust":"","parry":"","jump":"player.jump","roll":"player.dodge","dash":"player.dash","dash_charge":"","charge":"","stagger":"","dead":"player.death","defeated":"player.death","stand":"","stand_sheathed":"","water":"","water_lance":""}
		id=String(mapping.get(action,""))
		var weapon=String(event.get("weapon_type","greatsword"))
		if not id.is_empty() and action in ["light","heavy","thrust"] and weapon in ["spear","rapier"]:id="weapon."+weapon+".thrust"
		if id.is_empty():return false
	return play(id,event.get("at",Vector3.ZERO),event)
func _identity(id:String,context:Dictionary) -> String:
	if context.has("identity"):return str(context.identity)
	if context.has("action_id") and (context.has("actor_id") or context.has("stable_id")):
		return "%s:%s:%s:%s:%s:%s"%[context.get("world_generation",generation),context.get("actor_id",context.get("stable_id","")),context.action_id,context.get("event_index",id),context.get("target_id",""),id]
	return ""
func _stream(path:String) -> AudioStream:
	if not streams.has(path):streams[path]=load(path)
	return streams[path] as AudioStream
func play(id:String, at:Vector3=Vector3.ZERO, context:Dictionary={}) -> bool:
	if not initialized:return false
	if not events.has(id):
		stats.missing+=1
		push_warning("Unmapped audio event: "+id)
		return false
	if context.has("world_generation") and int(context.world_generation)!=generation:return false
	if context.get("historical",false) or context.get("restored",false):return false
	var item:Dictionary=events[id]
	if item.get("loop",false):return false
	var bus=String(item.bus)
	if bus!="UI" and paused:return false
	if bus!="UI" and is_instance_valid(game) and String(game.get("game_mode"))!="world_rise":return false
	var identity=_identity(id,context)
	if not identity.is_empty() and dedup.has(identity):stats.deduplicated+=1;return false
	var owner=String(context.get("actor_id",context.get("stable_id","local")))
	var cooldown_key=id+":"+owner+":"+str(context.get("target_id",""))
	if clock<float(cooldowns.get(cooldown_key,-1)):return false
	var listener=listener_position()
	var distance=listener.distance_to(at)
	if bus!="UI" and distance>float(item.max_distance):stats.culled+=1;return false
	var pool=ui_voices if bus=="UI" else voices
	var target:Dictionary={}
	var lowest=INF
	var owner_count=0
	for entry in pool:
		if entry.player.playing and entry.owner==owner:owner_count+=1
	if owner_count>=4 and int(item.priority)<90:stats.culled+=1;return false
	for entry in pool:
		if not entry.player.playing:target=entry;break
		var score=float(entry.priority)-minf(10,clock-float(entry.started))
		if score<lowest:lowest=score;target=entry
	if target.is_empty():return false
	var priority=int(item.priority)
	if target.player.playing:
		if int(target.priority)>priority:stats.culled+=1;return false
		stats.stolen+=1;_stop_player(target.player)
	var choices:Array=item.clips
	var variant=rng.randi_range(0,choices.size()-1)
	if choices.size()>1 and variant==int(last_variants.get(id,-1)):variant=(variant+1)%choices.size()
	last_variants[id]=variant
	var stream=_stream(choices[variant])
	if stream==null:stats.missing+=1;return false
	var player=target.player
	player.stream=stream
	player.bus="Underwater" if underwater and bus=="SFX" else bus
	player.volume_db=float(item.gain_db)+float(context.get("gain_db",0))-(3 if prefs.quiet and priority>=80 else 0)
	player.pitch_scale=rng.randf_range(float(item.pitch_min),float(item.pitch_max))
	if player is AudioStreamPlayer3D:
		player.global_position=at;player.max_distance=float(item.max_distance);player.unit_size=1.0
	player.play()
	target.priority=priority;target.started=clock;target.id=id;target.owner=owner
	cooldowns[cooldown_key]=clock+float(item.cooldown)
	if not identity.is_empty():dedup[identity]=clock
	stats.played+=1
	var active=0
	for entry in voices:
		if entry.player.playing:active+=1
	stats.peak_world=maxi(stats.peak_world,active)
	if prefs.captions and not String(item.caption).is_empty() and priority>=65:
		var text=String(item.caption)
		if bus!="UI" and is_instance_valid(game.get("camera")):
			var camera=game.get("camera")
			var lateral=camera.global_basis.x.dot(at-listener)
			if absf(lateral)>2:text+=("  ←" if lateral<0 else "  →")
		caption_requested.emit(text,at)
		caption_label.text=text;caption_until=clock+1.4
	event_played.emit(id,identity)
	return true
func listener_position() -> Vector3:
	if is_instance_valid(game) and is_instance_valid(game.get("camera")):return game.get("camera").global_position
	return Vector3.ZERO
func stop_owner(actor_id:String) -> void:
	for entry in voices:
		if entry.owner==actor_id:_stop_player(entry.player)
func reset_world() -> void:
	generation+=1;dedup.clear();cooldowns.clear();have_position=false;stride=0;last_gait_phase=-1;wet=false;underwater=false
	for entry in voices:_stop_player(entry.player)
	for entry in loops.values():entry.target=0.0
func _sync_pause() -> void:
	online=game.has_method("online_session_active") and game.online_session_active()
	var actor=game.get("player")
	var next_paused=not online and is_instance_valid(actor) and not actor.simulation_active()
	if next_paused!=paused:
		paused=next_paused
		for entry in voices:entry.player.stream_paused=paused
		have_position=false;stride=0;last_gait_phase=-1
func _process(delta:float) -> void:
	if not initialized or not is_instance_valid(game):return
	clock+=delta
	var key=String(game.get("map_id"))+":"+str(game.get("current_world"))
	if key!=map_key:map_key=key;reset_world()
	_sync_pause()
	var next_duck=.55 if voice_active or clock<speech_until else 1.0
	var smoothed=move_toward(duck,next_duck,delta*(3 if next_duck<duck else 1.5))
	if smoothed!=duck:duck=smoothed;apply_preferences()
	if caption_label!=null:
		caption_label.visible=prefs.captions and clock<caption_until
		var screen=get_viewport().get_visible_rect().size
		caption_label.position=Vector2(20,screen.y-92);caption_label.size=Vector2(screen.x-40,40)
	zone_clock-=delta
	if zone_clock<=0:zone_clock=.35;_zones()
	occlusion_clock-=delta
	if occlusion_clock<=0 and not paused:occlusion_clock=.12;_occlusion()
	_update_loops(delta)
	if not paused:_movement()
	for identity in dedup.keys():
		if clock-float(dedup[identity])>12:dedup.erase(identity)
	# Bounded state even for long sessions/many remote actors.
	if cooldowns.size()>512:
		for key_name in cooldowns.keys():
			if float(cooldowns[key_name])<clock:cooldowns.erase(key_name)
func _movement() -> void:
	if String(game.get("game_mode"))!="world_rise":return
	var actor=game.get("player")
	if not is_instance_valid(actor):return
	var at:Vector3=actor.global_position
	var distance=Vector2(at.x-previous_position.x,at.z-previous_position.z).length()
	previous_position=at
	if not have_position:have_position=true;return
	var surface=Surface.surface(game,at)
	var next_wet=surface=="water" and at.y<.10 and not actor.jump_active
	if next_wet!=wet:
		play("world.water.enter" if next_wet else "world.water.exit",at)
		wet=next_wet
	underwater=String(game.get("map_id"))=="wr_floor_02" and listener_position().y<-.15
	if not actor.input_enabled or actor.health<=0 or actor.jump_active or actor.state!="free" or distance>2:
		stride=0;last_gait_phase=-1;return
	if distance<.001:return
	# Actual movement advances the rig gait. Its planted contacts own the cadence.
	if actor.has_node("BetaHero"):
		var gait=actor.get_node("BetaHero").get("gait")
		if gait!=null:
			var phase=float(gait.phase)
			if last_gait_phase>=0:
				var crossed=(phase<last_gait_phase) or (last_gait_phase<.5 and phase>=.5)
				if crossed:play("player.step."+surface,at,{"actor_id":"local_player","gain_db":-5 if prefs.reduced_footsteps else 0})
			last_gait_phase=phase
			return
	stride+=distance
	var interval=.95 if actor.sprinting else .68
	if stride>=interval:
		stride=fmod(stride,interval)
		play("player.step."+surface,at,{"actor_id":"local_player","gain_db":-5 if prefs.reduced_footsteps else 0})
func _zones() -> void:
	var title=game.get("title_screen")
	if is_instance_valid(title) and title.visible:
		_set_loop("music","music.title");_set_loop("bed","ambience.wind");_set_loop("detail","");_set_loop("night","");return
	if String(game.get("game_mode"))!="world_rise":
		_set_loop("music","");_set_loop("bed","");_set_loop("detail","");_set_loop("night","");return
	var map_id=String(game.get("map_id"));var actor=game.get("player")
	if not is_instance_valid(actor):return
	var bed="ambience.wind";var music="music.reach"
	var at:Vector3=actor.global_position
	if map_id=="wr_floor_02":bed="ambience.fen";music="music.fen"
	elif map_id=="wr_boss_chamber":bed="ambience.cave";music="music.vault"
	elif map_id=="wr_floor_01":
		if at.x < -65 and at.z < 0:bed="ambience.forest"
		if Vector2(at.x-146,at.z-146).length()<18:bed="ambience.guild"
	var rise=game.get("worldrise")
	var night_amount=0.0
	if rise!=null and map_id!="wr_boss_chamber":
		night_amount=1.0-float(rise.daylight(rise.day_clock)) if rise.has_method("daylight") else (1.0 if rise.is_night() else 0.0)
	if underwater:bed="ambience.underwater"
	var enemies=game.get("enemies")
	if enemies is Array:
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.health>0 and enemy.global_position.distance_squared_to(at)<625 and enemy.get("state") in ["windup","lunge","strike","rush","howl","leap","bite","slam"]:combat_until=clock+4;break
	if clock<combat_until:music="music.combat"
	_set_loop("music",music);_set_loop("bed",bed,1.0 if underwater else 1.0-night_amount*.75)
	_set_loop("night","ambience.night" if not underwater and night_amount>.01 else "",night_amount*.8)
	_set_loop("detail","ambience.water" if wet and not underwater else "")
	var sfx_bus=AudioServer.get_bus_index("SFX")
	if sfx_bus>=0 and AudioServer.get_bus_effect_count(sfx_bus)>0:AudioServer.set_bus_effect_enabled(sfx_bus,0,map_id=="wr_boss_chamber")
func _set_loop(group:String,id:String,weight:float=1.0) -> void:
	var keys=[group+"_a",group+"_b"]
	for key in keys:
		if loops[key].id==id and loops[key].target>0:
			loops[key].target=weight;return
	for key in keys:loops[key].target=0.0
	if id.is_empty():return
	var target=loops[keys[0]] if loops[keys[0]].gain<=loops[keys[1]].gain else loops[keys[1]]
	_stop_player(target.player);target.id=id;target.gain=0.0;target.target=weight
	var item:Dictionary=events[id];target.player.stream=_stream(item.clips[0]);target.player.bus=item.bus
	target.player.volume_db=-80;target.player.play()
func _update_loops(delta:float) -> void:
	for entry in loops.values():
		entry.gain=move_toward(float(entry.gain),float(entry.target),delta/.9)
		if entry.gain<=0:
			if entry.player.playing:_stop_player(entry.player)
			continue
		var pause_gain=.35 if paused else 1.0
		entry.player.volume_db=float(events[entry.id].gain_db)+linear_to_db(maxf(.0001,float(entry.gain)*pause_gain))

func _occlusion() -> void:
	if not is_inside_tree():return
	var camera=game.get("camera")
	if not is_instance_valid(camera):return
	var world=camera.get_world_3d()
	if world==null:return
	var listener=listener_position()
	# At most four collision queries per update; important tells remain legible.
	for offset in range(4):
		var entry=voices[(occlusion_cursor+offset)%voices.size()]
		if not entry.player.playing or entry.priority>=90:continue
		var source:Vector3=entry.player.global_position+Vector3.UP*.35
		if listener.distance_squared_to(source)<4:continue
		var query=PhysicsRayQueryParameters3D.create(listener,source,1)
		var blocked=not world.direct_space_state.intersect_ray(query).is_empty()
		entry.player.attenuation_filter_cutoff_hz=lerpf(entry.player.attenuation_filter_cutoff_hz,2200.0 if blocked else 12000.0,.55)
	occlusion_cursor=(occlusion_cursor+4)%voices.size()

func settings_panel() -> Control:
	var panel=VBoxContainer.new();panel.name="AudioSettings"
	var heading=Label.new();heading.text="SOUND";panel.add_child(heading)
	for bus in ["Master","Music","SFX","Ambience","UI","Voice"]:
		var row=HBoxContainer.new();panel.add_child(row)
		var label=Label.new();label.text=bus;label.custom_minimum_size.x=90;row.add_child(label)
		var slider=HSlider.new();slider.min_value=0;slider.max_value=100;slider.step=1;slider.value=float(prefs[bus])*100;slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		slider.tooltip_text=bus+" volume; zero mutes";slider.custom_minimum_size.x=130;row.add_child(slider)
		slider.value_changed.connect(func(value):set_preference(bus,value/100.0))
		slider.drag_ended.connect(func(changed):
			if changed:play("ui.confirm"))
	for setting in [["quiet","Quiet listening"],["mono","Mono output"],["captions","Important sound captions"],["background_mute","Mute in background"],["reduced_footsteps","Quieter footsteps"]]:
		var toggle=CheckBox.new();toggle.text=setting[1];toggle.button_pressed=prefs[setting[0]];panel.add_child(toggle)
		toggle.toggled.connect(func(value):set_preference(setting[0],value))
	var preview=Button.new();preview.text="Preview sound";panel.add_child(preview);preview.pressed.connect(func():play("ui.confirm"))
	return panel

func _track_playback(player:Node) -> void:
	if player.has_stream_playback():
		var playback=player.get_stream_playback()
		if playback!=null:playback_watch[playback.get_instance_id()]=weakref(playback)
	# Retired effects are observed weakly only until the engine releases them.
	for identity in playback_watch.keys():
		if playback_watch[identity].get_ref()==null:playback_watch.erase(identity)
func pending_playback_count() -> int:
	# Keep get_ref() temporaries inside a synchronous stack frame; an async
	# waiter must not itself retain the playback it is waiting to retire.
	for identity in playback_watch.keys():
		if playback_watch[identity].get_ref()==null:playback_watch.erase(identity)
	return playback_watch.size()
func _stop_player(player:Node) -> void:
	_track_playback(player)
	player.stop()
func shutdown() -> void:
	initialized=false
	set_process(false)
	for entry in voices+ui_voices:
		if is_instance_valid(entry.player):
			_stop_player(entry.player);entry.player.stream=null;entry.player.queue_free()
	for entry in loops.values():
		if is_instance_valid(entry.player):
			_stop_player(entry.player);entry.player.stream=null;entry.player.queue_free()
	# 4.5.1 positional players can retain an unstarted private setplayback after
	# stop(). Permanently retired pools must destroy their nodes to release it.
	voices.clear();ui_voices.clear();loops.clear()
	streams.clear();dedup.clear();cooldowns.clear()
	if is_instance_valid(caption_label):caption_label.hide()
func shutdown_and_drain(timeout_seconds:float=1.5) -> bool:
	# Godot fades stopped playback on its audio thread, then retires it in a later
	# main-thread AudioServer update. Wait for observed playback refs, not a guessed
	# sleep duration; process frames also cover headless/background frame caps.
	shutdown()
	var deadline=Time.get_ticks_msec()+int(maxf(.1,timeout_seconds)*1000)
	await get_tree().process_frame
	await get_tree().process_frame
	while true:
		if pending_playback_count()==0:return true
		if Time.get_ticks_msec()>=deadline:
			push_error("Audio shutdown timed out with %d mixer playback references"%playback_watch.size())
			return false
		await get_tree().process_frame
	return false
func _exit_tree() -> void:shutdown()
