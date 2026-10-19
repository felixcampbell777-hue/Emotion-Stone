extends RefCounted
## Pure validation plus one authority-owned durable commit per accepted trade.
const Guild=preload("res://scripts/rise_guild.gd")
const Rise=preload("res://scripts/rise_shape.gd")
const Fen=preload("res://scripts/swamp_shape.gd")
static func vendor_position(floor_id:String,role:String) -> Vector3:
	if floor_id=="wr_floor_02":return Vector3(Fen.spec.raft.anchor[0]+16+(-1.7 if role=="wr_clerk" else 1.7),.85,Fen.spec.raft.anchor[1]+.1)
	var local={"wr_clerk":Vector3(0,0,-4.5),"wr_armorer":Vector3(-6,0,3.5),"wr_swords":Vector3(7,0,1.5)}.get(role,Vector3.ZERO)
	return Vector3(Rise.spec.guild.at[0],Rise.spec.guild.height,Rise.spec.guild.at[1])+local.rotated(Vector3.UP,float(Rise.spec.guild.rotation))
static func nearby(p:Dictionary,role:String) -> bool:
	if p.floor not in ["wr_floor_01","wr_floor_02"] or int(p.health)<=0:return false
	if p.floor=="wr_floor_02" and role=="wr_armorer":return false
	var at=Vector3(p.position[0],p.position[1],p.position[2])
	return at.distance_to(vendor_position(p.floor,role))<4.0
static func transact(authority:RefCounted,p:Dictionary,kind:String,payload:Dictionary) -> Dictionary:
	var profile=p.profile.duplicate(true);var next=authority.store.data.duplicate(true)
	var item=String(payload.get("item",payload.get("id","")))
	if kind=="purchase":
		if item in ["wooden_arrows","guild_healing_potion"]:
			var raw=payload.get("count",1)
			if not raw is int or raw<1 or raw>99:return authority.fail("Invalid quantity")
			var role="wr_swords" if item=="wooden_arrows" else "wr_clerk"
			if not nearby(p,role):return authority.fail("Speak to this vendor nearby")
			var count=int(raw);var owned=int(profile.magic_items.quantities.get(item,0));var cost=count*(1 if item=="wooden_arrows" else 25)
			if owned+count>99:return authority.fail("Item stack is full")
			if int(profile.copper)<cost:return authority.fail("Not enough copper")
			profile.copper-=cost;profile.magic_items.quantities[item]=owned+count
			if item not in profile.magic_items.owned:profile.magic_items.owned.append(item)
		else:
			var recipe=Guild.catalog.recipes.get(item,{})
			if recipe.is_empty():return authority.fail("Unknown recipe")
			if not nearby(p,String(recipe.get("vendor","wr_armorer"))):return authority.fail("Speak to this vendor nearby")
			if not String(recipe.get("floor","")).is_empty() and recipe.floor!=p.floor:return authority.fail("This recipe is available on another floor")
			if recipe.get("requires_elder",false) and "elder_defeated" not in next.flags:return authority.fail("Defeat the Elder first")
			if item in profile.magic_items.owned:return authority.fail("Already owned")
			var growth=preload("res://scripts/progression.gd").new();growth.restore(profile.progression)
			if growth.level()<int(recipe.level):return authority.fail("Level requirement not met")
			if int(profile.copper)<int(recipe.copper):return authority.fail("Not enough copper")
			for material in recipe.materials:
				if int(profile.materials.get(material,0))<int(recipe.materials[material]):return authority.fail("Not enough materials")
			profile.copper-=int(recipe.copper)
			for material in recipe.materials:
				profile.materials[material]-=int(recipe.materials[material])
				if profile.materials[material]<=0:profile.materials.erase(material)
			profile.magic_items.owned.append(item)
	elif kind=="sell":
		if not nearby(p,"wr_clerk") or not Guild.catalog.materials.has(item):return authority.fail("Speak to the clerk nearby")
		var count=int(profile.materials.get(item,0)) if payload.get("all",false)==true else 1
		if count<1 or int(profile.materials.get(item,0))<count:return authority.fail("Material not owned")
		var value=count*int(Guild.catalog.materials[item].value)
		if int(profile.copper)+value>100000000:return authority.fail("Purse is full")
		profile.copper+=value;profile.materials[item]-=count
		if profile.materials[item]<=0:profile.materials.erase(item)
	elif kind=="contract":
		if p.floor!="wr_floor_01" or not nearby(p,"wr_clerk") or not Guild.catalog.contracts.has(item):return authority.fail("Speak to the Floor One clerk nearby")
		var visitor=next.visitors.get(p.id,{}).duplicate(true);var contracts=visitor.get("contracts",{}).duplicate(true);var state=contracts.get(item,{"active":false,"count":0,"completed":false})
		if state.get("completed",false):return authority.fail("Contract already paid")
		if not state.get("active",false):contracts[item]={"active":true,"count":0,"completed":false}
		else:
			var contract=Guild.catalog.contracts[item]
			if int(state.count)<int(contract.target):return authority.fail("Complete the hunt first")
			if int(profile.copper)+int(contract.reward)>100000000:return authority.fail("Purse is full")
			profile.copper+=int(contract.reward)
			var thresholds=JSON.parse_string(FileAccess.get_file_as_string("res://content/progression.json")).level_thresholds;var level=int(contract.xp_level)
			profile.progression.xp=mini(10000000,int(profile.progression.xp)+roundi((float(thresholds[level])-float(thresholds[level-1]))/3.0))
			contracts[item]={"active":false,"count":10,"completed":true}
		visitor["contracts"]=contracts;next.visitors[p.id]=visitor
	else:return authority.fail("Unknown transaction")
	return authority.finish_economy(p,profile,next)
static func record_kill(next:Dictionary,character_id:String,kind:String) -> void:
	var visitor=next.visitors.get(character_id,{});var contracts=visitor.get("contracts",{})
	for id in contracts:
		if contracts[id].get("active",false) and Guild.catalog.contracts.has(id) and Guild.catalog.contracts[id].kind==("beta_wolf" if kind=="beta_twin_wolf" else kind):contracts[id].count=mini(10,int(contracts[id].count)+1)
	visitor["contracts"]=contracts;next.visitors[character_id]=visitor
