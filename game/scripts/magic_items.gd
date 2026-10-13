extends RefCounted
const Visuals=preload("res://scripts/equipment_visuals.gd")
const SLOTS=["ring1","ring2","torso","leggings","boots","headwear","necklace"]
var game:Node
var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://content/magic_items.json"))
var owned:Array=[]
var slots:Dictionary={}
var phoenix_cooldown=0.0
var quiet_seconds=0.0
var heal_clock=0.0
var visual_key=""
var healing:Array=[]
var quantities:Dictionary={}

func item(id:String) -> Dictionary:
	for entry in catalog.items:
		if entry.id==id: return entry
	return {}
static func category(slot:String) -> String:
	return "ring" if slot in ["ring1","ring2"] else slot
static func valid_save(data:Variant) -> bool:
	if not data is Dictionary: return false
	var items=JSON.parse_string(FileAccess.get_file_as_string("res://content/magic_items.json")).items
	var collection=data.get("owned",[]); var equipped=data.get("slots",{})
	if not collection is Array or collection.size()>items.size() or not equipped is Dictionary or equipped.size()>SLOTS.size(): return false
	var seen=[]
	for id in collection:
		if not id is String or id in seen or not items.any(func(e): return e.id==id): return false
		seen.append(id)
	seen.clear()
	for slot in equipped:
		var id=equipped[slot]
		if slot not in SLOTS or not id is String: return false
		if id.is_empty(): continue
		if id not in collection or id in seen or not items.any(func(e): return e.id==id and e.category==category(slot)): return false
		seen.append(id)
	var counts=data.get("quantities",{})
	if not counts is Dictionary: return false
	for id in counts:
		if id not in collection or not items.any(func(e): return e.id==id and e.category=="consumable"): return false
		if not (counts[id] is int or counts[id] is float) or not is_finite(float(counts[id])) or counts[id]!=int(counts[id]) or counts[id]<1 or counts[id]>99: return false
	if data.has("quantities"):
		for id in collection:
			if items.any(func(e): return e.id==id and e.category=="consumable") and not counts.has(id): return false
	var buffs=data.get("healing",[])
	if buffs is Dictionary: buffs=[] if buffs.is_empty() else [buffs]
	if not buffs is Array or buffs.size()>297: return false
	for buff in buffs:
		if not buff is Dictionary or buff.size()!=3 or not buff.has_all(["id","remaining","clock"]): return false
		var entries=items.filter(func(e): return e.id==buff.id and e.category=="consumable")
		if entries.is_empty(): return false
		for key in ["remaining","clock"]:
			if not (buff[key] is float or buff[key] is int) or not is_finite(float(buff[key])) or buff[key]<0: return false
		if buff.remaining>entries[0].effects.regen_seconds or buff.clock>=1: return false
	var cooldown=data.get("phoenix_cooldown",0)
	return (cooldown is int or cooldown is float) and is_finite(float(cooldown)) and cooldown>=0 and cooldown<=60
func reset() -> void:
	owned.clear(); slots.clear(); phoenix_cooldown=0; quiet_seconds=0; heal_clock=0; visual_key="!"; healing.clear(); quantities.clear()
func snapshot() -> Dictionary:
	return {"owned":owned.duplicate(),"slots":slots.duplicate(),"phoenix_cooldown":phoenix_cooldown,"healing":healing.duplicate(true),"quantities":quantities.duplicate()}
func restore(data:Dictionary) -> void:
	owned=data.get("owned",[]).duplicate(); slots=data.get("slots",{}).duplicate(); phoenix_cooldown=float(data.get("phoenix_cooldown",0)); visual_key="!"; quiet_seconds=0; heal_clock=0
	var buffs=data.get("healing",[])
	healing=([buffs.duplicate()] if not buffs.is_empty() else []) if buffs is Dictionary else buffs.duplicate(true)
	quantities=data.get("quantities",{}).duplicate()
	for id in owned:
		if item(id).category=="consumable" and not quantities.has(id): quantities[id]=1
func drink(id:String) -> bool:
	var entry=item(id)
	if id not in owned or entry.get("category","")!="consumable" or game.player.health<=0 or healing.size()>=297: return false
	quantities[id]=int(quantities.get(id,1))-1
	if quantities[id]<=0: quantities.erase(id); owned.erase(id)
	healing.append({"id":id,"remaining":float(entry.effects.regen_seconds),"clock":0.0})
	game.player.restore_health(game.player.health+int(entry.effects.burst_heal))
	game.notify("Drank "+entry.name+".")
	return true
func found_windstep() -> void:
	if "windstep" not in owned: owned.append("windstep")
	slots.necklace="windstep"
	game.goblin_campaign.charm_equipped=true
func migrate_windstep(legacy:Dictionary) -> void:
	if "windstep" in legacy.get("flags",[]):
		if "windstep" not in owned: owned.append("windstep")
		if not slots.has("necklace") and legacy.get("charm_equipped",false): slots.necklace="windstep"
	game.goblin_campaign.charm_equipped=slots.get("necklace","")=="windstep" and "windstep" in game.goblin_campaign.flags

func bonus(key:String) -> float:
	var value=0.0
	for id in slots.values(): value+=float(item(id).get("effects",{}).get(key,0))
	for group in catalog.get("sets",[]):
		if group.items.all(func(id): return id in slots.values()): value+=float(group.effects.get(key,0))
	return value
func claim(id:String) -> bool:
	var entry=item(id)
	if entry.is_empty() or game.map_id!="menagery": return false
	if entry.category=="consumable":
		if int(quantities.get(id,0))>=99: return false
		quantities[id]=int(quantities.get(id,0))+1
	elif id in owned: return false
	if id not in owned: owned.append(id)
	game.notify("Added "+entry.name+". "+("Drink in Inventory [I]." if entry.category=="consumable" else "Select an equipment slot in Inventory [I]."))
	return true
func equip(slot:String,id:String) -> bool:
	if slot not in SLOTS or (not id.is_empty() and (id not in owned or item(id).category!=category(slot))): return false
	# One specimen may move between ring slots, but cannot occupy both at once.
	for other in SLOTS:
		if not id.is_empty() and slots.get(other,"")==id: slots[other]=""
	slots[slot]=id
	if slot=="necklace": game.goblin_campaign.charm_equipped=id=="windstep" and "windstep" in game.goblin_campaign.flags
	game.apply_skill_stats()
	return true
func apply_stats() -> void:
	var p=game.player
	p.max_health+=roundi(bonus("health"))
	p.combat.stamina_regen+=bonus("stamina_regen")
	var speed=1+bonus("speed")
	p.walk_speed*=speed
	for key in ["drawn_walk_speed","sprint_speed","drawn_sprint_speed"]: p.combat[key]*=speed
	for key in ["sprint_drain","drawn_sprint_drain"]: p.combat[key]*=1-clampf(bonus("sprint_saving"),0,.65)
	for key in ["light","heavy","thrust"]: p.combat[key].damage=roundi(p.combat[key].damage*(1+bonus("melee")))
	for attack in p.combat.combo: attack.damage=roundi(attack.damage*(1+bonus("melee")))
	for key in ["water","lance"]:
		p.combat[key].stamina_cost*=1-clampf(bonus("water_saving"),0,.65)
		p.combat[key].damage=roundi(p.combat[key].damage*(1+bonus("water_damage")))
		p.combat[key].range*=1+bonus("water_range")
	p.combat.lance.splash_damage=roundi(p.combat.lance.splash_damage*(1+bonus("water_damage")))
	p.combat.lance.blast_radius*=1+bonus("water_range")
	p.combat.lance.charge_seconds*=1-clampf(bonus("lance_haste"),0,.4)
	p.combat.parry.stamina_cost*=1-clampf(bonus("parry_saving"),0,.65)
	p.combat.parry.active_end=minf(.62,p.combat.parry.active_end+bonus("parry_window"))
	p.combat.dodge.stamina_cost*=1-clampf(bonus("dodge_saving"),0,.65)
	p.combat.dodge.stand_seconds*=1-clampf(bonus("stand_haste"),0,.4)
	p.combat.slam_shockwave.radius*=1+bonus("slam_range")
	p.combat.slam_shockwave.force_factor*=1+bonus("slam_force")
	p.magic_gear=self
	var key=JSON.stringify(slots)
	if key!=visual_key:
		visual_key=key; Visuals.apply(p,self)
func incoming_damage(amount:int) -> int:
	quiet_seconds=0; heal_clock=0
	amount=maxi(1,roundi(amount*(1-clampf(bonus("armor"),-.5,.6))))
	if amount>=game.player.health and bonus("phoenix")>0 and phoenix_cooldown<=0:
		phoenix_cooldown=60; game.notify("Phoenix Diadem ignites! You survive at 1 HP. Recharge: 60 seconds.")
		return game.player.health-1
	return amount
func parried() -> void:
	var refund=bonus("parry_refund")
	if refund>0: game.player.restore_stamina(game.player.stamina+refund)
func sword_hit(enemy:Node,previous:int) -> void:
	if enemy.health>=previous: return
	var heal=roundi(bonus("life_on_hit"))
	if heal>0 and game.player.health>0: game.player.restore_health(game.player.health+heal)
func tick(delta:float) -> void:
	if not game.player.input_enabled or game.player.health<=0 or game.gallery_mode: return
	phoenix_cooldown=maxf(0,phoenix_cooldown-delta); quiet_seconds+=delta
	for buff in healing:
		var active=minf(delta,buff.remaining); buff.remaining=maxf(0,buff.remaining-delta); buff.clock+=active
		while buff.clock>=1:
			buff.clock-=1; game.player.restore_health(game.player.health+int(item(buff.id).effects.regen_rate))
	healing=healing.filter(func(buff): return buff.remaining>0)
	if bonus("health_regen")>0 and quiet_seconds>=4 and game.player.state=="free":
		heal_clock+=delta
		if heal_clock>=1:
			heal_clock-=1; game.player.restore_health(game.player.health+roundi(bonus("health_regen")))
