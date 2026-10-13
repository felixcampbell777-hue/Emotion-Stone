extends RefCounted
func picture(game: Control, path: String, world_only: bool=false) -> void:
	await game.get_tree().create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	var viewport=game.world_view if world_only else game.get_viewport()
	viewport.get_texture().get_image().save_png(path)

func run(game: Control, directory: String) -> void:
	game.set_resolution(0)
	game.load_map("coastal_path",Vector2(0,3.5))
	await picture(game,directory+"/full-resolution-v9.png")
	await picture(game,directory+"/full-resolution-world-v9.png",true)
	game.gallery_mode=true
	game.current_world.visible=false
	for npc in game.npcs:
		npc.visible=false
	game.player.position=Vector3(.75,0,0)
	game.camera.size=3.2
	game.camera_offset=Vector3(0,4,13)
	for item in [{"name":"front","angle":0},{"name":"side","angle":PI/2},{"name":"back","angle":PI},{"name":"three-quarter","angle":PI*.8}]:
		game.player.visual.rotation.y=item.angle
		await picture(game,directory+"/sword-back-v9-"+item.name+".png",true)
	var metrics={"preset":game.graphics_preset,"viewport":[game.world_view.size.x,game.world_view.size.y],"window":[game.get_viewport_rect().size.x,game.get_viewport_rect().size.y],"msaa":8,"camera_pixel_snapping":false}
	var file=FileAccess.open(directory+"/full-resolution-v9.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t"))
