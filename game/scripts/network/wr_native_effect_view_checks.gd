extends SceneTree
const Rise=preload("res://scripts/world_rise.gd")
class Floor extends Node3D:
	var bounds=Rect2(-64,-64,128,128)
	func ground_height(_at:Vector3) -> float:return 0.0
class Player extends Node3D:
	var health=100
	var slow_sources={}
	var combat=JSON.parse_string(FileAccess.get_file_as_string("res://content/combat.json"))
	func take_damage(amount:int,_away:Vector3) -> void:health-=amount
	func try_parry(_source:Node,_at:Variant=null) -> bool:return false
class Game extends Control:
	var game_mode="world_rise"
	var map_id="wr_boss_chamber"
	var gallery_mode=false
	var audio=null
	var current_world:Node3D
	var player:Node3D
	var menagery={"catalog":JSON.parse_string(FileAccess.get_file_as_string("res://content/menagery.json"))}
	func simulation_active() -> bool:return true
var failures=[]
func check(ok:bool,message:String) -> void:
	if not ok:failures.append(message);push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=Game.new();root.add_child(game);game.current_world=Floor.new();game.add_child(game.current_world);game.player=Player.new();game.current_world.add_child(game.player)
	var rise=Rise.new();rise.game=game
	var records={}
	for kind in ["elder_stone","rock_projectile","resin_gloop","menagery_projectile","menagery_hazard","ashfang_impact"]:
		records[kind]={"id":kind,"kind":kind,"floor":game.map_id,"position":[0,0,0],"direction":[0,0,1],"landing":[0,0,0],"age":.2,"life":9.8,"reflected":true,"sticky":false,"radius":2.0}
	rise.apply_authoritative_effects(records)
	check(rise.authoritative_effect_nodes.size()==6,"All authored native effect visuals appear")
	for node in rise.authoritative_effect_nodes.values():check(not node.is_physics_processing() and not node.is_processing(),"Observer effect has no autonomous gameplay clock")
	for i in range(4):await physics_frame
	check(game.player.health==100 and game.player.slow_sources.is_empty(),"Visible acknowledged hazards cannot apply local damage or sticky states")
	rise.apply_authoritative_effects(records)
	check(rise.authoritative_effect_nodes.size()==6,"Repeated snapshot reuses existing visual nodes")
	rise.apply_authoritative_effects({});await process_frame
	check(rise.authoritative_effect_nodes.is_empty(),"Missing server effects remove their visual nodes")
	var resin=load("res://scripts/menagery_enemy.gd").new();resin.set_physics_process(false);resin.game=game;resin.style="resin_slime";resin.player=game.player;game.current_world.add_child(resin)
	var trapped=Player.new();game.current_world.add_child(trapped);trapped.position=Vector3(4,0,2)
	check(resin.notice_trapped_target(trapped) and resin.player==trapped and resin.dash_target==trapped.position,"Resin charge binds the body actually trapped rather than another old target")
	resin.free();trapped.free()
	print("NATIVE_EFFECT_VIEW_CHECKS ",JSON.stringify({"checks":11,"failures":failures}))
	game.free();quit(0 if failures.is_empty() else 1)
