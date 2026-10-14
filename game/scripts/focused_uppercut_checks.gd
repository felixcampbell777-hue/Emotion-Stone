extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;await process_frame
	await load("res://scripts/uppercut_verification.gd").new().run(game,true)
