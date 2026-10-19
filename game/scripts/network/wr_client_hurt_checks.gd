extends SceneTree
## Production Main providers with the real prediction shadow and visible peer Actors.
const Hurt=preload("res://scripts/player_hurt.gd")
const Ballistics=preload("res://scripts/arrow_ballistics.gd")
const Bridge=preload("res://scripts/network/wr_actor_bridge.gd")
class SessionState extends Node:
	var active=true
	func online_session_active() -> bool:return active
var checks=0
var failures:Array=[]
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func region(actor:Node,name:String) -> Dictionary:
	for volume in Hurt.volumes(actor):
		if volume.region==name:return volume
	return {}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame;await process_frame
	game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide()
	game.set_process(false);game.set_physics_process(false);game.set_process_input(false);game.player.set_physics_process(false)
	for enemy in game.enemies:enemy.set_physics_process(false);enemy.ai_enabled=false
	var session=SessionState.new();game.add_child(session);game.network_session=session
	game.wr_session.character_id="client-hurt-self";game.player.entity_id="client-hurt-self"
	game.player.set_sword_drawn(false)
	var profile={"progression":game.progression.snapshot(),"magic_items":game.magic_items.snapshot(),"skill_loadout":{},"heavy_attack":"overhead"}
	game.prediction._create(profile)
	var shadow=game.prediction.bridge.actor
	game.prediction.bridge.set_pose(game.player.position,0,0)
	var friend_bridge=Bridge.new();friend_bridge.prediction_mode=true;friend_bridge.authoritative_simulation=false
	game.add_child(friend_bridge);friend_bridge.setup(game,profile,"client-hurt-friend")
	var friend=friend_bridge.actor
	friend.visible=true;friend.collision_layer=2;friend.collision_mask=0
	friend_bridge.set_pose(game.player.position+Vector3(3,0,0),0,0)
	game.online_view.remotes[friend.entity_id]=friend
	var other_world=Node3D.new();game.add_child(other_world)
	var wrong_bridge=Bridge.new();wrong_bridge.prediction_mode=true;wrong_bridge.authoritative_simulation=false
	game.add_child(wrong_bridge);wrong_bridge.setup(game,profile,"client-hurt-wrong-floor")
	wrong_bridge.actor.ground_world=other_world
	game.online_view.remotes[wrong_bridge.actor.entity_id]=wrong_bridge.actor
	await physics_frame
	var targets=game.combat_player_targets(shadow)
	check(shadow!=game.player and shadow.entity_id==game.player.entity_id,"Real prediction shadow is distinct but shares portable identity")
	check(targets==[friend],"Main excludes visible logical self and different-floor actors")
	check(game.combat_player_targets(game.player)==[friend],"Visible source excludes itself with same target semantics")
	check(game.prediction.bridge.combat_player_targets()==[friend],"Prediction bridge delegates to canonical Main target provider")
	var excluded=game.combat_player_exclusions(shadow)
	check(shadow.get_rid() in excluded and game.player.get_rid() in excluded,"Ray exclusions contain both real shadow and visible-self movement RIDs")
	check(friend.get_rid() not in excluded and wrong_bridge.actor.get_rid() not in excluded,"Exclusions do not blanket-ignore peers")
	check(game.prediction.bridge.combat_player_exclusions()==excluded,"Prediction bridge delegates identical ray exclusions")
	var space=game.player.get_world_3d().direct_space_state
	var lower=game.player.global_position+Vector3.UP*.6
	var self_ray=Ballistics.sweep(space,lower+Vector3.RIGHT*.4,lower-Vector3.RIGHT*.4,excluded,targets)
	check(self_ray.is_empty(),"Combined query ignores actual visible-self movement capsule")
	var head=region(game.player,"head")
	check(not head.is_empty(),"Actual visible native head volume exists")
	if not head.is_empty():
		self_ray=Ballistics.sweep(space,head.from+Vector3.RIGHT*.4,head.from-Vector3.RIGHT*.4,excluded,targets)
		check(self_ray.is_empty(),"Combined query ignores own visible head through real shadow provider")
	for name in ["head","torso","lower_body"]:
		var volume=region(friend,name)
		check(not volume.is_empty(),"Visible peer exposes "+name)
		if volume.is_empty():continue
		var center=(volume.from+volume.to)*.5
		var start=center+Vector3.BACK;var finish=center+Vector3.FORWARD
		var contact=Hurt.segment_contact(friend,start,finish)
		var query=Ballistics.sweep(space,start,finish,excluded,targets)
		check(not query.is_empty() and query.collider==friend,"Combined preview query reaches visible peer "+name)
		if not query.is_empty():check(contact.hit and query.position.distance_to(contact.point)<.000001,"Visible peer "+name+" matches shared authoritative contact point")
	friend.health=0
	check(game.combat_player_targets(shadow).is_empty(),"Dead peer is removed from hurt candidates")
	friend.health=friend.max_health
	friend.queue_free()
	check(game.combat_player_targets(shadow).is_empty(),"Queued peer is removed before its body is freed")
	game.online_view.clear()
	check(game.combat_player_targets(shadow).is_empty(),"Observer lifecycle clear removes all stale combat candidates")
	session.active=false
	check(game.combat_player_targets(shadow).is_empty(),"Offline mode retains no online hurt candidates")
	check(game.combat_player_exclusions(shadow)==[shadow.get_rid()],"Offline exclusions retain legacy source-only ray behavior")
	game.prediction.clear();friend_bridge.queue_free();wrong_bridge.queue_free();other_world.queue_free()
	if game.audio!=null:check(await game.audio.shutdown_and_drain(),"Audio playback drains before fixture exit")
	print("WR_CLIENT_HURT_CHECKS "+JSON.stringify({"checks":checks,"failures":failures}))
	game.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
