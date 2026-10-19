extends SceneTree
## Standalone presentation fixture; does not instantiate production saves or actors.
class TestActor extends Node3D:
	var input_enabled=true
	var health=100
	var jump_active=false
	var state="free"
	var sprinting=false
	func simulation_active() -> bool:return input_enabled
class TestRise extends RefCounted:
	func is_night() -> bool:return false
class TestGame extends Node3D:
	var game_mode="world_rise"
	var map_id="audio_fixture"
	var world_root:Node3D
	var world_view:SubViewport
	var current_world:Node3D
	var camera:Camera3D
	var player:Node3D
	var title_screen:Control
	var worldrise=TestRise.new()
	var enemies=[]
	var online=false
	func online_session_active() -> bool:return online
var failures:Array=[]
var checks=0
func check(condition:bool,label:String) -> void:
	checks+=1
	if not condition:failures.append(label);push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=TestGame.new();root.add_child(game)
	game.world_view=SubViewport.new();game.world_view.own_world_3d=true;game.add_child(game.world_view)
	game.world_root=Node3D.new();game.world_view.add_child(game.world_root)
	game.current_world=Node3D.new();game.world_root.add_child(game.current_world)
	game.player=TestActor.new();game.world_root.add_child(game.player)
	game.camera=Camera3D.new();game.world_root.add_child(game.camera);game.camera.make_current()
	game.title_screen=Control.new();game.add_child(game.title_screen);game.title_screen.hide()
	var director=load("res://scripts/audio/audio_director.gd").new();game.add_child(director);director.configure(game)
	director.set_process(false)
	check(director.loops.size()==8,"loop crossfade pool bounded")
	check(director.voices[0].player.get_viewport()==game.world_view,"emitters share camera SubViewport")
	check(game.world_view.audio_listener_enable_3d,"gameplay SubViewport listener enabled")
	for id in director.events:
		var item:Dictionary=director.events[id]
		check(AudioServer.get_bus_index(item.bus)>=0,"bus "+id)
		for path in item.clips:
			var stream=load(path)
			check(stream is AudioStream and stream.get_length()>0,"audible stream "+path)
	var context={"actor_id":"fixture","action_id":"attack1","event_index":0}
	check(director.play("combat.parry",Vector3.ZERO,context),"first event plays")
	check(not director.play("combat.parry",Vector3.ZERO,context),"confirmed duplicate suppressed")
	check(director.play("combat.hit.flesh",Vector3.ZERO,{"actor_id":"fixture","action_id":"sweep","target_id":"wolf1"}),"first sweep target plays")
	check(director.play("combat.hit.flesh",Vector3.ZERO,{"actor_id":"fixture","action_id":"sweep","target_id":"wolf2"}),"separate sweep target plays")
	check(not director.play("player.hurt",Vector3.ZERO,{"historical":true}),"historical result suppressed")
	check(not director.play("player.hurt",Vector3.ZERO,{"world_generation":-1}),"old world suppressed")
	check(not director.play("enemy.wolf.tell",Vector3(1000,0,0)),"distant source culled")
	game.player.input_enabled=false;director._sync_pause()
	check(director.paused,"offline overlay freezes world audio")
	check(not director.play("player.hurt"),"paused gameplay event suppressed")
	check(director.play("ui.confirm"),"UI audible while paused")
	game.online=true;director._sync_pause()
	check(not director.paused,"online menu keeps shared-world audio")
	game.player.input_enabled=true;game.online=false;director._sync_pause()
	for i in range(80):director.play("combat.hit.stone",Vector3.ZERO,{"actor_id":"mob"+str(i),"action_id":str(i)})
	check(director.voices.size()==32,"world pool bounded")
	check(director.stats.peak_world<=32,"world voice cap obeyed")
	check(director.play("player.hurt",Vector3.ZERO,{"actor_id":"priority_fixture"}),"critical damage preempts lower priority")
	check(not director.play("enemy.step.grass",Vector3.ZERO,{"actor_id":"quiet_fixture"}),"footsteps cannot steal active combat cues")
	director.reset_world()
	var all_stopped=true
	for entry in director.voices:
		if entry.player.playing:all_stopped=false
	check(all_stopped and director.dedup.is_empty(),"world reset retires voices and dedup")
	var record=AudioEffectRecord.new()
	AudioServer.add_bus_effect(0,record)
	record.set_recording_active(true)
	director.set_process(true)
	director.set_voice_activity(true);director._process(.6)
	check(director.duck<1.0,"voice activity ducks game beds")
	director.set_voice_activity(false)
	var sequence=["player.step.grass","player.step.stone","player.step.wood","player.step.metal","player.step.water","player.draw","combat.swing.light","combat.hit.flesh","combat.parry","enemy.wolf.tell","enemy.slime.tell","enemy.giant_slime.split","enemy.elder.tell","enemy.elder.slam","weapon.spear.thrust","weapon.rapier.thrust","weapon.bow.draw","weapon.bow.release","projectile.impact.wood","world.rest"]
	for id in sequence:
		director.play(id,Vector3(0,0,-3),{"actor_id":"montage","action_id":id})
		await create_timer(.55).timeout
	# Deliberately saturate the bounded pool: the master limiter must retain headroom.
	for i in range(32):director.play("enemy.elder.slam",Vector3(0,0,-1),{"actor_id":"stress"+str(i),"action_id":"stress"})
	await create_timer(1.).timeout
	record.set_recording_active(false)
	var recording=record.get_recording()
	var output=OS.get_environment("WORLD_RISE_AUDIO_EVIDENCE")
	if output.is_empty():output=ProjectSettings.globalize_path("res://../output/verification/audio-current")
	DirAccess.make_dir_recursive_absolute(output)
	DirAccess.make_dir_recursive_absolute(output)
	if recording!=null:
		check(recording.data.size()>0,"mixed output recorded")
		recording.save_to_wav(output.path_join("audio-montage.wav"))
	else:check(false,"mixed output recorded")
	check(await director.shutdown_and_drain(),"Mixer refs drain before game destruction")
	var result={"checks":checks,"failures":failures,"events":director.events.size(),"stats":director.stats,"recorded":recording!=null}
	var file=FileAccess.open(output.path_join("audio-checks.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n")
	print("AUDIO_CHECKS "+JSON.stringify(result))
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	recording=null;record=null
	game.queue_free();director=null;await process_frame;await process_frame
	call_deferred("finish",0 if failures.is_empty() else 1)
func finish(code:int) -> void:quit(code)
