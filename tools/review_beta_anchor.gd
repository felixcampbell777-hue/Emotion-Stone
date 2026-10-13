extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame;game.game_mode="beta";game.start_new_game(false)
	game.gallery_mode=true;game.set_process(false)
	for enemy in game.enemies:enemy.visible=false;enemy.ai_enabled=false
	var dir="C:/Games/CoastalFoundation/art/character/back-anchor-review";DirAccess.make_dir_recursive_absolute(dir)
	await load("res://scripts/beta_anchor_capture.gd").new().run(game,dir)
	quit()
