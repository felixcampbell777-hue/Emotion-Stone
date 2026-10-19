extends SceneTree
const Checkpoint=preload("res://scripts/network/wr_world_checkpoint.gd")
const Store=preload("res://scripts/network/wr_store.gd")
const Profile=preload("res://scripts/network/wr_profile.gd")
var failures:Array=[]
var checks=0
func check(value:bool,label:String) -> void:
 checks+=1
 if not value:failures.append(label)
func _init() -> void:
 var store=Store.new();check(store.open("user://strict-world"),"fresh accepted world")
 var accepted=store.data.duplicate(true)
 check(Checkpoint.valid(JSON.parse_string(JSON.stringify(accepted))),"accepted world survives JSON roundtrip")
 for field in ["world_id","day_clock","encounters","claims","transactions","flags","visitors","characters","sequence"]:
  var corrupt=accepted.duplicate(true);corrupt.erase(field)
  check(not Checkpoint.valid(corrupt),"missing required "+field)
 var owner=Crypto.new().generate_rsa(2048)
 var character=Profile.new_profile(owner.save_to_string(true));var id=character.character_id
 var populated=accepted.duplicate(true);populated.characters[id]=character
 populated.visitors[id]={"floor":"wr_floor_01","position":[0,0,0],"checkpoint":{},"discoveries":{},"contracts":{}}
 check(Checkpoint.valid(populated),"valid character and visitor")
 var corrupt=populated.duplicate(true);corrupt.characters[id].appearance={"path":"arbitrary"}
 check(not Checkpoint.valid(corrupt),"corrupt character rejected before runtime")
 corrupt=populated.duplicate(true);corrupt.visitors[id].position=[0,"bad",0]
 check(not Checkpoint.valid(corrupt),"corrupt saved position rejected")
 corrupt=populated.duplicate(true);corrupt.visitors[id].discoveries={"unknown_floor":["arrival"]}
 check(not Checkpoint.valid(corrupt),"unknown discovery floor rejected")
 corrupt=populated.duplicate(true);corrupt.encounters["wr_floor_01/probe"]={"position":[0,0,0],"health":-1,"generation":0,"cooldown_remaining":0}
 check(not Checkpoint.valid(corrupt),"negative encounter health rejected")
 corrupt=populated.duplicate(true);corrupt.encounters["wr_floor_01/probe"]={"position":[0,0,0],"health":1,"generation":0,"cooldown_remaining":0,"native_state":{"direction":{"vector3":[1,2]}}}
 check(not Checkpoint.valid(corrupt),"malformed tagged native vector rejected")
 var file=FileAccess.open(store.directory.path_join("world.json"),FileAccess.WRITE);file.store_string(preload("res://scripts/network/wr_storage_codec.gd").encode(corrupt,"world"));file.close();store.stop_worker()
 var reopened=Store.new();check(not reopened.open("user://strict-world"),"corrupt durable world fails explicitly at open")
 print("WR_CHECKPOINT_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
