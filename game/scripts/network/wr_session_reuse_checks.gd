extends SceneTree
## Real ENet/RPC lifetimes: durable leave/rejoin, one-peer loss, full server restart.
class StartupSession extends "res://scripts/network/wr_session.gd":
 var startup_count=0
 func _ready() -> void:
  startup_count+=1
  super._ready()
const Session=preload("res://scripts/network/wr_session.gd")
const Profile=preload("res://scripts/network/wr_profile.gd")
var checks=0
var failures:Array=[]
var server:Node
var first:Node
var remaining:Node
var snapshots=0
var joined=0
var port=25871
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func wait_for(test:Callable,seconds:float=12.0) -> bool:
 var deadline=Time.get_ticks_msec()+int(seconds*1000)
 while not test.call() and Time.get_ticks_msec()<deadline:await process_frame
 return test.call()
func ready_client(client:Node) -> bool:
 return client.connected and client.voice_udp!=null and client.voice_udp.is_ready()
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--port="):port=int(arg.trim_prefix("--port="))
 server=StartupSession.new();server.name="Server";root.add_child(server)
 first=Session.new();first.name="Traveller";first.checkpoint_path="user://reuse-first/character.json";root.add_child(first)
 remaining=Session.new();remaining.name="Remaining";remaining.checkpoint_path="user://reuse-remaining/character.json";root.add_child(remaining)
 first.joined.connect(func(_id):joined+=1)
 remaining.snapshot_received.connect(func(_snapshot):snapshots+=1)
 var identity=first.get_instance_id();var path=first.get_path();var index=first.get_index()
 first.owner=root
 first.password="reuse-fixture";remaining.password="reuse-fixture"
 check(server.start_server(port,"user://reuse-server","reuse-fixture")==OK,"real server starts")
 check(first.join("127.0.0.1",port)==OK and remaining.join("127.0.0.1",port)==OK,"two real clients begin authentication")
 var initial=await wait_for(func():return ready_client(first) and ready_client(remaining) and snapshots>=5)
 if not initial:print("REUSE_INITIAL_DIAGNOSTIC ",server.status," | ",first.status," | ",remaining.status," snapshots=",snapshots," voice=",first.voice_udp,"/",remaining.voice_udp)
 check(initial,"two profiles authenticate, snapshots and voice become ready")
 if not first.connected or not remaining.connected:finish();return
 var server_api=server._subtree_api;var remaining_api=remaining._subtree_api;var old_api=first._subtree_api
 var old_voice=first.voice_udp;var before=snapshots
 first.leave_server()
 check(await wait_for(func():return not first.connected,22),"normal durable departure completes")
 check(first.get_instance_id()==identity and first.get_path()==path and first.get_index()==index and first.owner==root,"natural retirement preserves Session identity/path/order/owner")
 check(first._subtree_api!=old_api and old_api.multiplayer_peer==null,"departed client retires old RPC scope and receives fresh API")
 await process_frame;await process_frame
 check(not is_instance_valid(old_voice) and first.voice_udp==null,"departed voice child drains and retires")
 check(server._subtree_api==server_api and remaining._subtree_api==remaining_api and remaining.connected and snapshots>before+5,"individual departure preserves server/remaining APIs and active snapshots")
 check(Profile.digest(first.local_profile)==Profile.digest(server.storage.data.characters[first.character_id]),"durable export exactly matches server checkpoint")
 old_api=first._subtree_api;first.password="wrong-fixture"
 check(first.join("127.0.0.1",port)==OK,"same Session starts deliberate rejected authentication")
 check(await wait_for(func():return first.status.begins_with("Rejected:")),"real server denies wrong password")
 check(first._subtree_api!=old_api and old_api.multiplayer_peer==null and not first.connecting,"rejected admission naturally retires cached RPC scope before immediate retry")
 first.password="reuse-fixture"
 check(first.join("127.0.0.1",port)==OK,"same Session begins rejoin")
 check(await wait_for(func():return ready_client(first) and server.members.size()==2),"same Session rejoins with fresh authenticated voice")
 check(joined==2,"public joined signal binding survives natural retirement")
 old_api=first._subtree_api;before=snapshots
 var peer_id=0
 for id in server.members:
  if server.members[id]==first.character_id:peer_id=int(id)
 server.peer.disconnect_peer(peer_id)
 check(await wait_for(func():return not first.connected),"unexpected server-side peer loss reaches client disconnect route")
 check(first._subtree_api!=old_api and old_api.multiplayer_peer==null,"unexpected loss naturally retires warm client RPC cache")
 await create_timer(.3).timeout
 check(server._subtree_api==server_api and remaining._subtree_api==remaining_api and remaining.connected and snapshots>before,"remaining peer stays live after another peer disconnects")
 # Simulate a reconnect request to reclaim its still-vulnerable disconnected body.
 first.reconnect_requested=true
 check(first.join("127.0.0.1",port)==OK,"same Session starts explicit reconnect after unexpected loss")
 check(await wait_for(func():return ready_client(first) and server.members.size()==2),"reconnect restores authenticated game and voice")
 first.reconnect_requested=false
 var old_server_api=server._subtree_api
 server.leave_server()
 check(await wait_for(func():return not first.connected and not remaining.connected),"whole-server stop reaches both client retirement routes")
 check(not server.server and server.authority==null and server.storage==null and server.voice_udp==null and server.peer==null and server._subtree_api!=old_server_api and old_server_api.multiplayer_peer==null,"whole server releases authority/store/voice/peer and retires transport without changing Session identity")
 await process_frame;await process_frame
 check(server.startup_count==1,"dedicated-style subclass one-time startup does not rerun on transport retirement")
 check(server.start_server(port,"user://reuse-server","reuse-fixture")==OK,"same server Session restarts and reacquires durable store")
 # Server shutdown is not a confirmed portable export; normal reconnect explicitly
 # chooses its authoritative checkpoint rather than overwriting it with stale data.
 first.reconnect_requested=true;remaining.reconnect_requested=true
 check(first.join("127.0.0.1",port)==OK and remaining.join("127.0.0.1",port)==OK,"both existing client Sessions explicitly reconnect to restarted server")
 var restarted=await wait_for(func():return ready_client(first) and ready_client(remaining))
 if not restarted:print("REUSE_RESTART_DIAGNOSTIC ",server.status," | ",first.status," | ",remaining.status," members=",server.members)
 check(restarted,"restarted transport authenticates both profiles and voice children")
 server.leave_server()
 await wait_for(func():return not first.connected and not remaining.connected)
 finish()
func finish() -> void:
 for node in [first,remaining,server]:
  if is_instance_valid(node):node.queue_free()
 await process_frame;await process_frame;await process_frame
 print("SESSION_REUSE_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
