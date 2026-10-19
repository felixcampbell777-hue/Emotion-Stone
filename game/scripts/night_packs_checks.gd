extends RefCounted
func freeze(g:Node) -> void:
	g.player.set_physics_process(false);g.set_process(false);g.set_physics_process(false)
	for e in g.enemies:e.set_physics_process(false);e.ai_enabled=false
func drain(g:Node) -> void:
	# Actual streaming remains bounded to one model per tick in production.
	var clock=g.worldrise.clock;g.worldrise.clock=-1000
	for i in range(96):g.worldrise.tick(.001)
	g.worldrise.clock=clock
	freeze(g)
func run(test:RefCounted) -> void:
	var g=test.game;var r=g.worldrise
	g.start_new_game(false);g.title_screen.hide();g._refresh_simulation();drain(g)
	var boars=r.packs.boars_00;var wolves=r.packs.values().filter(func(p):return p.spec.kind=="beta_wolf")[0]
	if not wolves.active:r.spawn_pack(wolves)
	drain(g)
	freeze(g);var boar_count=boars.members.size();var wolf_count=wolves.members.size();var original=boars.members[0];original.health=31
	r.day_clock=599.99;r.tick(.02);drain(g)
	test.check(boars.members.size()==boar_count*2 and wolves.members.size()==wolf_count*2,"Night doubles both already loaded boar herds and wolf packs")
	test.check(original in boars.members and original.health==31,"Night reinforcements preserve the original animals and existing damage")
	var extra=boars.members.filter(func(e):return String(e.definition.id).ends_with("_night"))[0];extra.health=27;var extra_id=String(extra.definition.id)
	r.day_clock=1079.99;r.tick(.02);drain(g)
	test.check(boars.members.size()==boar_count and wolves.members.size()==wolf_count and original.health==31,"Dawn removes only extra night members without healing the daytime pack")
	r.day_clock=600;r.refresh_population();drain(g)
	var returned=boars.members.filter(func(e):return e.definition.id==extra_id)[0]
	test.check(returned.health==27,"A night member retains its damage across dawn and the next night")
	returned.take_damage(99999,Vector3.ZERO);var xp=g.progression.xp
	r.day_clock=0;r.refresh_population();r.day_clock=600;r.refresh_population();drain(g)
	test.check(not boars.members.any(func(e):return e.definition.id==extra_id) and g.progression.xp==xp,"Night cycling cannot resurrect a defeated extra or duplicate its XP")
	r.remember_all();var path="user://night-packs-verification.json";var data=g.save_data()
	test.check(g.Save.write(data,path)==OK and not g.Save.read(path).is_empty() and g.apply_save(g.Save.read(path)),"Strict saves accept stable night-enemy identities, health, loot and defeat records")
	freeze(g);r.day_clock=600
	var distant=r.packs.values().filter(func(p):return not p.active and p.spec.kind=="library_boar")[0]
	r.spawn_pack(distant);drain(g)
	test.check(distant.members.size()==int(distant.spec.count)*2,"Packs first streamed in during night spawn at twice their daytime size")
	g.load_map("wr_boss_chamber",Vector2(0,36),true);g.current_world.set_physics_process(false)
	test.check(g.enemies.is_empty() and g.current_world.encounter=="waiting","Night population does not multiply or prematurely spawn the Elder boss")
	if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
