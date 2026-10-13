extends RefCounted
func picture(game:Control,path:String) -> void:
	await game.get_tree().create_timer(.6).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
func run(game:Control,directory:String) -> void:
	var path="user://title-capture.json"
	DirAccess.remove_absolute(path)
	game.title_screen.show_menu(path)
	await picture(game,directory+"/title-new-game.png")
	game.start_new_game(false)
	game.progression.restore({"tree_version":2,"xp":1000,"learned":[]})
	game.load_map("village_green",Vector2(0,3.5),true)
	game.Save.write(game.save_data(),path)
	game.title_screen.show_menu(path)
	await picture(game,directory+"/title-saved-game.png")
	game.title_screen.load_button.pressed.emit()
	await picture(game,directory+"/title-loaded-game.png")
	DirAccess.remove_absolute(path)
