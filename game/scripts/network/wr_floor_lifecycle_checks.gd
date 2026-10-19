extends SceneTree
const Runtime=preload("res://scripts/network/wr_floor_runtime.gd")
class Enemy extends Node3D:
	var definition={"id":"lifecycle_mock"}
	var direction=Vector3.ONE
	var player:Variant
	var velocity=Vector3.ONE
	var lunge_hit=false
	var state="lunge"
	var state_time=.2
class Bridge extends Node:
	var actor:Variant
var failures=[]
func check(ok:bool,message:String) -> void:
	if not ok:failures.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var runtime=Runtime.new();root.add_child(runtime)
	runtime.world_root=Node3D.new();root.add_child(runtime.world_root)
	runtime.current_world=Node3D.new();runtime.world_root.add_child(runtime.current_world)
	var actor=Node3D.new();root.add_child(actor);actor.set_meta("character_id","departing")
	var friend=Node3D.new();root.add_child(friend);friend.set_meta("character_id","remaining")
	var enemy=Enemy.new();root.add_child(enemy);enemy.player=actor;runtime.enemies=[enemy]
	var effect=Node3D.new();runtime.world_root.add_child(effect);effect.set_meta("target_character","departing")
	var other_effect=Node3D.new();runtime.world_root.add_child(other_effect);other_effect.set_meta("target_character","remaining")
	runtime.players={"departing":actor,"remaining":friend};runtime.player=actor
	runtime.detach_player("departing")
	check(not runtime.players.has("departing") and runtime.players.has("remaining"),"Detach removes only departing registry before ownership frees")
	check(enemy.player==null and enemy.state=="recover" and enemy.lunge_hit,"Committed enemy contact cannot keep departed target")
	check(effect.is_queued_for_deletion() and not other_effect.is_queued_for_deletion(),"Only original target's bound effect is cancelled")
	check(runtime.player==friend and is_instance_valid(actor),"Canonical actor remains owner-owned; current target is live friend")
	actor.free()
	check(runtime.character_id(actor)=="","Freed instance never enters typed Node conversion")
	var stale=Node3D.new();root.add_child(stale);runtime.players["stale"]=stale;runtime.player=stale;enemy.player=stale;stale.free()
	runtime.prune_players()
	check(not runtime.players.has("stale") and enemy.player==null,"Late owner deletion is pruned safely and clears enemy reference")
	var bridge=Bridge.new();root.add_child(bridge);bridge.actor=friend;bridge.queue_free()
	runtime.sync_players([{"id":"remaining","floor":"","bridge":bridge}])
	check(runtime.players.is_empty() and runtime.player==null,"Queued bridge cannot retain actor registry")
	await process_frame
	runtime.sync_players([]);runtime.prune_players()
	check(runtime.character_id(actor)=="" and runtime.combat_players().is_empty(),"Repeated cleanup after free remains safe")
	enemy.state="idle";enemy.state_time=.2;enemy.direction=Vector3.ONE;enemy.lunge_hit=false
	runtime.restore_enemy_state(enemy,{"direction":{"vector3":[1,2]},"state":{},"state_time":{},"lunge_hit":"true"})
	check(enemy.direction==Vector3.ONE and enemy.state=="idle" and is_equal_approx(enemy.state_time,.2) and not enemy.lunge_hit,"Malformed native scalar/vector state is rejected before assignment/indexing")
	print("FLOOR_LIFECYCLE_CHECKS ",JSON.stringify({"checks":9,"failures":failures}))
	runtime.world_root.free();runtime.free();enemy.free();friend.free();quit(0 if failures.is_empty() else 1)
