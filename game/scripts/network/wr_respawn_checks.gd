extends SceneTree
## Actual authority, canonical bodies, retained terrain and native enemy solids.
const Authority=preload("res://scripts/network/wr_authority.gd")
const Store=preload("res://scripts/network/wr_store.gd")
const Profile=preload("res://scripts/network/wr_profile.gd")
var failures:Array=[]
var checks=0
func check(value:bool,label:String) -> void:
 checks+=1
 if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func put(authority:RefCounted,p:Dictionary,at:Vector3,health:int) -> void:
 p.position=authority.arr(at);p.health=health;p.bridge.set_pose(at,p.yaw,p.pitch);p.bridge.actor.health=health;p.bridge.actor.state="free" if health>0 else "dead"
func run() -> void:
 create_timer(30).timeout.connect(func():print("WR_RESPAWN_TIMEOUT");quit(1))
 var store=Store.new();check(store.open("user://respawn-check"),"Disposable durable world opens")
 var host=Node.new();root.add_child(host)
 var authority=Authority.new();authority.attach(host);authority.configure(store)
 var key=Crypto.new().generate_rsa(2048)
 var a=Profile.new_profile(key.save_to_string(true));var b=Profile.new_profile(key.save_to_string(true))
 check(store.import_character(a).ok and store.import_character(b).ok,"Two disposable portable profiles accepted")
 var p=authority.add_player(a);var friend=authority.add_player(b)
 await physics_frame;await physics_frame
 var floor_id=String(p.floor);var runtime=authority.runtimes[floor_id];var origin=authority.vec(p.position)
 var excluded:Array[RID]=[p.bridge.actor.get_rid()]
 p.checkpoint[floor_id]=authority.arr(origin)
 put(authority,friend,origin,friend.max_health);put(authority,p,origin+Vector3(8,0,0),0)
 await physics_frame
 check(authority.action(p.id,"respawn").ok,"Occupied checkpoint respawns through production action")
 check(authority.vec(p.position).distance_to(origin)>=.65,"Respawn separates from stationary live peer")
 check(friend.position==authority.arr(origin),"Stationary friend is not displaced or reset")
 check(runtime.valid_player_position(authority.vec(p.position),4,excluded),"Respawn uses clear actual terrain and enemy solids")
 put(authority,friend,origin+Vector3(8,0,0),friend.max_health);put(authority,p,origin+Vector3(-8,0,0),0)
 var enemy=load("res://scripts/slime.gd").new()
 enemy.configure({"id":"respawn_obstruction","kind":"green_slime","at":[origin.x,origin.z]},p.bridge.actor)
 runtime.world_root.add_child(enemy);enemy.position=origin;enemy.set_physics_process(false)
 await physics_frame;await physics_frame
 check(not runtime.valid_player_position(origin,4,excluded),"Actual native enemy obstructs checkpoint capsule")
 check(authority.action(p.id,"respawn").ok,"Enemy-occupied checkpoint finds nearby clear position")
 check(authority.vec(p.position).distance_to(origin)>.69,"Respawn avoids actual native enemy solid")
 check(enemy.health==enemy.max_health,"Respawn preserves native enemy encounter")
 enemy.free()
 put(authority,p,origin+Vector3(-8,0,0),0);p.stamina=17.25;p.bridge.actor.stamina=17.25
 var before_position=p.position.duplicate();var before_checkpoint=p.checkpoint.duplicate(true)
 var wall=StaticBody3D.new();wall.collision_layer=1
 var collision=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(20,8,20);collision.shape=shape;wall.add_child(collision)
 runtime.world_root.add_child(wall);wall.position=origin+Vector3.UP*2
 await physics_frame;await physics_frame
 var result=authority.action(p.id,"respawn")
 check(not result.ok and not String(result.get("error","")).is_empty(),"Fully obstructed search fails explicitly")
 check(p.health==0 and p.bridge.actor.health==0,"Failed respawn preserves defeated health")
 check(p.stamina==17.25 and p.bridge.actor.stamina==17.25,"Failed respawn preserves resources")
 check(p.position==before_position and p.bridge.actor.position==authority.vec(before_position),"Failed respawn does not teleport")
 check(p.checkpoint==before_checkpoint,"Failed respawn preserves checkpoint")
 wall.free();store.stop_worker();host.free()
 await process_frame
 print("WR_RESPAWN_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
