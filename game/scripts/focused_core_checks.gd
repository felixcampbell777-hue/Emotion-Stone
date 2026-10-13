extends SceneTree
func _initialize() -> void: call_deferred("run_checks")
func run_checks() -> void:
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); await process_frame; await process_frame
	var test=load("res://scripts/verification.gd").new(); test.game=game
	await load("res://scripts/core_checks.gd").new().run(test)
	print("CORE_CHECKS ",test.checks.size()," checks; ",test.failures)
	quit(0 if test.failures.is_empty() else 1)
