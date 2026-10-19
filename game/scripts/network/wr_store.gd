extends RefCounted
## One durable world+character transaction. No network-controlled filesystem paths.
const Profile=preload("res://scripts/network/wr_profile.gd")
const StorageCodec=preload("res://scripts/network/wr_storage_codec.gd")
var directory=""
var python="python3"
var helper=""
var data:Dictionary={}
var last_error=""
var read_only=false
var last_commit_usec=0
var max_commit_usec=0
var worker:Dictionary={}
var worker_sequence=0
var worker_namespace=""
var last_commit_stages:Dictionary={}
var last_worker_stages:Dictionary={}
func open(path:String) -> bool:
 directory=ProjectSettings.globalize_path(path)
 if DirAccess.make_dir_recursive_absolute(directory)!=OK:last_error="Cannot create server data directory";return false
 helper=ProjectSettings.globalize_path("res://../tools/network/durable_replace.py")
 if not FileAccess.file_exists(helper):helper=OS.get_environment("WORLD_RISE_DURABLE_HELPER")
 if not OS.get_environment("WORLD_RISE_PYTHON").is_empty():python=OS.get_environment("WORLD_RISE_PYTHON")
 var file=directory.path_join("world.json")
 if not start_worker(file):return false
 if FileAccess.file_exists(file):
  var loaded=StorageCodec.read_file(file,"world")
  if not loaded.ok:last_error=loaded.error;stop_worker();return false
  var restored=loaded.data
  if not preload("res://scripts/network/wr_world_checkpoint.gd").valid(restored):last_error="Invalid server checkpoint; restore a known backup explicitly";stop_worker();return false
  data=restored
  # Move only the world fingerprint; dormant character hashes/anchors are immutable.
  if data.content!=Profile.content_digest():
   var compatible=data.duplicate(true);compatible.content=Profile.content_digest()
   if not commit(compatible):stop_worker();return false
  return true
 data={"schema":1,"content":Profile.content_digest(),"world_id":Profile.random_id(),"sequence":0,"characters":{},"visitors":{},"encounters":{},"claims":{},"flags":[],"day_clock":0.0,"cooldowns":{},"transactions":{}}
 return commit(data)
func commit(next:Dictionary) -> bool:
 var started=Time.get_ticks_usec()
 if read_only:last_error="Storage is read only";return false
 last_commit_stages={}
 var proposed=next.duplicate(true);proposed.sequence=int(data.get("sequence",0))+1
 last_commit_stages["clone_us"]=Time.get_ticks_usec()-started
 var encode_started=Time.get_ticks_usec()
 var target=directory.path_join("world.json")
 if not start_worker(target):return false
 var encoded=StorageCodec.encode(proposed,"world")
 if encoded.is_empty():last_error="World checkpoint rejected: "+StorageCodec.last_encode_error;return false
 last_commit_stages["encode_us"]=Time.get_ticks_usec()-encode_started
 var write_started=Time.get_ticks_usec()
 var file=FileAccess.open(target+".pending."+worker_namespace,FileAccess.WRITE)
 if file==null:last_error="Cannot write durable checkpoint";return false
 file.store_string(encoded);file.flush();var error=file.get_error();file.close()
 if error!=OK:last_error="Checkpoint write failed";return false
 if helper.is_empty() or not FileAccess.file_exists(helper):last_error="Durable checkpoint helper unavailable";return false
 last_commit_stages["proposal_write_us"]=Time.get_ticks_usec()-write_started
 var wait_started=Time.get_ticks_usec()
 if not durable_commit(target):return false
 last_commit_stages["worker_wait_us"]=Time.get_ticks_usec()-wait_started;last_commit_stages["worker"]=last_worker_stages.duplicate()
 data=proposed;last_error="";last_commit_usec=Time.get_ticks_usec()-started;max_commit_usec=maxi(max_commit_usec,last_commit_usec);return true
func import_character(profile:Dictionary,recover:bool=false) -> Dictionary:
 if not Profile.valid(profile):return {"ok":false,"error":"Invalid portable character"}
 var id=profile.character_id
 var old=data.characters.get(id,{})
 var selected=profile
 var recovered=false
 if not old.is_empty():
  if old.public_key!=profile.public_key:return {"ok":false,"error":"Character owner does not match"}
  var old_hash=Profile.digest(old);var incoming_hash=Profile.digest(profile)
  if recover:selected=old;recovered=true
  elif incoming_hash==old_hash:selected=old
  elif old_hash not in profile.ancestors and profile.get("anchors",{}).get(old.get("issuer",""),"")!=old_hash:return {"ok":false,"error":"Portable character conflict: reconnect to recover this session, or export the current branch from its last server. No data was replaced.","conflict":true}
 # Never normalize a candidate before the original digest/lineage is accepted.
 var accepted=selected.duplicate(true)
 if int(selected.progression.tree_version)==4:
  var migrated=Profile.upgraded(selected)
  if migrated.is_empty():return {"ok":false,"error":"Portable progression migration failed; no data was replaced"}
  accepted=Profile.checkpoint(migrated,data.world_id,selected)
 if old.is_empty() or Profile.digest(accepted)!=Profile.digest(old):
  var next=data.duplicate(true);next.characters[id]=accepted
  if not commit(next):return {"ok":false,"error":last_error}
 return {"ok":true,"profile":accepted.duplicate(true),"recovered":recovered}
func checkpoint_character(id:String,profile:Dictionary,visitor:Dictionary={}) -> Dictionary:
 var next=data.duplicate(true)
 var exported=Profile.checkpoint(profile,data.world_id,data.characters.get(id,{}))
 next.characters[id]=exported
 if not visitor.is_empty():next.visitors[id]=visitor.duplicate(true)
 if not commit(next):return {}
 return exported

func start_worker(target:String) -> bool:
 if not worker.is_empty():return true
 if helper.is_empty() or not FileAccess.file_exists(helper):last_error="Durable checkpoint helper unavailable";return false
 worker_namespace=Profile.random_id()
 worker=OS.execute_with_pipe(python,[helper,"--worker",target,str(OS.get_process_id()),worker_namespace],false)
 if worker.is_empty():last_error="Cannot start durable checkpoint worker";return false
 var stream:FileAccess=worker.stdio
 var response=PackedByteArray();var deadline=Time.get_ticks_msec()+5000
 while Time.get_ticks_msec()<deadline:
  response.append_array(stream.get_buffer(1024))
  if response.size()>4096:break
  if response.has(10):
   var value=JSON.parse_string(response.get_string_from_utf8())
   if value is Dictionary and value.get("ready",false) and value.get("namespace")==worker_namespace:
    return true
   last_error=String(value.get("error","World writer lock unavailable")) if value is Dictionary else "Invalid world writer acknowledgement"
   stop_worker();return false
  OS.delay_usec(100)
 last_error="World writer lock startup timed out"+worker_failure_detail(stream);stop_worker();return false
func durable_commit(target:String) -> bool:
 if worker.is_empty() and not start_worker(target):return false
 worker_sequence+=1;last_worker_stages={}
 var stream:FileAccess=worker.stdio
 # Atomic local request files avoid writing a dead child's pipe (SIGPIPE).
 var request_path=target+".request."+worker_namespace+".json"
 var request=FileAccess.open(request_path+".pending",FileAccess.WRITE)
 if request==null:last_error="Cannot create checkpoint worker request";return false
 request.store_string(JSON.stringify({"id":worker_sequence,"op":"commit"}));request.close()
 if DirAccess.rename_absolute(request_path+".pending",request_path)!=OK:last_error="Cannot publish checkpoint worker request";return false
 var response=PackedByteArray();var reply_error=""
 var deadline=Time.get_ticks_msec()+5000
 while Time.get_ticks_msec()<deadline:
  var chunk=stream.get_buffer(1024)
  response.append_array(chunk)
  if response.size()>4096:break
  if response.has(10):
   var value=JSON.parse_string(response.get_string_from_utf8())
   if value is Dictionary and value.get("error") is String:reply_error=" "+String(value.error).left(512)
   if value is Dictionary and value.get("id")==worker_sequence and value.get("ok") is bool:
    if value.ok:last_worker_stages=value.get("stages",{}).duplicate();return true
    read_only=true;last_error="Durable checkpoint failed; restart to recover disk state: "+String(value.get("error","unknown error")).left(512);stop_worker();return false
   break
  if stream.get_error()==ERR_FILE_EOF:break
  OS.delay_usec(100)
 # An acknowledgement lost after rename is ambiguous. Freeze writes until an
 # explicit restart reloads the committed file; never overwrite it from stale RAM.
 read_only=true;last_error="Durable checkpoint worker failed; restart to recover the accepted disk checkpoint"+reply_error+worker_failure_detail(stream)
 stop_worker();return false
func worker_failure_detail(stream:FileAccess) -> String:
 var detail=" [reply pipe="+str(stream.get_error())+"]"
 var errors:FileAccess=worker.get("stderr")
 if errors!=null:
  var diagnostic=errors.get_buffer(2048).get_string_from_utf8().strip_edges()
  if not diagnostic.is_empty():detail+=" "+diagnostic.left(2048)
 return detail
func stop_worker() -> void:
 if worker.is_empty():return
 OS.kill(int(worker.pid))
 var stream:FileAccess=worker.get("stdio")
 if stream!=null:stream.close()
 var errors:FileAccess=worker.get("stderr")
 if errors!=null:errors.close()
 worker.clear()
func _notification(what:int) -> void:
 if what==NOTIFICATION_PREDELETE and not worker.is_empty():
  OS.kill(int(worker.pid))
  var stream:FileAccess=worker.get("stdio")
  if stream!=null:stream.close()
  var errors:FileAccess=worker.get("stderr")
  if errors!=null:errors.close()
  worker.clear()
