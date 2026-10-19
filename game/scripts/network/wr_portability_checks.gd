extends SceneTree
## Independent storage boundary checks using real durable store writes.
const Profile=preload("res://scripts/network/wr_profile.gd")
const Store=preload("res://scripts/network/wr_store.gd")
const Storage=preload("res://scripts/network/wr_storage_codec.gd")
var failures=[]
var count=0
func check(ok:bool,message:String) -> void:
	count+=1
	if not ok:failures.append(message);push_error(message)
func disk_roundtrip(value:Dictionary,name:String) -> Dictionary:
	var path="user://"+name+".json"
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(Storage.encode(value,"character"));file.flush();file.close()
	return Storage.read_file(path,"character").get("data",{})
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var key=Crypto.new().generate_rsa(2048)
	var profile=Profile.new_profile(key.save_to_string(true))
	check(Profile.valid(profile),"Fresh portable profile validates")
	check(Profile.digest(profile)==Profile.digest(JSON.parse_string(JSON.stringify(profile))),"Checkpoint hash survives JSON numeric roundtrip")
	for replacement in [{"progression":{"tree_version":3,"xp":0,"learned":[],"passives":[]}}, {"materials":{"unregistered_material":1}}, {"appearance":{"hair":"res://scripts/main.gd"}}, {"parent":"x".repeat(64)}]:
		var malformed=profile.duplicate(true);malformed.merge(replacement,true)
		check(not Profile.valid(malformed),"Malformed portable data rejected: "+str(replacement.keys()))
	var a=Store.new();var b=Store.new()
	check(a.open("user://probe-world-a") and b.open("user://probe-world-b"),"Two durable world stores open")
	check(a.import_character(profile).ok,"Character imported into A")
	var gain_a=profile.duplicate(true);gain_a.copper=10
	var exported_a=a.checkpoint_character(profile.character_id,gain_a)
	check(not exported_a.is_empty() and Profile.valid(exported_a),"A economy checkpoint is valid")
	check(b.import_character(disk_roundtrip(exported_a,"from-a")).ok,"A exported character imports into B after disk roundtrip")
	var gain_b=exported_a.duplicate(true);gain_b.copper=15
	var exported_b=b.checkpoint_character(profile.character_id,gain_b)
	var return_a=a.import_character(disk_roundtrip(exported_b,"from-b"))
	check(return_a.ok and int(return_a.get("profile",{}).get("copper",-1))==15,"A to B to A carries legitimate newer economy")
	var fractional=return_a.profile.duplicate(true)
	fractional.resources.stamina=99.9876543210987
	fractional.magic_items.healing=[{"id":"mending_tonic","remaining":19.1234567890123,"clock":.123456789012345}]
	fractional.magic_items.phoenix_cooldown=17.1234567890123
	check(Profile.valid(fractional),"Real fractional stamina, healing timer and cooldown profile validates")
	var fractional_export=a.checkpoint_character(profile.character_id,fractional)
	check(not fractional_export.is_empty(),"Fractional resource checkpoint commits durably")
	a.stop_worker()
	var reopened=Store.new()
	check(reopened.open("user://probe-world-a"),"Fractional durable world closes and reopens")
	check(Profile.digest(fractional_export)==Profile.digest(reopened.data.characters[profile.character_id]),"Disk reopen preserves exact fractional character digest")
	check(reopened.import_character(fractional_export).ok,"Unchanged fractional export imports after actual disk reopen")
	check(b.import_character(disk_roundtrip(fractional_export,"fractional-a")).ok,"Fractional checkpoint transfers to second durable world")
	a=reopened
	var stale=a.import_character(profile)
	check(not stale.ok and stale.get("conflict",false),"Stale portable branch rejected without replacing latest")
	var recover=a.import_character(profile,true)
	check(recover.ok and int(recover.profile.copper)==15,"Explicit recovery returns current durable branch")
	a.stop_worker();b.stop_worker()
	print("PORTABILITY_CHECKS ",JSON.stringify({"checks":count,"failures":failures,"return_to_a_ok":return_a.ok,"returned_copper":return_a.get("profile",{}).get("copper",-1)}))
	quit(0 if failures.is_empty() else 1)
