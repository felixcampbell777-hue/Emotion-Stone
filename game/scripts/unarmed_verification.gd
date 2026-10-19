extends RefCounted
func run(game:Control,source:bool=false) -> void:
	game.start_new_game(false)
	game.get_window().size=Vector2i(1280,720)
	await game.get_tree().physics_frame
	var test=load("res://scripts/verification.gd").new();test.game=game
	load("res://scripts/locomotion_phase_checks.gd").new().run(test)
	load("res://scripts/swing_sampler_checks.gd").new().run(test)
	await load("res://scripts/unarmed_checks.gd").new().run(test)
	await load("res://scripts/grip_checks.gd").new().run(test)
	load("res://scripts/motion_contact_checks.gd").new().run(test)
	await load("res://scripts/motion_input_checks.gd").new().run(test)
	if game.audio!=null and game.audio.has_method("shutdown"):
		game.audio.shutdown();await game.get_tree().create_timer(.15).timeout
	var args=OS.get_cmdline_user_args();var path="res://../output/verification/unarmed-source-report.json" if source else "res://../output/verification/export-integration-report.json"
	if "--report" in args: path=args[args.find("--report")+1]
	var report={"passed":test.failures.is_empty(),"suite":"unarmed","reused_full_baseline":"0.31.9","check_count":test.checks.size(),"checks":test.checks,"failures":test.failures}
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"	"));file.close()
	print("VERIFICATION_PASS " if test.failures.is_empty() else "VERIFICATION_FAIL ",test.checks.size()," checks (visible hands and sword grip)")
	game.get_tree().quit(0 if test.failures.is_empty() else 1)
