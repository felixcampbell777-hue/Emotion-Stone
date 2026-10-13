extends RefCounted
func run(test:RefCounted) -> void:
	var game=test.game
	game.game_mode="alpha";game.environment_profile="darkwood";game.start_new_game(false)
	game.load_map("coastal_path",Vector2(0,-5),true);game.camera_driver.set_mode("first_person");game.camera_driver.yaw=PI
	var actor=game.player
	game.progression.restore({"tree_version":2,"xp":957383,"learned":["strength","form","mana","charge_thrust","mana_lance","efficient_swing","crushing_force","flowing_splash"]});game.apply_skill_stats()
	test.check(game.progression.passives.size()==3,"Existing learned passives migrate into three equipped slots without losing ranks or XP")
	var costs=actor.combat.heavy.stamina_cost
	game.toggle_passive("efficient_swing")
	test.check(actor.combat.heavy.stamina_cost>costs and game.progression.has("efficient_swing"),"Unequipping a passive removes its real effect while retaining its learned rank")
	game.toggle_passive("efficient_swing")
	var initial=actor.combat.duplicate(true)
	for id in ["opening_cut","return_cut","spinning_cut","heavy_mastery","thrust_power","water_power","lance_power","thrust_control","lance_control","endurance","dash","jump"]: game.learn_skill(id)
	test.check(actor.combat.light.damage==roundi(initial.light.damage*1.15) and actor.combat.combo[0].damage==roundi(initial.combo[0].damage*1.15) and actor.combat.combo[1].damage==roundi(initial.combo[1].damage*1.15),"Separate light upgrades increase the opener, return cut and spin's actual contact damage")
	test.check(actor.combat.water.damage>initial.water.damage and actor.combat.lance.damage>initial.lance.damage and actor.combat.lance.splash_damage>initial.lance.splash_damage,"Water upgrades strengthen the fan, lance and impact explosion")
	test.check(actor.thrust_charge_rate>1 and actor.combat.thrust_charge.hold_base_seconds<initial.thrust_charge.hold_base_seconds and actor.combat.thrust_charge.release_windup_seconds<initial.thrust_charge.release_windup_seconds and actor.combat.lance.charge_seconds<initial.lance.charge_seconds,"Control upgrades accelerate real charge buildup and shorten windup, stuck time and lance charging")
	test.check(is_equal_approx(actor.lance_stability,.25),"First Lance Control rank reduces actual aim kick by 25 percent")
	test.check(actor.max_stamina==110 and actor.dash_equipped and actor.jump_equipped,"Stamina capacity increases the maximum; newly learned movement skills equip into their own slots")
	var damage=actor.combat.light.damage;game.apply_skill_stats()
	test.check(actor.combat.light.damage==damage and actor.max_stamina==110,"Refreshing stats does not stack upgrades or capacity increases")
	for i in range(2): game.learn_skill("opening_cut");game.learn_skill("efficient_swing")
	test.check(game.progression.rank("opening_cut")==3 and not game.progression.learn("opening_cut") and actor.combat.heavy.stamina_cost<costs,"Active/passive upgrades cap at three ranks and passive ranks improve real swing efficiency")
	game.learn_skill("lance_control");game.learn_skill("lance_control");game.apply_skill_stats()
	test.check(is_equal_approx(actor.lance_stability,.75) and not game.progression.learn("lance_control"),"Three Lance Control ranks cap real aim stabilization at 75 percent without stacking on stat rebuild")
	actor.set_sword_drawn(false);actor.position=Vector3(0,0,-5);actor.restore_stamina(110)
	var press=InputEventKey.new();press.physical_keycode=KEY_T;press.pressed=true
	var release=press.duplicate();release.pressed=false
	Input.parse_input_event(press);Input.flush_buffered_events();await test.frames(15)
	test.check(actor.state=="dash_charge","Actual T input begins the equipped Dash charge")
	game.toggle_pause();var clock=actor.state_time;await test.frames(4)
	test.check(actor.state=="dash_charge" and actor.state_time==clock,"Pause freezes a charging Dash without releasing or resetting it")
	game.pause_menu.close();var start=actor.position
	Input.parse_input_event(release);Input.flush_buffered_events();await test.frames(38)
	var short_distance=actor.position.distance_to(start)
	test.check(short_distance>2.5 and short_distance<3.9 and actor.state=="free","Releasing a short T hold launches a short dash and recovers control")
	actor.position=Vector3(0,0,-5);actor.restore_stamina(110)
	Input.parse_input_event(press.duplicate());Input.flush_buffered_events();await test.frames(95)
	start=actor.position;Input.parse_input_event(release.duplicate());Input.flush_buffered_events();await test.frames(38)
	test.check(actor.position.distance_to(start)>6.5 and actor.position.distance_to(start)<7.3 and actor.position.distance_to(start)>short_distance+2,"Longer T holds charge a bounded seven-metre dash")
	actor.position=Vector3(8,0,3);actor.restore_stamina(110);game.camera_driver.yaw=-PI/2
	actor.begin_dash_charge();actor.state_time=1.5;actor.release_dash();await test.frames(38)
	test.check(actor.position.x<8.8,"Dash stops at shoreline collision instead of tunnelling outside the map")
	actor.position=Vector3(0,0,-5);game.camera_driver.yaw=PI;actor.restore_stamina(110);actor.restore_health(actor.max_health);actor.invulnerability=0
	var jump=InputEventKey.new();jump.physical_keycode=KEY_SPACE;jump.pressed=true
	Input.parse_input_event(jump);Input.flush_buffered_events();await test.frames(12)
	test.check(actor.jump_active and actor.position.y>.45 and game.camera.position.y>2,"Space lifts the actual capsule and first-person eye above the ground")
	var airborne=actor.position;game.toggle_pause();await test.frames(4)
	test.check(actor.position.is_equal_approx(airborne),"Pause freezes the real jump and gravity")
	game.pause_menu.close();var hp=actor.health
	test.check(actor.take_damage(7,Vector3.ZERO) and actor.health<hp,"Jump supplies no damage immunity")
	jump.pressed=false;Input.parse_input_event(jump);await test.frames(45)
	test.check(not actor.jump_active and actor.state=="free" and absf(actor.position.y)<.02,"Jump lands on terrain and restores normal movement without a persistent height offset")
	actor.restore_stamina(5);test.check(not actor.begin_jump() and not actor.begin_dash_charge(),"Low stamina prevents Jump and Dash with the existing stamina feedback")
	actor.restore_stamina(110);actor.restore_health(actor.max_health)
	var path="user://skill-upgrade-private.json";var save=game.save_data()
	test.check(game.Save.write(save,path)==OK and game.apply_save(game.Save.read(path)) and game.progression.rank("opening_cut")==3 and actor.dash_equipped and actor.jump_equipped,"New ranks, passive slots and active movement slots survive private save/load")
	test.check(is_equal_approx(actor.lance_stability,.75) and game.progression.rank("lance_control")==3,"Private save/load rebuilds Mana Lance control from existing learned ranks")
	var bad=save.duplicate(true);bad.progression.passives=["dash"];game.Save.write(bad,path)
	test.check(game.Save.read(path).is_empty(),"Save rejects an active ability in a passive slot")
	bad=save.duplicate(true);bad.skill_loadout={"dash":"yes"};game.Save.write(bad,path)
	test.check(game.Save.read(path).is_empty() and not game.apply_save(bad),"Save and direct-load validation reject malformed active slots")
	DirAccess.remove_absolute(path)
	await load("res://scripts/dash_attack_checks.gd").new().run(test)
	await load("res://scripts/mana_dash_checks.gd").new().run(test)
	game.progression.restore({"tree_version":2,"xp":0,"learned":[]});game.apply_skill_stats();actor.set_sword_drawn(false)
