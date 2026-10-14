extends RefCounted
func run(game:Control,directory:String) -> void:
	game.game_mode="alpha";game.start_new_game(false);game.load_map("coastal_path",Vector2(0,-5),true);game.set_resolution(0);game.camera_driver.set_mode("first_person")
	game.progression.restore({"tree_version":3,"xp":957383,"learned":["form","dash","mana","flowing_splash"],"passives":["flowing_splash"]});game.apply_skill_stats();game.update_progression_ui();game.player.dash_equipped=true
	for enemy in game.enemies: enemy.ai_enabled=false;enemy.position.x+=25
	await load("res://scripts/dash_attack_capture.gd").new().run(game,directory,false)
	await load("res://scripts/dash_attack_capture.gd").new().run(game,directory,true)
