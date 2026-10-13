extends SceneTree
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_new_game(false)
	var test=load("res://scripts/verification.gd").new()
	test.game=game
	await load("res://scripts/combo_motion_checks.gd").new().run(test)
	await load("res://scripts/thrust_checks.gd").new().run(test)
	await load("res://scripts/animation_checks.gd").new().run(test)
	print("FOCUSED_COMBAT ",test.checks.size()," checks; ",test.failures)
	quit(0 if test.failures.is_empty() else 1)
