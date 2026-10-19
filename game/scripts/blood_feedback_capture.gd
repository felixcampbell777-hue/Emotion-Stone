extends SceneTree
## Real offline Actor hurt with the release-active Main presentation hooks.
var failures:Array=[]
func _initialize() -> void:call_deferred("run")
func require(ok:bool,label:String) -> void:
	if not ok:failures.append(label);push_error(label)
func capture(name:String) -> void:
	await RenderingServer.frame_post_draw
	var directory=ProjectSettings.globalize_path("res://../output/verification/current-render/blood")
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_png(directory.path_join(name+".png"))
func run() -> void:
	root.size=Vector2i(1366,768)
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide()
	game.blood.level="full";game.blood.clear_feedback()
	for enemy in game.enemies:enemy.set_physics_process(false);enemy.ai_enabled=false
	game.camera_driver.set_mode("first_person")
	for index in range(5):await physics_frame
	game.player.invulnerability=0
	require(game.player.take_damage(12,Vector3.ZERO),"Actual offline Actor accepts first-person hurt")
	require(game.blood.vignette_remaining>0,"Production Main routes accepted hurt into blood module")
	require(game.hud_feedback.damage_flash_remaining==0,"World Rise suppresses the old duplicate flash")
	game.blood.set_process(false)
	await capture("first-person-hurt")
	game.blood.clear_feedback();game.camera_driver.set_mode("third_person")
	for index in range(12):await physics_frame
	game.player.invulnerability=0
	require(game.player.take_damage(12,Vector3.ZERO),"Actual offline Actor accepts third-person hurt")
	require(game.blood.overlay.visible and game.world_root.get_node_or_null("HumanHitSplashes")==null,"Third-person hurt uses only the screen vignette with no world blood")
	game.blood._process(.06);game.blood.set_process(false)
	await capture("third-person-hurt")
	game.blood.set_level("off");game.player.invulnerability=0;game.player.take_damage(12,Vector3.ZERO)
	require(not game.blood.overlay.visible,"Off preference suppresses actual gameplay hurt feedback")
	game.settings_menu.open();await process_frame
	game.settings_menu.content_scroll.scroll_vertical=10000;await process_frame
	await capture("blood-settings")
	if game.voice!=null:await game.voice.shutdown_and_drain()
	if game.audio!=null:await game.audio.shutdown_and_drain()
	print("VERIFICATION_BLOOD_GAMEPLAY_CHECKS "+JSON.stringify({"checks":6,"failures":failures}))
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
