extends SceneTree
## Compare server numeric proxy against the actual playable Actor and existing builders.
const Stats=preload("res://scripts/network/wr_actor_stats.gd")
const Profiles=preload("res://scripts/weapon_profiles.gd")
var failures=[]
var count=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
	count+=1
	if not ok:failures.append(message);push_error(message)
func equivalent(a:Variant,b:Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a))==JSON.parse_string(JSON.stringify(b))
func run() -> void:
	var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);await process_frame;await process_frame
	g.game_mode="world_rise";g.start_new_game(false);g.title_screen.hide();g._refresh_simulation();g.set_process(false);g.set_physics_process(false);g.player.set_physics_process(false)
	for e in g.enemies:e.set_physics_process(false);e.ai_enabled=false
	g.progression.xp=10000000;g.progression.greatsword_kills=1000
	for id in ["iron_body","iron_body","honed_arms","swiftfoot","dash","streaming_dash","lightstep","belly_roll","roly_poly","speed_freak","great_greatsword","great_greatsword","charge_thrust","fast_thrust","basher","basher","basher","devastating_blade"]:
		check(g.progression.learn(id),"Actual progression learns "+id)
	for item in ["standard_greatsword","field_spear","duelist_rapier","hunting_bow"]:
		if item not in g.magic_items.owned:g.magic_items.owned.append(item)
		g.magic_items.weapon_id=item;g.player.weapon_type=Profiles.kind(item);g.player.weapon_runtime.equip(item);g.apply_skill_stats()
		var proxy=Stats.build({"progression":g.progression.snapshot(),"magic_items":g.magic_items.snapshot()})
		for field in ["max_health","max_stamina","walk_speed","dash_distance_multiplier","dash_stamina_multiplier","jump_stamina_multiplier"]:
			check(is_equal_approx(float(g.player.get(field)),float(proxy[field])),item+" actual Actor stat matches authority: "+field)
		check(equivalent(g.player.combat,proxy.combat),item+" actual combat dictionary matches authority")
		if item!="standard_greatsword":check(equivalent(g.player.weapon_runtime.settings,proxy.weapon),item+" actual weapon tuning matches authority")
	var equipment={"ring1":"starfall_band","torso":"stormweave","leggings":"hunter","boots":"gale","headwear":"lantern","necklace":"cruel_charm"}
	for id in equipment.values():
		if id not in g.magic_items.owned:g.magic_items.owned.append(id)
	g.magic_items.slots=equipment
	for item in ["improved_standard_greatsword","field_spear"]:
		if item not in g.magic_items.owned:g.magic_items.owned.append(item)
		g.magic_items.weapon_id=item;g.player.weapon_type=Profiles.kind(item);g.player.weapon_runtime.equip(item);g.apply_skill_stats()
		var geared=Stats.build({"progression":g.progression.snapshot(),"magic_items":g.magic_items.snapshot()})
		for field in ["max_health","max_stamina","walk_speed"]:
			check(is_equal_approx(float(g.player.get(field)),float(geared[field])),item+" geared actual Actor matches authority: "+field)
		check(equivalent(g.player.combat,geared.combat),item+" geared health/regen/speed/melee/all-damage combat parity")
		check(is_equal_approx(g.magic_items.weapon_base(),geared.weapon_multiplier),item+" nondefault weapon multiplier matches authority")
		if item=="improved_standard_greatsword":check(is_equal_approx(geared.weapon_multiplier,1.6),"Improved Standard keeps actual 1.6 weapon base multiplier")
		else:check(equivalent(g.player.weapon_runtime.settings,geared.weapon),"Geared spear accepted strength/melee/all-damage tuning parity")
	g.magic_items.weapon_id="standard_greatsword";g.player.weapon_type="greatsword";g.player.weapon_runtime.equip("standard_greatsword");g.apply_skill_stats()
	var actor=g.player;actor.state="free";actor.health=actor.max_health;actor.simulation_enabled=true;actor.damage_authority=true;actor.input_enabled=false;actor.online_mode=true;actor.invulnerability=0
	check(actor.simulation_active(),"Online overlay keeps actual Actor simulation active")
	var hp=actor.health;check(actor.take_damage(7,Vector3.ZERO) and actor.health<hp,"Online overlay leaves actual Actor vulnerable")
	actor.state="parry";actor.state_time=0;actor.state_duration=1;actor.knockback=Vector3.ZERO;actor._physics_process(.02)
	check(actor.state_time>0,"Online overlay advances committed actual Actor action clock")
	actor.online_mode=false;actor.invulnerability=0;hp=actor.health;var clock=actor.state_time
	actor._physics_process(.02)
	check(not actor.simulation_active() and actor.state_time==clock,"Offline overlay freezes actual Actor action clock")
	check(not actor.take_damage(7,Vector3.ZERO) and actor.health==hp,"Offline overlay denies actual Actor damage")
	if g.audio!=null:check(await g.audio.shutdown_and_drain(),"Actual Actor fixture releases every mixer playback before exit")
	print("ACTOR_PARITY_CHECKS ",JSON.stringify({"checks":count,"failures":failures}))
	g.queue_free();call_deferred("finish",0 if failures.is_empty() else 1)
func finish(code:int) -> void:
	await process_frame
	await process_frame
	quit(code)
