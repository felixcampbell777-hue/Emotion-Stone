extends SceneTree
## Focused native tree6 acceptance; all userdata is supplied by the isolated harness.
var game:Node
var failures:Array=[]
var checks=0
func _initialize() -> void:call_deferred("run")
func check(value:bool,message:String) -> void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	game.get_window().size=Vector2i(1280,720)
	await load("res://scripts/world_rise_stat_checks.gd").new().run(self)
	if game.audio!=null:check(await game.audio.shutdown_and_drain(),"Focused progression fixture drains audio before exit")
	print("WORLD_RISE_PROGRESSION_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
	game.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
