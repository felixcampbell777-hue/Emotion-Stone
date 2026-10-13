extends RefCounted
func run(test:RefCounted) -> void:
	var game=test.game
	game.progression.restore({"tree_version":2,"xp":0,"learned":[]})
	game.apply_skill_stats()
	game.defeated_enemies.clear()
	game.conversation.close()
	game.dialog.visible=false
	game.inventory.close()
	game.load_map("coastal_path",Vector2(-2,3),true)
	game._refresh_simulation()
	var travel={}
	for size in ["small","medium","large","giant"]:
		var enemy=game.Slime.new()
		enemy.configure({"id":"recoil_fixture","kind":"slime","at":[0,1],"size":size},game.player)
		game.world_root.add_child(enemy)
		enemy.ai_enabled=false
		enemy.take_sword_damage(1,Vector3(0,0,2),false)
		test.check(enemy.health==59 and is_zero_approx(enemy.knockback.y),"Sword hit applies damage and horizontal recoil for "+size)
		var light=enemy.knockback.length()
		test.check(enemy.sword_recoil_force(true)>=light,"Strong attacks recoil at least as much as light attacks for "+size)
		await test.frames(ceili(light/float(enemy.recoil_policy.deceleration)*60)+4)
		travel[size]=enemy.position.z-1
		test.check(enemy.knockback.is_zero_approx(),"Sword recoil decays to rest for "+size)
		enemy.free()
	test.check(travel.small>travel.medium and travel.medium>travel.large and travel.large>0 and is_zero_approx(travel.giant),"Actual collision-aware travel decreases Small > Medium > Large > Giant")
	var blocked=game.Slime.new()
	blocked.configure({"id":"wall_fixture","kind":"slime","at":[-5.8,-2.5],"size":"small"},game.player)
	game.world_root.add_child(blocked)
	blocked.ai_enabled=false
	blocked.take_sword_damage(1,Vector3(0,0,-1),true)
	await test.frames(60)
	test.check(blocked.position.z> -3.0,"Strong sword recoil stops at the cottage wall instead of passing through it")
	blocked.free()
	game.load_map("herb_glade",Vector2(0,14),true)
	for enemy in game.enemies: enemy.ai_enabled=false
	var warden=game.enemies[2]
	warden.knockback=Vector3.ZERO
	warden.take_sword_damage(5,Vector3(0,0,1),true)
	test.check(warden.health==90 and warden.knockback.is_zero_approx(),"Armored Giant rejects sword damage and recoil")
	warden.armor_open=5
	warden.take_sword_damage(5,Vector3(0,0,1),false)
	test.check(warden.health==85 and warden.knockback.is_zero_approx(),"Exposed Warden takes light damage without sword knockback")
	warden.take_sword_damage(5,Vector3(0,0,1),true)
	test.check(warden.health==80 and is_equal_approx(warden.knockback.length(),2.2),"Strong hit on exposed Warden applies the Giant weakspot recoil")
	var position_before=warden.position
	await test.frames(30)
	test.check(warden.position.z>position_before.z+.15,"Exposed Warden visibly recoils under a strong hit")
	warden.repel(Vector3(0,0,1),8,1)
	test.check(is_equal_approx(warden.knockback.length(),8),"Parry knockback remains independent of sword size resistance")
	# Exercise the real sword-contact dispatch, including the strong-hit flag.
	game.load_map("slime_forest",Vector2(0,3),true)
	var slime=game.enemies[0]
	slime.ai_enabled=false
	slime.position=Vector3(0,0,4.3)
	game.player.set_sword_drawn(true)
	game.player.state="heavy"
	game.player.state_duration=2.45
	game.player.visual.rotation.y=0
	game.player.blade_sweep_previous.clear()
	game.player._pose_sword("heavy",.66)
	game._attack_contact("heavy",Vector3(0,0,1),{})
	test.check(slime.health==15 and is_equal_approx(slime.knockback.length(),8.0),"Real heavy sword contact uses Medium strong recoil on the slime")
	game.player.set_sword_drawn(false)
	game.load_map("coastal_path",Vector2(0,3),true)
