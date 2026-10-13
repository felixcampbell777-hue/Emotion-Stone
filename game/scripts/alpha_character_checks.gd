extends RefCounted
func run(test:RefCounted) -> void:
	var game=test.game
	game.game_mode="alpha";game.character_profile="game";game.environment_profile="original"
	game.start_new_game(false);game.load_map("village_green",Vector2(0,3),true)
	game.gain_xp(200);game.quest_stage="active"
	var xp=game.progression.xp;var speed=game.player.walk_speed;var damage=game.player.combat.light.damage;var cost=game.player.combat.light.stamina_cost
	game.set_environment_profile("darkwood");await test.frames(3)
	test.check(game.player.has_node("BetaHero") and not game.player.has_node("StandaloneHero") and not game.player.visual.visible,"Advanced Alpha selects the animated personal heroine by default")
	test.check(game.camera_mode=="first_person" and game.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Selecting Advanced Alpha enables first person")
	test.check(game.player.equipment.get_meta("beta_sword",false) and game.player.walk_speed==speed and game.quest_stage=="active" and game.progression.xp==xp and game.player.combat.light.damage==damage and game.player.combat.light.stamina_cost==cost,"Advanced Alpha equips the war sword while preserving speed, combat costs, XP and quest progress")
	var hero=game.player.get_node("BetaHero")
	var hands=game.camera_driver.visuals
	var arms=hands.rig.find_children("*","MeshInstance3D",true,false).filter(func(m):return m.has_meta("first_person_arms"))
	test.check(not arms.is_empty() and hands.source_rig==hero.rig and (game.camera.cull_mask&hands.BODY_LAYER)==0,"First person derives its view arms from the personal heroine's current skin and hides her head")
	game.player.set_sword_drawn(true);game.player.restore_stamina(100);game.player.begin_parry();await test.frames(3)
	test.check(game.player.state=="parry" and hero.sword.visible,"Personal Alpha arms follow the existing parry and equipped sword")
	game.toggle_pause();var clock=game.player.state_time;await test.frames(4)
	test.check(clock==game.player.state_time and not game.camera_driver.owns_pointer,"Advanced Alpha pause freezes combat and releases first-person pointer")
	game.pause_menu.close();await test.frames(75);game.player.set_sword_drawn(false)
	game.toggle_inventory();game.inventory.preview.refresh(game)
	test.check(game.inventory.preview.actor.has_node("BetaHero") and game.inventory.preview.actor.equipment.get_meta("beta_sword",false) and game.inventory.weapon_name()=="Blue-gem War Sword","Alpha inventory presents the same equipped war sword and its matching item name")
	game.inventory.close()
	var path="user://alpha-character-verification.json";game.Save.write(game.save_data(),path)
	game.set_environment_profile("original")
	test.check(not game.player.has_node("BetaHero") and game.player.visual.visible and not game.player.equipment.get_meta("beta_sword",false),"Original graphics restore the retained original character and sword")
	test.check(game.apply_save(game.Save.read(path)) and game.player.has_node("BetaHero") and game.player.equipment.get_meta("beta_sword",false) and game.camera_mode=="first_person" and game.quest_stage=="active","Private Alpha save/load restores the personal heroine, war sword, first person and quest")
	game.set_character_profile("standalone")
	test.check(game.player.has_node("StandaloneHero") and not game.player.has_node("BetaHero"),"Static review remains available without a duplicate personal body")
	game.set_character_profile("game");game.load_map("coastal_path",Vector2(0,3),true);await test.frames(3)
	test.check(game.player.has_node("BetaHero") and not game.player.has_node("StandaloneHero"),"Map travel and animated profile switching retain the main personal character")
	DirAccess.remove_absolute(path);game.set_environment_profile("original");game.camera_driver.set_mode("overhead")
