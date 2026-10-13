extends RefCounted
func run(test:RefCounted) -> void:
	var game=test.game
	var campaign=game.goblin_campaign
	game.start_new_game(false)
	game.home_intro_complete=true
	game.load_map("village_green",Vector2(0,-9.3),true)
	game.exit_cooldown=0
	await test.frames(4)
	test.check(game.map_id=="lark_farm","North town exit opens the independent farm route")
	test.check(game.npcs.size()==3,"The farm has three interactable family members")
	var rowan=game.current_world.interactions.filter(func(t): return t.id=="rowan")[0]
	game.conversation.show_character(rowan)
	game._refresh_simulation()
	test.check(game.conversation.choices.get_child(0).text.contains("recover"),"Farm dialogue offers the stolen harvest quest")
	game.conversation.choices.get_child(0).pressed.emit()
	test.check(campaign.stage=="active" and game.quest_stage=="not_started","Accepting farm campaign preserves Mother's independent quest")
	game.conversation.close()
	game.inventory.show_page("quests")
	test.check(game.inventory.slots.get_child(2).text.contains("Mother"),"Journal keeps Mother and northern campaign objectives separate")
	game.inventory.show_page("equipment")
	game.load_map("goblin_approach",Vector2(0,3),true)
	for enemy in game.enemies: enemy.ai_enabled=false
	await test.frames(3)
	var ray=PhysicsRayQueryParameters3D.create(Vector3(0,.8,0),Vector3(0,.8,-2),1)
	test.check(not game.player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Closed palisade physically blocks the north route")
	campaign.interact({"campaign_action":"gate_lever"})
	await test.frames(3)
	test.check(game.player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Winch removes gate collision without changing terrain")
	campaign.interact({"campaign_action":"alarm"})
	var rush=game.enemies.filter(func(e): return e.definition.id=="rush_left")[0]
	test.check(rush.dormant and not rush.visible,"Ambushers remain hidden before entering the trigger")
	game.player.position=Vector3(0,0,-4)
	game.player.input_enabled=false
	campaign.tick()
	test.check(rush.dormant,"Paused gameplay cannot trigger an ambush")
	game.player.input_enabled=true
	campaign.tick()
	test.check(not rush.dormant and rush.visible and rush.state_time>1.5,"Silenced alarm delays the revealed patrol")
	var xp=game.progression.xp
	rush.take_damage(9999,Vector3.RIGHT)
	test.check(game.progression.xp==xp+30,"A goblin kill gives its fixed XP reward")
	rush.take_damage(9999,Vector3.RIGHT)
	test.check(game.progression.xp==xp+30,"Repeated damage to a defeated goblin cannot duplicate XP")
	var sentry=game.enemies.filter(func(e): return e.definition.id=="sentry")[0]
	sentry.repel(Vector3.RIGHT,5,.8)
	test.check(sentry.state=="recover" and sentry.knockback.x==5,"Goblins respond to timed parry recoil")
	sentry.take_thrust_gust(Vector3.LEFT,2.5,.85)
	test.check(sentry.knockback.x<0 and sentry.state=="recover","Goblins receive size-scaled thrust gust interruption")
	# Exercise AI and projectile contact, rather than testing damage helpers alone.
	game.player.position=Vector3(0,0,7); game.player.invulnerability=0; game.player.state="free"
	sentry.position=Vector3(0,0,6.3); sentry.ai_enabled=true; sentry.knockback=Vector3.ZERO
	sentry.direction=Vector3.BACK; sentry.state="lunge"; sentry.state_time=.3; sentry.lunge_hit=false
	var hp=game.player.health
	sentry._physics_process(.016)
	test.check(game.player.health==hp-9,"Actual raider lunge contact damages the player")
	sentry.ai_enabled=false
	var slinger=game.enemies.filter(func(e): return e.definition.id=="lookout")[0]
	slinger.position=Vector3(2,0,7); slinger.ai_enabled=true; slinger.state="windup"; slinger.state_time=.001; slinger.direction=Vector3.LEFT
	slinger._physics_process(.016)
	var shot=game.projectiles.back()
	test.check(is_instance_valid(shot) and shot.damage==8,"Slinger wind-up creates a damaging rock projectile")
	shot._physics_process(.10)
	shot.repel(Vector3.RIGHT,1,.4)
	test.check(shot.reflected and shot.direction.x>0,"Parried goblin rocks reflect toward their thrower")
	slinger.ai_enabled=false
	game.player.restore_health(game.player.max_health)
	game.load_map("goblin_cave",Vector2(3,4),true)
	for enemy in game.enemies: enemy.ai_enabled=false
	await test.frames(2)
	campaign.interact({"campaign_action":"barricade","position":Vector3(.15,0,2.6)})
	test.check("barricade" not in campaign.flags,"Guarded barricade resists simple interaction")
	for enemy in game.enemies: enemy.take_damage(9999,Vector3.ZERO)
	campaign.interact({"campaign_action":"barricade","position":Vector3(.15,0,2.6)})
	test.check("barricade" in campaign.flags,"Cleared guards allow the barricade to be dismantled")
	xp=game.progression.xp
	campaign.interact({"campaign_action":"heirloom"})
	campaign.interact({"campaign_action":"heirloom"})
	test.check(game.progression.xp==xp+25,"Optional family keepsake grants discovery XP exactly once")
	game.load_map("goblin_depths",Vector2(0,4),true)
	for enemy in game.enemies: enemy.ai_enabled=false
	var foreman=game.enemies.filter(func(e): return e.definition.id=="foreman")[0]
	foreman.ai_enabled=true; foreman.state="lunge"; foreman.state_time=.001; foreman.lunge_hit=true; foreman.direction=Vector3.BACK
	foreman._physics_process(.016)
	test.check(foreman.state=="cleave_windup" and foreman.size_class=="large","Foreman chains his charge into a telegraphed cleave")
	foreman.repel(Vector3.LEFT,5,.8)
	foreman._physics_process(.016)
	test.check(foreman.state=="recover" and not foreman.ground_tell.visible,"Parry interrupts the foreman's follow-up cleave")
	foreman.ai_enabled=false
	campaign.interact({"campaign_action":"goods"})
	test.check(campaign.stage=="active","Foreman must be defeated before looting quest supplies")
	campaign.interact({"campaign_action":"windstep"})
	test.check("windstep" not in campaign.flags,"Hidden shrine treasure cannot be taken through its closed wall")
	campaign.interact({"campaign_action":"secret_wall"})
	campaign.interact({"campaign_action":"windstep"})
	var speed=game.player.walk_speed
	test.check(is_equal_approx(speed,2.88) and campaign.charm_equipped,"Found Windstep Charm auto-equips a twenty percent movement boost")
	game.apply_skill_stats()
	test.check(is_equal_approx(game.player.walk_speed,speed),"Repeated stat rebuilds never stack charm speed")
	campaign.toggle_charm()
	test.check(is_equal_approx(game.player.walk_speed,2.4),"Unequipping the charm removes its bonus")
	campaign.toggle_charm()
	for enemy in game.enemies: enemy.take_damage(9999,Vector3.ZERO)
	campaign.interact({"campaign_action":"goods"})
	test.check(campaign.stage=="goods_ready","Foreman defeat unlocks the stolen farm supply cache")
	campaign.interact({"campaign_action":"shortcut"})
	test.check(game.map_id=="lark_farm" and "shortcut" in campaign.flags,"Recovered key opens a return shortcut to the farm")
	campaign.interact({"campaign_action":"shortcut_back"})
	test.check(game.map_id=="goblin_depths","Unlocked supply tunnel works from farm back to vault")
	campaign.interact({"campaign_action":"shortcut"})
	rowan=game.current_world.interactions.filter(func(t): return t.id=="rowan")[0]
	game.conversation.show_character(rowan)
	xp=game.progression.xp
	game.conversation.choices.get_child(0).pressed.emit()
	test.check(campaign.stage=="completed" and game.progression.xp==xp+160,"Returning stolen supplies completes campaign and awards quest XP")
	game.conversation.menu()
	test.check(not game.conversation.choices.get_child(0).text.contains("Return the"),"Completed quest cannot pay again")
	game.conversation.close()
	game.player.position=Vector3(0,0,7)
	var saved=game.save_data()
	var path="user://verification-goblin-save.json"
	test.check(game.Save.write(saved,path)==OK and not game.Save.read(path).is_empty(),"Campaign, goblin defeats and charm survive private save validation")
	campaign.reset(); game.apply_skill_stats()
	test.check(game.apply_save(game.Save.read(path)) and campaign.stage=="completed" and campaign.charm_equipped,"Loading restores quest progress, secrets and equipped speed item")
	game.player.take_damage(9999,Vector3.RIGHT)
	game.respawn_player()
	test.check(game.map_id=="village_green" and campaign.stage=="completed" and campaign.charm_equipped,"Death and village respawn preserve farm quest and magic equipment")
	var bad=saved.duplicate(true); bad.goblin_campaign.flags.append("invented_flag")
	game.Save.write(bad,path)
	test.check(game.Save.read(path).is_empty() and not game.apply_save(bad),"Unknown campaign flags are rejected by file and direct load validation")
	bad=saved.duplicate(true); bad.defeated_enemies.erase("goblin_depths/foreman")
	game.Save.write(bad,path)
	test.check(game.Save.read(path).is_empty(),"Quest completion without foreman defeat is rejected")
	var legacy=saved.duplicate(true); legacy.erase("goblin_campaign")
	test.check(game.apply_save(legacy) and campaign.stage=="not_started" and not campaign.charm_equipped,"Legacy saves default to a fresh independent campaign")
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.start_new_game(false)
	test.check(campaign.stage=="not_started" and campaign.flags.is_empty() and is_equal_approx(game.player.walk_speed,2.4),"New Game clears campaign and speed item without writing player saves")
	game.load_map("coastal_path",Vector2(0,3),true)
