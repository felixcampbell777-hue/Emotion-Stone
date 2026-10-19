extends SceneTree
## Native, disposable-userdata screenshots of the production three-branch menu.
var game:Node
var failures:Array=[]
func _initialize() -> void:call_deferred("run")
func capture(name:String,require_first_card:bool=true) -> void:
	for frame in range(6):await process_frame
	var menu=game.skill_tree.rise_menu
	if menu.scroll.position.y<menu.categories.position.y+menu.categories.size.y:failures.append("Attribute buttons overlap scrolling content")
	if require_first_card and menu.grid.get_child_count()>0:
		var first_card=menu.grid.get_child(0)
		if not menu.scroll.get_global_rect().encloses(first_card.get_global_rect()):
			failures.append(name+": first complete perk card must fit without scrolling")
			print("PERK_LAYOUT_DIAGNOSTIC ",name," ",menu.scroll.get_global_rect()," ",first_card.get_global_rect())
	await RenderingServer.frame_post_draw
	var directory=ProjectSettings.globalize_path("res://../output/verification/current-render/progression")
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_png(directory.path_join(name+".png"))
func run() -> void:
	root.size=Vector2i(1366,768)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide()
	game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
	for enemy in game.enemies:enemy.set_physics_process(false);enemy.ai_enabled=false
	game.progression.xp=8200
	for index in range(6):game.progression.increase_attribute("strength")
	game.progression.learn("iron_body");game.progression.learn("honed_arms");game.progression.award_practice("greatsword",49)
	game.apply_skill_stats();game.update_progression_ui();game.toggle_inventory();game.inventory.show_page("level")
	var menu=game.skill_tree.rise_menu
	menu.selected="strength";menu.refresh();await capture("strength-1366x768")
	menu.selected="greatsword";menu.refresh();await capture("greatsword-1366x768")
	menu.practice_expanded=true;menu.refresh();await capture("practice-expanded-1366x768",false)
	menu.practice_expanded=false
	root.size=Vector2i(960,540);menu.selected="strength";menu.refresh();menu.scroll.scroll_vertical=0
	await capture("strength-960x540")
	menu.selected="agility";menu.refresh();menu.scroll.scroll_vertical=0
	await capture("agility-960x540")
	menu.reset_confirm=true;menu.refresh();await process_frame;menu.scroll.scroll_vertical=100000
	await capture("reset-960x540",false)
	if game.voice!=null:await game.voice.shutdown_and_drain()
	if game.audio!=null:await game.audio.shutdown_and_drain()
	print("CAPTURE_OK tree6 native production menus 1366x768 and 960x540 ",JSON.stringify({"failures":failures}))
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
