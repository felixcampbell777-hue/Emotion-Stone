extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;await process_frame
	var ok=await load("res://scripts/swamp_review.gd").new().run(game)
	if game.audio!=null:
		var drained=await game.audio.shutdown_and_drain()
		ok=ok and drained
	quit(0 if ok else 1)
