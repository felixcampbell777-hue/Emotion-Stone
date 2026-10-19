extends SceneTree
## Real authored Floor Two/Vault transitions; run only with isolated platform userdata.
var game:Node
var played:Array=[]
func _initialize() -> void:call_deferred("run")
func collect(id:String,identity:String) -> void:played.append({"at_ms":Time.get_ticks_msec(),"event":id,"identity":identity})
func wait(seconds:float) -> void:await create_timer(seconds).timeout
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;await process_frame
	game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide();game._refresh_simulation()
	game.audio.event_played.connect(collect)
	game.player.max_health=10000;game.player.health=10000
	var record=AudioEffectRecord.new();AudioServer.add_bus_effect(0,record);record.set_recording_active(true)
	var fen=load("res://scripts/swamp_shape.gd")
	var entry:Dictionary=fen.spec.enemies.filter(func(e):return e.style=="giant_green_slime")[0]
	game.load_map("wr_floor_02",Vector2(entry.at[0]+4,entry.at[1]),true);game._refresh_simulation()
	await wait(3.6)
	var giant=game.worldrise.swamp.live.get(entry.id)
	if is_instance_valid(giant):giant.take_damage(10000,Vector3.BACK)
	await wait(2.4)
	var found=false
	for x in range(-15,16):
		if found:break
		for z in range(-15,16):
			var p=Vector3(float(entry.at[0])+x,0,float(entry.at[1])+z)
			if fen.depth(p)>.10 and fen.depth(p)<.24:
				game.player.position=p;game.player.position.y=game.current_world.ground_height(p);found=true;break
	Input.action_press("move_up");await wait(1.6);Input.action_release("move_up")
	game.load_map("wr_boss_chamber",Vector2(0,36),true);game._refresh_simulation()
	await wait(.25)
	game.player.position=Vector3(0,0,-1)
	await wait(5.5)
	if is_instance_valid(game.current_world.boss):game.current_world.boss.take_damage(10000,Vector3.BACK)
	await wait(1.3)
	record.set_recording_active(false)
	var recording=record.get_recording()
	var output=ProjectSettings.globalize_path("res://../output/verification/audio-current");DirAccess.make_dir_recursive_absolute(output)
	if recording!=null:recording.save_to_wav(output.path_join("world-audio.wav"))
	var result={"events":played,"stats":game.audio.stats.duplicate(),"recorded":recording!=null,"scope":"Actual Floor Two giant leap/landing/split/greens and shallow-water movement; actual Vault formation/tell/death; fixture-only high HP and scripted damage"}
	var file=FileAccess.open(output.path_join("world-audio.json"),FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(result,"  ")+"\n");file.close()
	print("AUDIO_WORLD "+JSON.stringify({"event_count":played.size(),"stats":result.stats,"recorded":result.recorded}))
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1);recording=null;record=null
	var drained=await game.audio.shutdown_and_drain()
	game.queue_free();await process_frame;await process_frame
	call_deferred("finish",0 if result.recorded and played.size()>5 and drained else 1)
func finish(code:int) -> void:quit(code)
