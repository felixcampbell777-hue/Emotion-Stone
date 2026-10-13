extends RefCounted
func run(test:RefCounted) -> void:
	var game=test.game
	var xp=game.progression.xp
	var progress=game.defeated_enemies.duplicate()
	for source in ["coastal_path","village_green"]:
		var data=game.read_data("res://content/maps/"+source+".json")
		var gates=data.exits.filter(func(item): return item.target=="menagery")
		test.check(gates.size()==1 and gates[0].rect[0]<data.spawn[0],source+" has its signed Menagery connection west of spawn")
	game.load_map("menagery",Vector2(10,0),true)
	game.camera_driver.set_mode("overhead")
	game.player.restore_health(100)
	game.player.invulnerability=0
	game.player.set_sword_drawn(true)
	game.player.restore_stamina(100)
	game._refresh_simulation()
	test.check(game.menagery.catalog.features.size()==36 and game.menagery.spawn_buttons.size()==10,"Menagery exposes 36 stable scenery codes and ten monster spawn buttons")
	var labels=[]
	for child in game.current_world.get_children():
		if child.name.begins_with("feature_"):
			for node in child.get_children():
				if node is Label3D: labels.append(node.text)
	var prop=load("res://scripts/props.gd").create({"kind":"catalog_feature","id":"syntax_check","catalog_code":"2A","at":[4,-3],"rotation":90,"scale":1.2})
	test.check(prop.position==Vector3(4,0,-3) and is_equal_approx(prop.rotation.y,PI/2) and is_equal_approx(prop.scale.x,1.2),"Catalog placement honors shared sketch coordinates, rotation and scale")
	prop.free()
	test.check(labels.size()==36 and labels[0].begins_with("1A") and labels[22].begins_with("6D") and labels[30].begins_with("4G"),"Every gallery feature carries its catalog label in the actual map")
	for code in game.menagery.spawn_buttons:
		game.menagery.spawn_buttons[code].pressed.emit()
		var mob=game.menagery.spawned[code]
		mob.ai_enabled=false
	test.check(game.enemies.size()==10 and game.enemy_bars.size()==10,"All ten buttons spawn fightable distinct specimens with floating health bars")
	for code in game.menagery.spawned:
		var mob=game.menagery.spawned[code]
		mob.ai_enabled=true
		game.player.position=mob.position+Vector3(0,0,1)
		if code=="10E": mob.state_time=0
		mob._physics_process(.01)
		test.check(mob.state in ["windup","brood_windup"] or (code=="7E" and mob.velocity.length()>0),code+" begins its authored attack or ranged retreat when approached")
		mob.ai_enabled=false; mob.state="idle"; mob.knockback=Vector3.ZERO
	game.player.position=Vector3(10,0,0)
	var previous=game.menagery.spawned["1E"]
	var replacement=game.menagery.spawn("1E")
	replacement.ai_enabled=false
	test.check(game.enemies.size()==10 and previous.is_queued_for_deletion(),"Repeated spawning replaces that specimen instead of accumulating copies")
	await test.frames(2)
	var resin=game.menagery.spawned["2E"]
	resin.direction=Vector3.FORWARD
	resin._release_ability()
	var gloops=game.get_tree().get_nodes_in_group("resin_gloop")
	test.check(gloops.size()==1,"Resin slime throws an airborne gloop before any puddle appears")
	var gloop=gloops[0]; gloop.set_physics_process(false); game.player.state="free"
	gloop._physics_process(gloop.duration)
	var patches=game.get_tree().get_nodes_in_group("menagery_effect").filter(func(node): return node.has_method("contains_player"))
	test.check(patches.size()==1,"Resin gloop splashes down into one visible sticky puddle")
	var patch=patches[0]
	patch.set_physics_process(false)
	game.player.position=Vector3(patch.position.x,0,patch.position.z)
	patch._physics_process(.1)
	test.check(is_equal_approx(game.player.terrain_speed_scale(),.45),"Sticky resin lowers actual character movement to 45 percent")
	game.menagery.toggle()
	var age=patch.age
	var clocks=[]
	for mob in game.enemies: clocks.append(mob.phase)
	await test.frames(12)
	patch._physics_process(.5)
	test.check(not game.player.input_enabled and patch.age==age and game.enemies[1].phase==clocks[1],"Catalog overlay pauses actors, sticky hazards and active attacks")
	game.nearest={"id":"catalog_sign","actor":null,"title":"Catalog","lines":["Sample"]}
	var interact=InputEventKey.new(); interact.physical_keycode=KEY_E; interact.pressed=true
	game._unhandled_key_input(interact)
	test.check(not game.dialog.visible and game.menagery.opened,"Catalog blocks world interaction while its paused overlay is open")
	var escape=InputEventKey.new(); escape.physical_keycode=KEY_ESCAPE; escape.pressed=true
	game._unhandled_key_input(escape)
	test.check(not game.menagery.opened and not game.pause_menu.visible,"Escape closes the catalog before opening Pause")
	game.player.slow_sources.clear()
	game.projectiles=game.projectiles.filter(func(item): return is_instance_valid(item) and not item.is_queued_for_deletion())
	var bramble=game.menagery.spawned["3E"]
	bramble.direction=Vector3.FORWARD
	bramble._release_ability()
	test.check(game.projectiles.size()==3,"Bramble slime throws its three-seed fan")
	var shot=game.projectiles[1]
	shot.set_physics_process(false)
	game.player.set_sword_drawn(true)
	game.player.restore_stamina(100)
	game.player.position=Vector3(10,0,0)
	game.player.state="free"
	game.player.visual.rotation.y=0
	game.player.begin_parry(); game.player.state_time=.3
	shot.position=game.player.position+Vector3(0,.7,1)
	test.check(game.player.try_parry(shot) and shot.reflected,"Forest projectiles use the real right-click timed parry and reflect")
	var hog=game.menagery.spawned["4E"]
	hog.state="lunge"; hog.take_slam_shockwave(Vector3.RIGHT,1,.65)
	test.check(hog.state=="recover" and hog.knockback.length()>0,"New charging creatures respect slam interruption and size recoil")
	var puff=game.menagery.spawned["8E"]
	puff._release_ability()
	test.check(game.get_tree().get_nodes_in_group("menagery_effect").filter(func(node): return node.has_method("contains_player") and not node.sticky).size()==1,"Puffcap creates a telegraphed spore burst")
	for mob in game.enemies: mob.take_lance_damage(999,Vector3.ZERO)
	var reward=0
	for entry in game.menagery.catalog.monsters: reward+=int(game.progression.definition.enemy_xp[entry.style])+game.monster_cores.boss_bonus(entry.style)
	test.check(game.progression.xp==xp+reward and game.defeated_enemies==progress,"Every Menagery creature pays its fixed XP without contaminating story defeats")
	var earned=game.progression.xp
	for mob in game.enemies: mob.take_lance_damage(999,Vector3.ZERO)
	test.check(game.progression.xp==earned,"Repeated damage on dead creatures cannot duplicate XP")
	var grind=game.menagery.spawn("1E"); grind.ai_enabled=false; grind.take_damage(999,Vector3.ZERO)
	test.check(game.progression.xp==earned+int(game.progression.definition.enemy_xp.moss_slime),"Respawning and defeating a fresh catalog creature supports XP grinding")
	var data=game.save_data()
	var path="user://menagery-verification.json"
	game.Save.write(data,path)
	test.check(not game.Save.read(path).is_empty(),"Menagery location survives existing private-save validation")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.menagery.clear()
	await test.frames(2)
	test.check(game.enemies.is_empty() and game.enemy_bars.is_empty() and game.player.terrain_speed_scale()==1,"Clearing practice specimens removes mobs, bars and sticky penalties")
	game.load_map("coastal_path",Vector2(0,3),true)
	await test.frames(2)
	test.check(game.get_tree().get_nodes_in_group("menagery_effect").is_empty() and not game.menagery.visible,"Leaving Menagery cleans up its effects and toolbar")
	game.player.set_sword_drawn(false)
