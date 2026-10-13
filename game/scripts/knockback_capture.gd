extends RefCounted
func picture(game:Control,path:String,delay:float=.1) -> void:
	await game.get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(path)
func run(game:Control,directory:String) -> void:
	game.camera_driver.set_mode("overhead")
	game.defeated_enemies.clear()
	for specimen in ["slime","boar","warden"]:
		game.load_map("slime_forest" if specimen=="slime" else "herb_glade",Vector2(0,2),true)
		for other in game.enemies: other.ai_enabled=false
		var target=game.enemies[0] if specimen!="warden" else game.enemies[2]
		target.position=Vector3(0,0,3.5)
		target.health=999
		target.max_health=999
		game.player.restore_stamina(100)
		game.player.set_sword_drawn(true)
		game.player.visual.rotation.y=0
		if specimen=="warden":
			target.armor_open=0
			game.player.state="heavy"
			game._attack_contact("heavy",Vector3(0,0,1),{})
			await picture(game,directory+"/recoil-warden-armored.png",.2)
			target.armor_open=5
			game.player.set_sword_drawn(true)
		await picture(game,directory+"/recoil-"+specimen+"-before.png",.3)
		game.player.begin_attack("heavy")
		await picture(game,directory+"/recoil-"+specimen+"-impact.png",1.58)
		await picture(game,directory+"/recoil-"+specimen+"-after.png",.4)
