extends Node
## ENet session. Install under its own multiplayer subtree for consistent RPC paths.
signal snapshot_received(snapshot:Dictionary)
signal profile_received(profile:Dictionary)
signal status_changed(message:String)
signal joined(character_id:String)
signal action_result(result:Dictionary)
signal action_requested(kind:String,payload:Dictionary,sequence:int)
signal voice_received(peer_id:int,channel:String,sequence:int,payload:PackedByteArray)
signal voice_status_changed(message:String)
const Profile=preload("res://scripts/network/wr_profile.gd")
const Store=preload("res://scripts/network/wr_store.gd")
const Authority=preload("res://scripts/network/wr_authority.gd")
const VoiceRelay=preload("res://scripts/voice/voice_relay.gd")
const StorageCodec=preload("res://scripts/network/wr_storage_codec.gd")
const VoiceUDP=preload("res://scripts/voice/voice_udp.gd")
const DEFAULT_PORT=24571
var authority:RefCounted
var storage:RefCounted
var peer:ENetMultiplayerPeer
var server=false
var character_id=""
var local_peer_id=0
var last_error=""
var status="Disconnected"
var password=""
var voice_udp:Node
var voice_port=0
var voice_token=PackedByteArray()
var voice_host=""
var owner_key:CryptoKey
var local_profile:Dictionary={}
var pending:Dictionary={}
var members:Dictionary={}
var rates:Dictionary={}
var reconnect_requested=false
var checkpoint_path="user://world-rise-portable/character.json"
var snapshot_clock=0.0
var checkpoint_clock=0.0
var lifecycle_clock=0.0
var input_sequence=0
var request_sequence=0
var connected=false
var connecting=false
var pending_export:Dictionary={}
var departure_waiting=false
var snapshot_parts:Dictionary={}
var last_snapshot_tick=-1
var pending_initial_join=false
var departures:Dictionary={}
var tick_samples:Array=[]
var interval_samples:Array=[]
var last_physics_usec=0
var max_physics_usec=0
var max_interval_usec=0
var input_diagnostics={"sent":0,"received":0,"accepted":0,"rate_rejected":0,"size_rejected":0,"validation_rejected":0,"per_peer":{}}
var transport_extrema:Dictionary={}
var profile_snapshot_saved:Dictionary={}
var snapshot_diagnostics={"raw_bytes":0,"compressed_bytes":0,"packets":0,"compress_usec":0,"compress_max_usec":0,"started_usec":Time.get_ticks_usec(),"per_peer":{}}
var voice_diagnostics={"incoming":0,"forwarded":0,"recipients":{},"last_sequence":{}}
var relay=VoiceRelay.new()
var data_dir=""
var _subtree_api:SceneMultiplayer
var _retiring_transport_scope=false
func _ready() -> void:_configure_subtree_api()
func _configure_subtree_api() -> void:
 _subtree_api=SceneMultiplayer.new();_subtree_api.allow_object_decoding=false;_subtree_api.server_relay=false
 get_tree().set_multiplayer(_subtree_api,get_path())
 # Engine RPC-cache callbacks run synchronously on tree_exited. Release the
 # private API afterward from a static callable that outlives this Node.
 tree_exited.connect(_release_subtree_api.bind(get_tree(),get_path(),_subtree_api),CONNECT_DEFERRED|CONNECT_ONE_SHOT)
 _subtree_api.peer_connected.connect(_peer_connected);_subtree_api.peer_disconnected.connect(_peer_disconnected)
 _subtree_api.connected_to_server.connect(_connected);_subtree_api.connection_failed.connect(_connection_failed)
 _subtree_api.server_disconnected.connect(_server_disconnected)
func _connection_failed() -> void:
 connecting=false;stop_voice_transport();_retire_transport_scope();report("Connection failed")
func _server_disconnected() -> void:
 connected=false;connecting=false;stop_voice_transport();_retire_transport_scope()
 if status.begins_with("Rejected:"):status_changed.emit(status)
 else:report("Server disconnected; portable checkpoint retained")
func report(message:String) -> void:
 status=message;last_error=message;status_changed.emit(message)
func online_session_active() -> bool:return connected
func ensure_character() -> bool:
 var directory=ProjectSettings.globalize_path(checkpoint_path.get_base_dir())
 if DirAccess.make_dir_recursive_absolute(directory)!=OK:report("Cannot create portable profile directory");return false
 var key_path=directory.path_join("owner.private.pem")
 owner_key=CryptoKey.new()
 if FileAccess.file_exists(key_path):
  if owner_key.load(key_path)!=OK:report("Cannot read owner credential; character was not replaced");return false
 else:
  owner_key=Crypto.new().generate_rsa(2048)
  if owner_key.save(key_path)!=OK:report("Cannot store owner credential");return false
 if FileAccess.file_exists(checkpoint_path):
  var loaded=StorageCodec.read_file(checkpoint_path,"character")
  if not loaded.ok:report(loaded.error);return false
  var value=loaded.data
  if not Profile.valid(value):report("Invalid portable profile; restore a known checkpoint");return false
  local_profile=value
  if local_profile.public_key!=owner_key.save_to_string(true):report("Owner credential does not match profile");return false
 else:
  local_profile=Profile.new_profile(owner_key.save_to_string(true))
  if not install_checkpoint(local_profile):return false
 character_id=local_profile.character_id
 return true
func local_host_available() -> bool:
 return OS.has_feature("editor")
func host(port:int=DEFAULT_PORT) -> Error:
 if not local_host_available():report("Host a world with the Docker dedicated server, then choose Join. Installed clients do not include local server tools.");return ERR_UNAVAILABLE
 if connecting or connected or server:return ERR_ALREADY_IN_USE
 if not ensure_character():return ERR_INVALID_DATA
 var result=start_server(port,"user://world-rise-server",password,"0.0.0.0")
 if result!=OK:return result
 var imported=storage.import_character(local_profile,reconnect_requested)
 if not imported.ok:
  peer.close();stop_voice_transport();server=false;authority=null;report(imported.error);return ERR_INVALID_DATA
 local_profile=imported.profile
 if not install_checkpoint(local_profile):peer.close();stop_voice_transport();server=false;authority=null;return ERR_CANT_CREATE
 if authority.add_player(local_profile).is_empty():peer.close();stop_voice_transport();server=false;authority=null;report("No safe arrival position available");return ERR_CANT_CREATE
 members[1]=character_id;local_peer_id=1;connected=true
 voice_token=Crypto.new().generate_random_bytes(32);voice_udp.add_member(1,voice_token,"127.0.0.1")
 joined.emit(character_id);report("Hosting World Rise on UDP %d"%port);return OK
func join(address:String,port:int=DEFAULT_PORT) -> Error:
 if not ensure_character():return ERR_INVALID_DATA
 return join_server(address,port,local_profile,"",password)
func start_server(port:int=DEFAULT_PORT,path:String="user://world-rise-server",server_password:String="",bind_address:String="127.0.0.1",configured_voice_port:int=0) -> Error:
 voice_port=port+1 if configured_voice_port==0 else configured_voice_port
 if port<1024 or port>65535 or voice_port<1024 or voice_port>65535 or voice_port==port:report("Choose distinct valid game/voice UDP ports (default game + 1)");return ERR_INVALID_PARAMETER
 storage=Store.new()
 if not storage.open(path):report(storage.last_error);return ERR_CANT_CREATE
 authority=Authority.new();authority.configure(storage)
 if authority.has_method("attach"):authority.attach(self)
 relay=VoiceRelay.new()
 reset_network_diagnostics()
 password=server_password;data_dir=storage.directory;server=true
 peer=ENetMultiplayerPeer.new();peer.set_bind_ip(bind_address)
 var result=peer.create_server(port,8,5)
 if result!=OK:
  peer.close();server=false;authority=null;report("Could not bind server UDP port");return result
 multiplayer.multiplayer_peer=peer
 create_voice_transport()
 var voice_error=voice_udp.start_server(voice_port,relay,bind_address)
 if voice_error!=OK:peer.close();server=false;authority=null;voice_udp.queue_free();voice_udp=null;report("Cannot bind voice UDP port %d"%voice_port);return voice_error
 report("Server listening on %s:%d; voice UDP %d; use trusted LAN/private VPN"%[bind_address,port,voice_port]);return OK
func join_server(address:String,port:int=DEFAULT_PORT,checkpoint:Dictionary={},_unused_owner_secret:String="",server_password:String="") -> Error:
 if connected or connecting or server:return ERR_ALREADY_IN_USE
 if checkpoint.is_empty():
  if not ensure_character():return ERR_INVALID_DATA
 else:local_profile=checkpoint
 if owner_key==null:
  if not ensure_character():return ERR_INVALID_DATA
 if address.length()>253 or port<1024 or port>65535:return ERR_INVALID_PARAMETER
 reset_network_diagnostics()
 password=server_password;server=false;last_snapshot_tick=-1;snapshot_parts.clear();input_sequence=0;request_sequence=0;pending_initial_join=false;departure_waiting=false;pending_export.clear();peer=ENetMultiplayerPeer.new()
 var result=peer.create_client(address,port,5)
 if result!=OK:report("Could not create network client");return result
 multiplayer.multiplayer_peer=peer;connecting=true;report("Connecting over trusted LAN/private VPN");return OK
func _connected() -> void:
 configure_gameplay_peer(peer.get_peer(1))
 local_peer_id=multiplayer.get_unique_id();report("Connected; authenticating character")
func _peer_connected(id:int) -> void:
 configure_gameplay_peer(peer.get_peer(id))
 if not server:return
 var nonce=Crypto.new().generate_random_bytes(32)
 pending[id]={"nonce":nonce,"deadline":Time.get_ticks_msec()+10000}
 _challenge.rpc_id(id,nonce)
@rpc("authority","call_remote","reliable",0)
func _challenge(nonce:PackedByteArray) -> void:
 if server or nonce.size()!=32:return
 var signature=Crypto.new().sign(HashingContext.HASH_SHA256,nonce.hex_encode().sha256_buffer(),owner_key)
 _authenticate.rpc_id(1,{"protocol":Profile.PROTOCOL,"content":Profile.content_digest(),"profile":local_profile,"signature":signature,"password_proof":(password.sha256_text()+nonce.hex_encode()).sha256_text(),"recover":reconnect_requested})
@rpc("any_peer","call_remote","reliable",0)
func _authenticate(message:Dictionary) -> void:
 if not server:return
 var sender=multiplayer.get_remote_sender_id()
 if not pending.has(sender) or Time.get_ticks_msec()>pending[sender].deadline or var_to_bytes(message).size()>262144:return reject(sender,"Authentication expired or oversized")
 var challenge:PackedByteArray=pending[sender].nonce;pending.erase(sender)
 if message.get("protocol")!=Profile.PROTOCOL:return reject(sender,"World Rise version mismatch. Update both client and server for progression tree 6; older servers cannot read upgraded characters.")
 if message.get("content")!=Profile.content_digest():return reject(sender,"World Rise content mismatch. Install matching client and server downloads.")
 if not Profile.valid(message.get("profile",{})):return reject(sender,"Invalid portable character; no checkpoint was replaced")
 var profile:Dictionary=message.profile;var signature=message.get("signature")
 if not signature is PackedByteArray or signature.size()>1024:return reject(sender,"Invalid proof")
 var key=CryptoKey.new();key.load_from_string(profile.public_key,true)
 if not Crypto.new().verify(HashingContext.HASH_SHA256,challenge.hex_encode().sha256_buffer(),signature,key):return reject(sender,"Character ownership proof failed")
 if not password.is_empty() and message.get("password_proof")!=(password.sha256_text()+challenge.hex_encode()).sha256_text():return reject(sender,"Incorrect server password")
 if members.size()>=8:return reject(sender,"Server is full (eight players)")
 if profile.character_id in members.values():return reject(sender,"Character already connected")
 if profile.character_id in storage.data.get("banned",[]):return reject(sender,"Character is banned from this world")
 var whitelist=storage.data.get("whitelist",{})
 if whitelist.get("enabled",false) and profile.character_id not in whitelist.get("characters",[]):return reject(sender,"Character is not on the world whitelist")
 var imported=storage.import_character(profile,bool(message.get("recover",false)))
 if not imported.ok:return reject(sender,imported.error)
 members[sender]=profile.character_id
 if authority.players.has(profile.character_id):
  var existing=authority.players[profile.character_id];existing.disconnected=0.0;existing.input={};existing.input_seq=-1;existing.input_received_seq=-1;existing.action_ack=0
  imported.profile=existing.profile
 else:
  if authority.add_player(imported.profile).is_empty():members.erase(sender);return reject(sender,"No safe arrival position available")
 var token=Crypto.new().generate_random_bytes(32)
 var remote_ip=peer.get_peer(sender).get_remote_address()
 if not voice_udp.add_member(sender,token,remote_ip):members.erase(sender);authority.release_player(profile.character_id);return reject(sender,"Could not authenticate voice membership")
 _accepted.rpc_id(sender,imported.profile,storage.data.world_id,token,voice_port)
func reject(id:int,message:String) -> void:
 _denied.rpc_id(id,message)
 pending.erase(id)
 if peer!=null:
  var rejected_peer=peer.get_peer(id)
  if rejected_peer!=null and rejected_peer.is_active():rejected_peer.peer_disconnect_later()
@rpc("authority","call_remote","reliable",0)
func _denied(message:String) -> void:
 connecting=false;stop_voice_transport();_retire_transport_scope();report("Rejected: "+message)
@rpc("authority","call_remote","reliable",0)
func _accepted(profile:Dictionary,_world_id:String,token:PackedByteArray,server_voice_port:int) -> void:
 if server or not Profile.valid(profile) or token.size()!=32 or server_voice_port<1024 or server_voice_port>65535:return
 voice_token=token.duplicate();voice_port=server_voice_port;voice_host=peer.get_peer(1).get_remote_address()
 character_id=profile.character_id;connecting=false;last_snapshot_tick=-1;snapshot_parts.clear()
 if not install_checkpoint(profile):pending_export=profile.duplicate(true);pending_initial_join=true;return
 local_profile=profile;connected=true;start_client_voice();joined.emit(character_id);report("World Rise connected")
func _peer_disconnected(id:int) -> void:
 pending.erase(id);departures.erase(id);relay.remove_peer(id);input_diagnostics.per_peer.erase(id);transport_extrema.erase(id)
 if voice_udp!=null:voice_udp.remove_member(id)
 for key in rates.keys():
  if String(key).begins_with(str(id)+"/"):rates.erase(key)
 if not server or not members.has(id):return
 var character=members[id];members.erase(id)
 if authority.players.has(character):authority.players[character].input={};authority.players[character].disconnected=15.0
func allowed(sender:int,lane:String,limit:int) -> bool:
 if not members.has(sender) or departures.has(sender):return false
 var now=Time.get_ticks_msec();var key=str(sender)+"/"+lane;var budget=rates.get(key,{"at":now,"count":0})
 if now-int(budget.at)>1000:budget={"at":now,"count":0}
 budget.count+=1;rates[key]=budget
 return int(budget.count)<=limit
func send_input(command:Dictionary) -> void:
 if not connected:return
 input_sequence+=1;input_diagnostics.sent+=1;command=command.duplicate(true);command.seq=input_sequence
 if server:authority.input(character_id,command)
 else:_submit_input.rpc_id(1,command)
@rpc("any_peer","call_remote","unreliable_ordered",1)
func _submit_input(command:Dictionary) -> void:
 var sender=multiplayer.get_remote_sender_id()
 if not server or not members.has(sender):return
 input_diagnostics.received+=1
 if not input_diagnostics.per_peer.has(sender):input_diagnostics.per_peer[sender]={"received":0,"accepted":0,"last_received_seq":-1,"last_accepted_seq":-1,"rate_rejected":0,"size_rejected":0,"validation_rejected":0}
 var sample=input_diagnostics.per_peer[sender];sample.received+=1;sample.last_received_seq=command.get("seq",-1) if command.get("seq",-1) is int else -1
 if not allowed(sender,"input",90):input_diagnostics.rate_rejected+=1;sample.rate_rejected+=1;return
 if var_to_bytes(command).size()>=1024:input_diagnostics.size_rejected+=1;sample.size_rejected+=1;return
 if authority.input(members[sender],command):input_diagnostics.accepted+=1;sample.accepted+=1;sample.last_accepted_seq=int(authority.players[members[sender]].input_received_seq)
 else:input_diagnostics.validation_rejected+=1;sample.validation_rejected+=1
func request_action(kind:String,payload:Dictionary={}) -> void:
 if not connected:return
 request_sequence+=1;action_requested.emit(kind,payload.duplicate(true),request_sequence)
 if server:
  authority.players[character_id].action_ack=request_sequence
  var result=authority.action(character_id,kind,payload);result["kind"]=kind;action_result.emit(result)
 else:_submit_action.rpc_id(1,request_sequence,kind,payload)
@rpc("any_peer","call_remote","reliable",2)
func _submit_action(sequence:int,kind:String,payload:Dictionary) -> void:
 var sender=multiplayer.get_remote_sender_id()
 if not server or not allowed(sender,"action",20) or kind.length()>24 or var_to_bytes(payload).size()>12288:return
 var key=str(sender)+"/last_action"
 if sequence<=int(rates.get(key,0)):return
 rates[key]=sequence
 authority.players[members[sender]].action_ack=sequence
 var before_revision=int(authority.players[members[sender]].profile.revision)
 var result=authority.action(members[sender],kind,payload)
 result["kind"]=kind
 _action_result.rpc_id(sender,result)
 if result.ok and int(authority.players[members[sender]].profile.revision)!=before_revision:_checkpoint.rpc_id(sender,authority.players[members[sender]].profile)
@rpc("authority","call_remote","reliable",2)
func _action_result(result:Dictionary) -> void:action_result.emit(result)
@rpc("authority","call_remote","reliable",2)
func _checkpoint(profile:Dictionary) -> void:
 if not server and Profile.valid(profile) and profile.character_id==character_id:
  if install_checkpoint(profile):local_profile=profile;profile_received.emit(profile)
  else:pending_export=profile.duplicate(true)
func install_checkpoint(profile:Dictionary) -> bool:
 if not Profile.valid(profile):report("Rejected invalid portable checkpoint");return false
 var target=ProjectSettings.globalize_path(checkpoint_path)
 if DirAccess.make_dir_recursive_absolute(target.get_base_dir())!=OK:report("Cannot create portable checkpoint directory");return false
 var encoded=StorageCodec.encode(profile,"character")
 if encoded.is_empty():report("Portable character exceeds its storage bound or contains unsupported data");return false
 var file=FileAccess.open(target+".pending",FileAccess.WRITE)
 if file==null:report("Cannot save received portable checkpoint; server retains recovery copy");return false
 file.store_string(encoded);file.flush();var error=file.get_error();file.close()
 if error!=OK:report("Portable checkpoint write failed; server retains recovery copy");return false
 var verified=StorageCodec.read_file(target+".pending","character")
 var check=verified.data
 if not verified.ok or not Profile.valid(check) or Profile.digest(check)!=Profile.digest(profile):report("Portable checkpoint verification failed");return false
 if FileAccess.file_exists(target):
  if DirAccess.copy_absolute(target,target+".previous.pending")!=OK:report("Cannot back up portable character");return false
  if DirAccess.rename_absolute(target+".previous.pending",target+".previous")!=OK:report("Cannot install portable backup");return false
 if DirAccess.rename_absolute(target+".pending",target)!=OK:report("Cannot install portable checkpoint");return false
 # Godot flush+atomic replacement works in installed clients without Python.
 # Server durability is the recovery authority; client directory fsync is not claimed.
 return true
func _physics_process(delta:float) -> void:
 if not server or authority==null:return
 var started=Time.get_ticks_usec()
 if last_physics_usec>0:
  var interval=started-last_physics_usec;interval_samples.append(interval);max_interval_usec=maxi(max_interval_usec,interval)
  if interval_samples.size()>600:interval_samples.pop_front()
 last_physics_usec=started
 authority.step(delta);snapshot_clock+=delta;checkpoint_clock+=delta;lifecycle_clock+=delta
 for departing_peer in departures.keys():
  var departure=departures[departing_peer]
  if not departure.profile.is_empty():
   if Time.get_ticks_msec()-int(departure.get("finalized_at",Time.get_ticks_msec()))>30000:
    if members.has(departing_peer):members.erase(departing_peer)
    relay.remove_peer(int(departing_peer));departures.erase(departing_peer)
    if voice_udp!=null:voice_udp.remove_member(int(departing_peer))
    peer.disconnect_peer(int(departing_peer))
   continue
  if authority.elapsed<float(departure.due):continue
  if not members.has(departing_peer):departures.erase(departing_peer);continue
  var departing_id=members[departing_peer]
  var final_profile=authority.save_departure(departing_id)
  if final_profile.is_empty():continue
  departure.profile=final_profile;departure["finalized_at"]=Time.get_ticks_msec()
  authority.release_player(departing_id)
  _departure_complete.rpc_id(int(departing_peer),final_profile)
 if snapshot_clock>=.05:
  var publish_started=Time.get_ticks_usec()
  snapshot_clock=0;var snapshot=authority.snapshot()
  authority.sample_stage("snapshot_build",Time.get_ticks_usec()-publish_started)
  snapshot["voice_roster"]={}
  for id in members:
   if not authority.players.has(members[id]):continue
   var voice_player=authority.players[members[id]]
   snapshot.players[voice_player.id]["peer_id"]=int(id)
   snapshot.voice_roster[int(id)]={"position":voice_player.position.duplicate(),"floor":voice_player.floor,"group":"friends"}
   relay.set_peer(int(id),authority.vec(voice_player.position),voice_player.floor,"friends")
  for id in members:
   if not authority.players.has(members[id]):continue
   var p=authority.players[members[id]];snapshot.players[p.id]["peer_id"]=int(id);relay.set_peer(int(id),authority.vec(p.position),p.floor,"friends")
   var filter_started=Time.get_ticks_usec()
   var personal=preload("res://scripts/network/wr_snapshot_filter.gd").personal(snapshot,p,authority)
   authority.sample_stage("recipient_filter",Time.get_ticks_usec()-filter_started)
   if int(id)==1:snapshot_received.emit(personal)
   else:send_snapshot(int(id),personal)
  authority.events.clear()
 if checkpoint_clock>=30:
  checkpoint_clock=0
  if authority.checkpoint_all():
   for id in members:
    if not authority.players.has(members[id]) or departures.has(id):continue
    var profile=authority.players[members[id]].profile
    if int(id)==1:local_profile=profile;install_checkpoint(profile);profile_received.emit(profile)
    else:_checkpoint.rpc_id(int(id),profile)
 if lifecycle_clock>=2:
  lifecycle_clock=0
  if not data_dir.is_empty():
   process_admin()
   var file=FileAccess.open(data_dir.path_join("ready.json"),FileAccess.WRITE)
   if file!=null:file.store_string(JSON.stringify({"ready":not authority.persistence_failed and storage.last_error.is_empty() and voice_udp!=null and voice_udp.is_ready(),"tick":authority.tick,"players":members.size(),"active_players":members.size()-departures.size(),"departing":departures.size(),"storage_error":storage.last_error,"unix":Time.get_unix_time_from_system(),"performance":performance_status(),"voice_port":voice_port,"voice_ready":voice_udp!=null and voice_udp.is_ready()}));file.close()
   if FileAccess.file_exists(data_dir.path_join("stop.request")):
    leave_server()
    if not server:get_tree().quit()
 for id in pending.keys():
  if Time.get_ticks_msec()>pending[id].deadline:reject(int(id),"Authentication timed out")
 var duration=Time.get_ticks_usec()-started;tick_samples.append(duration);max_physics_usec=maxi(max_physics_usec,duration)
 if tick_samples.size()>600:tick_samples.pop_front()
func performance_status() -> Dictionary:
 var ordered=tick_samples.duplicate();ordered.sort()
 var intervals=interval_samples.duplicate();intervals.sort()
 var snapshot_report=snapshot_diagnostics.duplicate(true);snapshot_report["elapsed_seconds"]=(Time.get_ticks_usec()-int(snapshot_diagnostics.started_usec))/1000000.0
 return {"physics_ms_p95":float(ordered[mini(ordered.size()-1,floori(ordered.size()*.95))])/1000 if not ordered.is_empty() else 0,"physics_ms_max":max_physics_usec/1000.0,"physics_ms_window_max":float(ordered[-1])/1000.0 if not ordered.is_empty() else 0,"interval_ms_p95":float(intervals[mini(intervals.size()-1,floori(intervals.size()*.95))])/1000 if not intervals.is_empty() else 0,"interval_ms_max":max_interval_usec/1000.0,"interval_ms_window_max":float(intervals[-1])/1000.0 if not intervals.is_empty() else 0,"commit_ms_last":storage.last_commit_usec/1000.0,"commit_ms_max":storage.max_commit_usec/1000.0,"commit_stages":storage.last_commit_stages.duplicate(true),"sample_count":ordered.size(),"snapshots":snapshot_report,"voice":voice_diagnostics.duplicate(true),"stages":authority.stage_status(),"network":network_diagnostics(),"pvp":authority.pvp_diagnostics.duplicate(true)}
func process_admin() -> void:
 var path=data_dir.path_join("admin.request.json")
 if not FileAccess.file_exists(path):return
 var file=FileAccess.open(path,FileAccess.READ)
 if file==null:return
 if file.get_length()>8192:file.close();DirAccess.remove_absolute(path);return
 var request=JSON.parse_string(file.get_as_text());file.close();DirAccess.remove_absolute(path)
 if not request is Dictionary:return
 var op=String(request.get("op",""));var id=String(request.get("character",""));var result={"id":String(request.get("id","")).left(64),"ok":false,"op":op}
 if op=="status":result.ok=true;result["players"]=members.duplicate();result["world_id"]=storage.data.world_id;result["storage_error"]=storage.last_error;result["voice_port"]=voice_port;result["voice_ready"]=voice_udp!=null and voice_udp.is_ready()
 elif op=="save":result.ok=authority.checkpoint_all();result["error"]=storage.last_error
 elif op in ["kick","ban"] and Profile.identifier(id):
  if op=="ban":
   var next=storage.data.duplicate(true)
   if not next.has("banned"):next.banned=[]
   if id not in next.banned:next.banned.append(id)
   result.ok=storage.commit(next)
  else:result.ok=true
  if result.ok:
   for peer_id in members.keys():
    if members[peer_id]==id and int(peer_id)!=1:peer.disconnect_peer(int(peer_id))
 elif op=="whitelist":
  var characters=request.get("characters",[]);var valid=characters is Array and characters.size()<=256 and request.get("enabled") is bool
  if valid:
   for character in characters:
    if not Profile.identifier(character):valid=false
  if valid:
   var next=storage.data.duplicate(true);next.whitelist={"enabled":request.enabled,"characters":characters.duplicate()};result.ok=storage.commit(next)
 elif op=="restart":
  result.ok=authority.checkpoint_all()
  if result.ok:
   var stop=FileAccess.open(data_dir.path_join("stop.request"),FileAccess.WRITE)
   if stop!=null:stop.store_string("admin restart");stop.close()
 var output=FileAccess.open(data_dir.path_join("admin.result.json"),FileAccess.WRITE)
 if output!=null:output.store_string(JSON.stringify(result));output.flush();output.close()
func send_snapshot(recipient:int,snapshot:Dictionary) -> void:
 # ENet can finish disconnecting between the last roster update and this tick.
 if peer==null or recipient not in multiplayer.get_peers():return
 var recipient_peer=peer.get_peer(recipient)
 if recipient_peer==null or recipient_peer.get_state()!=ENetPacketPeer.STATE_CONNECTED:return
 var started=Time.get_ticks_usec();var raw=var_to_bytes(snapshot)
 if members.size()==8 and authority.tick>=600 and OS.get_environment("WORLD_RISE_PROFILE_RUNTIME")=="1" and OS.get_environment("WORLD_RISE_PROFILE_SNAPSHOT")=="1":
  var capture_floor=String(snapshot.players.get(members.get(recipient,""),{}).get("floor","unknown"))
  if not profile_snapshot_saved.has(capture_floor):
   var capture=FileAccess.open(data_dir.path_join("profile-snapshot-"+capture_floor+".bin"),FileAccess.WRITE)
   if capture!=null:capture.store_buffer(raw);capture.close();profile_snapshot_saved[capture_floor]=true
 var packed=preload("res://scripts/network/wr_snapshot_codec.gd").encode_raw(raw)
 if packed.is_empty():return
 var spent=Time.get_ticks_usec()-started;snapshot_diagnostics.raw_bytes+=raw.size();snapshot_diagnostics.compressed_bytes+=packed.size();snapshot_diagnostics.packets+=1;snapshot_diagnostics.compress_usec+=spent;snapshot_diagnostics.compress_max_usec=maxi(int(snapshot_diagnostics.compress_max_usec),spent);snapshot_diagnostics.per_peer[recipient]=int(snapshot_diagnostics.per_peer.get(recipient,0))+packed.size()
 var count=ceili(float(packed.size())/900.0)
 if count>128:return
 for index in range(count):_receive_chunk.rpc_id(recipient,int(snapshot.tick),index,count,packed.slice(index*900,mini(packed.size(),(index+1)*900)))
@rpc("authority","call_remote","unreliable",3)
func _receive_chunk(frame:int,index:int,count:int,chunk:PackedByteArray) -> void:
 if server or not connected or frame<=last_snapshot_tick or count<1 or count>128 or index<0 or index>=count or chunk.size()>900:return
 for old in snapshot_parts.keys():
  if int(old)<frame-6:snapshot_parts.erase(old)
 if not snapshot_parts.has(frame):snapshot_parts[frame]={"count":count,"pieces":{}}
 var assembly=snapshot_parts[frame]
 if assembly.count!=count:return
 assembly.pieces[index]=chunk
 if assembly.pieces.size()!=count:return
 var packet=PackedByteArray()
 for piece in range(count):packet.append_array(assembly.pieces[piece])
 var snapshot=preload("res://scripts/network/wr_snapshot_codec.gd").decode(packet)
 if not snapshot.is_empty() and snapshot.get("tick")==frame:last_snapshot_tick=frame;snapshot_received.emit(snapshot)
 snapshot_parts.erase(frame)
func stop_voice_transport() -> void:
 if voice_udp!=null:voice_udp.stop();voice_udp.queue_free();voice_udp=null
 voice_token=PackedByteArray();voice_host=""
func create_voice_transport() -> void:
 if voice_udp!=null:voice_udp.stop();voice_udp.queue_free()
 voice_udp=VoiceUDP.new();add_child(voice_udp)
 voice_udp.frame_received.connect(func(sender:int,channel:String,sequence:int,payload:PackedByteArray):voice_received.emit(sender,channel,sequence,payload))
 voice_udp.status_changed.connect(func(message:String):voice_status_changed.emit(message))
func start_client_voice() -> void:
 create_voice_transport()
 var result=voice_udp.start_client(voice_host,voice_port,local_peer_id,voice_token)
 if result!=OK:voice_status_changed.emit("Voice UDP unavailable; game connection remains active")
func send_voice(channel:String,sequence:int,payload:PackedByteArray) -> void:
 if not connected or voice_udp==null:return
 voice_udp.send_frame(channel,sequence,payload)
@rpc("any_peer","call_remote","unreliable",4)
func _voice(channel:String,sequence:int,payload:PackedByteArray) -> void:
 pass # Voice is accepted only on the authenticated dedicated UDP transport.
func relay_voice(sender:int,channel:String,sequence:int,payload:PackedByteArray) -> void:
 voice_diagnostics.incoming+=1
 var recipients=relay.recipients(sender,channel,sequence,payload,Time.get_ticks_msec())
 voice_diagnostics.last_sequence[sender]=sequence
 for recipient in recipients:
  voice_diagnostics.forwarded+=1;voice_diagnostics.recipients[recipient]=int(voice_diagnostics.recipients.get(recipient,0))+1
  if recipient==1:voice_received.emit(sender,channel,sequence,payload)
  else:_receive_voice.rpc_id(recipient,sender,channel,sequence,payload)
@rpc("authority","call_remote","unreliable",4)
func _receive_voice(sender:int,channel:String,sequence:int,payload:PackedByteArray) -> void:voice_received.emit(sender,channel,sequence,payload)
func disconnect_session() -> void:leave_server()
func leave_server() -> void:
 if connecting and not connected:
  connecting=false
  _retire_transport_scope()
  report("Connection cancelled");return
 if server and authority!=null:
  if not authority.checkpoint_all():report("Cannot stop: "+storage.last_error);return
  for id in members:
   if not authority.players.has(members[id]) or departures.has(id):continue
   var profile=authority.players[members[id]].profile
   if profile.is_empty():report("Cannot stop: "+storage.last_error);return
   if int(id)==1 and not profile.is_empty():local_profile=profile;install_checkpoint(profile)
   elif not profile.is_empty():_checkpoint.rpc_id(int(id),profile)
  for id in authority.players.keys():authority.release_player(id)
  for runtime in authority.runtimes.values():runtime.queue_free()
  stop_voice_transport()
  authority=null;storage=null;server=false;connected=false;members.clear();departures.clear();_retire_transport_scope();report("Server stopped after checkpoint")
 elif connected:_depart.rpc_id(1)
 elif peer!=null:_retire_transport_scope()
@rpc("any_peer","call_remote","reliable",2)
func _depart() -> void:
 var sender=multiplayer.get_remote_sender_id()
 if not server or not members.has(sender):return
 if departures.has(sender):
  if not departures[sender].profile.is_empty():_departure_complete.rpc_id(sender,departures[sender].profile)
  return
 var id=members[sender]
 authority.players[id].input={};authority.players[id]["departing"]=true
 departures[sender]={"due":authority.elapsed+15.0,"profile":{}}
 _action_result.rpc_id(sender,{"ok":true,"message":"Disconnecting: body remains vulnerable for fifteen seconds; final character export follows."})
@rpc("authority","call_remote","reliable",2)
func _departure_complete(profile:Dictionary) -> void:
 if install_checkpoint(profile):
  local_profile=profile;_export_ack.rpc_id(1,Profile.digest(profile));report("Checkpoint stored; confirming departure")
 else:pending_export=profile.duplicate(true);departure_waiting=true
@rpc("any_peer","call_remote","reliable",2)
func _export_ack(digest:String) -> void:
 var sender=multiplayer.get_remote_sender_id()
 if not server or not members.has(sender):return
 var id=members[sender]
 if not departures.has(sender) or departures[sender].profile.is_empty() or Profile.digest(departures[sender].profile)!=digest:return
 _export_closed.rpc_id(sender)
 departures.erase(sender);members.erase(sender);relay.remove_peer(sender)
 if voice_udp!=null:voice_udp.remove_member(sender)
@rpc("authority","call_remote","reliable",2)
func _export_closed() -> void:
 connected=false;connecting=false
 stop_voice_transport()
 _retire_transport_scope()
 report("Character exported; disconnected")
func retry_checkpoint_install() -> bool:
 if pending_export.is_empty():return true
 if not install_checkpoint(pending_export):return false
 local_profile=pending_export.duplicate(true);pending_export.clear()
 if departure_waiting:
  departure_waiting=false;_export_ack.rpc_id(1,Profile.digest(local_profile));report("Checkpoint stored; confirming departure")
 elif pending_initial_join:
  pending_initial_join=false
  if peer!=null and peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED:connected=true;start_client_voice();joined.emit(character_id);profile_received.emit(local_profile)
  else:report("Checkpoint installed; reconnect to resume character")
 else:profile_received.emit(local_profile)
 return true

func reset_network_diagnostics() -> void:
 input_diagnostics={"sent":0,"received":0,"accepted":0,"rate_rejected":0,"size_rejected":0,"validation_rejected":0,"per_peer":{}};transport_extrema.clear()
func network_diagnostics() -> Dictionary:
 var result={"input":input_diagnostics.duplicate(true),"peers":{}}
 if peer==null or peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:return result
 for id in multiplayer.get_peers():
  var connection=peer.get_peer(id)
  if connection==null or not connection.is_active():continue
  var sample={"throttle":connection.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE),"limit":connection.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_LIMIT),"rtt_ms":connection.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME),"variance_ms":connection.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME_VARIANCE),"loss_scaled":connection.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS),"acceleration":connection.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_ACCELERATION),"deceleration":connection.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_DECELERATION),"interval_ms":connection.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_INTERVAL)}
  if not transport_extrema.has(id):transport_extrema[id]={"throttle_min":32,"limit_min":32,"rtt_max_ms":0}
  var extremes=transport_extrema[id];extremes.throttle_min=minf(extremes.throttle_min,sample.throttle);extremes.limit_min=minf(extremes.limit_min,sample.limit);extremes.rtt_max_ms=maxf(extremes.rtt_max_ms,sample.rtt_ms)
  sample.merge(extremes);result.peers[id]=sample
 return result
func _retire_transport_scope() -> void:
 # Retire only an entire transport, never an individual server member. A real
 # tree exit lets Godot's stored RPC-cache callbacks remove tracked nodes.
 if _retiring_transport_scope or not is_inside_tree() or is_queued_for_deletion():return
 var parent=get_parent()
 if parent==null or parent.is_queued_for_deletion():return
 var tree=get_tree();var path=get_path();var api=_subtree_api;var index=get_index()
 var owners:Array=[]
 _capture_tree_owners(self,owners)
 _retiring_transport_scope=true
 parent.remove_child(self)
 _release_subtree_api(tree,path,api,false)
 peer=null
 # A real tree-exit observer may have requested shutdown during removal.
 if is_queued_for_deletion() or not is_instance_valid(parent) or parent.is_queued_for_deletion() or not parent.is_inside_tree():
  if not is_queued_for_deletion():queue_free()
  _retiring_transport_scope=false
  return
 # Re-enter the existing Node without re-running subclass one-time startup.
 parent.add_child(self);_configure_subtree_api();parent.move_child(self,mini(index,parent.get_child_count()-1))
 for entry in owners:
  if is_instance_valid(entry.node) and is_instance_valid(entry.owner):entry.node.owner=entry.owner
 _retiring_transport_scope=false

static func _capture_tree_owners(node:Node,result:Array) -> void:
 if node.owner!=null:result.append({"node":node,"owner":node.owner})
 for child in node.get_children():_capture_tree_owners(child,result)

func _exit_tree() -> void:
 # Scene removal is an abrupt disconnect, never a successful portable export.
 connected=false;connecting=false
 if _retiring_transport_scope:return
 # The registered peer is released after natural tree_exited callbacks. A peer
 # that never belonged to the API has no RPC tracking and can close immediately.
 if peer!=null and (_subtree_api==null or _subtree_api.multiplayer_peer!=peer):peer.close()
 stop_voice_transport()
 if server and storage!=null:storage.stop_worker()

static func _release_subtree_api(tree:SceneTree,path:NodePath,api:SceneMultiplayer,unregister:bool=true) -> void:
 var retired_peer=api.multiplayer_peer
 api.clear()
 api.multiplayer_peer=null
 if retired_peer!=null:retired_peer.close()
 # A replacement Session may already own this path by the deferred turn.
 if unregister and is_instance_valid(tree) and tree.get_multiplayer(path)==api:tree.set_multiplayer(null,path)

static func configure_gameplay_peer(connection:ENetPacketPeer) -> void:
 if connection==null or not connection.is_active():return
 # Input and snapshots already have strict application rate/size bounds. RTT
 # variance needs prompt recovery to preserve their .3s input heartbeat.
 # Reliable ENet congestion/retransmission and host bandwidth limits remain.
 connection.throttle_configure(1000,ENetPacketPeer.PACKET_THROTTLE_SCALE,2)
