extends RefCounted
## Portable character data is distinct from world position/encounter state and private keys.
const SCHEMA=1
const PROTOCOL=4
# Only this exact released candidate may upgrade its persisted world fingerprint.
const LEGACY_CONTENT_F3111C1="933244fd47437c84992d30917ceb0be3561144a2f4cc20cd15ff324583ccc6c6"
const Growth=preload("res://scripts/progression.gd")
static var cached_content=""
static func content_digest() -> String:
 if not cached_content.is_empty():return cached_content
 var files=["res://content/combat.json","res://content/progression.json","res://content/progression_legacy_v4.json","res://content/magic_items.json","res://content/first_person_motion.json","res://content/knockback.json","res://content/platform.json","res://content/beta.json","res://content/alpha2.json","res://content/alpha2_creatures.json","res://content/menagery.json","res://content/beta_locomotion_samples.json","res://content/maps/wr_floor_01.json","res://content/maps/wr_floor_02.json","res://content/maps/wr_boss_chamber.json"]
 for filename in DirAccess.get_files_at("res://content/world_rise"):
  if filename.ends_with(".json"):files.append("res://content/world_rise/"+filename)
 files.sort()
 var manifest="4.5.1/world-rise-network-v1"
 for path in files:manifest+=path+":"+FileAccess.get_sha256(path)
 cached_content=manifest.sha256_text();return cached_content
static func compatible_world_content(value:Variant) -> bool:
 return value is String and value in [content_digest(),LEGACY_CONTENT_F3111C1]
static func upgraded(profile:Dictionary) -> Dictionary:
 # Call only after authenticating the original owner and resolving its original lineage.
 if not valid(profile):return {}
 var next=profile.duplicate(true)
 next.progression=Growth.migrate_world_rise(profile.progression)
 clamp_resources(next)
 return next if valid(next) else {}
static func resource_maxima(profile:Dictionary) -> Dictionary:
 var gear=preload("res://scripts/magic_items.gd").new();gear.restore(profile.magic_items)
 var combat=JSON.parse_string(FileAccess.get_file_as_string("res://content/combat.json"))
 var health=float(combat.max_health)+roundi(gear.bonus("health"));var stamina=float(combat.max_stamina)
 if int(profile.progression.tree_version)==4:
  var legacy=JSON.parse_string(FileAccess.get_file_as_string("res://content/progression_legacy_v4.json"))
  var gain=1+.01*(Growth.legacy_level(int(profile.progression.xp),legacy)-1)
  return {"health":roundi(health*gain),"stamina":stamina*gain}
 var growth=Growth.new();growth.restore(profile.progression)
 var stats=preload("res://scripts/world_rise_stats.gd")
 return {"health":stats.max_health(health,growth),"stamina":stats.max_stamina(stamina,growth)}
static func clamp_resources(profile:Dictionary) -> void:
 var maximum=resource_maxima(profile)
 var resources=profile.get("resources",{"health":100,"stamina":100.0})
 profile.resources={"health":mini(int(resources.health),int(maximum.health)),"stamina":minf(float(resources.stamina),float(maximum.stamina))}
static func random_id() -> String:
 return Crypto.new().generate_random_bytes(16).hex_encode()
static func new_profile(public_key:String,name:String="Traveller") -> Dictionary:
 var growth=Growth.new();growth.set_profile(true)
 return {"schema":SCHEMA,"character_id":random_id(),"public_key":public_key,"name":name.left(32),"revision":0,"parent":"","ancestors":[],"anchors":{},"issuer":"","progression":growth.snapshot(),"magic_items":{"owned":["standard_greatsword"],"weapon_id":"standard_greatsword","slots":{},"quantities":{},"healing":[],"phoenix_cooldown":0},"copper":0,"materials":{},"skill_loadout":{"dash":false,"jump":true,"flowing_counter":false},"heavy_attack":"overhead","resources":{"health":100,"stamina":100.0},"appearance":preload("res://scripts/appearance_profile.gd").default_profile(),"bonus_claims":[]}
static func digest(profile:Dictionary) -> String:
 return JSON.stringify(canonical(profile),"",true,true).sha256_text()
static func canonical(value:Variant) -> Variant:
 if value is Dictionary:
  var result={}
  for key in value:result[key]=canonical(value[key])
  return result
 if value is Array:
  var result=[]
  for item in value:result.append(canonical(item))
  return result
 if value is float and is_finite(value) and value==floor(value) and absf(value)<9007199254740991.0:return int(value)
 return value
static func integer(value:Variant,maximum:int=100000000) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and value==int(value) and value>=0 and value<=maximum
static func identifier(value:Variant) -> bool:
 if not value is String or value.length()!=32:return false
 for ch in value:
  if ch not in "0123456789abcdef":return false
 return true
static func hash_string(value:Variant) -> bool:
 if not value is String or value.length()!=64:return false
 for ch in value:
  if ch not in "0123456789abcdef":return false
 return true
static func valid(profile:Variant) -> bool:
 if not profile is Dictionary or profile.size()>24 or profile.get("schema")!=SCHEMA:return false
 if not identifier(profile.get("character_id")) or not profile.get("name") is String or profile.name.length()>32:return false
 if not profile.get("public_key") is String or profile.public_key.length()>4096:return false
 var key=CryptoKey.new()
 if key.load_from_string(profile.public_key,true)!=OK:return false
 if not integer(profile.get("revision")) or not integer(profile.get("copper")):return false
 if profile.get("parent","")!="" and not hash_string(profile.get("parent")):return false
 var ancestors=profile.get("ancestors",[])
 if not ancestors is Array or ancestors.size()>128:return false
 for hash_value in ancestors:
  if not hash_string(hash_value):return false
 var anchors=profile.get("anchors",{})
 if not anchors is Dictionary or anchors.size()>256:return false
 for world_id in anchors:
  if not identifier(world_id) or not hash_string(anchors[world_id]):return false
 if not preload("res://scripts/progression.gd").valid(profile.get("progression",{})) or profile.progression.get("tree_version") not in [4,5] or profile.progression.get("profile")!="world_rise":return false
 if not preload("res://scripts/magic_items.gd").valid_save(profile.get("magic_items",{})):return false
 var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://content/magic_items.json")).items
 var weapon=profile.magic_items.get("weapon_id","standard_greatsword")
 if weapon not in profile.magic_items.get("owned",[]) or not catalog.any(func(item):return item.id==weapon and item.category=="weapon"):return false
 if not profile.get("materials") is Dictionary or profile.materials.size()>64:return false
 for id in profile.materials:
  if not id is String or id not in preload("res://scripts/rise_guild.gd").catalog.materials or not integer(profile.materials[id],99999):return false
 if not preload("res://scripts/appearance_profile.gd").valid(profile.get("appearance",{})):return false
 var resources=profile.get("resources",{"health":100,"stamina":100.0})
 if not resources is Dictionary or resources.size()!=2 or not integer(resources.get("health"),100000) or not (resources.get("stamina") is int or resources.get("stamina") is float) or not is_finite(float(resources.stamina)) or resources.stamina<0 or resources.stamina>100000:return false
 var maximum=resource_maxima(profile)
 if resources.health>maximum.health or resources.stamina>maximum.stamina:return false
 var loadout=profile.get("skill_loadout",{})
 if not loadout is Dictionary or loadout.size()>3:return false
 for skill in loadout:
  if skill not in ["dash","jump","flowing_counter"] or not loadout[skill] is bool:return false
  if loadout[skill] and skill!="jump" and skill not in profile.progression.learned:return false
 if profile.get("heavy_attack","overhead") not in ["overhead","charge_thrust"]:return false
 if profile.get("heavy_attack","overhead")=="charge_thrust" and "charge_thrust" not in profile.progression.learned:return false
 if not profile.get("bonus_claims",[]) is Array or profile.bonus_claims.size()>128:return false
 for claim in profile.bonus_claims:
  if claim not in ["elder_first_kill_bonus","ashfang_first_kill_bonus"]:return false
 return true
static func checkpoint(profile:Dictionary,issuer:String,accepted:Dictionary={}) -> Dictionary:
 var next=profile.duplicate(true)
 clamp_resources(next)
 var prior=accepted if not accepted.is_empty() else profile
 var previous=digest(prior)
 next.parent=previous;next.revision=maxi(int(profile.revision),int(prior.revision))+1;next.issuer=issuer
 next.ancestors=prior.get("ancestors",[]).duplicate()
 next["anchors"]=prior.get("anchors",{}).duplicate()
 if not String(prior.get("issuer","")).is_empty() and prior.issuer!=issuer:next.anchors[prior.issuer]=previous
 if next.anchors.size()>256:next.anchors.erase(next.anchors.keys()[0])
 next.ancestors.append(previous)
 if next.ancestors.size()>128:next.ancestors.pop_front()
 return next
