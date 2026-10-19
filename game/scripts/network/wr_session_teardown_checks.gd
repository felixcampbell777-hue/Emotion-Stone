extends SceneTree
## Private multiplayer ownership must end before a removed Session's callbacks die.
const Session=preload("res://scripts/network/wr_session.gd")
var checks=0
var failures:Array=[]
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var default_api=root.multiplayer
 for mode in ["remove","free","queued"]:
  var session=Session.new();session.name="Session";root.add_child(session)
  var path=session.get_path();var api=session._subtree_api
  check(get_multiplayer(path)==api and api!=default_api,mode+": Session owns only its registered private subtree")
  session.leave_server()
  check(get_multiplayer(path)==api,mode+": normal alive-node disconnect retains API registration for reuse")
  var peer=ENetMultiplayerPeer.new();var result=peer.create_server(0)
  check(result==OK,mode+": actual ENet peer binds an isolated ephemeral port")
  if result==OK:session.peer=peer;api.multiplayer_peer=peer
  session.connected=true;session.connecting=true
  if mode=="remove":
   root.remove_child(session)
   check(not session.connected and not session.connecting,mode+": abrupt removal clears lifecycle flags")
   session.free()
  elif mode=="queued":
   session.queue_free();await process_frame
  else:session.free()
  check(get_multiplayer(path)==default_api,mode+": subtree registration no longer retains removed Session API")
  check(api.multiplayer_peer==null and peer.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED,mode+": private API detaches and closes actual peer before destruction")
  api.clear() # Must remain safely empty even when an external reference outlives the Node.
  api=null;peer=null
  await process_frame
 print("SESSION_TEARDOWN_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
