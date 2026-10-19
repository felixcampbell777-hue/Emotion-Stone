extends RefCounted
## World Rise weapon identities. The legacy greatsword never receives replacement tuning.
const CONTENT="res://content/world_rise/weapons.json"
static func definitions() -> Dictionary:
 return JSON.parse_string(FileAccess.get_file_as_string(CONTENT)).profiles
static func kind(item_id:String) -> String:
 var profiles=definitions()
 for key in profiles:
  if item_id in profiles[key].items:return key
 return "greatsword"
static func profile(item_id:String) -> Dictionary:
 var result:Dictionary=definitions()[kind(item_id)].duplicate(true)
 result["kind"]=kind(item_id);result["item_id"]=item_id
 return result
static func valid_item(item_id:String) -> bool:
 for entry in definitions().values():
  if item_id in entry.items:return true
 return false
static func apply_tuning(actor:Node,item_id:String) -> void:
 var p=profile(item_id)
 if p.legacy:return
 actor.combat.draw_seconds=p.draw_seconds;actor.combat.sheathe_seconds=p.draw_seconds
 actor.combat.drawn_walk_speed*=p.ready_movement_multiplier
 actor.combat.drawn_sprint_speed*=p.ready_movement_multiplier
