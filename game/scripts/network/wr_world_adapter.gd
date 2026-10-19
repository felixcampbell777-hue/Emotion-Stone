extends RefCounted
## The dedicated authority uses the same authored support, obstacles and encounter
## data as local play. No render nodes, client camera or local save are required.
const Rise=preload("res://scripts/rise_shape.gd")
const Fen=preload("res://scripts/swamp_shape.gd")
const West=preload("res://scripts/west_islands.gd")
const Swamp=preload("res://scripts/swamp_campaign.gd")
const Guild=preload("res://scripts/rise_guild.gd")
const FLOORS=["wr_floor_01","wr_floor_02","wr_boss_chamber"]
const RESET_EMPTY_SECONDS=30.0
const PARTICIPATION_RADIUS=40.0
var loot=Guild.new()
var beta:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://content/beta.json"))
var library:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://content/alpha2_creatures.json"))
var progression:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://content/progression.json"))

func ground_height(floor_id:String,at:Vector3) -> float:
	match floor_id:
		"wr_floor_01":
			if Vector2(at.x,at.z).length()>239:
				var support=West.support(at)
				return -55.0 if is_nan(support) else support
			return Rise.height(at)
		"wr_floor_02":return Fen.height(at)
		"wr_boss_chamber":return 0.0 if chamber_supported(at) else -55.0
	return -55.0

func chamber_supported(at:Vector3,margin:float=0.0) -> bool:
	return Vector2(at.x/(23.0-margin),at.z/(25.0-margin)).length()<=1.0 or (absf(at.x)<3.0-margin and at.z>=21 and at.z<=40-margin)

func safe_position(floor_id:String,at:Vector3) -> bool:
	if not at.is_finite():return false
	match floor_id:
		"wr_floor_01":
			if not Rise.safe(at):return false
			# Aqueduct columns have collision in rise_floor; retain their real footprint.
			for i in range(7):
				if absf(at.x-(45+i*8))<.95 and absf(at.z+150)<1.15:return false
			return true
		"wr_floor_02":
			# Deep water is traversable (and lethal), rather than an invisible wall.
			return Vector2(at.x,at.z).length()<239.0 and not raft_obstructed(at)
		"wr_boss_chamber":
			if not chamber_supported(at):return false
			return not (absf(absf(at.x)-3.8)<1.05 and absf(at.z-38.5)<1.75)
	return false

func raft_obstructed(at:Vector3) -> bool:
	var p=Vector2(at.x-Fen.spec.raft.anchor[0],at.z-Fen.spec.raft.anchor[1])
	# Actual deck edge posts; deck/gangplank itself stays traversable.
	return p.x>=12 and p.x<=20 and absf(absf(p.y)-4.2)<.25 and (absf(p.x-12.5)<.3 or absf(p.x-19.5)<.3)

func floor_arrival(floor_id:String) -> Vector3:
	var result=Vector3(0,0,36) if floor_id=="wr_boss_chamber" else Vector3(Fen.arrival().x,0,Fen.arrival().y) if floor_id=="wr_floor_02" else Vector3.ZERO
	result.y=ground_height(floor_id,result);return result

func safe_move(floor_id:String,origin:Vector3,destination:Vector3,radius:float=.3) -> Vector3:
	if not origin.is_finite() or not destination.is_finite():return origin
	var steps=clampi(ceili(origin.distance_to(destination)/.2),1,256);var result=origin
	for index in range(1,steps+1):
		var candidate=origin.lerp(destination,float(index)/steps);var blocked=not safe_position(floor_id,candidate)
		for offset in [Vector3(radius,0,0),Vector3(-radius,0,0),Vector3(0,0,radius),Vector3(0,0,-radius)]:
			if not safe_position(floor_id,candidate+offset):blocked=true;break
		if blocked:break
		candidate.y=ground_height(floor_id,candidate);result=candidate
	return result

func impact_blocked(floor_id:String,origin:Vector3,destination:Vector3) -> bool:
	var steps=clampi(ceili(origin.distance_to(destination)/.2),1,2048)
	for i in range(1,steps):
		var at=origin.lerp(destination,float(i)/steps)
		if at.y<ground_height(floor_id,at):return true
		if floor_id=="wr_floor_01":
			for tree in Rise.spec.trees:
				if Vector2(tree[0]+168,tree[1]+125).length()<10:continue
				if at.y<Rise.height(at)+float(tree[2]) and Vector2(at.x-tree[0],at.z-tree[1]).length()<float(tree[3]):return true
			var local=(Vector2(at.x,at.z)-Vector2(Rise.spec.guild.at[0],Rise.spec.guild.at[1])).rotated(Rise.spec.guild.rotation)
			for solid in Rise.spec.guild.solids:
				if at.y<Rise.spec.guild.height+6 and absf(local.x-solid[0])<solid[2]*.5 and absf(local.y-solid[1])<solid[3]*.5:return true
			for column in range(7):
				if absf(at.x-(45+column*8))<.7 and absf(at.z+150)<.9 and at.y<Rise.height(at)+8:return true
		elif floor_id=="wr_boss_chamber" and absf(absf(at.x)-3.8)<.8 and absf(at.z-38.5)<1.5 and at.y<6.4:return true
	return false

func encounter_entries(floor_id:String) -> Array:
	var entries=[]
	if floor_id=="wr_floor_02":
		for entry in Swamp.all_entries():
			var stats=Swamp.STATS[entry.style]
			var record=base_entry(floor_id,entry,entry.style,int(stats[0]),int(stats[1]),int(stats[2]))
			record.merge({"speed":1.25 if entry.style=="giant_green_slime" else 2.5,"aggro":19.0,"windup":.85,"recovery":1.45,"range":9.0 if entry.style=="giant_green_slime" else 3.6,"attack_speed":7.0,"lunge_seconds":.32})
			if entry.has("parent_id"):record.parent_id=entry.parent_id
			if entry.style=="giant_green_slime":record.split=4
			entries.append(record)
	elif floor_id=="wr_floor_01":
		var data=JSON.parse_string(FileAccess.get_file_as_string("res://content/maps/wr_floor_01.json"))
		for entry in data.enemies:
			var pack=Rise.spec.packs.filter(func(p):return p.id==entry.get("pack",""))
			if pack.is_empty():continue
			var p=pack[0];var kind=String(p.kind);var stats=library.get(kind,{}) if kind=="library_boar" else beta.animals.get("beta_wolf",{})
			var health=65+int(p.tier)*25 if kind=="library_boar" else int(beta.animals.get(kind,stats).get("max_health",80))
			var damage=9+int(p.tier)*4 if kind=="library_boar" else 14 if kind=="beta_twin_wolf" else 12
			var record=base_entry(floor_id,entry,kind,health,damage,xp_for(kind))
			record.merge({"pack":p.id,"home":[p.at[0],ground_height(floor_id,Vector3(p.at[0],0,p.at[1])),p.at[1]],"speed":float(stats.get("speed",stats.get("walk_speed",1.65))),"aggro":20.0,"leash":42.0,"windup":.8 if kind=="library_boar" else .7,"recovery":1.1 if kind=="library_boar" else 1.0,"range":5.5 if kind=="library_boar" else 3.2,"night_double":p.get("night_double",true)})
			entries.append(record)
		var ash=base_entry(floor_id,{"id":"ashfang","at":[-437,55]},"ashfang",360,24,xp_for("ashfang"))
		ash.merge({"night_only":true,"cooldown":1080.0,"aggro":19.0,"leash":22.0,"speed":2.7,"windup":1.35,"recovery":1.25,"range":14.0,"first_bonus":200,"first_flag":"ashfang_first_kill_bonus"});entries.append(ash)
		for i in range(3):
			var angle=(i+1)*TAU/3;var at=West.GROVE+Vector3(cos(angle),0,sin(angle))*21
			var aid=base_entry(floor_id,{"id":"ashfang_wolf_%d"%i,"at":[at.x,at.z]},"beta_wolf",80,12,xp_for("beta_wolf"));aid.merge({"summoned":true,"parent_boss":"ashfang","night_only":true,"pack":"ashfang_aid"});entries.append(aid)
	elif floor_id=="wr_boss_chamber":
		var elder=base_entry(floor_id,{"id":"vault_elder","at":[0,-5]},"vault_elder",1100,19,500)
		elder.merge({"cooldown":1080.0,"aggro":80.0,"leash":100.0,"speed":2.2,"windup":1.25,"recovery":1.3,"range":4.8,"first_bonus":1000,"first_flag":"elder_first_kill_bonus","arena":true});entries.append(elder)
	return entries

func xp_for(kind:String) -> int:
	if Guild.catalog.kill_xp_overrides.has(kind):return int(Guild.catalog.kill_xp_overrides[kind])
	return roundi(float(progression.enemy_xp.get(kind,0))*float(Guild.catalog.kill_xp_multiplier))

func base_entry(floor_id:String,entry:Dictionary,kind:String,hp:int,damage:int,xp:int) -> Dictionary:
	var at=Vector3(entry.at[0],0,entry.at[1]);at.y=ground_height(floor_id,at)
	return {"id":entry.id,"floor":floor_id,"at":entry.at.duplicate(),"position":[at.x,at.y,at.z],"kind":kind,"max_health":hp,"health":hp,"damage":damage,"xp":xp,"copper":Guild.catalog.coins.get("green_slime" if kind=="resin_slime" else "beta_wolf" if kind=="beta_twin_wolf" else kind,[0,0]).duplicate(),"split":0}

func roll_rewards(entry:Dictionary,rng:RandomNumberGenerator) -> Dictionary:
	if entry.get("summoned",false):return {"xp":int(entry.xp),"copper":0,"items":{}}
	# Reuse the offline table verbatim, with the authority's durable RNG stream.
	loot.rng=rng
	var rolled=loot.roll(String(entry.kind))
	if rolled.is_empty():rolled={"copper":0,"items":{}}
	rolled.xp=int(entry.get("xp",xp_for(String(entry.kind))))
	return rolled
