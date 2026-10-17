extends RefCounted
func run(test: RefCounted) -> void:
	var game=test.game
	game.load_map("coastal_path",Vector2(0,3))
	game.player.set_sword_drawn(false)
	game.set_resolution(0)
	await test.frames(2)
	var available=game.get_viewport_rect().size
	var scale=minf(available.x/16,available.y/9)
	test.check(game.world_view.size==Vector2i(floori(scale*16),floori(scale*9)),"Full resolution renders at the available window size rather than a pixel preset")
	test.check(game.world_view.msaa_3d==int(game.render_budget.profile().msaa) and game.image_view.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR,"Full resolution uses selected budget AA and smooth presentation")
	test.check(game.view_button.text=="Full resolution" and game.save_data().resolution==0,"Full graphics uses a stable preset ID independent of display resolution")
	var path="user://full-graphics-verification.json"
	game.Save.write(game.save_data(),path)
	var saved=game.Save.read(path)
	game.set_resolution(320)
	test.check(not saved.is_empty() and game.apply_save(saved) and game.graphics_preset==0,"Full resolution survives save validation and load")
	var expected=[640,320,960,0]
	var correct=true
	for preset in expected:
		game.toggle_resolution()
		correct=correct and game.graphics_preset==preset
	test.check(correct,"Graphics button cycles Full, Fine, Chunky and Detailed presets")
	test.check(not game.has_node("Controls") and not game.get("controls") and game.help_panel.get_child(0).get_child(1).text.contains("WASD"),"Permanent bottom instructions are removed; controls remain available in Help")
	# Retired overhead viewport-footprint checks are no longer part of gameplay QA.
	game.player.visual.rotation.y=0
	await test.frames(2)
	var equipment=game.player.equipment
	var blade=equipment.find_child("SwordBlade",true,false)
	var gem=equipment.find_child("SwordBlueGem",true,false)
	var blade_at=game.player.visual.global_transform.affine_inverse()*(blade.global_transform*blade.get_aabb().get_center())
	var gem_at=game.player.visual.global_transform.affine_inverse()*(gem.global_transform*gem.get_aabb().get_center())
	test.check(blade_at.z<-.15 and gem_at.y>blade_at.y and absf(gem_at.x-blade_at.x)>.5 and game.player.sword_tip().y>.02,"Back-mounted blade lies diagonally behind the body with a raised hilt and ground clearance")
	game.player.set_sword_drawn(true)
	await test.frames(2)
	test.check(game.player.equipment.get_parent()==game.player.visual and absf(game.player.sword_tip().y)<.09,"Revised back mounting preserves drawn sword placement")
	game.player.set_sword_drawn(false)
	DirAccess.remove_absolute(path)
	game.set_resolution(960)
