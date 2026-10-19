extends SceneTree
## Exercises real gameplay entry points using the platform runner's disposable userdata.
var played:Array=[]
var game:Node
func _initialize() -> void:call_deferred("run")
func collect(id:String,identity:String) -> void:played.append({"at_ms":Time.get_ticks_msec(),"event":id,"identity":identity})
func wait(seconds:float) -> void:await create_timer(seconds).timeout
func run() -> void:
	var output=ProjectSettings.globalize_path("res://../output/verification/audio-current")
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide();game._refresh_simulation()
	game.audio.event_played.connect(collect)
	var record=AudioEffectRecord.new();AudioServer.add_bus_effect(0,record);record.set_recording_active(true)
	await wait(.5)
	Input.action_press("move_up");await wait(1.6);Input.action_release("move_up")
	game.player.position=Vector3(34,0,0);game.player.position.y=game.current_world.ground_height(game.player.position)
	await wait(.2);Input.action_press("move_up");await wait(1.4);Input.action_release("move_up")
	game.player.begin_jump();await wait(1.)
	game.player.toggle_sword();await wait(.9)
	game.player.begin_attack("light");await wait(1.1)
	game.player.begin_attack("heavy");await wait(1.3)
	for item in ["field_spear","duelist_rapier","hunting_bow"]:
		game.player.state="free";game.player.restore_stamina(game.player.max_stamina)
		game.player.set_weapon_visual(item);game.player.set_sword_drawn(true)
		game.magic_items.quantities["wooden_arrows"]=3
		if "wooden_arrows" not in game.magic_items.owned:game.magic_items.owned.append("wooden_arrows")
		game.player.weapon_runtime.begin_primary();await wait(1.15 if item=="hunting_bow" else 1.)
		if item=="hunting_bow":game.player.weapon_runtime.release_primary();await wait(.8)
	game.player.state="free";game.player.set_weapon_visual("standard_greatsword");game.player.set_sword_drawn(true)
	game.player.take_damage(1,Vector3.BACK);await wait(.4)
	game.pause_menu.open();await wait(.4);game.pause_menu.close();await wait(.2)
	# Move to an authored wolf pack: its AI owns the tell rather than a direct sound call.
	game.player.position=Vector3(-63,0,-57);game.player.position.y=game.current_world.ground_height(game.player.position)
	await wait(2.)
	for enemy in game.enemies:
		if is_instance_valid(enemy) and enemy.health>0 and enemy.global_position.distance_to(game.player.global_position)<20:
			enemy.position=game.player.position+game.player.facing()*1.6;enemy.position.y=game.current_world.ground_height(enemy.position)
			game.player.state="free";game.player.begin_attack("light");break
	await wait(1.3)
	record.set_recording_active(false)
	var recording=record.get_recording()
	var result={"events":played,"stats":game.audio.stats.duplicate(),"recorded":recording!=null,"scope":"Real Floor One movement/jump/greatsword/new weapon/damage/menu/wolf entry points; headless audio mix, not human listening approval"}
	DirAccess.make_dir_recursive_absolute(output)
	if recording!=null:recording.save_to_wav(output.path_join("gameplay-audio.wav"))
	var file=FileAccess.open(output.path_join("gameplay-audio.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close()
	print("AUDIO_GAMEPLAY "+JSON.stringify({"event_count":played.size(),"stats":result.stats,"recorded":result.recorded}))
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	recording=null;record=null
	var drained=await game.audio.shutdown_and_drain()
	game.queue_free();await process_frame;await process_frame
	call_deferred("finish",0 if result.recorded and played.size()>8 and drained else 1)
func finish(code:int) -> void:quit(code)
