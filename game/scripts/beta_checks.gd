extends RefCounted
func run(test:RefCounted) -> void:
	var game=test.game
	game.title_screen.show_menu("user://beta-test-missing.json")
	game.title_screen.select_mode(1); game.start_new_game()
	test.check(game.game_mode=="beta" and game.map_id=="beta_meadow" and not game.dialog.visible,"Beta starts directly in meadow without Alpha opening dialogue")
	test.check(game.player.position.distance_to(Vector3(0,0,-12))<.1 and game.player.input_enabled,"Beta meadow spawn is safe and playable")
	test.check(game.enemies.size()==14,"Beta contains two four-wolf packs and the six existing slime/rat encounters")
	for enemy in game.enemies: enemy.ai_enabled=false
	await load("res://scripts/castle_town_checks.gd").new().run(test)
	game._update_combat_ui()
	test.check(game.enemy_bars.all(func(item): return not item.root.visible),"Undamaged Beta enemies show neither name nor health bar")
	var avatar=game.player.get_node("BetaHero")
	test.check(avatar.rig.get_bone_count()>=16 and avatar.rig.find_bone("skirt_sway")>=0 and not game.player.visual.visible,"Beta uses personal heroine with sixteen driven bones")
	var meshes=avatar.find_children("*","MeshInstance3D",true,false); var skinned=0
	for mesh in meshes:
		if mesh.skin!=null: skinned+=1
	test.check(skinned>10,"Personal heroine clothing, body and hair retain skin weights")
	game.camera_driver.set_mode("first_person")
	await load("res://scripts/beta_sword_checks.gd").new().run(test)
	await load("res://scripts/beta_anchor_checks.gd").new().run(test)
	await load("res://scripts/beta_gait_checks.gd").new().run(test)
	await load("res://scripts/first_person_checks.gd").new().run(test)
	await load("res://scripts/wolf_pack_checks.gd").new().run(test)
	for enemy in game.enemies: enemy.ai_enabled=false
	game.player.set_sword_glow(true,2.2); avatar.synchronize()
	var mirrored=true
	for pair in avatar.gear_parts:
		if pair[0] is MeshInstance3D:
			for surface in range(pair[0].mesh.get_surface_count()): mirrored=mirrored and pair[0].get_surface_override_material(surface)==pair[1].get_surface_override_material(surface)
	test.check(mirrored,"Beta live steel follows actor-owned energy materials")
	game.player.set_sword_glow(false); avatar.synchronize(); mirrored=true
	for pair in avatar.gear_parts:
		if pair[0] is MeshInstance3D:
			for surface in range(pair[0].mesh.get_surface_count()): mirrored=mirrored and pair[0].get_surface_override_material(surface)==pair[1].get_surface_override_material(surface)
	test.check(mirrored,"Beta steel restores with the actor-owned longsword")
	var leg=avatar.rig.find_bone("thigh_L")
	if leg<0: leg=avatar.rig.find_bone("thigh.L")
	var before=avatar.rig.get_bone_pose_rotation(leg)
	game.camera_driver.set_mode("overhead")
	Input.action_press("move_right"); await test.frames(18); Input.action_release("move_right")
	test.check(game.player.position.x>.35 and not game.player.visual.visible and not before.is_equal_approx(avatar.rig.get_bone_pose_rotation(leg)),"Retargeted natural-speed walk moves only personal heroine and changes personal skeleton")
	var wolf; var rat; var resin
	for enemy in game.enemies:
		if enemy.definition.kind=="beta_wolf": wolf=enemy
		if enemy.definition.kind=="beta_rat": rat=enemy
		if enemy.get("style")=="resin_slime": resin=enemy
	for animal in [wolf,rat]:
		test.check(animal!=null and animal.animation_names.has("attack"),"Imported animal has supplied attack clip")
		animal.state="windup"; animal.state_time=.3; animal._physics_process(.02)
		test.check(animal.current_animation==animal.animation_names.get("attack","") and animal.animator.current_animation_position>0,"Animal windup samples existing attack animation")
	test.check(wolf.max_health==80 and wolf.tuning.damage==12 and rat.max_health==35 and rat.tuning.damage==6,"Animal health and contact damage use Beta tuning")
	await rat_sword_checks(test,rat)
	rat.take_sword_damage(22,Vector3.RIGHT)
	test.check(rat.health==13 and rat.knockback.length()>5,"Rat accepts sword damage and Small recoil")
	wolf.take_sword_damage(45,Vector3.RIGHT,true)
	test.check(wolf.health==35 and wolf.knockback.length()>5,"Wolf accepts strong sword damage and Medium recoil")
	test.check(resin!=null and resin.max_health==42,"Beta reuses original sticky resin slime")
	var puddle=load("res://scripts/menagery_hazard.gd").new(); game.current_world.add_child(puddle)
	resin.ai_enabled=true
	puddle.configure(game,game.player.position,true,resin); puddle._physics_process(.02)
	test.check(not game.player.slow_sources.is_empty() and resin.state=="resin_charge","Original sticky puddle slows heroine and triggers Resin dash")
	resin.ai_enabled=false
	puddle.queue_free(); game.player.slow_sources.clear()
	game.toggle_pause(); var position=game.player.position; var clock=wolf.phase
	Input.action_press("move_up"); await test.frames(5); Input.action_release("move_up")
	test.check(game.player.position.is_equal_approx(position) and wolf.phase==clock,"Pause gates Beta character and animal simulation")
	game.pause_menu.close()
	var path="user://beta-verification.json"; var save=game.save_data()
	test.check(save.game_mode=="beta" and game.current_save_path()=="user://beta-save-v1.json","Beta serializes mode and uses separate player save path")
	test.check(game.Save.write(save,path)==OK and not game.Save.read(path).is_empty(),"Beta private save passes validation")
	game.player.position=Vector3(2,0,-12)
	test.check(game.apply_save(game.Save.read(path)) and game.map_id=="beta_meadow" and game.player.has_node("BetaHero"),"Beta private load restores meadow and animated heroine")
	game.toggle_inventory(); game.inventory.show_page("equipment"); game.inventory.preview.refresh(game)
	test.check(game.inventory.preview.actor.has_node("BetaHero") and not game.inventory.preview.actor.visual.visible,"Inventory previews the same animated personal heroine")
	test.check(game.inventory.preview.actor.equipment.get_meta("beta_sword",false),"Inventory uses the same shorter Beta longsword")
	game.inventory.close()
	var enemy=game.enemies[0]; var id=game.map_id+"/"+String(enemy.definition.id)
	enemy.take_damage(999,Vector3.RIGHT)
	test.check(id in game.defeated_enemies,"Beta kill records a permanent encounter defeat")
	game.recovering=true; game.respawn_player()
	test.check(game.map_id=="beta_meadow" and id in game.defeated_enemies and game.player.health==game.player.max_health,"Beta respawn returns to meadow retaining defeats")
	var bad=save.duplicate(true); bad.game_mode="alpha"; game.Save.write(bad,path)
	test.check(game.Save.read(path).is_empty() and not game.apply_save(bad),"Mode/map mismatch cannot contaminate Alpha saves")
	DirAccess.remove_absolute(path)
	game.game_mode="alpha"; game.start_new_game(false)
	test.check(game.map_id=="home_upstairs" and game.player.has_node("BetaHero") and not game.player.visual.visible,"Returning to Advanced Alpha retains its home opening and animated personal heroine")
	test.check(game.current_save_path()=="user://save-v1.json","Alpha retains original player save path")
	test.check(game.player.equipment.get_meta("beta_sword",false) and game.player.equipment.find_child("SwordBlade",true,false)!=null,"Returning to Advanced Alpha retains the shared broad war sword and back mounting")

func rat_sword_checks(test:RefCounted,rat:Node3D) -> void:
	var game=test.game; var actor=game.player
	var home=rat.position
	actor.set_sword_drawn(true); actor.position=Vector3(0,0,-12); actor.visual.rotation.y=0
	actor.restore_stamina(100); actor.combo_remaining=0; actor.combo_queued=false
	rat.position=Vector3(0,0,-10.8); rat.set_physics_process(false)
	actor.begin_attack("light")
	await test.frames(105)
	test.check(rat.health==13,"A real opening sword cut damages the low rat exactly once")
	game._update_combat_ui()
	var bar=game.enemy_bars.filter(func(item): return item.enemy==rat)[0]
	test.check(bar.root.visible and bar.bar.value==13,"Rat name and health bar appear after the real sword hit")
	game.toggle_pause(); game._update_combat_ui()
	test.check(not bar.root.visible,"Damaged rat bar stays hidden during pause")
	game.pause_menu.close(); game._update_combat_ui()
	test.check(bar.root.visible,"Damaged rat bar returns after closing pause")
	rat.health=rat.max_health; rat.knockback=Vector3.ZERO
	actor.position=Vector3(0,0,-12); actor.restore_stamina(100); actor.combo_remaining=0
	rat.position=Vector3(0,0,-15)
	actor.begin_attack("light"); await test.frames(105)
	test.check(rat.health==rat.max_health,"Opening sword cut still misses a rat behind the heroine")
	rat.health=rat.max_health; rat.knockback=Vector3.ZERO; rat.position=home; rat.state="idle"
	rat.set_physics_process(true)
	actor.position=Vector3(0,0,-12); actor.set_sword_drawn(false)
