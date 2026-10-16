extends RefCounted
func run(game:Control,source:bool=false) -> void:
	game.get_window().size=Vector2i(1280,720)
	var test=load("res://scripts/verification.gd").new();test.game=game
	await load("res://scripts/alpha2_checks.gd").new().run(test)
	await load("res://scripts/dreadmore_checks.gd").new().run(test)
	var args=OS.get_cmdline_user_args();var path="res://../output/verification/alpha2-source-report.json" if source else "res://../output/verification/export-integration-report.json"
	if "--report" in args: path=args[args.find("--report")+1]
	var report={"passed":test.failures.is_empty(),"suite":"alpha2","reused_animation_baseline":"0.31.10","check_count":test.checks.size(),"checks":test.checks,"failures":test.failures}
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("VERIFICATION_PASS " if test.failures.is_empty() else "VERIFICATION_FAIL ",test.checks.size()," checks (Alpha 2 campaign, import, saves, boss and legacy modes)")
	game.get_tree().quit(0 if test.failures.is_empty() else 1)
