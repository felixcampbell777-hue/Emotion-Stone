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
func set_profile(enabled:bool) -> void:
	world_rise=enabled;definition=JSON.parse_string(FileAccess.get_file_as_string("res://content/progression.json"))
	if enabled:definition.skills=JSON.parse_string(FileAccess.get_file_as_string("res://content/world_rise/skills.json")).skills
func kill_requirement(id:String) -> int:
	var item=skill(id)
	return maxi(int(item.get("kills",0)),int(item.get("kill_step",0))*(rank(id)+1))
func requirements_met(id:String) -> bool:
	var item=skill(id)
	if not item.requires.all(func(parent):return has(parent)):return false
	for parent in item.get("requires_ranks",{}):
		if rank(parent)<int(item.requires_ranks[parent]):return false
	return not world_rise or greatsword_kills>=kill_requirement(id)

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
	if world_rise:return {"tree_version":4,"profile":"world_rise","xp":xp,"learned":learned.duplicate(),"passives":[],"greatsword_kills":greatsword_kills}
	return {"tree_version":3,"xp":xp,"learned":learned.duplicate(),"passives":passives.duplicate()}

func restore(data: Dictionary) -> void:
	if data.get("profile","")=="world_rise" and int(data.get("tree_version",1))==4:set_profile(true)
	xp=int(data.get("xp",0))
	if world_rise:
		learned=data.get("learned",[]).duplicate() if int(data.get("tree_version",1))==4 else []
		greatsword_kills=int(data.get("greatsword_kills",0));passives=[];return
	# Retire the old tree and refund its allocations, preserving earned XP.
	learned=data.get("learned",[]).duplicate() if int(data.get("tree_version",1)) in [2,3] else []
	passives=data.get("passives",[]).duplicate() if int(data.get("tree_version",1))==3 else []
	if int(data.get("tree_version",1))!=3:
		for id in learned:
			if skill(id).get("category","")=="passive" and id not in passives and passives.size()<PASSIVE_SLOTS: passives.append(id)

static func valid(data: Variant) -> bool:
	if not data is Dictionary: return false
	if data.get("tree_version",1)==4:return valid_world_rise(data)
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

static func valid_world_rise(data:Dictionary) -> bool:
	if data.get("profile","")!="world_rise":return false
	for key in ["xp","greatsword_kills"]:
		var value=data.get(key,0)
		if not (value is int or value is float) or not is_finite(value) or value!=int(value) or value<0 or value>MAX_XP:return false
	var entries=data.get("learned",[])
	if not entries is Array or entries.size()>49:return false
	var state=load("res://scripts/progression.gd").new();state.set_profile(true);state.xp=int(data.get("xp",0));state.greatsword_kills=int(data.get("greatsword_kills",0))
	for id in entries:
		if not id is String or not state.can_learn(id):return false
		state.learned.append(id)
	return data.get("passives",[])==[]

static func valid_loadout(growth:Dictionary,loadout:Variant) -> bool:
	if not loadout is Dictionary: return false
	var state=load("res://scripts/progression.gd").new();state.restore(growth)
	for id in loadout:
		if id not in ["dash","jump","flowing_counter"] or not loadout[id] is bool or (id!="jump" and loadout[id] and not state.has(id)): return false
	return true
