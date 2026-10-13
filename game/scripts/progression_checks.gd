extends RefCounted
func run(test: RefCounted) -> void:
	var game=test.game
	game.progression.restore({"xp":0,"learned":[]})
	game.apply_skill_stats()
	game.defeated_enemies=[]
	game.quest_stage="not_started"
	game.player.set_sword_drawn(false)
	game.load_map("herb_glade",Vector2(0,14))
	for enemy in game.enemies:
		enemy.ai_enabled=false
	var warden=game.enemies[2]
	test.check(warden.guardian!=null and warden.guardian.arms.size()==2 and warden.guardian.plates.size()==2,"Warden uses articulated stone armor and a distinct core")
	var closed=warden.guardian.plates[0].position.x
	warden.open_armor()
	await test.frames(5)
	test.check(warden.guardian.plates[0].position.x<closed-.05,"Reflected-rock armor opening visibly parts the chest plates")
	game._enemy_defeated("slime_forest/forest_slime","slime")
	game._enemy_defeated("slime_forest/forest_slime","slime")
	test.check(game.progression.xp==35,"Repeated defeat callbacks cannot farm XP")
	game._enemy_defeated("herb_glade/briar_boar","boar")
	game._enemy_defeated("herb_glade/briar_boar_second","boar")
	game._enemy_defeated("herb_glade/stone_warden","warden")
	test.check(game.progression.xp==575 and game.progression.level()==4 and game.progression.points()==3,"Enemy XP crosses cumulative level thresholds and grants three points including the boss bonus")
	game.quest_stage="component_ready"
	game.conversation.complete_quest()
	game.conversation.complete_quest()
	test.check(game.progression.xp==655,"Alchemical core quest awards XP exactly once")
	test.check(not game.progression.learn("charge_thrust") and not game.progression.learn("unknown"),"Unknown skills and missing roots cannot consume points")
	game.progression.restore({"tree_version":2,"xp":355,"learned":[]})
	game.learn_skill("strength")
	game.learn_skill("efficient_swing")
	test.check(game.progression.points()==0 and not game.progression.learn("form") and not game.progression.learn("crushing_force"),"One point per rank; overspending is rejected")
	test.check(game.player.max_health==110 and game.player.combat.light.damage==26 and game.player.combat.combo[1].damage==34 and is_equal_approx(game.player.combat.heavy.stamina_cost,25.2),"Strength increases HP and every sword strike; Measured Force lowers actual swing costs")
	game.apply_skill_stats()
	test.check(game.player.combat.heavy.damage==49,"Reapplying skill stats does not stack bonuses")
	game.progression.restore({"tree_version":2,"xp":8200,"learned":[]})
	for id in ["strength","efficient_swing","crushing_force","form","charge_thrust","belly_roll","mana","mana_lance","flowing_splash"]: game.learn_skill(id)
	test.check(game.progression.learned.size()==9 and game.progression.points()==5,"Both upgrade paths in all three branches can be purchased for one point each")
	test.check(game.player.roll_unlocked and game.player.lance_unlocked and is_equal_approx(game.player.combat.heavy.stamina_cost,25.2) and is_equal_approx(game.player.combat.water.stamina_cost,9.6) and game.player.combat.heavy.damage>49,"Paired branch bonuses and ability unlocks work together")
	game.select_heavy_attack("charge_thrust")
	game.select_special_attack("water_lance")
	var paired_path="user://progression-paired-verification.json"
	game.Save.write(game.save_data(),paired_path)
	var paired=game.Save.read(paired_path)
	test.check(not paired.is_empty() and game.apply_save(paired) and game.progression.learned.size()==9 and game.player.roll_unlocked and game.player.heavy_style=="charge_thrust" and game.selected_special_attack=="water_lance","Both paths and equipped attacks survive a private save/load round trip")
	game.skill_tree.refresh()
	test.check(not game.skill_tree.nodes.belly_roll.blocked and not game.skill_tree.nodes.flowing_splash.blocked,"Learning both paths never crosses out the sibling nodes")
	game.progression.restore({"tree_version":2,"xp":8200,"learned":[]})
	game.apply_skill_stats()
	game.player.set_sword_drawn(true)
	test.check(not game.player.begin_water() and not game.player.begin_water_lance(),"Both water abilities are locked before Mana investment")
	for i in range(5):
		game.learn_skill("strength")
		game.learn_skill("form")
	test.check(game.progression.rank("strength")==5 and game.progression.rank("form")==5 and not game.progression.learn("strength") and not game.progression.learn("form"),"Base Strength and Form accept five point stacks and reject the sixth")
	test.check(game.player.max_health==150 and is_equal_approx(game.player.walk_speed,3.0) and is_equal_approx(game.player.combat.drawn_sprint_speed,3.0) and is_equal_approx(game.player.combat.drawn_sprint_drain,20.4),"Five Form ranks increase walking and sprint speed and reduce both sprint drains")
	for id in ["crushing_force","charge_thrust","mana","mana_lance"]: game.learn_skill(id)
	test.check(game.progression.points()==0 and game.player.combat.heavy.damage==98 and game.player.water_unlocked and game.player.lance_unlocked,"Crushing Force multiplies ranked damage; Mana root and Lance choice unlock casts")
	test.check(not game.progression.learn("belly_roll") and not game.progression.learn("flowing_splash"),"Unlearned split nodes still require available skill points")
	game.select_heavy_attack("charge_thrust")
	game.select_special_attack("water_lance")
	game.player.restore_health(150)
	game.player.restore_stamina(100)
	game.load_map("coastal_path",Vector2(-3,1),true)
	game.player.visual.rotation.y=0
	game.player.set_sword_drawn(true)
	var start_position=game.player.position
	test.check(game.player.begin_attack("heavy") and game.player.state=="thrust","Equipped Driving Thrust replaces the actual heavy attack")
	await test.frames(52)
	var active_speed=game.player.velocity.length()
	test.check(game.player.position.distance_to(start_position)>1.5 and active_speed>5.0,"Driving Thrust charges a long straight distance through its active attack")
	await test.frames(45)
	test.check(game.player.state=="thrust" and game.player.velocity.length()<active_speed and not game.player.begin_attack("light"),"Thrust ends in a decelerating slide with attacks locked until recovery")
	await test.frames(270)
	test.check(game.player.state=="free","Thrust returns smoothly to the burden stance after sliding cooldown")
	game.player.set_sword_drawn(true)
	game.player.restore_stamina(100)
	game.player.rush_credit=.2
	game.player.begin_charge()
	game.player.state_time=.42
	test.check(game.player.release_charge("heavy") and game.player.state=="thrust" and game.player.attack_rushing and game.player.attack_phase()>0.0 and game.player.attack_phase()<.24,"Rush-held thrust releases from its prepared side pose without resetting the blade")
	game.player.set_sword_drawn(true)
	game.player.restore_stamina(100)
	game.load_map("coastal_path",Vector2(0,3),true)
	var path="user://progression-verification.json"
	game.Save.write(game.save_data(),path)
	var saved=game.Save.read(path)
	test.check(not saved.is_empty() and game.apply_save(saved) and game.player.max_health==150 and game.progression.rank("strength")==5 and game.player.heavy_style=="charge_thrust" and game.selected_special_attack=="water_lance","Ranked roots, unlocks and equipped attacks survive save/load")
	var bad=saved.duplicate(true)
	for growth in [{"tree_version":2,"xp":0,"learned":["strength"]},{"tree_version":2,"xp":8200,"learned":["charge_thrust"]},{"tree_version":2,"xp":8200,"learned":["mana","mana_lance","mana_lance"]},{"tree_version":2,"xp":8200,"learned":["form","form","form","form","form","form"]}]:
		bad.progression=growth
		game.Save.write(bad,path)
		test.check(game.Save.read(path).is_empty(),"Save rejects overspending, skipped roots, duplicate unlocks or excess ranks: "+str(growth.learned))
	var old=saved.duplicate(true)
	old.progression={"xp":1400,"learned":["steady_heart","heavy_hands","rising_tide","deep_breath","sure_guard","flowing_reserve"]}
	old.health=115
	old.stamina=115
	game.Save.write(old,path)
	var migrated=game.Save.read(path)
	test.check(not migrated.is_empty() and game.apply_save(migrated) and game.progression.xp==1400 and game.progression.points()==6 and game.progression.learned.is_empty() and game.player.health==100 and game.player.stamina==100,"Retired six-skill saves retain XP, refund all old allocations and clamp old resource maxima")
	game.progression.restore({"tree_version":2,"xp":8200,"learned":["form","belly_roll","mana","flowing_splash"]})
	game.apply_skill_stats()
	test.check(is_equal_approx(game.player.combat.water.stamina_cost,9.6) and not game.player.lance_unlocked and game.player.heavy_style=="overhead","Flowing Splash lowers real slash cost by 60 percent; locked equipment falls back safely")
	game.load_map("coastal_path",Vector2(0,3),true)
	game.player.set_sword_drawn(true)
	game.player.restore_stamina(100)
	game.player.invulnerability=0
	game.player.input_enabled=true
	var press=InputEventKey.new()
	press.physical_keycode=KEY_SHIFT
	press.pressed=true
	game.player._input(press)
	await test.frames(5)
	var release=InputEventKey.new()
	release.physical_keycode=KEY_SHIFT
	release.pressed=false
	game.player._input(release)
	test.check(game.player.state=="roll" and is_equal_approx(game.player.stamina,82),"A Shift tap starts the unlocked Dodge and spends its fixed stamina cost")
	await test.frames(20)
	var root=game.player.skeleton.find_bone("root")
	game.player.skeleton.force_update_all_bone_transforms()
	test.check(abs(game.player.skeleton.get_bone_global_pose(root).basis.y.dot(Vector3.UP))<.20,"Somersault tips the actual rig forward through horizontal")
	var forearm=game.player.skeleton.find_bone("forearm_R")
	if forearm<0: forearm=game.player.skeleton.find_bone("forearm.R")
	var wrist_offset=game.player.skeleton.get_bone_global_rest(forearm).affine_inverse()*Vector3(-.385,.88,.015)
	var hand=game.player.skeleton.global_transform*(game.player.skeleton.get_bone_global_pose(forearm)*wrist_offset)
	var grip=game.player.equipment.global_transform*Vector3(0,.16,0)
	test.check(hand.distance_to(grip)<.13,"The rolling right hand remains on the sword grip, rather than carrying a floating weapon")
	test.check(game.player.take_damage(12,Vector3.ZERO) and not game.player.begin_attack("heavy"),"Hits damage the rolling middle while heavy attacks remain action-locked")
	await test.frames(34)
	test.check(game.player.state=="stand" and game.player.current_clip=="stand_up","A crouched somersault landing enters its authored stand-up animation")
	await test.frames(12)
	var foot=game.player.skeleton.find_bone("foot_L")
	if foot<0: foot=game.player.skeleton.find_bone("foot.L")
	game.player.skeleton.force_update_all_bone_transforms()
	var planted=game.player.skeleton.global_transform*game.player.skeleton.get_bone_global_pose(foot).origin
	test.check(planted.y>=-.02 and planted.y<.25,"Stand-up plants the foot close to the ground while the body rises")
	await test.frames(24)
	test.check(game.player.state=="free" and game.player.sword_drawn,"Stand-up restores the original sword stance and player control")
	game.player.restore_stamina(100)
	game.player._input(press)
	Input.action_press("sprint")
	Input.action_press("move_right")
	await test.frames(20)
	test.check(game.player.sprinting and game.player.state=="free","Holding Shift still sprints after the short tap window")
	Input.action_release("sprint")
	Input.action_release("move_right")
	game.player._input(release)
	test.check(game.player.state=="free","Releasing a held sprint never triggers a roll")
	game.player.restore_stamina(100)
	game._refresh_simulation()
	var control=InputEventKey.new()
	control.physical_keycode=KEY_CTRL
	control.pressed=true
	control.ctrl_pressed=true
	Input.parse_input_event(control)
	await test.frames(2)
	test.check(game.player.state=="roll","Real viewport Ctrl input triggers Dodge immediately")
	control=control.duplicate()
	control.pressed=false
	control.ctrl_pressed=false
	Input.parse_input_event(control)
	await test.frames(90)
	game.player.restore_stamina(100)
	press.shift_pressed=true
	Input.parse_input_event(press)
	await test.frames(15)
	Input.parse_input_event(release)
	await test.frames(2)
	test.check(game.player.state=="roll","A real Shift tap with modifier flags works in the more forgiving 0.30-second window")
	await test.frames(90)
	game.player.set_sword_drawn(false)
	game.player.restore_stamina(100)
	var mount_parent=game.player.equipment.get_parent()
	var mount_transform=game.player.equipment.transform
	var started=game.player.request_dodge()
	test.check(started and game.player.current_clip=="dodge_roll_sheathed" and not game.player.sword_drawn and game.player.equipment.get_parent()==mount_parent,"A sheathed dodge uses tucked free hands and never draws the sword")
	var stayed_mounted=true
	var sheathed_stand=false
	for index in range(90):
		await test.frames(1)
		stayed_mounted=stayed_mounted and not game.player.sword_drawn and game.player.equipment.get_parent()==mount_parent and game.player.equipment.transform.is_equal_approx(mount_transform)
		sheathed_stand=sheathed_stand or game.player.current_clip=="stand_up_sheathed"
	test.check(stayed_mounted and sheathed_stand and game.player.state=="free","Sword stays on its animated back mount through the full sheathed somersault and stand-up")
	game.player.set_sword_drawn(true)
	game.player.restore_stamina(5)
	Input.parse_input_event(control.duplicate())
	control.pressed=true
	control.ctrl_pressed=true
	Input.parse_input_event(control)
	await test.frames(2)
	test.check(game.player.state=="free" and game.hud_feedback.pulse_remaining>0,"Low stamina gives visible Dodge feedback instead of silently failing")
	control.pressed=false
	control.ctrl_pressed=false
	Input.parse_input_event(control)
	game.player.roll_unlocked=false
	game.player.restore_stamina(100)
	test.check(not game.player.request_dodge() and game.toast.text.contains("Unlock Dodge"),"Locked Dodge explains its Form unlock requirement")
	test.check(game.progression.skill("belly_roll").name=="Dodge","Existing saved roll skill is displayed as Dodge")
	var legacy=saved.duplicate(true)
	legacy.erase("progression")
	legacy.health=100
	legacy.stamina=100
	test.check(game.apply_save(legacy) and game.progression.xp==355 and game.progression.learned.is_empty() and game.player.max_health==100,"Old saves receive historical credit for cleared enemies and completed quests without retroactive boss bonuses")
	game.player.state="free"
	game.toggle_skills()
	var before=game.player.position
	Input.action_press("move_right")
	await test.frames(8)
	Input.action_release("move_right")
	test.check(game.skill_tree.visible and not game.player.input_enabled and game.player.position.is_equal_approx(before) and game.enemies.all(func(e): return not e.simulation_enabled),"Skill menu pauses movement, enemies and combat")
	var escape=InputEventKey.new()
	escape.physical_keycode=KEY_ESCAPE
	escape.pressed=true
	game._unhandled_key_input(escape)
	test.check(not game.skill_tree.visible and not game.help_panel.visible,"Escape closes the skill menu directly")
	game.player.invulnerability=0
	game.player.take_damage(game.player.max_health,Vector3.ZERO)
	game.respawn_player()
	test.check(game.progression.xp==355 and game.progression.level()==3,"Death and village respawn preserve XP and skill points")
	DirAccess.remove_absolute(path)
