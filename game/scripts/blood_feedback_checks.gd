extends SceneTree
const Blood=preload("res://scripts/blood_feedback.gd")
class Player extends Node:
	var max_health=100
class Game extends Control:
	var world_root:Node3D
	var camera:Camera3D
	var player:Node
	var image_view:TextureRect
	var active=true
	var online=false
	func online_session_active() -> bool:return online
	func simulation_active() -> bool:return active
var checks=0
var failures:Array=[]
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=Game.new();root.add_child(game)
	game.world_root=Node3D.new();game.add_child(game.world_root)
	game.camera=Camera3D.new();game.world_root.add_child(game.camera);game.camera.position=Vector3(0,1.5,5)
	game.player=Player.new();game.add_child(game.player)
	var world_children=game.world_root.get_child_count()
	var blood=Blood.new();game.add_child(blood);blood.configure(game);blood.level="full"
	await process_frame
	var hurt={"id":"player.hurt","actor_id":"self","action_id":"self:1","event_index":2,"at":Vector3.ZERO,"amount":20}
	check(blood.actor_event(hurt),"Accepted offline human hurt produces feedback")
	check(blood.vignette_remaining>0 and blood.overlay.visible,"Accepted local hurt gives a brief screen vignette")
	check(game.world_root.get_child_count()==world_children and blood.get_child_count()==0,"Blood feedback creates no world-space 3D objects")
	check(not blood.actor_event(hurt) and blood.accepted_hits==1,"Repeated accepted presentation does not duplicate blood")
	check(not blood.actor_event({"id":"enemy.hurt","amount":20}),"Enemy/slime hurt cannot trigger the local damage screen")
	game.online=true;hurt.event_index=3
	check(not blood.actor_event(hurt),"Online predicted/replayed Actor hurt is rejected before feedback")
	game.online=false;hurt.event_index=2
	game.active=false;var before=blood.vignette_remaining;blood._process(.1)
	check(blood.vignette_remaining==before,"Offline overlay simulation gate freezes feedback")
	game.active=true;blood._process(.5)
	check(blood.vignette_remaining==0 and not blood.overlay.visible and not blood.is_processing(),"Expired effects stop all active presentation work")
	blood.clear_feedback()
	var event={"id":"server-1","kind":"audio","event":"player.hurt","actor_id":"self","floor":"floor_01","position":[0,0,0],"amount":12}
	blood.snapshot_events([event],"self","floor_01",10)
	check(blood.vignette_remaining==0,"Initial snapshot suppresses pre-join historical hurt")
	blood.snapshot_events([event],"self","floor_01",11)
	check(blood.vignette_remaining==0,"Repeated historical event remains deduplicated")
	event.id="server-2";blood.snapshot_events([event],"self","floor_01",12)
	check(blood.vignette_remaining>0,"Fresh accepted local authoritative hurt gives vignette")
	before=blood.accepted_hits;event.id="server-stale";blood.snapshot_events([event],"self","floor_01",11)
	check(blood.accepted_hits==before,"Reordered snapshot cannot replay blood")
	blood._process(.5);event.id="remote-1";event.actor_id="friend"
	before=blood.accepted_hits;blood.snapshot_events([event],"self","floor_01",13)
	check(blood.accepted_hits==before and blood.vignette_remaining==0 and not blood.overlay.visible and not blood.is_processing(),"Remote human damage has no local screen effect or active work")
	before=blood.accepted_hits;event.id="wrong-floor";event.actor_id="self";event.floor="floor_02"
	blood.snapshot_events([event],"self","floor_01",14)
	check(blood.accepted_hits==before,"Wrong-floor damage is ignored")
	blood.level="reduced";blood.clear_feedback();blood.actor_event(hurt)
	check(blood.vignette_strength<=.15 and blood.overlay.visible,"Reduced mode keeps a faint screen edge cue")
	blood.level="off";blood.clear_feedback();blood.actor_event(hurt)
	check(not blood.overlay.visible and not blood.is_processing(),"Off mode creates no visible feedback or active work")
	blood.level="full";blood.clear_feedback();game.camera.position=Vector3(0,1.5,.05);blood.actor_event(hurt)
	check(blood.overlay.visible and game.world_root.get_child_count()==world_children,"First-person hurt remains entirely on screen")
	game.camera.position=Vector3(0,1.5,5);blood.clear_feedback()
	for index in range(40):
		hurt.event_index=index;blood.actor_event(hurt)
	check(game.world_root.get_child_count()==world_children and blood.get_child_count()==0 and blood.vignette_strength<=.32,"Repeated local hits remain bounded and never create any 3D effects")
	for index in range(600):blood._remember("bounded-%d"%index)
	check(blood.seen.size()==Blood.EVENT_LIMIT,"Damage event history remains bounded")
	blood.clear_feedback()
	check(blood.seen.is_empty() and not blood.snapshot_ready and not blood.is_processing(),"Lifecycle clear retires event history and effects")
	print("VERIFICATION_BLOOD_FEEDBACK_CHECKS "+JSON.stringify({"checks":checks,"failures":failures}))
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
