extends RefCounted
func run(test:RefCounted) -> void:
	var game=test.game
	game.start_new_game(false); game.home_intro_complete=true
	game.load_map("menagery",Vector2(10,0),true)
	var gear=game.magic_items
	test.check(gear.catalog.items.size()==35 and gear.SLOTS.size()==7,"Magic codex contains thirty-two wearables, three draughts and seven independent wearable slots")
	for type in ["ring","torso","leggings","boots","headwear","necklace"]:
		test.check(gear.catalog.items.filter(func(e): return e.category==type).size()==(6 if type in ["torso","boots"] else 5),type+" includes its distinct item definitions and campaign treasure")
	game.menagery.toggle(); game.menagery.tabs.current_tab=2
	test.check(game.menagery.codex.list.get_child_count()==35 and not game.player.input_enabled,"Menagerie magic codex is accessible and pauses gameplay")
	var card=game.menagery.codex.list.get_child(0).get_child(0).get_child(1)
	card.get_child(2).pressed.emit()
	test.check("tidal_signet" in gear.owned,"Actual codex Claim button grants an owned specimen")
	for entry in gear.catalog.items: gear.claim(entry.id)
	test.check(gear.owned.size()==35 and not gear.claim("tidal_signet"),"Specimen claims never duplicate ownership")
	game.menagery.close()
	game.load_map("coastal_path",Vector2(0,3),true)
	test.check(not gear.claim("unknown") and not gear.equip("boots","unowned"),"Unknown and unowned equipment are rejected")
	test.check(not gear.equip("torso","gale"),"An item cannot be equipped in the wrong category")
	gear.equip("ring1","tidal_signet"); gear.equip("ring2","echo_loop")
	test.check(is_equal_approx(game.player.combat.water.stamina_cost,16.8) and game.player.combat.water.damage==38,"Tidal ring modifies real spell cost and damage")
	gear.equip("ring2","tidal_signet")
	test.check(gear.slots.ring1.is_empty() and gear.slots.ring2=="tidal_signet","Moving a unique ring clears its former slot instead of duplicating its effect")
	gear.equip("ring1","echo_loop")
	gear.equip("torso","oakheart")
	game.player.restore_health(100); game.player.invulnerability=0
	game.player.take_damage(20,Vector3.RIGHT)
	test.check(game.player.max_health==135 and game.player.health==84,"Oakheart changes maximum health and reduces actual incoming damage")
	gear.equip("leggings","ironroot"); game.player.invulnerability=0
	game.player.take_damage(10,Vector3.RIGHT)
	test.check(is_equal_approx(game.player.knockback.x,1.56),"Ironroot reduces actual hurt recoil")
	gear.equip("boots","marshgrip")
	game.player.slow_sources.test={"remaining":10,"factor":.45}
	test.check(is_equal_approx(game.player.terrain_speed_scale(),1),"Marshgrip removes the movement penalty of real sticky terrain")
	gear.equip("boots","gale")
	test.check(is_equal_approx(game.player.walk_speed,2.832),"Gale Boots increase actual movement speed")
	game.apply_skill_stats()
	test.check(is_equal_approx(game.player.walk_speed,2.832),"Stat rebuild does not stack item bonuses")
	game.player.set_sword_drawn(true); game.player.set_sword_glow(true)
	var energy=game.player.sword_energy_materials.duplicate()
	gear.equip("torso","stormweave")
	test.check(not energy.is_empty() and game.player.sword_energy_materials==energy,"Equipment refresh preserves actor-owned blade energy shaders")
	game.player.set_sword_glow(false)
	gear.equip("headwear","phoenix")
	game.player.restore_health(40); game.player.invulnerability=0
	game.player.take_damage(999,Vector3.RIGHT)
	test.check(game.player.health==1 and gear.phoenix_cooldown==60 and not game.recovering,"Phoenix prevents a lethal hit once and starts its cooldown")
	game.toggle_inventory(); game.inventory.selected_category="apparel"; game.inventory.refresh()
	var cooldown=gear.phoenix_cooldown
	await test.frames(6)
	test.check(gear.phoenix_cooldown==cooldown,"Equipment menu pauses magic-item cooldowns")
	test.check(game.inventory.preview.visible and game.inventory.preview.actor.find_children("MagicGear_*","BoneAttachment3D",true,false).is_empty() and game.player.find_children("MagicGear_*","BoneAttachment3D",true,false).is_empty(),"Equipped items keep their effects and slots without accessories on the player or inventory skin")
	var grid=game.inventory.slots.get_child(2)
	for button in grid.get_children():
		if button is Button and button.text.begins_with("RING 2"): button.pressed.emit(); break
	test.check(game.inventory.selected_slot=="ring2","Actual equipment slot button opens its item selector")
	game.inventory.close()
	game.player.restore_health(40); game.player.invulnerability=0
	game.player.take_damage(999,Vector3.RIGHT)
	test.check(game.recovering,"Phoenix cannot prevent another lethal hit during recharge")
	game.respawn_player(); game.player.invulnerability=0
	gear.equip("ring1","bloodbloom")
	game.player.restore_health(80)
	var enemy=game.Slime.new(); enemy.configure({"id":"heal_test","kind":"slime","at":[0,6]},game.player); game.world_root.add_child(enemy)
	var before=enemy.health; enemy.take_damage(5,Vector3.RIGHT); gear.sword_hit(enemy,before)
	test.check(game.player.health==83,"Bloodbloom heals only after successful enemy damage")
	gear.sword_hit(enemy,enemy.health)
	test.check(game.player.health==83,"Blocked or duplicate contacts cannot give Bloodbloom healing")
	gear.equip("ring1","echo_loop"); game.player.restore_stamina(20)
	game._parry_succeeded(enemy)
	test.check(is_equal_approx(game.player.stamina,32),"Successful parry hook applies Echo Loop's stamina refund")
	enemy.queue_free()
	gear.equip("leggings","hunter")
	var xp=game.progression.xp; game.gain_xp(100)
	test.check(game.progression.xp==xp+120,"Hunter's XP multiplier applies to the shared reward path")
	gear.equip("boots","quake"); gear.equip("ring2","starfall_band")
	test.check(is_equal_approx(game.player.combat.slam_shockwave.radius,4.16) and is_equal_approx(game.player.combat.slam_shockwave.force_factor,1.4625),"Quake and Starfall combine real slam range and force bonuses")
	gear.equip("boots","pilgrim"); game.player.restore_health(60); gear.quiet_seconds=4; gear.heal_clock=0
	game.player.state="free"; game._refresh_simulation(); gear.tick(1)
	test.check(game.player.health==61,"Pilgrim heals during active quiet time")
	# Necklace migration preserves the old shrine discovery without applying speed twice.
	for slot in gear.SLOTS: gear.equip(slot,"")
	gear.slots.erase("necklace")
	game.goblin_campaign.flags.append_array(["secret_wall","windstep"])
	gear.migrate_windstep({"flags":["windstep"],"charm_equipped":true}); game.apply_skill_stats()
	test.check(gear.slots.necklace=="windstep" and is_equal_approx(game.player.walk_speed,2.88),"Legacy Windstep migrates into necklace with one speed bonus")
	gear.equip("necklace","warding"); gear.migrate_windstep({"flags":["windstep"],"charm_equipped":true}); game.apply_skill_stats()
	test.check(gear.slots.necklace=="warding" and "windstep" in gear.owned and is_equal_approx(game.player.walk_speed,2.4),"An explicit replacement necklace survives migration while Windstep remains owned")
	gear.equip("necklace",""); gear.migrate_windstep({"flags":["windstep"],"charm_equipped":true})
	test.check(gear.slots.necklace.is_empty(),"An explicitly unequipped necklace is not silently equipped by legacy migration")
	for slot in ["torso","leggings","boots"]: gear.equip(slot,"kings_"+slot)
	test.check(is_equal_approx(gear.bonus("armor"),.12) and gear.bonus("health_regen")==0,"Three King pieces grant 12% defense without full-set regeneration")
	gear.equip("headwear","kings_headwear")
	test.check(is_equal_approx(gear.bonus("armor"),.16) and gear.incoming_damage(100)==84,"Four King pieces grant additive 16% damage reduction")
	game.player.restore_health(60); game.player.state="free"; gear.quiet_seconds=4; gear.heal_clock=0; game._refresh_simulation(); gear.tick(1)
	test.check(game.player.health==63,"Complete King's Armor regenerates three HP per second after a quiet period")
	gear.equip("boots",""); gear.tick(1)
	test.check(game.player.health==63 and gear.bonus("health_regen")==0,"Removing any King piece disables the set bonus immediately")
	gear.equip("headwear","phoenix")
	game.player.restore_health(100)
	gear.equip("ring1","echo_loop")
	var path="user://verification-magic-items.json"
	var saved=game.save_data()
	test.check(game.Save.write(saved,path)==OK and not game.Save.read(path).is_empty(),"Owned items, equipment and expanded health validate in private saves")
	gear.reset(); game.apply_skill_stats()
	test.check(game.apply_save(game.Save.read(path)) and gear.slots.headwear=="phoenix" and gear.phoenix_cooldown>0,"Save loading restores wearables, effects and Phoenix recharge")
	for mode in ["duplicate","wrong_slot","unknown","unowned","cooldown"]:
		var bad=saved.duplicate(true)
		match mode:
			"duplicate": bad.magic_items.slots.ring2=bad.magic_items.slots.ring1
			"wrong_slot": bad.magic_items.slots.boots="phoenix"
			"unknown": bad.magic_items.owned.append("fake_item")
			"unowned": bad.magic_items.owned.erase("phoenix")
			"cooldown": bad.magic_items.phoenix_cooldown=61
		game.Save.write(bad,path)
		test.check(game.Save.read(path).is_empty() and not game.apply_save(bad),"Invalid "+mode+" equipment is rejected without applying it")
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.start_new_game(false)
	test.check(gear.owned.is_empty() and gear.slots.is_empty() and game.player.max_health==100,"New Game removes magic equipment and restores baseline stats")
	game.load_map("coastal_path",Vector2(0,3),true)
