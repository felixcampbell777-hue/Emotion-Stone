extends SceneTree
const Store=preload("res://scripts/network/wr_store.gd")
var failures:Array=[]
var checks=0
func check(value:bool,label:String) -> void:
 checks+=1
 if not value:failures.append(label)
func _init() -> void:
 var store=Store.new()
 check(store.open("user://worker-check"),"initial durable worker checkpoint")
 var first_pid=int(store.worker.get("pid",-1))
 var samples:Array=[]
 var stage_samples:Dictionary={}
 for i in 30:
  var proposed=store.data.duplicate(true);proposed["probe_counter"]=i
  check(store.commit(proposed),"durable commit %d"%i)
  samples.append(store.last_commit_usec)
  collect_stages(stage_samples,store.last_commit_stages)
 check(first_pid==int(store.worker.get("pid",-2)),"worker reused across commits")
 var accepted=store.data.duplicate(true)
 OS.kill(first_pid)
 OS.delay_msec(20)
 var rejected=accepted.duplicate(true);rejected.probe_counter=999
 check(not store.commit(rejected),"dead worker never acknowledged")
 check(store.read_only,"ambiguous worker failure freezes further writes")
 check(store.data==accepted,"failed write leaves accepted memory unchanged")
 var reopened=Store.new()
 check(reopened.open("user://worker-check"),"explicit restart recovers durable file")
 check(reopened.data.get("probe_counter")==29,"accepted disk preserved after worker failure")
 var fault=Store.new()
 check(fault.open("user://post-rename-fault"),"fault fixture initial durable checkpoint")
 fault.stop_worker()
 var wrapper_path=ProjectSettings.globalize_path("user://directory_fsync_fault.py")
 var wrapper=FileAccess.open(wrapper_path,FileAccess.WRITE)
 wrapper.store_string("import runpy,os,stat,sys\nmodule=runpy.run_path("+JSON.stringify(fault.helper)+")\nreal_fsync=os.fsync\ndef injected(fd):\n if stat.S_ISDIR(os.fstat(fd).st_mode): raise OSError('injected directory fsync failure')\n return real_fsync(fd)\nos.fsync=injected\nraise SystemExit(module['worker'](sys.argv[2],int(sys.argv[3]),sys.argv[4]))\n");wrapper.close()
 fault.helper=wrapper_path
 var before=fault.data.duplicate(true);var after=before.duplicate(true);after["post_rename_probe"]=123
 check(not fault.commit(after),"post-rename fsync failure never acknowledged")
 check(fault.read_only,"negative acknowledgement freezes ambiguous disk state")
 check(fault.data==before,"ambiguous negative acknowledgement retains prior accepted RAM")
 var disk=preload("res://scripts/network/wr_storage_codec.gd").read_file(fault.directory.path_join("world.json"),"world").data
 check(disk.get("post_rename_probe")==123,"fault actually occurred after atomic replacement")
 check(not fault.commit(before),"stale RAM cannot overwrite replaced checkpoint")
 fault.stop_worker()
 var precision=Store.new()
 check(precision.open("user://fractional-precision"),"fractional checkpoint opens")
 var owner=Crypto.new().generate_rsa(2048)
 var profile=preload("res://scripts/network/wr_profile.gd").new_profile(owner.save_to_string(true))
 profile.resources.stamina=63.12345678901234;profile.magic_items.phoenix_cooldown=.1234567890123456
 check(precision.import_character(profile).ok,"valid fractional profile accepted")
 var proposal=precision.data.duplicate(true);proposal.day_clock=123.12345678901234;proposal["elapsed"]=567.12345678901234
 proposal.encounters["wr_floor_01/precision_probe"]={"position":[0,0,0],"health":1,"generation":0,"cooldown_remaining":0.0,"native_state":{"state_time":.44999999999999996}}
 check(precision.commit(proposal),"fractional profile and native clocks durably committed")
 precision.stop_worker()
 var exact=Store.new();check(exact.open("user://fractional-precision"),"fractional checkpoint reopened")
 check(preload("res://scripts/network/wr_profile.gd").digest(profile)==preload("res://scripts/network/wr_profile.gd").digest(exact.data.characters[profile.character_id]),"fractional profile disk digest exact")
 check(exact.data.day_clock==proposal.day_clock and exact.data.elapsed==proposal.elapsed and exact.data.encounters["wr_floor_01/precision_probe"].native_state.state_time==.44999999999999996,"world and native clocks retain full double precision")
 check(exact.import_character(profile).ok,"unchanged fractional portable profile is not a false conflict after restart")
 exact.stop_worker()
 samples.sort()
 print("WR_STORE_WORKER_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"warm_commit_p95_usec":samples[28],"warm_commit_max_usec":samples[-1],"stages":summarize_stages(stage_samples)}))
 store.stop_worker();reopened.stop_worker();quit(0 if failures.is_empty() else 1)

func collect_stages(samples:Dictionary,stages:Dictionary,prefix:String="") -> void:
 for key in stages:
  if stages[key] is Dictionary:collect_stages(samples,stages[key],prefix+str(key)+"/")
  elif stages[key] is int or stages[key] is float:
   var name=prefix+str(key)
   if not samples.has(name):samples[name]=[]
   samples[name].append(stages[key])
func summarize_stages(samples:Dictionary) -> Dictionary:
 var result:Dictionary={}
 for key in samples:
  var values:Array=samples[key];values.sort()
  result[key]={"p95_us":values[int(ceil(values.size()*.95))-1],"max_us":values[-1]}
 return result
