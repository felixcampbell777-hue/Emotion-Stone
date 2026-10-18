extends RefCounted
const DATA=preload("res://scripts/rise_shape.gd")
const Props=preload("res://scripts/props.gd")
static var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://content/world_rise/guild.json"))
var game:Node
var copper=0
var materials:Dictionary={}
var drops:Dictionary={}
var nodes:Dictionary={}
var contracts:Dictionary={}
var rng=RandomNumberGenerator.new()
func _init() -> void:rng.randomize()
func active() -> bool:return game!=null and game.game_mode=="world_rise" and game.map_id=="wr_floor_01"
static func integer(value:Variant,limit:int) -> bool:return (value is int or value is float) and is_finite(float(value)) and value==int(value) and value>=0 and value<=limit
static func valid_counts(data:Variant,gear:bool=false) -> bool:
	if not data is Dictionary or data.size()>catalog.materials.size()+1:return false
	for id in data:
		if (not catalog.materials.has(id) and not (gear and (id=="elder_heart_necklace" or id in ["wolfs_bane_greatsword","improved_standard_greatsword"]))) or not integer(data[id],99999) or data[id]<1:return false
	return true
static func valid(data:Variant) -> bool:
	if not data is Dictionary or not integer(data.get("copper",0),100000000) or not valid_counts(data.get("materials",{})):return false
	var quests=data.get("contracts",{})
	if not quests is Dictionary or quests.size()>2:return false
	for id in quests:
		if not catalog.contracts.has(id) or not quests[id] is Dictionary:return false
		var entry=quests[id]
		if not entry.get("active",false) is bool or not entry.get("completed",false) is bool or not integer(entry.get("count",0),10):return false
		if entry.get("completed",false) and (entry.get("active",false) or entry.get("count",0)!=10):return false
		if not entry.get("completed",false) and not entry.get("active",false) and entry.get("count",0)!=0:return false
	var pending=data.get("drops",{})
	if not pending is Dictionary or pending.size()>160:return false
	var enemies=JSON.parse_string(FileAccess.get_file_as_string("res://content/maps/wr_floor_01.json")).enemies
	for key in pending:
		if key not in ["wr_boss_chamber/vault_elder","wr_floor_01/ashfang"] and not enemies.any(func(e):return key=="wr_floor_01/"+e.id or key=="wr_floor_01/"+e.id+"_night"):return false
		var drop=pending[key]
		if not drop is Dictionary or not drop.has_all(["at","copper","items"]) or not integer(drop.copper,100000000) or not valid_counts(drop.items,true):return false
		if not drop.at is Array or drop.at.size()!=2:return false
		for v in drop.at:
			if not (v is int or v is float) or not is_finite(float(v)) or absf(v)>500:return false
	return true
func reset() -> void:copper=0;materials.clear();drops.clear();nodes.clear();contracts.clear()
func snapshot() -> Dictionary:return {"copper":copper,"materials":materials.duplicate(),"drops":drops.duplicate(true),"contracts":contracts.duplicate(true)}
func restore(data:Dictionary) -> void:
	copper=int(data.get("copper",0));materials=data.get("materials",{}).duplicate();drops=data.get("drops",{}).duplicate(true);contracts=data.get("contracts",{}).duplicate(true);nodes.clear()
	# Earlier sacks contained coins. Credit those once on load, preserving items.
	for key in drops.keys():
		copper=mini(100000000,copper+int(drops[key].copper));drops[key].copper=0
		if drops[key].items.is_empty():drops.erase(key)
func purse() -> String:return "%d gp %d cp"%[copper/100,copper%100]
func roll(kind:String,coin_roll:int=-1,hide_roll:float=-1,rare_roll:float=-1) -> Dictionary:
	if not catalog.coins.has(kind):return {}
	var range= catalog.coins[kind];var result={"copper":rng.randi_range(range[0],range[1]) if coin_roll<0 else clampi(coin_roll,range[0],range[1]),"items":{}}
	if kind=="ashfang":
		result.items.wolf_fang=1;result.items.wolf_hide=rng.randi_range(2,3)
		if rng.randf()<.04:result.items.wolfs_bane_greatsword=1
		return result
	for id in catalog.materials:
		var entry=catalog.materials[id]
		if entry.beast!=kind:continue
		var chance=hide_roll if id.ends_with("hide") or id=="elder_leaves" else rare_roll
		if (rng.randf() if chance<0 else chance)<entry.chance:result.items[id]=1
	if kind=="vault_elder" and (rng.randf() if rare_roll<0 else rare_roll)<.05:result.items.elder_heart_necklace=1
	return result
func defeated(key:String,kind:String,at:Vector3) -> void:
	if not active() and not (game.game_mode=="world_rise" and game.map_id=="wr_boss_chamber" and kind=="vault_elder"):return
	var rolled=roll(kind)
	if rolled.is_empty():return
	if "elder_heart_necklace" in game.magic_items.owned or drops.values().any(func(d):return d.items.has("elder_heart_necklace")):rolled.items.erase("elder_heart_necklace")
	for id in contracts:
		if contracts[id].active and catalog.contracts[id].kind==kind:contracts[id].count=mini(10,int(contracts[id].count)+1)
	copper=mini(100000000,copper+int(rolled.copper))
	if rolled.items.is_empty():return
	var horizontal=Vector2(at.x,at.z).limit_length(500);at=Vector3(horizontal.x,0,horizontal.y)
	if not drops.has(key):drops[key]={"at":[at.x,at.z],"copper":0,"items":{}}
	var drop=drops[key]
	for id in rolled.items:drop.items[id]=mini(99999,int(drop.items.get(id,0))+rolled.items[id])
	build_drop(key)
func build() -> void:
	nodes.clear()
	if not active():return
	for key in drops:build_drop(key)
	var house=game.current_world.get_node("AdventurersGuild")
	for entry in [["wr_clerk","Mara · Guild Front Desk","farm_mira",Vector3(0,0,-3)],["wr_armorer","Bram · Guild Armorer","farm_rowan",Vector3(-6,0,5)],["wr_swords","Corin · Sword Merchant","keeper",Vector3(7,0,3)]]:
		var npc=load("res://scripts/actor.gd").new();npc.name=entry[0]
		var definition=game.read_data("res://content/characters/"+entry[2]+".json").duplicate(true);definition.display_name=entry[1];npc.configure(definition)
		game.EnvironmentArt.actor_quality(npc,game.environment_profile);npc.ground_world=game.current_world;game.world_root.add_child(npc);npc.position=house.to_global(entry[3]);npc.visual.rotation.y=house.rotation.y+PI;game.npcs.append(npc)
		game.current_world.interactions.append({"id":entry[0],"title":entry[1],"role":entry[0],"position":house.to_global(entry[3]+Vector3(0,0,-1.5)),"actor":npc,"lines":[]})
func build_drop(key:String) -> void:
	if game==null or game.game_mode!="world_rise" or game.map_id!=key.get_slice("/",0):return
	if nodes.has(key) and is_instance_valid(nodes[key]):nodes[key].queue_free()
	game.current_world.interactions=game.current_world.interactions.filter(func(t):return t.get("beast_loot","")!=key)
	var drop=drops[key];var root=Node3D.new();root.name="BeastLoot";game.current_world.add_child(root);nodes[key]=root;root.position=Vector3(drop.at[0],0,drop.at[1]);root.position.y=game.current_world.ground_height(root.position)
	Props.cone(root,Vector3(0,.16,0),.24,.32,"#8d6843",.14);Props.cone(root,Vector3(0,.35,0),.14,.09,"#b6a27c",.06)
	game.current_world.interactions.append({"id":"beast_loot_"+key.get_file(),"beast_loot":key,"title":"Loot Elder spoils" if key.begins_with("wr_boss_chamber/") else "Loot beast spoils","position":root.position,"actor":null,"lines":[]})
func collect(key:String) -> bool:
	if not drops.has(key) or game.game_mode!="world_rise" or game.map_id!=key.get_slice("/",0) or not game.player.input_enabled:return false
	var drop=drops[key];var at=Vector3(drop.at[0],0,drop.at[1]);at.y=game.current_world.ground_height(at)
	if game.player.position.distance_to(at)>float(game.config.interaction_distance):return false
	var summary=[]
	for id in drop.items:
		if id=="elder_heart_necklace":
			if id not in game.magic_items.owned:game.magic_items.owned.append(id)
			summary.append("Elder Heart Necklace")
		elif catalog.materials.has(id):materials[id]=mini(99999,int(materials.get(id,0))+int(drop.items[id]));summary.append("%s ×%d"%[catalog.materials[id].name,drop.items[id]])
		elif game.magic_items.item(id).get("category","")=="weapon":
			if id not in game.magic_items.owned:game.magic_items.owned.append(id)
			summary.append(game.magic_items.item(id).name)
	drops.erase(key)
	if nodes.has(key) and is_instance_valid(nodes[key]):nodes[key].queue_free()
	nodes.erase(key);game.current_world.interactions=game.current_world.interactions.filter(func(t):return t.get("beast_loot","")!=key);game.nearest={};game.notify("Collected "+", ".join(summary)+".");return true
func context(role:String) -> bool:
	return active() and game.conversation.visible and game.conversation.target.get("role","")==role and game.player.position.distance_to(game.conversation.target.position)<4 and game.player.health>0
func sell(id:String,all_items:bool=false) -> bool:
	if not context("wr_clerk") or not catalog.materials.has(id) or int(materials.get(id,0))<1:return false
	var count=int(materials[id]) if all_items else 1;var value=count*int(catalog.materials[id].value)
	if copper+value>100000000:return false
	materials[id]-=count
	if materials[id]<=0:materials.erase(id)
	copper+=value;return true
func contract_action(id:String) -> bool:
	if not context("wr_clerk") or not catalog.contracts.has(id):return false
	var state=contracts.get(id,{"active":false,"count":0})
	if state.get("completed",false):return false
	if not state.active:contracts[id]={"active":true,"count":0,"completed":false};return true
	if int(state.count)<10 or copper+int(catalog.contracts[id].reward)>100000000:return false
	copper+=int(catalog.contracts[id].reward);contracts[id]={"active":false,"count":10,"completed":true};game.gain_xp(contract_xp(id));return true
func contract_xp(id:String) -> int:
	var level=int(catalog.contracts[id].xp_level);var thresholds=game.progression.definition.level_thresholds
	return roundi((float(thresholds[level])-float(thresholds[level-1]))/3.0)
func buy_potion() -> bool:
	var id="guild_healing_potion"
	if not context("wr_clerk") or copper<25 or int(game.magic_items.quantities.get(id,0))>=99:return false
	copper-=25
	if id not in game.magic_items.owned:game.magic_items.owned.append(id)
	game.magic_items.quantities[id]=int(game.magic_items.quantities.get(id,0))+1
	game.notify("Purchased Healing Potion · restores 25 HP.");return true
func craft_error(id:String) -> String:
	if not catalog.recipes.has(id):return "Unknown recipe"
	if id in game.magic_items.owned:return "Already owned"
	var recipe=catalog.recipes[id]
	if recipe.get("requires_elder",false) and not elder_unlocked():return "Defeat the Elder first"
	if game.progression.level()<int(recipe.level):return "Requires level %d"%recipe.level
	for material in recipe.materials:
		if int(materials.get(material,0))<int(recipe.materials[material]):return "Not enough materials"
	if copper<int(recipe.copper):return "Not enough copper"
	return ""
func craft(id:String) -> bool:
	if not catalog.recipes.has(id) or not context(catalog.recipes[id].get("vendor","wr_armorer")) or not craft_error(id).is_empty():return false
	var recipe=catalog.recipes[id];copper-=int(recipe.copper)
	for material in recipe.materials:
		materials[material]-=int(recipe.materials[material])
		if materials[material]<=0:materials.erase(material)
	game.magic_items.owned.append(id)
	game.notify(("Purchased " if recipe.get("vendor","")=="wr_swords" else "Crafted ")+game.magic_items.item(id).name+". Find it in Inventory → "+("Weapons." if game.magic_items.item(id).category=="weapon" else "Apparel."));return true
func elder_unlocked() -> bool:return "elder_defeated" in game.worldrise.flags or "wr_boss_chamber/vault_elder" in game.defeated_enemies
func dialogue(ui:Control,target:Dictionary,page:String="") -> void:
	ui.clear_choices();ui.title.text=target.title.to_upper()
	if target.role=="wr_clerk":
		ui.text.text="Welcome to the Verdant Reach Adventurers' Guild. Sell beast spoils here, or keep your hides for Bram's armor.\nPurse: "+purse()
		if page=="contracts":
			ui.text.text="One-time guild contracts · kills count after acceptance. Return here to claim each reward once.\nPurse: "+purse()
			for id in catalog.contracts:
				var contract=catalog.contracts[id];var state=contracts.get(id,{"active":false,"count":0});var label=("Completed · " if state.get("completed",false) else "Accept · " if not state.active else "Turn in · " if state.count>=10 else "Hunting · ")+contract.name+" · %d/10 · %d cp + %d XP"%[state.count,contract.reward,contract_xp(id)]
				var action=game.button(label,func():contract_action(id);dialogue(ui,target,"contracts"));action.disabled=state.get("completed",false) or (state.active and state.count<10);ui.choices.add_child(action)
			ui.choices.add_child(game.button("Back",func():dialogue(ui,target)))
		elif page in ["boar","wolf"]:
			for id in catalog.materials:
				if not id.begins_with(page):continue
				var item=catalog.materials[id];var action=game.button("Sell 1 %s · %d cp (owned: %d)"%[item.name,item.value,materials.get(id,0)],func():sell(id);dialogue(ui,target,page));action.disabled=int(materials.get(id,0))<1;ui.choices.add_child(action)
			ui.choices.add_child(game.button("Back",func():dialogue(ui,target)))
		else:
			var potion=game.button("Buy Healing Potion · 25 HP · 25 cp (owned: %d)"%game.magic_items.quantities.get("guild_healing_potion",0),func():buy_potion();dialogue(ui,target));potion.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			potion.disabled=copper<25 or int(game.magic_items.quantities.get("guild_healing_potion",0))>=99;ui.choices.add_child(potion)
			ui.choices.add_child(game.button("Sell boar materials",func():dialogue(ui,target,"boar")));ui.choices.add_child(game.button("Sell wolf materials",func():dialogue(ui,target,"wolf")))
			ui.choices.add_child(game.button("Guild contracts · 10 boars / 10 wolves",func():dialogue(ui,target,"contracts")))
	elif target.role in ["wr_armorer","wr_swords"]:
		ui.text.text=("I turn hard-earned hides and trophies into equipment." if target.role=="wr_armorer" else "Corin's sword shop. Choose a blade, then equip it from Inventory → Weapons.")+"\nPurse: "+purse()+" · Level %d"%game.progression.level()
		for id in catalog.recipes:
			var recipe=catalog.recipes[id];var costs=[]
			if recipe.get("vendor","wr_armorer")!=target.role:continue
			if recipe.get("requires_elder",false) and not elder_unlocked():continue
			for material in recipe.materials:costs.append("%d %s (%d owned)"%[recipe.materials[material],catalog.materials[material].name,materials.get(material,0)])
			costs.append("%d cp"%recipe.copper)
			var reason=craft_error(id);var action=game.button("%s · Lv %d · %s%s"%[game.magic_items.item(id).name,recipe.level," + ".join(costs)," · "+reason if not reason.is_empty() else ""],func():craft(id);dialogue(ui,target));action.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;action.disabled=not reason.is_empty();ui.choices.add_child(action)
	ui.choices.add_child(game.button("Leave  /  E",ui.close));ui.choices.get_child(0).grab_focus()
func inventory_items() -> Array:
	var result=[]
	for id in materials:
		var item=catalog.materials[id];result.append({"kind":"material","id":id,"name":item.name,"description":"Guild trade material · %d copper each. Keep for crafting, or sell at the front desk."%item.value,"count":int(materials[id])})
	return result
