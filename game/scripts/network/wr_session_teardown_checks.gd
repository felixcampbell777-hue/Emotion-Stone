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
  var replacement:Node
  if mode=="free":
   replacement=Session.new();replacement.name="Session";root.add_child(replacement)
  await process_frame;await process_frame
  if is_instance_valid(replacement):
   check(get_multiplayer(path)==replacement._subtree_api,mode+": deferred old cleanup cannot unregister a same-path replacement")
   replacement.free();await process_frame;await process_frame
  check(get_multiplayer(path)==default_api,mode+": subtree registration no longer retains removed Session API")
  check(api.multiplayer_peer==null and peer.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED,mode+": private API detaches and closes actual peer after node-exit cache cleanup")
  api.clear() # Must remain safely empty even when an external reference outlives the Node.
  api=null;peer=null
  await process_frame
 var retiring=Session.new();retiring.name="Retiring";root.add_child(retiring)
 var retiring_path=retiring.get_path();var retiring_api=retiring._subtree_api
 var retiring_peer=ENetMultiplayerPeer.new()
 check(retiring_peer.create_server(0)==OK,"shutdown observer: actual isolated ENet transport starts")
 retiring.peer=retiring_peer;retiring_api.multiplayer_peer=retiring_peer
 retiring.tree_exited.connect(retiring.queue_free,CONNECT_ONE_SHOT)
 retiring.leave_server()
 check(not retiring.is_inside_tree() and retiring.is_queued_for_deletion(),"shutdown observer: real exit requesting deletion never re-adds Session")
 await process_frame;await process_frame
 check(not is_instance_valid(retiring) and get_multiplayer(retiring_path)==default_api and retiring_api.multiplayer_peer==null,"shutdown observer: deferred API and Node cleanup finish without transport resurrection")
 for mode in ["queued","removed/freed"]:
  var container=Node.new();container.name="LifecycleOwner";root.add_child(container)
  var child=Session.new();child.name="Session";container.add_child(child)
  var child_path=child.get_path();var child_api=child._subtree_api
  var child_peer=ENetMultiplayerPeer.new()
  check(child_peer.create_server(0)==OK,"parent "+mode+": isolated ENet transport starts")
  child.peer=child_peer;child_api.multiplayer_peer=child_peer
  child.tree_exited.connect(func():
   if mode=="queued":container.queue_free()
   else:
    # remove_child holds its parent locked until return; a real immediate free
    # inside this signal is illegal. Remove it now and free at the safe turn.
    root.remove_child(container);container.call_deferred("free"),CONNECT_ONE_SHOT)
  child.leave_server()
  check(not child.is_inside_tree() and child.is_queued_for_deletion(),"parent "+mode+": detached Session queues itself instead of resurrecting or orphaning")
  await process_frame;await process_frame
  check(not is_instance_valid(child) and not is_instance_valid(container) and get_multiplayer(child_path)==default_api and child_api.multiplayer_peer==null,"parent "+mode+": Node, parent and private transport all release")
 print("SESSION_TEARDOWN_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
