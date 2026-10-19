extends SceneTree
## Real main-scene playback lifecycle; --floors additionally repeats both authored floors.
var checks=0
var failures:Array=[]
var observations:Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame;await create_timer(.25).timeout
	var audio=game.audio
	check(audio.initialized,"Main scene initializes audio")
	check(audio.loops.music_a.player.playing or audio.loops.music_b.player.playing,"Actual title music is active before teardown")
	var identities=[]
	for entry in audio.voices+audio.ui_voices+audio.loops.values():identities.append(entry.player.get_instance_id())
	if "--floors" in OS.get_cmdline_user_args():
		game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide();game._refresh_simulation()
		for cycle in range(3):
			for floor_id in ["wr_floor_02","wr_floor_01"]:
				var at=load("res://scripts/swamp_shape.gd").arrival() if floor_id=="wr_floor_02" else Vector2.ZERO
				game.load_map(floor_id,at,true);await create_timer(.25).timeout
				audio.play("combat.parry",game.player.global_position,{"actor_id":"lifecycle","action_id":str(cycle)+floor_id})
				var current=[]
				for entry in audio.voices+audio.ui_voices+audio.loops.values():current.append(entry.player.get_instance_id())
				check(current==identities,"Floor transition reuses the same bounded emitter nodes "+str(cycle)+floor_id)
				var parents_ok=true
				for entry in audio.voices:
					if entry.player.get_parent()!=game.world_root:parents_ok=false
				check(parents_ok,"World emitters retain persistent gameplay parent "+floor_id)
				check(audio.streams.size()<=119,"Stream cache remains bounded by curated catalog "+floor_id)
				observations.append({"floor":floor_id,"cached_streams":audio.streams.size(),"pending_playbacks":audio.playback_watch.size(),"emitter_nodes":current.size()})
	var retired=[]
	for entry in audio.voices+audio.ui_voices+audio.loops.values():retired.append(weakref(entry.player))
	var drained=await audio.shutdown_and_drain()
	check(drained,"Mixer actually releases every observed playback before quit")
	check(audio.streams.is_empty() and audio.playback_watch.is_empty(),"Shutdown releases stream cache and retired playback observations")
	check(not audio.play("ui.confirm"),"Shutdown rejects new presentation events")
	var streams_clear=true
	for entry in audio.voices+audio.ui_voices+audio.loops.values():
		if entry.player.stream!=null:streams_clear=false
	check(streams_clear,"All emitter stream references are cleared")
	game.queue_free();audio=null;game=null
	await process_frame;await process_frame
	var nodes_freed=true
	for observer in retired:
		if observer.get_ref()!=null:nodes_freed=false
	check(nodes_freed,"Destroying the game frees positional, UI, and loop emitter nodes")
	var result={"checks":checks,"failures":failures,"floor_cycles":observations,"drained":drained}
	var output=ProjectSettings.globalize_path("res://../output/verification/audio-current");DirAccess.make_dir_recursive_absolute(output)
	var filename="audio-floor-lifecycle.json" if "--floors" in OS.get_cmdline_user_args() else "audio-startup-lifecycle.json"
	var file=FileAccess.open(output.path_join(filename),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close()
	print("AUDIO_LIFECYCLE "+JSON.stringify(result))
	call_deferred("finish",0 if failures.is_empty() else 1)
func finish(code:int) -> void:quit(code)
