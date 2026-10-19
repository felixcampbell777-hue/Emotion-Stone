extends RefCounted
const MAX_XP=10000000
const LEGACY_IDS=["steady_heart","heavy_hands","rising_tide","deep_breath","sure_guard","flowing_reserve"]
var definition=JSON.parse_string(FileAccess.get_file_as_string("res://content/progression.json"))
var xp=0
var learned:Array=[]
var passives:Array=[]
var world_rise=false
var greatsword_kills=0
const PASSIVE_SLOTS=3
const ATTRIBUTE_IDS=["body","reflexes","precision","endurance","mastery"]
const WEAPON_KINDS=["greatsword","spear","rapier","bow"]
const PRACTICE_MILESTONES=[15,50,100,200,400]
const LEGACY_WORLD_RISE="res://content/progression_legacy_v4.json"
var attributes:Dictionary={"body":3,"reflexes":3,"precision":3,"endurance":3,"mastery":3}
var weapon_kills:Dictionary={"greatsword":0,"spear":0,"rapier":0,"bow":0}
var attribute_reset_used=false
var migration_v4:Dictionary={}
var migration_notice=false
func set_profile(enabled:bool) -> void:
	world_rise=enabled;definition=JSON.parse_string(FileAccess.get_file_as_string("res://content/progression.json"))
	if enabled:
		var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://content/world_rise/skills.json"))
		definition.skills=catalog.skills;definition["attributes"]=catalog.attributes
func kill_requirement(id:String) -> int:
	var item=skill(id)
	return maxi(int(item.get("kills",0)),int(item.get("kill_step",0))*(rank(id)+1))
func requirements_met(id:String) -> bool:
	var item=skill(id)
	if item.is_empty():return false
	if not item.requires.all(func(parent):return has(parent)):return false
	for parent in item.get("requires_ranks",{}):
		if rank(parent)<int(item.requires_ranks[parent]):return false
	return not world_rise or int(attributes.get(item.get("attribute",""),3))>=int(item.get("gate",4))

func level() -> int:
	var result=0
	for threshold in definition.level_thresholds:
		if xp>=int(threshold): result+=1
	return maxi(1,result)

func points() -> int:
	var paid=learned.filter(func(id): return id!="jump").size()
	return level()-1-paid

func next_threshold() -> int:
	return int(definition.level_thresholds[mini(level(),definition.level_thresholds.size()-1)])

func skill(id: String) -> Dictionary:
	for item in definition.skills:
		if item.id==id: return item
	return {}

func rank(id: String) -> int:
	return learned.count(id)

func has(id: String) -> bool:
	return rank(id)>0

func excluded(id: String) -> bool:
	var item=skill(id)
	return not item.is_empty() and item.get("excludes",[]).any(func(other): return has(other))

func can_learn(id: String) -> bool:
	var item=skill(id)
	return not item.is_empty() and id!="jump" and rank(id)<int(item.max_rank) and points()>0 and not excluded(id) and requirements_met(id)

func learn(id: String) -> bool:
	if not can_learn(id): return false
	learned.append(id)
	if not world_rise and skill(id).get("category","")=="passive" and id not in passives and passives.size()<PASSIVE_SLOTS: passives.append(id)
	return true

func toggle_passive(id:String) -> bool:
	if not has(id) or skill(id).get("category","")!="passive": return false
	if id in passives: passives.erase(id)
	elif passives.size()<PASSIVE_SLOTS: passives.append(id)
	else: return false
	return true

func award(amount: int) -> int:
	var before=level()
	xp=mini(MAX_XP,xp+maxi(0,amount))
	return level()-before

func snapshot() -> Dictionary:
	if world_rise:
		var result={"tree_version":5,"profile":"world_rise","xp":xp,"learned":learned.duplicate(),"passives":[],"greatsword_kills":greatsword_kills,"attributes":attributes.duplicate(),"weapon_kills":weapon_kills.duplicate(),"attribute_reset_used":attribute_reset_used}
		if not migration_v4.is_empty():result["migration_v4"]=migration_v4.duplicate(true)
		return result
	return {"tree_version":3,"xp":xp,"learned":learned.duplicate(),"passives":passives.duplicate()}

func restore(data: Dictionary) -> void:
	if data.get("profile","")=="world_rise" and int(data.get("tree_version",1)) in [4,5]:set_profile(true)
	xp=int(data.get("xp",0))
	if world_rise:
		var migrated=migrate_world_rise(data) if data.get("profile","")=="world_rise" else {}
		learned=migrated.get("learned",[]).duplicate()
		attributes=migrated.get("attributes",base_attributes()).duplicate()
		weapon_kills=migrated.get("weapon_kills",empty_weapon_kills()).duplicate()
		greatsword_kills=int(migrated.get("greatsword_kills",0))
		attribute_reset_used=bool(migrated.get("attribute_reset_used",false))
		var previous_receipt=migration_v4.duplicate(true)
		migration_v4=migrated.get("migration_v4",{}).duplicate(true)
		migration_notice=not migration_v4.is_empty() and (migration_notice or previous_receipt.is_empty())
		passives=[];return
	# Retire the old tree and refund its allocations, preserving earned XP.
	learned=data.get("learned",[]).duplicate() if int(data.get("tree_version",1)) in [2,3] else []
	passives=data.get("passives",[]).duplicate() if int(data.get("tree_version",1))==3 else []
	if int(data.get("tree_version",1))!=3:
		for id in learned:
			if skill(id).get("category","")=="passive" and id not in passives and passives.size()<PASSIVE_SLOTS: passives.append(id)

static func valid(data: Variant) -> bool:
	if not data is Dictionary: return false
	if data.get("tree_version",1)==4 or data.get("tree_version",1)==5:return valid_world_rise(data)
	var amount=data.get("xp",0)
	var entries=data.get("learned",[])
	var version=data.get("tree_version",1)
	if not (version is int or version is float) or not is_finite(float(version)) or float(version)!=int(version): return false
	version=int(version)
	if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount)!=int(amount) or amount<0 or amount>MAX_XP: return false
	if not entries is Array: return false
	var maximum_ranks=0
	for item in JSON.parse_string(FileAccess.get_file_as_string("res://content/progression.json")).skills: maximum_ranks+=int(item.max_rank)
	if entries.size()>maximum_ranks: return false
	var state=load("res://scripts/progression.gd").new()
	state.xp=int(amount)
	if version==1:
		if entries.size()>6: return false
		var seen=[]
		for id in entries:
			if not id is String or id not in LEGACY_IDS or id in seen: return false
			seen.append(id)
		if entries.size()>state.level()-1: return false
		for pair in [["deep_breath","steady_heart"],["sure_guard","heavy_hands"],["flowing_reserve","rising_tide"]]:
			if pair[0] in entries and pair[1] not in entries: return false
		return true
	if version not in [2,3]: return false
	for id in entries:
		if not id is String or state.skill(id).is_empty(): return false
		state.learned.append(id)
	if state.points()<0: return false
	for id in entries:
		var item=state.skill(id)
		if state.rank(id)>int(item.max_rank) or state.excluded(id) or not item.requires.all(func(parent): return state.has(parent)): return false
	if version==3:
		var equipped=data.get("passives",[])
		if not equipped is Array or equipped.size()>PASSIVE_SLOTS: return false
		var seen=[]
		for id in equipped:
			if not id is String or id in seen or not state.has(id) or state.skill(id).get("category","")!="passive": return false
			seen.append(id)
	return true

func bonus(effect: String) -> float:
	if world_rise:return .25*(1+.25*(rank("breaker")-1)) if effect=="breaker" and has("breaker") else 0.0
	var total=0.0
	var seen=[]
	for id in learned:
		if id in seen: continue
		seen.append(id)
		var item=skill(id)
		if item.get("category","")=="passive":
			if id in passives: total+=float(item.effects.get(effect,0))*(1+.25*(rank(id)-1))
		else: total+=float(item.effects.get(effect,0))*rank(id)
	return total

static func whole(value:Variant,maximum:int=MAX_XP) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value==int(value) and value>=0 and value<=maximum

static func base_attributes() -> Dictionary:
	return {"body":3,"reflexes":3,"precision":3,"endurance":3,"mastery":3}
static func empty_weapon_kills() -> Dictionary:
	return {"greatsword":0,"spear":0,"rapier":0,"bow":0}
static func legacy_skill(definition_data:Dictionary,id:String) -> Dictionary:
	for item in definition_data.skills:
		if item.id==id:return item
	return {}
static func legacy_level(amount:int,definition_data:Dictionary) -> int:
	var result=0
	for threshold in definition_data.level_thresholds:
		if amount>=int(threshold):result+=1
	return maxi(1,result)
static func valid_world_rise4(data:Dictionary) -> bool:
	if data.get("profile","")!="world_rise" or data.get("tree_version")!=4:return false
	for key in ["xp","greatsword_kills"]:
		if not whole(data.get(key,0)):return false
	var entries=data.get("learned",[])
	if not entries is Array or entries.size()>49 or data.get("passives",[])!=[]:return false
	var legacy:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(LEGACY_WORLD_RISE))
	var prior:Array=[]
	if entries.size()>legacy_level(int(data.get("xp",0)),legacy)-1:return false
	for id in entries:
		if not id is String:return false
		var item=legacy_skill(legacy,id)
		if item.is_empty() or prior.count(id)>=int(item.max_rank):return false
		for parent in item.requires:
			if parent not in prior:return false
		for parent in item.get("requires_ranks",{}):
			if prior.count(parent)<int(item.requires_ranks[parent]):return false
		var needed=maxi(int(item.get("kills",0)),int(item.get("kill_step",0))*(prior.count(id)+1))
		if int(data.get("greatsword_kills",0))<needed:return false
		prior.append(id)
	return true

static func valid_world_rise(data:Dictionary) -> bool:
	if data.get("tree_version")==4:return valid_world_rise4(data)
	if data.get("profile","")!="world_rise" or data.get("tree_version")!=5:return false
	var allowed=["tree_version","profile","xp","learned","passives","greatsword_kills","attributes","weapon_kills","attribute_reset_used","migration_v4"]
	for key in data:
		if key not in allowed:return false
	if not whole(data.get("xp")) or not whole(data.get("greatsword_kills")) or not data.get("attribute_reset_used") is bool:return false
	var attrs=data.get("attributes")
	var kills=data.get("weapon_kills")
	if not attrs is Dictionary or attrs.size()!=ATTRIBUTE_IDS.size() or not kills is Dictionary or kills.size()!=WEAPON_KINDS.size():return false
	for key in ATTRIBUTE_IDS:
		if not whole(attrs.get(key),20) or attrs[key]<3:return false
	for key in WEAPON_KINDS:
		if not whole(kills.get(key)):return false
	if kills.greatsword!=data.greatsword_kills:return false
	var state=load("res://scripts/progression.gd").new();state.set_profile(true);state.xp=int(data.xp);state.attributes=attrs.duplicate()
	if state.attribute_points()<0:return false
	var entries=data.get("learned")
	if not entries is Array or entries.size()>49 or data.get("passives")!=[]:return false
	for id in entries:
		if not id is String or state.skill(id).is_empty():return false
		state.learned.append(id)
	if state.points()<0:return false
	for id in entries:
		if state.rank(id)>int(state.skill(id).max_rank) or not state.requirements_met(id):return false
	if data.has("migration_v4"):
		var receipt=data.migration_v4
		if not receipt is Dictionary or receipt.size()!=1 or not receipt.get("learned") is Array:return false
		if not valid_world_rise4({"tree_version":4,"profile":"world_rise","xp":data.xp,"greatsword_kills":data.greatsword_kills,"learned":receipt.learned,"passives":[]}):return false
	return true

static func migrate_world_rise(data:Dictionary) -> Dictionary:
	if data.get("tree_version")==5:return data.duplicate(true) if valid_world_rise(data) else {}
	if not valid_world_rise4(data):return {}
	var attrs=base_attributes();var kept:Array=[]
	for id in data.get("learned",[]):
		if id in ["dash","belly_roll","charge_thrust"]:kept.append(id)
	if "dash" in kept or "belly_roll" in kept:attrs.reflexes=4
	if "charge_thrust" in kept:attrs.mastery=4
	var kills=empty_weapon_kills();kills.greatsword=int(data.get("greatsword_kills",0))
	return {"tree_version":5,"profile":"world_rise","xp":int(data.get("xp",0)),"learned":kept,"passives":[],"greatsword_kills":kills.greatsword,"weapon_kills":kills,"attributes":attrs,"attribute_reset_used":false,"migration_v4":{"learned":data.get("learned",[]).duplicate()}}

func attribute_points() -> int:
	var spent=0
	for id in ATTRIBUTE_IDS:spent+=int(attributes.get(id,3))-3
	return 7+level()-1-spent
func increase_attribute(id:String) -> bool:
	if not world_rise or id not in ATTRIBUTE_IDS or attribute_points()<=0 or int(attributes.get(id,3))>=20:return false
	attributes[id]+=1;return true
func can_refund(id:String) -> bool:
	if not world_rise or not has(id):return false
	var item=skill(id)
	if item.is_empty():return false
	var remaining=rank(id)-1
	for child in definition.skills:
		if not has(child.id):continue
		if id in child.requires and remaining<int(child.get("requires_ranks",{}).get(id,1)):return false
	return true
func refund(id:String) -> bool:
	if not can_refund(id):return false
	learned.erase(id);return true
func reset_attributes() -> bool:
	if not world_rise or attribute_reset_used:return false
	attributes=base_attributes();learned=[];attribute_reset_used=true;return true
func award_practice(kind:String,amount:int=1) -> void:
	if not world_rise or kind not in WEAPON_KINDS or amount<=0:return
	weapon_kills[kind]=mini(MAX_XP,int(weapon_kills.get(kind,0))+amount)
	greatsword_kills=int(weapon_kills.greatsword)
func practice_rank(kind:String) -> int:
	var count=greatsword_kills if kind=="greatsword" else int(weapon_kills.get(kind,0))
	var result=0
	for threshold in PRACTICE_MILESTONES:
		if count>=threshold:result+=1
	return result

static func valid_loadout(growth:Dictionary,loadout:Variant) -> bool:
	if not loadout is Dictionary: return false
	var state=load("res://scripts/progression.gd").new();state.restore(growth)
	for id in loadout:
		if id not in ["dash","jump","flowing_counter"] or not loadout[id] is bool or (id!="jump" and loadout[id] and not state.has(id)): return false
	return true
