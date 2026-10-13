extends RefCounted
func run(test:RefCounted) -> void:
	var game=test.game
	game.start_new_game(false); game.load_map("coastal_path",Vector2(0,3),true)
	for enemy in game.enemies: enemy.ai_enabled=false
	var rig=game.player.skeleton;var animation=game.player.animator.get_animation(game.player.clips.walk_loop)
	var stats=Vector3(game.player.max_health,game.player.max_stamina,game.player.walk_speed)
	game.set_character_profile("standalone")
	var model=game.player.get_node("StandaloneHero")
	test.check(model.find_children("*","Skeleton3D",true,false).is_empty() and model.find_children("*","AnimationPlayer",true,false).is_empty(),"Standalone model has no skeleton, skins or animation clock")
	var pose=[]
	for mesh in model.find_children("*","MeshInstance3D",true,false): pose.append(mesh.transform)
	var box=game.StandaloneHero.bounds(model)
	test.check(absf(box.size.y-1.67)<.025 and absf(box.position.y)<.015,"Standalone height is 1.67m and boots touch ground")
	test.check(box.size.y<2.24,"Standalone fits existing 2.24m door height")
	game._refresh_simulation();var origin=game.player.position
	Input.action_press("move_right");await test.frames(15);Input.action_release("move_right")
	test.check(game.player.position.distance_to(origin)>.4 and not game.player.visual.visible,"Standalone moves for scale inspection without duplicate animated body")
	var i=0
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		test.check(mesh.transform.is_equal_approx(pose[i]),"Static mesh pose stays fixed: "+String(mesh.name));i+=1
	test.check(game.player.skeleton==rig and game.player.animator.get_animation(game.player.clips.walk_loop)==animation and stats.is_equal_approx(Vector3(game.player.max_health,game.player.max_stamina,game.player.walk_speed)),"Standalone leaves gameplay rig, resources and stats intact")
	game.toggle_pause();var at=game.player.position
	Input.action_press("move_down");await test.frames(5);Input.action_release("move_down")
	test.check(game.player.position.is_equal_approx(at),"Pause still gates movement in standalone")
	game.pause_menu.close()
	var save=game.save_data();var path="user://standalone-verification.json"
	game.Save.write(save,path);game.set_character_profile("game")
	test.check(game.apply_save(game.Save.read(path)) and game.character_profile=="standalone" and game.player.has_node("StandaloneHero"),"Standalone choice survives private save/load and map replacement")
	game.toggle_inventory();game.inventory.show_page("equipment");game.inventory.preview.refresh(game)
	test.check(game.inventory.preview.actor.has_node("StandaloneHero") and not game.inventory.preview.actor.visual.visible,"Inventory preview shows standalone without duplicate body or sword")
	game.inventory.close()
	var bad=save.duplicate(true);bad.character_profile="bad";game.Save.write(bad,path)
	test.check(game.Save.read(path).is_empty() and not game.apply_save(bad),"Unknown character profile rejected")
	var legacy=save.duplicate(true);legacy.erase("character_profile")
	test.check(game.apply_save(legacy) and game.character_profile=="game" and game.player.visual.visible and not game.player.has_node("StandaloneHero"),"Legacy save restores animated game presentation")
	game.set_environment_profile("darkwood");game.set_character_profile("standalone")
	game.set_environment_profile("original")
	test.check(game.player.has_node("StandaloneHero") and game.player.visual.visible==(game.camera_mode=="first_person"),"Standalone selection survives world-art switch with the active camera's body layers")
	game.camera_driver.set_mode("first_person")
	test.check(game.player.visual.visible and (game.camera.cull_mask&game.camera_driver.visuals.BODY_LAYER)==0,"Static review first-person camera hides its fixed body and shows the gameplay arms/steel")
	game.set_character_profile("game"); game.set_character_profile("standalone")
	test.check(game.player.visual.visible and game.player.has_node("StandaloneHero"),"First-person presentation survives character profile switching")
	game.camera_driver.set_mode("overhead")
	test.check(not game.player.visual.visible,"Leaving first person restores the standalone fixed-pose presentation")
	game.set_character_profile("game")
	test.check(game.player.visual.visible and game.player.clips.size()==19,"Switching back preserves all nineteen game animation clips")
	DirAccess.remove_absolute(path)
