extends RefCounted
func run(game:Control,source:bool=false) -> void:
	game.start_new_game(false)
	game.get_window().size=Vector2i(1280,720)
	await game.get_tree().physics_frame
	var test=load("res://scripts/verification.gd").new();test.game=game
	await load("res://scripts/dash_attack_checks.gd").new().run(test)
	await load("res://scripts/mana_dash_checks.gd").new().run(test)
	await load("res://scripts/uppercut_checks.gd").new().run(test)
	var args=OS.get_cmdline_user_args();var path="res://../output/verification/dash-uppercut-source-report.json" if source else "res://../output/verification/export-integration-report.json"
	if "--report" in args: path=args[args.find("--report")+1]
	var report={"passed":test.failures.is_empty(),"suite":"dash-uppercut","reused_full_baseline":"0.31.8","check_count":test.checks.size(),"checks":test.checks,"failures":test.failures}
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"	"));file.close()
	print("VERIFICATION_PASS " if test.failures.is_empty() else "VERIFICATION_FAIL ",test.checks.size()," checks (dash uppercut only)")
	game.get_tree().quit(0 if test.failures.is_empty() else 1)
