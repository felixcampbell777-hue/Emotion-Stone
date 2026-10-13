extends SceneTree
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame; await process_frame
	var test=load("res://scripts/verification.gd").new(); test.game=game
	await load("res://scripts/magic_item_checks.gd").new().run(test)
	await load("res://scripts/equipment_clearance_checks.gd").new().run(test)
	await load("res://scripts/hud_healing_checks.gd").new().run(test)
	print("MAGIC_CHECKS ",test.checks.size()," checks; ",test.failures)
	quit(0 if test.failures.is_empty() else 1)
