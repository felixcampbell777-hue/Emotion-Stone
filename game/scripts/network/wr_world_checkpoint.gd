extends RefCounted
## Corrupt local saves fail before any native floor or character is constructed.
const Profile=preload("res://scripts/network/wr_profile.gd")
const FLOORS=["wr_floor_01","wr_floor_02","wr_boss_chamber"]
static func number(value:Variant,minimum:float,maximum:float) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and value>=minimum and value<=maximum
static func vector(value:Variant) -> bool:
 return value is Array and value.size()==3 and value.all(func(item):return number(item,-10000,10000))
static func json_value(value:Variant,depth:int=0) -> bool:
 if depth>12:return false
 if value==null or value is bool:return true
 if value is int or value is float:return number(value,-1e15,1e15)
 if value is String:return value.length()<=4096
 if value is Array:return value.size()<=1024 and value.all(func(item):return json_value(item,depth+1))
 if value is Dictionary:
  if value.has("vector3"):return value.size()==1 and vector(value.vector3)
  if value.size()>1024:return false
  for key in value:
   if not key is String or key.length()>256 or not json_value(value[key],depth+1):return false
  return true
 return false
static func visitor(value:Variant) -> bool:
 if not value is Dictionary or value.size()>12:return false
 if value.has("floor") or value.has("position"):
  if value.get("floor","") not in FLOORS or not vector(value.get("position")):return false
 elif value.keys()!=["contracts"]:return false
 for field in ["checkpoint","discoveries"]:
  if not value.get(field,{}) is Dictionary:return false
  for floor_id in value.get(field,{}):
   if floor_id not in FLOORS:return false
   if field=="checkpoint":
    if not vector(value[field][floor_id]):return false
   else:
    var entries=value[field][floor_id]
    if not entries is Array or entries.size()>256:return false
    for id in entries:
     if not id is String or id.length()>128:return false
 return json_value(value.get("contracts",{})) and value.get("contracts",{}) is Dictionary
static func valid(value:Variant) -> bool:
 if not value is Dictionary or value.get("schema")!=1 or value.get("content","")!=Profile.content_digest() or not Profile.identifier(value.get("world_id")):return false
 if not Profile.integer(value.get("sequence"),1000000000000) or not number(value.get("day_clock"),0,1080) or not number(value.get("elapsed",0),0,1e15):return false
 for field in ["characters","visitors","encounters","claims","transactions","cooldowns"]:
  if not value.get(field) is Dictionary:return false
 if not value.get("flags") is Array or value.flags.size()>256:return false
 for flag in value.flags:
  if not flag is String or flag.length()>128:return false
 for id in value.characters:
  if not Profile.identifier(id) or not Profile.valid(value.characters[id]) or value.characters[id].character_id!=id:return false
 for id in value.visitors:
  if not Profile.identifier(id) or not visitor(value.visitors[id]):return false
 if value.encounters.size()>10000 or value.transactions.size()>10000:return false
 for key in value.encounters:
  var e=value.encounters[key]
  if not key is String or key.length()>256 or not e is Dictionary or not vector(e.get("position")) or not number(e.get("health"),0,1000000) or not Profile.integer(e.get("generation")) or not number(e.get("cooldown_remaining"),0,1080) or not e.get("native_state",{}) is Dictionary or not json_value(e.get("native_state",{})):return false
 for key in value.claims:
  var claim=value.claims[key]
  if not key is String or key.length()>256 or not claim is Dictionary or not Profile.identifier(claim.get("owner")) or claim.get("floor") not in FLOORS or not vector(claim.get("position")) or not claim.get("items") is Dictionary or not claim.get("arrow") is bool or (claim.has("expires") and not number(claim.expires,0,1e15)):return false
  for id in claim.items:
   if not id is String or id.length()>128 or not Profile.integer(claim.items[id],99999) or claim.items[id]<1:return false
 for key in value.transactions:
  if not key is String or key.length()>256 or not Profile.integer(value.transactions[key]):return false
 for field in ["whitelist","banned","cooldowns"]:
  if value.has(field) and not json_value(value[field]):return false
 if value.has("banned"):
  if not value.banned is Array or value.banned.size()>10000:return false
  for id in value.banned:
   if not Profile.identifier(id):return false
 if value.has("whitelist"):
  var whitelist=value.whitelist
  if not whitelist is Dictionary or not whitelist.get("enabled") is bool or not whitelist.get("characters") is Array or whitelist.characters.size()>256:return false
  for id in whitelist.characters:
   if not Profile.identifier(id):return false
 return true
