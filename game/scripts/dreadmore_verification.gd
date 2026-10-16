extends RefCounted
func run(game:Control,source:bool=false) -> void:
	var test=load("res://scripts/verification.gd").new();test.game=game
	await load("res://scripts/dreadmore_checks.gd").new().run(test)
	var args=OS.get_cmdline_user_args();var path="res://../output/verification/dreadmore-source-report.json" if source else "res://../output/verification/export-integration-report.json"
	if "--report" in args:path=args[args.find("--report")+1]
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify({"passed":test.failures.is_empty(),"suite":"dreadmore","check_count":test.checks.size(),"checks":test.checks,"failures":test.failures},"\t"));file.close()
	print("VERIFICATION_PASS " if test.failures.is_empty() else "VERIFICATION_FAIL ",test.checks.size()," checks (Dreadmore terrain, ambushes, Fiend, grove and saves)")
	game.get_tree().quit(0 if test.failures.is_empty() else 1)
