extends RefCounted
func run(test: RefCounted) -> void:
	var game=test.game
	game.conversation.close()
	game.inventory.close()
	game.skill_tree.close()
	game.quest_stage="active"
	game.defeated_enemies=[]
	game.load_map("coastal_path",Vector2(0,3),true)
	var actor=game.player
	actor.input_enabled=true
	actor.restore_health(actor.max_health)
	actor.set_sword_drawn(true)
	actor.restore_stamina(actor.max_stamina)
	actor.invulnerability=0
	var emission={"count":0}
	var callback=func(_origin,_direction): emission.count+=1
	actor.lance_fired.connect(callback)
	actor.begin_water_lance()
	await test.frames(65)
	test.check(actor.take_damage(12,Vector3(0,0,-1)) and actor.state=="stagger","Successful damage staggers and interrupts the charging lance")
	test.check(actor.sword_material_backup.is_empty() and not is_instance_valid(actor.lance_charge_fx),"Interrupted lance immediately clears blade energy and aura")
	test.check(not actor.begin_water_lance() and not actor.begin_attack("light"),"Stagger prevents immediately restarting a spell or swing")
	await test.frames(210)
	test.check(actor.state=="free" and emission.count==0,"Interrupted lance returns to control and never fires later")
	actor.restore_stamina(actor.max_stamina)
	actor.invulnerability=1
	actor.begin_water_lance()
	await test.frames(8)
	test.check(not actor.take_damage(12,Vector3.ZERO) and actor.state=="lance_charge","Ignored damage cannot cancel a protected lance charge")
	actor.invulnerability=0
	test.check(not actor.take_damage(0,Vector3.ZERO) and actor.state=="lance_charge","Zero damage cannot trigger a stagger")
	actor.set_sword_drawn(true)
	actor.lance_fired.disconnect(callback)
	for id in ["slime_forest","herb_glade"]:
		game.load_map(id)
		for mob in game.enemies:
			mob.ai_enabled=false
		test.check(game.current_world.has_node("OldCobbledTrail") and game.current_world.get_node("OldCobbledTrail").multimesh.instance_count>100,"Weathered cobble geometry spans "+id)
		var clear=true
		for region in game.current_world.definition.terrain_regions:
			if region.kind=="cobble":
				clear=clear and game.current_world.safe_position(Vector3(region.rect[0]+1.5,0,region.rect[1]+.5))
		test.check(clear,"Cobble route is walkable from entrance to end in "+id)
	game.load_map("herb_glade",Vector2(0,8))
	for mob in game.enemies:
		mob.ai_enabled=false
	var warden=game.enemies[2]
	test.check(warden.health>0,"Corpse-loot fixture starts with a living warden")
	test.check(not game.loot_warden_core(),"Living warden has no lootable corpse")
	warden.open_armor()
	warden.take_damage(999,Vector3.ZERO)
	test.check(is_instance_valid(game.warden_remains) and game.warden_remains.component.visible,"Warden death creates collapsed remains with a visible alchemical core")
	test.check(not game.loot_warden_core(),"Corpse cannot be looted from across the map")
	game.player.position=game.warden_remains.position+Vector3(0,0,1)
	await test.frames(3)
	game.open_nearest()
	test.check(game.quest_stage=="component_ready" and not game.warden_remains.component.visible,"Nearby E interaction loots the core from the corpse")
	test.check(not game.loot_warden_core(),"Corpse core cannot be collected twice")
	var path="user://alchemy-verification.json"
	game.Save.write(game.save_data(),path)
	test.check(game.apply_save(game.Save.read(path)) and game.quest_stage=="component_ready" and not game.warden_remains.component.visible,"Core possession and depleted corpse survive save/load")
	var legacy=game.save_data()
	legacy.quest_stage="herbs_ready"
	game.Save.write(legacy,path)
	test.check(game.Save.read(path).get("quest_stage")=="component_ready","Previously collected herbs migrate to the replacement quest component")
	var impossible=legacy.duplicate(true)
	impossible.quest_stage="component_ready"
	impossible.defeated_enemies=[]
	game.Save.write(impossible,path)
	test.check(game.Save.read(path).is_empty(),"Un-earned saved core without a defeated warden is rejected")
	DirAccess.remove_absolute(path)
	game.load_map("home_downstairs",Vector2(-.1,-2.8))
	game.conversation.complete_quest()
	test.check(game.quest_stage=="completed","Mother accepts the alchemical core and completes the quest")
