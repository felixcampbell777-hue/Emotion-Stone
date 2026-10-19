extends SceneTree
## Disposable real-ENet migration probe. Production Session owns every admission/export.
const Session=preload("res://scripts/network/wr_session.gd")
const Profile=preload("res://scripts/network/wr_profile.gd")
const Store=preload("res://scripts/network/wr_store.gd")
const Codec=preload("res://scripts/network/wr_storage_codec.gd")
const Growth=preload("res://scripts/progression.gd")
const LEGACY_LEARNED=["iron_body","swiftfoot","dash","belly_roll","great_greatsword","charge_thrust"]
const RETAINED=["dash","belly_roll","charge_thrust"]
var options={"mode":"client","scenario":"","port-a":"25091","port-b":"25093"}
var checks:Array=[]
var phases:Array=[]
var failures:Array=[]
var session:Node
var original:Dictionary={}
var snapshots=0
var own_seen=false
var current_world=""
var accepted:Dictionary={}
func _initialize() -> void:
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--") and "=" in argument:
   var pieces=argument.substr(2).split("=",true,1);options[pieces[0]]=pieces[1]
 call_deferred("run")
func check(ok:bool,label:String) -> void:
 checks.append({"label":label,"passed":ok})
 if not ok:failures.append(label);push_error(label)
func write_text(path:String,value:String) -> bool:
 var file=FileAccess.open(path,FileAccess.WRITE)
 if file==null:return false
 file.store_string(value);file.flush();var error=file.get_error();file.close();return error==OK
func payload_digest(profile:Dictionary) -> String:
 var value=profile.duplicate(true)
 for key in ["revision","parent","ancestors","anchors","issuer","resources"]:value.erase(key)
 return Profile.digest(value)
func original_constants(profile:Dictionary) -> String:
 var value=profile.duplicate(true)
 for key in ["revision","parent","ancestors","anchors","issuer","resources","progression"]:value.erase(key)
 return Profile.digest(value)
func run() -> void:
 if options.scenario.is_empty():check(false,"disposable scenario path supplied");finish();return
 if options.mode=="seed":seed_scenario();return
 if options.mode=="reopen":reopen_worlds();return
 original=Codec.read_file(String(options.scenario).path_join("portable/character.json"),"character").get("data",{})
 check(Profile.valid(original) and original.progression.tree_version==4,"original portable file is strict tree4")
 if not failures.is_empty():finish();return
 session=Session.new();session.name="WorldRiseSession";session.checkpoint_path=String(options.scenario).path_join("portable/character.json");root.add_child(session)
 session.snapshot_received.connect(func(snapshot):
  snapshots+=1;own_seen=own_seen or snapshot.get("players",{}).has(session.character_id);current_world=snapshot.get("world_id",""))
 session.joined.connect(func(_id):accepted=session.local_profile.duplicate(true))
 check(session.ensure_character() and Profile.digest(session.local_profile)==Profile.digest(original),"normal client loads original hash without eager migration")
 var original_file=FileAccess.get_file_as_string(session.checkpoint_path)
 check(Codec.read_file(session.checkpoint_path,"character").data.progression.tree_version==4,"original disk remains tree4 before authentication")
 await visit("A-first",int(options["port-a"]),"a",true)
 print("PROGRESSION_HOP_START_B")
 var deadline=Time.get_ticks_msec()+30000
 while not FileAccess.file_exists(String(options.scenario).path_join("b-started")) and Time.get_ticks_msec()<deadline:await create_timer(.05).timeout
 check(FileAccess.file_exists(String(options.scenario).path_join("b-started")),"fresh B process became ready")
 if FileAccess.file_exists(String(options.scenario).path_join("b-started")):
  await visit("B-fresh",int(options["port-b"]),"b",false)
  await visit("A-return",int(options["port-a"]),"a",false)
 check(FileAccess.get_file_as_string(session.checkpoint_path)!=original_file,"migration installs a new lossless portable checkpoint")
 finish()
func seed_scenario() -> void:
 DirAccess.make_dir_recursive_absolute(String(options.scenario).path_join("portable"))
 var key=Crypto.new().generate_rsa(2048)
 var a=Store.new();var b=Store.new()
 check(a.open(String(options.scenario).path_join("a")),"seed A opens")
 check(b.open(String(options.scenario).path_join("b")),"seed B opens")
 var legacy=Profile.new_profile(key.save_to_string(true),"Legacy live traveller")
 legacy.progression={"tree_version":4,"profile":"world_rise","xp":1900,"learned":LEGACY_LEARNED.duplicate(),"passives":[],"greatsword_kills":31}
 legacy.copper=137;legacy.materials={"green_slime_residue":9};legacy.resources={"health":43,"stamina":67.125}
 legacy.magic_items.owned=["standard_greatsword","improved_standard_greatsword","hunting_bow","tidal_signet","gale","seer","mending_tonic","wooden_arrows"]
 legacy.magic_items.weapon_id="improved_standard_greatsword";legacy.magic_items.slots={"ring1":"tidal_signet","boots":"gale","headwear":"seer"};legacy.magic_items.quantities={"mending_tonic":3,"wooden_arrows":17}
 legacy.skill_loadout.dash=true;legacy.heavy_attack="charge_thrust";legacy.appearance.colors.cloth="#123ABC"
 check(Profile.valid(legacy),"synthetic tree4 seed validates against frozen original rules")
 legacy=Profile.checkpoint(legacy,a.data.world_id,legacy)
 for storage in [a,b]:
  var proposal=storage.data.duplicate(true);proposal.content=Profile.LEGACY_CONTENT_F3111C1;proposal.characters[legacy.character_id]=legacy.duplicate(true)
  check(storage.commit(proposal),"legacy world seed commits with exact predecessor fingerprint")
 check(key.save(String(options.scenario).path_join("portable/owner.private.pem"))==OK,"disposable owner credential saved")
 check(write_text(String(options.scenario).path_join("portable/character.json"),Codec.encode(legacy,"character")),"original portable lossless checkpoint saved")
 check(write_text(String(options.scenario).path_join("seed.json"),JSON.stringify({"original_digest":Profile.digest(legacy),"original_revision":legacy.revision,"character_id":legacy.character_id,"legacy_content":Profile.LEGACY_CONTENT_F3111C1})),"compact seed metadata saved")
 a.stop_worker();b.stop_worker()
 print("PROGRESSION_HOP_SEED ",JSON.stringify({"passed":failures.is_empty(),"checks":checks.size(),"failures":failures}))
 quit(0 if failures.is_empty() else 1)
func reopen_worlds() -> void:
 var seed_data=JSON.parse_string(FileAccess.get_file_as_string(String(options.scenario).path_join("seed.json")))
 var live=JSON.parse_string(FileAccess.get_file_as_string(String(options.scenario).path_join("client-result.json")))
 for world_name in ["a","b"]:
  var wanted="A-return" if world_name=="a" else "B-fresh"
  var expected=""
  for phase in live.phases:
   if phase.phase==wanted:expected=phase.exported_digest
  var storage=Store.new()
  var opened=storage.open(String(options.scenario).path_join(world_name))
  check(opened,world_name+": production Store reacquires lock and reopens final durable world")
  if opened:
   check(storage.data.content==Profile.content_digest(),world_name+": upgraded world fingerprint persists after process exit")
   check(not expected.is_empty() and Profile.digest(storage.data.characters.get(seed_data.character_id,{}))==expected,world_name+": exact final exported character survives server restart")
  storage.stop_worker()
 print("PROGRESSION_HOP_REOPEN ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
func visit(label:String,port:int,world_name:String,migrates:bool) -> void:
 snapshots=0;own_seen=false;current_world="";accepted={}
 var before=session.local_profile.duplicate(true);var incoming=Profile.digest(before)
 var directory=String(options.scenario).path_join(world_name)
 var disk_before=Codec.read_file(directory.path_join("world.json"),"world")
 check(disk_before.ok and disk_before.data.content==Profile.content_digest(),label+": exact legacy world header upgraded before admission")
 if label!="A-return":check(Profile.digest(disk_before.data.characters[session.character_id])==Profile.digest(original),label+": dormant raw profile remains unmodified before authentication")
 var start=Time.get_ticks_msec();var code=session.join("127.0.0.1",port)
 check(code==OK,label+": normal Session join started")
 if code!=OK:return
 while Time.get_ticks_msec()-start<12000 and snapshots<12:await create_timer(.05).timeout
 var voice_ready=session.voice_udp!=null and session.voice_udp.is_ready()
 check(session.connected and own_seen and snapshots>=12,label+": authenticated and receives own native snapshots")
 check(voice_ready,label+": authenticated voice UDP ready")
 if accepted.is_empty():check(false,label+": accepted profile observed");return
 check(Profile.valid(accepted) and accepted.progression.tree_version==5,label+": accepted profile is valid tree5")
 check(original_constants(accepted)==original_constants(original),label+": original identity copper materials equipment items appearance and equipped actives exact")
 check(accepted.progression.learned==RETAINED and accepted.progression.migration_v4.learned==LEGACY_LEARNED,label+": retained actives and exact refund receipt")
 check(accepted.progression.xp==1900 and accepted.progression.greatsword_kills==31,label+": original XP and historical practice preserved")
 var growth=Growth.new();growth.restore(accepted.progression)
 check(growth.points()==growth.level()-1-RETAINED.size() and growth.attribute_points()==7+growth.level()-1-2 and accepted.progression.attributes.reflexes==4 and accepted.progression.attributes.mastery==4,label+": refunded perk budget and minimum active attributes")
 if migrates:
  check(accepted.revision==before.revision+1 and accepted.parent==incoming and incoming in accepted.ancestors,label+": exactly one migration checkpoint descends from original authenticated head")
  check(accepted.resources==original.resources,label+": migration does not heal or round original resources")
 else:check(Profile.digest(accepted)==incoming,label+": handoff accepted unchanged without another migration")
 var payload=payload_digest(accepted)
 var record={"phase":label,"snapshots":snapshots,"voice_ready":voice_ready,"join_ms":Time.get_ticks_msec()-start,"incoming_digest":incoming,"incoming_revision":before.revision,"accepted_digest":Profile.digest(accepted),"accepted_revision":accepted.revision,"accepted_parent":accepted.parent,"world_id":current_world}
 if session.connected:
  session.leave_server();var departure=Time.get_ticks_msec()
  while session.connected and Time.get_ticks_msec()-departure<35000:await create_timer(.05).timeout
  check(not session.connected,label+": durable departure acknowledged")
  var exported=session.local_profile.duplicate(true);var digest=Profile.digest(exported)
  check(Profile.valid(exported) and payload_digest(exported)==payload,label+": complete XP equipment items appearance allocation and receipt preserved")
  check(exported.resources.health==43 and exported.resources.stamina<=Profile.resource_maxima(exported).stamina,label+": wounded health preserved and regenerated stamina bounded")
  check(exported.issuer==current_world and Profile.digest(accepted) in exported.ancestors,label+": export extends accepted lineage")
  if not before.issuer.is_empty() and before.issuer!=current_world:check(exported.anchors.get(before.issuer,"")==incoming,label+": prior world handoff anchor preserved")
  var local=Codec.read_file(session.checkpoint_path,"character");var world=Codec.read_file(directory.path_join("world.json"),"world")
  check(local.ok and Profile.digest(local.data)==digest,label+": exact durable portable file")
  check(world.ok and Profile.digest(world.data.characters[session.character_id])==digest,label+": exact durable server file")
  check(session.ensure_character() and Profile.digest(session.local_profile)==digest,label+": normal portable close/reopen exact")
  record.merge({"exported_digest":digest,"exported_revision":exported.revision,"ancestors":exported.ancestors,"anchors":exported.anchors,"resources":exported.resources,"stable_payload_digest":payload})
 phases.append(record)
 await create_timer(.2).timeout
func finish() -> void:
 print("PROGRESSION_HOP_RESULT ",JSON.stringify({"passed":failures.is_empty(),"protocol":Profile.PROTOCOL,"storage_format":Codec.FORMAT,"current_tree5_live_proof":true,"checks":checks,"phases":phases,"failures":failures,"blood_scope":"Not exercised: actual Session migration probe does not instantiate Main or synthesize blood events."}))
 quit(0 if failures.is_empty() else 1)
