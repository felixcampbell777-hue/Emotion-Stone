extends SceneTree
## Run from the exported World Rise client without --verify, in isolated userdata.
var failures:Array=[]
var checks=0
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	check(OS.has_feature("world_rise_client"),"Dedicated downloadable client identifies its scoped export feature")
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	check(game.game_mode=="world_rise" and game.default_title_mode()=="world_rise","Exported client selects World Rise by default")
	check(game.title_screen.visible,"Exported client waits on title instead of auto-starting gameplay")
	check(game.title_screen.mode_choice.selected==3,"Visible title selection matches World Rise")
	check(game.title_screen.mode_choice.item_count==4,"All legacy campaign choices remain available")
	check(not FileAccess.file_exists("user://world-rise-save-v1.json"),"Opening exported title does not create a player save")
	if game.audio!=null:check(await game.audio.shutdown_and_drain(),"Exported title fixture drains audio")
	print("EXPORT_TITLE_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
	game.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
