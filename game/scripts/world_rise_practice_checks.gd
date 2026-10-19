extends SceneTree
## Accepted contact practice and offline encounter-ledger regression; disposable userdata only.
const WorldRise=preload("res://scripts/world_rise.gd")
class Target extends Node3D:
	var definition={"id":"","kind":"beta_wolf"}
	var health=100
	var mob_category="canine"
	var reject=false
	var on_defeat:Callable
	func take_sword_damage(amount:int,_direction:Vector3,_strong:bool=false,_recoil:float=1.0) -> void:
		take_damage(amount,Vector3.ZERO)
	func take_damage(amount:int,_direction:Vector3) -> void:
		if reject or health<=0:return
		health=maxi(0,health-amount)
		if health==0 and on_defeat.is_valid():on_defeat.call()
var checks=0
var failures:Array=[]
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide();game._refresh_simulation()
	game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
	for enemy in game.enemies:enemy.set_physics_process(false);enemy.simulation_enabled=false
	var target=Target.new();game.world_root.add_child(target)
	target.definition.id=String(game.read_data("res://content/maps/wr_floor_01.json").enemies[0].id)
	var key=game.map_id+"/"+target.definition.id
	check(game.resolve_weapon_contact({"weapon_type":"spear","damage_kind":"projectile"},target,10,Vector3.ZERO),"Accepted spear contact records immutable practice")
	check(game.worldrise.practice_contributors.get(key,[])==["spear"],"Accepted nonlethal contribution is retained")
	target.reject=true
	check(not game.resolve_weapon_contact({"weapon_type":"bow","damage_kind":"projectile"},target,10,Vector3.ZERO),"Rejected contact does not deal damage")
	check(game.worldrise.practice_contributors.get(key,[])==["spear"],"Rejected contact rolls back newly staged weapon")
	target.reject=false
	var saved=game.worldrise.snapshot()
	check(WorldRise.valid(saved),"Partial encounter practice snapshot passes strict validation")
	game.worldrise.practice_contributors.clear();game.worldrise.restore(saved)
	check(game.worldrise.practice_contributors.get(key,[])==["spear"],"Practice survives world snapshot and restore")
	for invalid in [{"bad/encounter":["spear"]},{key:["spear","spear"]},{key:["unknown"]},{key:[]}]:
		check(not WorldRise.valid_practice_contributors(invalid),"Strict practice validator rejects malformed encounter or weapon set")
	target.on_defeat=func():game._award_weapon_practice(target,18)
	check(game.resolve_weapon_contact({"weapon_type":"rapier","damage_kind":"projectile"},target,1000,Vector3.ZERO),"Lethal accepted contact resolves synchronous award")
	check(game.progression.weapon_kills.spear==1 and game.progression.weapon_kills.rapier==1 and game.progression.weapon_kills.bow==0,"Each accepted used weapon receives one practice; rejected weapon receives none")
	check(not game.worldrise.practice_contributors.has(key),"Defeat consumes encounter practice ledger")
	game._award_weapon_practice(target,18)
	check(game.progression.weapon_kills.spear==1 and game.progression.weapon_kills.rapier==1,"Repeated award does not duplicate practice")
	target.health=10;target.on_defeat=func():game._award_weapon_practice(target,0)
	game.resolve_weapon_contact({"weapon_type":"greatsword","damage_kind":"projectile"},target,1000,Vector3.ZERO)
	check(game.progression.greatsword_kills==0 and not game.worldrise.practice_contributors.has(key),"Zero XP parent gives no practice and consumes its independent ledger")
	game.worldrise.practice_contributors[key]=["bow"]
	game.worldrise.practice_contributors["wr_boss_chamber/vault_elder"]=["greatsword"]
	game.worldrise.practice_contributors["wr_floor_02/"+String(game.worldrise.swamp.all_entries()[0].id)]=["spear"]
	game.worldrise.respawn_reset()
	check(not game.worldrise.practice_contributors.has(key) and not game.worldrise.practice_contributors.has("wr_boss_chamber/vault_elder") and game.worldrise.practice_contributors.size()==1,"Floor One rest clears local encounter practice and retains Floor Two")
	game.worldrise.swamp.respawn_reset()
	check(game.worldrise.practice_contributors.is_empty(),"Floor Two rest clears its local encounter practice")
	game.player.health=41;game.player.stamina=32
	game.gain_xp(1)
	check(game.player.health==41 and is_equal_approx(game.player.stamina,32),"Living XP stat refresh preserves current health and stamina without healing")
	game.progression.xp=int(game.progression.definition.level_thresholds[1]);game.apply_skill_stats()
	game.player.health=game.player.max_health;game.progression.xp=0;game.apply_skill_stats()
	check(game.player.health==game.player.max_health and game.player.health==100,"Reduced stat maximum only clamps living health downward")
	game.progression.xp=int(game.progression.definition.level_thresholds[1])-1
	game.apply_skill_stats();var old_max=game.player.max_health
	target.health=0;game._stage_weapon_practice(target,{"weapon_type":"bow"})
	var xp_before=game.progression.xp;var practice_before=game.progression.weapon_kills.bow
	game.player.health=0;game._player_defeated();var death_state=game.player.state
	game._enemy_defeated(key,"beta_wolf",target)
	check(game.progression.xp>xp_before and game.progression.weapon_kills.bow==practice_before+1,"Delayed qualified projectile kill still grants XP and immutable bow practice while dead")
	check(game.player.max_health>old_max and game.player.health==0,"Late level stat refresh updates maximum without reviving zero health")
	check(game.recovering and game.death_screen.visible and not game.player.input_enabled and game.player.state==death_state,"Late reward preserves death overlay action state and disabled controls")
	if game.audio!=null:check(await game.audio.shutdown_and_drain(),"Fixture drains actual mixer before exit")
	print("WORLD_RISE_PRACTICE_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
	game.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
