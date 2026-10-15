extends RefCounted
## The Hollow Bell: authored, separate campaign. Flags reward exactly once; no implicit saves.
const Props=preload("res://scripts/props.gd")
const Worlds=preload("res://scripts/world_pack.gd")
var game:Node
var definition:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://content/alpha2.json"))
var flags:Array=[]
var checkpoint="a2_haven"
var checkpoint_at:Array=[0,5]
var ending=""
var played_seconds=0.0
var objects:Dictionary={}
var compass:Label
var water_status:Label
var bell_notes:Array=[]
const STORY_FLAGS=["begun","medicine_asked","medicine_returned","courier_asked","courier_safe","courier_returned","ledger_asked","ledger_returned","memory_asked","memory_returned","completed","forest_tuned"]

static func valid_mode(mode:Variant,map_id:Variant,world:Variant="") -> bool:
	if not mode is String or not map_id is String: return false
	var areas=JSON.parse_string(FileAccess.get_file_as_string("res://content/alpha2.json")).maps
	return (mode=="alpha2" and world=="" and map_id in areas) or (mode=="beta" and world=="" and map_id=="beta_meadow") or (mode=="alpha" and map_id not in areas and map_id!="beta_meadow")

static func valid_save(data:Variant,defeated:Array) -> bool:
	if not data is Dictionary: return false
	var spec=JSON.parse_string(FileAccess.get_file_as_string("res://content/alpha2.json"))
	var found=data.get("flags",[])
	if not found is Array or found.size()>64: return false
	var allowed=STORY_FLAGS.duplicate()
	for action in spec.actions: allowed.append(action.id)
	var seen=[]
	for flag in found:
		if not flag is String or flag not in allowed or flag in seen: return false
		seen.append(flag)
	for action in spec.actions:
		if action.id in found:
			for enemy in action.get("requires",[]):
				if enemy not in defeated: return false
			if int(data.get("layout_revision",1))>=2:
				for needed in action.get("requires_flags",[]):
					if needed not in found:return false
	if int(data.get("layout_revision",1))>=2 and "wood_ward" in found and "forest_tuned" not in found:return false
	for rule in [["medicine_returned","medicine","medicine_asked"],["courier_returned","courier_safe","courier_asked"],["ledger_returned","ledger","ledger_asked"],["memory_returned","root_memory","memory_asked"]]:
		if rule[0] in found and (rule[1] not in found or rule[2] not in found): return false
	var choice=data.get("ending","")
	if choice not in ["","release","renew"]: return false
	if ("completed" in found)!=(choice!=""): return false
	if "completed" in found and ("bellheart" not in found or not ["mill_ward","quarry_ward","wood_ward"].all(func(id): return id in found)): return false
	var time=data.get("played_seconds",0)
	if not Worlds.finite_number(time) or time<0 or time>100000000: return false
	var at=data.get("checkpoint_at",[0,5])
	if not Worlds.point(at): return false
	# JSON numbers are floats; direct snapshots also contain integers. Compare coordinates numerically.
	var rest=spec.actions.filter(func(a): return a.type=="rest" and a.map==data.get("checkpoint","a2_haven") and float(a.at[0])==float(at[0]) and float(a.at[1])==float(at[1]))
	return not rest.is_empty()

func active() -> bool: return is_instance_valid(game) and game.game_mode=="alpha2"
func reset() -> void:
	flags.clear();bell_notes.clear();checkpoint="a2_haven";checkpoint_at=[0,5];ending="";played_seconds=0;objects.clear()
func snapshot() -> Dictionary:
	return {"layout_revision":2,"flags":flags.duplicate(),"checkpoint":checkpoint,"checkpoint_at":checkpoint_at.duplicate(),"ending":ending,"played_seconds":played_seconds}
func restore(data:Dictionary) -> void:
	flags=data.get("flags",[]).duplicate();checkpoint=data.get("checkpoint","a2_haven");checkpoint_at=data.get("checkpoint_at",[0,5]).duplicate();ending=data.get("ending","");played_seconds=float(data.get("played_seconds",0))
	bell_notes.clear()
	if int(data.get("layout_revision",1))<2:
		if "mill_ward" in flags:mark("wreck_winch");mark("tide_chime")
		if "wood_ward" in flags:mark("forest_tuned")
func mark(id:String,xp:int=0) -> bool:
	if id in flags: return false
	flags.append(id)
	if xp>0: game.gain_xp(xp)
	return true
func grant(item:String,count:int=1) -> void:
	var entry=game.magic_items.item(item)
	if entry.is_empty(): return
	if item not in game.magic_items.owned: game.magic_items.owned.append(item)
	if entry.category=="consumable": game.magic_items.quantities[item]=mini(99,int(game.magic_items.quantities.get(item,0))+count)
func start(imported:Dictionary={}) -> void:
	reset();game.home_intro_complete=true
	# Three familiar movement foundations, plus room to grow through the campaign.
	game.progression.restore({"tree_version":3,"xp":430,"learned":["form","belly_roll","jump"],"passives":[]})
	game.player.jump_equipped=true;game.player.dash_equipped=false;game.player.counter_equipped=false
	if not imported.is_empty():
		game.progression.restore(imported.get("progression",{}))
		game.magic_items.restore(imported.get("magic_items",{}))
		game.monster_cores.restore({"quantities":imported.get("monster_cores",{}).get("quantities",{}).duplicate(),"pending":[],"serial":0})
		var loadout=imported.get("skill_loadout",{})
		game.player.jump_equipped=bool(loadout.get("jump",false));game.player.dash_equipped=bool(loadout.get("dash",false));game.player.counter_equipped=bool(loadout.get("flowing_counter",false))
		game.selected_special_attack=String(imported.get("special_attack","water_sweep"));game.player.heavy_style=String(imported.get("heavy_attack","overhead"))
		game.player.set_sword_equipped(bool(imported.get("sword_equipped",true)))
		game.mother_unwrapped=bool(imported.get("mother_unwrapped",false));game.well_gift_stage="potion_owned" if imported.get("well_gift_stage","")=="potion_owned" else "not_started"
	grant("spring_elixir",3);game.apply_skill_stats();game.update_progression_ui()
func tick(delta:float) -> void:
	if active() and game.player.input_enabled: played_seconds+=delta
	if compass==null:
		compass=game.label("",18,Color("#e2d3ac"));compass.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;compass.mouse_filter=Control.MOUSE_FILTER_IGNORE;game.add_child(compass)
	compass.visible=active() and game.player.input_enabled
	if compass.visible:
		var heading=wrapf(rad_to_deg(game.camera_driver.yaw),0,360)
		var cardinal=["N","NW","W","SW","S","SE","E","NE"][int(round(heading/45))%8]
		compass.text="‹  "+cardinal+"  ›    ◇ %d/3"%wards();compass.size=Vector2(230,28);compass.position=game.world_rect.position+Vector2((game.world_rect.size.x-230)/2,24)
	if water_status==null:
		water_status=game.label("",18,Color("#c2e8ef"));water_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;water_status.mouse_filter=Control.MOUSE_FILTER_IGNORE;game.add_child(water_status)
	var depth=load("res://scripts/wading.gd").depth(game.current_world,game.player.position)
	water_status.visible=active() and game.player.input_enabled and depth>.08
	if water_status.visible:
		water_status.text="DEEP WATER · TURN BACK" if depth>.9 else "Wading · movement slowed"
		water_status.modulate=Color("#f6ad86") if depth>.9 else Color.WHITE
		water_status.size=Vector2(320,28);water_status.position=game.world_rect.position+Vector2((game.world_rect.size.x-320)/2,72)

func prepare_npcs() -> void:
	if not active() or "courier_safe" not in flags: return
	var entries:Array=game.current_world.npc_definitions.duplicate(true)
	if game.map_id=="a2_fen": entries=entries.filter(func(n): return n.id!="jun")
	if game.map_id=="a2_haven": entries.append({"id":"jun","character":"farm_mira","role":"a2_jun","at":[-5,-11],"dialogue":["Home at last!"]})
	game.current_world.npc_definitions=entries

func quest_items() -> Array:
	var items=[]
	if "tide_chime" in flags and "mill_ward" not in flags:items.append({"kind":"quest","id":"tide_chime","name":"Saltwind Bronze Chime","description":"Ring it at the northern shore ward."})
	for entry in [["medicine","medicine_returned","Mara's Medicine Chest","Return to Mara in Hearthmere."],["ledger","ledger_returned","Royal Treasure Ledger","Take the lost treasure routes to Ada in Hearthmere."],["bellheart","completed","Living Compass-heart","Bring the Bellkeeper's treasure to Mother in Hearthmere."]]:
		if entry[0] in flags and entry[1] not in flags: items.append({"kind":"quest","id":entry[0],"name":entry[2],"description":entry[3]})
	return items
func wards() -> int:
	return int("mill_ward" in flags)+int("quarry_ward" in flags)+int("wood_ward" in flags)
func objective() -> String:
	if "completed" in flags: return "The Hollow Bell · Complete. Return to your companions and explore remaining paths."
	if "begun" not in flags: return "Speak to Mother beside Hearthmere's hearth."
	if wards()<3:
		var missing=[]
		for pair in [["mill_ward","Saltwind Strand (west)"],["quarry_ward","Skyglass Bluffs (east)"],["wood_ward","Heartwood (north)"]]:
			if pair[0] not in flags: missing.append(pair[1])
		return "Quiet the wards (%d/3): "%wards()+", ".join(missing)+". I → Quests for leads."
	if "a2_belfry/bellkeeper" not in game.defeated_enemies: return "All three wards are quiet. Meet Sable in the northern chapel; face the Bellkeeper beyond."
	if "bellheart" not in flags: return "Take the heart from the fallen Bellkeeper in the belfry."
	return "Return to Mother in Hearthmere. Decide what becomes of the bell."
func can_travel(route:Dictionary) -> bool:
	if not active(): return true
	var target=String(route.target)
	if target=="a2_crossroads" and "begun" not in flags:
		game.notify("Mother is waiting by the hearth. Speak to her before taking the pilgrim roads.");return false
	if target=="a2_belfry" and wards()<3:
		game.notify("The belfry roots remain sealed: quiet all three ward-stones first (%d/3)."%wards());return false
	return true
func safe(at:Vector3,radius:float=10) -> bool:
	return not game.enemies.any(func(e): return is_instance_valid(e) and e.health>0 and e.position.distance_to(at)<radius)

func build_map() -> void:
	for object in objects.values():
		if is_instance_valid(object):object.queue_free()
	objects.clear()
	if not active(): return
	game.current_world.interactions=game.current_world.interactions.filter(func(t):return not t.has("a2_action"))
	if not game.current_world.has_meta("alpha2_scenery"):
		load("res://scripts/alpha2_scenery.gd").build(game);game.current_world.set_meta("alpha2_scenery",true)
	for npc in game.current_world.interactions:
		if String(npc.get("role","")).begins_with("a2_"):
			npc.title={"mother":"Mother","mara":"Mara, the apothecary","oren":"Oren, the millwright","ada":"Ada, the lantern keeper","jun":"Jun, the lost courier","sable":"Sable, the former keeper","sable_chapel":"Sable, the former keeper"}.get(String(npc.id),npc.title)
	for route in game.current_world.definition.exits:
		var at=Vector3(route.rect[0]+route.rect[2]/2,0,route.rect[1]+route.rect[3]/2)
		at.y=game.current_world.ground_height(at)
		# Visible travel markers instead of invisible trigger strips.
		var post=Node3D.new();game.current_world.add_child(post);post.position=at
		Props.box(post,Vector3(-.7,.65,0),Vector3(.12,1.3,.12),"#604f3d")
		Props.box(post,Vector3(-.7,1.15,0),Vector3(.75,.28,.12),"#b2a27e")
		for target in game.current_world.interactions:
			if target.get("travel",{}).get("id","")==route.id: target.position=at
	for action in definition.actions:
		if action.map!=game.map_id: continue
		if action.type=="heart" and "a2_belfry/bellkeeper" not in game.defeated_enemies: continue
		if action.id in flags and action.type!="rest": continue
		var node=Node3D.new();game.current_world.add_child(node);objects[action.id]=node
		node.position=Vector3(action.at[0],0,action.at[1]);node.position.y=game.current_world.ground_height(node.position)
		match action.type:
			"mechanism":
				Props.box(node,Vector3(0,.45,0),Vector3(1.2,.9,.7),"#62462f")
				for x in [-.4,.4]:Props.box(node,Vector3(x,.9,0),Vector3(.12,.8,.12),"#403b32")
				var axle=Props.cone(node,Vector3(0,1,0),.18,.95,"#9b8056",.18);axle.rotation.z=PI/2
				Props.box(node,Vector3(.55,1.1,0),Vector3(.12,.4,.12),"#ad8c54")
			"rest":
				Props.cone(node,Vector3(0,.10,0),.6,.20,"#6e776b",.48)
				var fire=Props.cone(node,Vector3(0,.42,0),.18,.55,"#e9b574",0)
				var flame=StandardMaterial3D.new();flame.albedo_color=Color("#e9b574");flame.emission_enabled=true;flame.emission=Color("#c77e39");flame.emission_energy_multiplier=1.4;fire.material_override=flame
			"ward":
				Props.box(node,Vector3(0,.12,0),Vector3(1.5,.24,1.5),"#636e66")
				var stone=Props.cone(node,Vector3(0,.8,0),.36,1.4,"#6faeae",.16)
				var magic=StandardMaterial3D.new();magic.albedo_color=Color("#6faeae");magic.emission_enabled=true;magic.emission=Color("#458981");magic.emission_energy_multiplier=.5;stone.material_override=magic
				if action.id=="wood_ward":
					for i in range(3):Props.cone(node,Vector3(-.75+i*.75,1.6,.15),.19,.38+i*.12,"#b2a074",.10)
			"heart":
				Props.cone(node,Vector3(0,.65,0),.33,1.0,"#82e2cb",.08)
			"lore":
				Props.cone(node,Vector3(0,.4,0),.42,.8,"#746448",.05)
			_:
				Props.box(node,Vector3(0,.3,0),Vector3(.8,.6,.6),"#795c3d")
				for x in [-.28,.28]: Props.box(node,Vector3(x,.32,0),Vector3(.06,.62,.64),"#b4a075")
		var glow=OmniLight3D.new();node.add_child(glow);glow.position.y=1.1;glow.light_color=Color("#e5b578" if action.type=="rest" else "#89d7cb");glow.light_energy=.7;glow.omni_range=3
		game.current_world.interactions.append({"id":"alpha2_"+action.id,"a2_action":action.id,"title":action.title,"position":node.position,"actor":null,"lines":[]})

func interact(target:Dictionary) -> bool:
	if not active() or not target.has("a2_action"): return false
	var matches=definition.actions.filter(func(a): return a.id==target.a2_action and a.map==game.map_id)
	if matches.is_empty(): return true
	var a=matches[0]
	if a.type!="rest" and a.id in flags: return true
	if not a.get("requires",[]).all(func(id): return id in game.defeated_enemies):
		game.notify("The ward is still guarded. Defeat its protectors first.");return true
	if not a.get("requires_flags",[]).all(func(id):return id in flags):
		game.notify("Recover the bronze chime from the wreck first." if a.id=="mill_ward" else "Use the salvage winch beside the wreck to lift the fallen mast first.");return true
	if a.type in ["ward","rest","quest","heart","mechanism"] and not safe(target.position,7):
		game.notify("Clear the nearby threats before stopping here.");return true
	if a.id=="wood_ward":
		bell_notes.clear();game.conversation.show_character({"role":"a2_forest_chime","title":"The listening bells"});game._refresh_simulation();return true
	if a.type=="rest":
		checkpoint=game.map_id;checkpoint_at=a.at.duplicate()
		game.player.restore_health(game.player.max_health);game.player.restore_stamina(game.player.max_stamina)
		game.notify("Rested. Respawn set here. F5 or Pause → Save keeps your progress.");return true
	if not mark(a.id,int(a.get("xp",0))): return true
	match a.type:
		"mechanism":game.notify("The winch lifts the broken mast. A bronze chime glints on the wreck's northern dock. +50 XP")
		"ward": game.notify("The ward falls silent (%d/3). +%d XP. The roots loosen toward the chapel."%[wards(),a.xp])
		"loot":
			grant(a.item,int(a.get("count",1)));game.notify("Found "+game.magic_items.item(a.item).name+". Equip or drink it in I → Inventory. +%d XP"%a.xp)
		"quest": game.notify({"tide_chime":"Recovered the bronze chime. Take it to the northern shore ward.","medicine":"Recovered Mara's medicine chest. Return it in Hearthmere.","ledger":"Recovered the keeper's ledger. Ada should see these treasure routes."}.get(a.id,"Recovered a clue.")+" +%d XP"%a.xp)
		"heart": game.notify("The living bell-heart is yours. Return to Mother to choose the valley's future. +300 XP")
		"lore":
			game.dialog_title.text=a.title;game.dialog_lines=[a.text];game.dialog_index=0;game.dialogue_target={};game.dialog.visible=true;game._show_line();game._refresh_simulation()
	remove_action(a.id)
	game.nearest={};return true

func remove_action(id:String) -> void:
	if objects.has(id):objects[id].queue_free();objects.erase(id)
	game.current_world.interactions=game.current_world.interactions.filter(func(t):return t.get("a2_action","")!=id)

func ring_note(note:String) -> bool:
	var sequence=["LOW","HIGH","MIDDLE"]
	if "wood_ward" in flags:return true
	if note!=sequence[bell_notes.size()]:bell_notes.clear();return false
	bell_notes.append(note)
	if bell_notes.size()==3:
		mark("forest_tuned");var ward=definition.actions.filter(func(a):return a.id=="wood_ward")[0]
		mark("wood_ward",int(ward.xp));remove_action("wood_ward");bell_notes.clear()
	return true

func boss_fell() -> void:
	if not active() or game.map_id!="a2_belfry": return
	# Rebuild only campaign interactions, once the guaranteed heart becomes available.
	build_map()
	game.notify("The Bellkeeper falls. The roots are still. Take its heart, then return to Hearthmere.")

func finish(choice:String) -> void:
	if "bellheart" not in flags or wards()!=3 or choice not in ["release","renew"] or not mark("completed",int(definition.quest_rewards.ending)): return
	ending=choice;grant("royal_tide" if choice=="release" else "bellward")
	game.conversation.say("The compass-heart spins, and blue lines trace a dozen lost roads across Mother's map. The villagers crowd around, arguing cheerfully about the first expedition. Mother hands you the Royal Tide Compass: 'For the next treasure hunt. You have earned it.'" if choice=="release" else "You set the compass-heart in the village lantern. Warm lights bloom along the old roads, all the way to the vault. Mara is already packing for a trading trip. Mother gives you a Bellward Explorer Coat: 'Something sturdy for our official explorer.'")
	game.notify("THE HOLLOW BELL · Complete. +650 XP and a keepsake. F5 saves your ending; remaining quests stay available.")

func dialogue(ui:Control,target:Dictionary) -> void:
	var who=String(target.get("role","")).trim_prefix("a2_")
	match who:
		"forest_chime":
			ui.text.text="Three bells answer the roots. The carved verse reads: 'Deep earth wakes, high leaves sing, the bough between remembers.'\nNotes: "+("—" if bell_notes.is_empty() else " → ".join(bell_notes))
			if "wood_ward" in flags:ui.text.text="The three notes resolve. Heartwood's ward is quiet."
			else:
				for note in ["LOW","MIDDLE","HIGH"]:
					ui.choices.add_child(game.button("Ring "+note,func():
						var correct=ring_note(note)
						if not correct:ui.say("The harmony breaks. The bells settle; begin again. Read the verse, or listen at Eli's roots to the northwest.")
						else:ui.menu()
					))
		"mother":
			ui.text.text="The old bell rang on its own at dawn, and a map appeared inside my brass compass! Three ward-stones point toward a lost royal vault. Your sword gem is humming too. I think we have finally found a real adventure."
			if "begun" not in flags:
				ui.choices.add_child(game.button("What do I need to do?",func(): mark("begun",250);ui.say("The map marks three ward-stones: Saltwind Strand to the west, Skyglass Bluffs to the east, and Heartwood to the north. Salvage a bronze chime from the wreck, defeat the bluff sentinel, and solve the forest bell harmony. The roads join up, so choose your own route. Sable knows the northern chapel. Ask the others about hidden treasures before you leave!")))
			elif "completed" in flags: ui.text.text="A royal vault, a living bell, and you home before supper! The village will be telling this story for years. There are still caches to find and friends to help if you feel like another expedition."
			elif "bellheart" in flags:
				ui.text.text="You found the living compass-heart! It can light our village roads, or reveal the lost routes beyond the valley. Sable says we must choose where to use its magic. What shall our next adventure be?"
				ui.choices.add_child(game.button("Reveal the lost roads. There are more treasures to find!",func(): finish("release")))
				ui.choices.add_child(game.button("Light the village roads. Let everyone explore safely.",func(): finish("renew")))
			else: ui.choices.add_child(game.button("Remind me about the wards.",func(): ui.say(objective()+" You can rest at amber pilgrim fires. Inventory has your remedies, magic equipment and a quest journal.")))
			ui.choices.add_child(game.button("Any advice before I head out?",func(): ui.say("Take a remedy, look behind ruined walls, and talk to everyone. Most importantly, come home with a good story. Amber pilgrim fires make good resting places. F5 saves whenever you are ready.")))
		"mara":
			ui.text.text="I'm Mara. Scavengers carried off my travelling medicine chest. They abandoned it near the wreck on Saltwind Strand: western side, south of the broken mast. Bring it back and I'll share my best remedies."
			quest_choice(ui,"medicine","A remedy for the living","medicine","medicine_returned","medicine_asked","Thank you. These will keep the fever down. Take two draughts; you need someone looking after you too.","renewal_draught")
		"ada":
			ui.text.text="Jun took my lantern into the fen and never returned. The west road reaches the shore, then north into the marsh. Follow the willow trees along the western bank. And if you find old records beneath the quarry, bring them to me. Someone ought to remember."
			quest_choice(ui,"courier","The last lantern","courier_safe","courier_returned","courier_asked","Jun is home. I thought keeping the lamps lit was enough. Thank you for going where I could not.","echo_loop")
			quest_choice(ui,"ledger","The royal treasure ledger","ledger","ledger_returned","ledger_asked","The king's supply tunnels! This is enough to plan a dozen expeditions. We will mark the safe roads first. Take a remedy for your trouble, and remember us when you find the gold.","mending_tonic")
		"oren":
			ui.text.text="I built the wheel at the mill. My brother Eli was a treasure hunter; he left a message in the listening roots before heading overseas. Find those roots in the north-west Heartwood and see whether he finally left me a decent clue."
			quest_choice(ui,"memory","A brother's voice","root_memory","memory_returned","memory_asked","A route to the islands! That old rascal always did save the best treasure for last. Take this Windstep necklace; it makes a long road shorter. Tell Eli I am finally coming along.","windstep")
		"jun":
			ui.text.text="Ada's lantern wouldn't go out, so I stayed beside it. I was sure I could see treasure under the water. Are those things outside gone?"
			if "courier_safe" in flags: ui.text.text="I'll follow the lanterns home. Tell Ada I kept her light safe."
			else:
				ui.choices.add_child(game.button("The road is clear. Come home.",func():
					if not safe(target.position,10): ui.say("There are still creatures close by. Please clear the way before I leave.")
					else: mark("courier_safe",100);ui.say("I'll stay on the old stones, all the way home. Tell Ada I'm safe. I found this ring in the mud; maybe it will help you." );grant("tidal_signet")
				))
		"sable","sable_chapel":
			ui.text.text="I was the royal vault's last apprentice. I spent forty years looking for its entrance, only to find I had the map upside down! The Bellkeeper is an ancient test of courage. Attune its three wards and it will let you try for the compass-heart."
			ui.choices.add_child(game.button("How do I stop it?",func(): ui.say("Quiet all three wards, then cross the open-sky chapel to the belfry. The living Bellkeeper casts a stone you can parry back to part its bark. The burrow sentinel on the bluffs can also be opened by returning its projectile. Leave the amber circle before its bell-slam lands, or jump the low ring. Below half health it rings twice. Attack its bright heart after the slam or a reflected stone; your Water Lance can pierce the bark.")))
			ui.choices.add_child(game.button("What is the treasure inside?",func(): ui.say("The compass-heart holds the king's final secret. Bring it to Mother: use it to reveal lost roads or light the village trails. Either way, the people who helped you should hear how the adventure ends.")))
	ui.choices.add_child(game.button("Leave conversation · E",ui.close));ui.choices.get_child(0).grab_focus()

func quest_choice(ui:Control,id:String,title:String,needed:String,done:String,asked:String,response:String,item:String) -> void:
	if done in flags: ui.choices.add_child(game.button(title+" · Complete",func(): ui.say(response)));return
	if asked not in flags:
		ui.choices.add_child(game.button("I'll help. · "+title,func(): mark(asked);ui.say("Thank you. Your journal now has the details. You can follow the other roads first; I'll be here.")));return
	if needed in flags:
		ui.choices.add_child(game.button("Complete: "+title+" · +%d XP"%definition.quest_rewards[id],func():
			if mark(done,int(definition.quest_rewards[id])): grant(item,2 if game.magic_items.item(item).category=="consumable" else 1)
			ui.say(response)
		));return
	ui.choices.add_child(game.button(title+" · Remind me",func(): ui.say(quest_text(id))))
func quest_text(id:String) -> String:
	return {"medicine":"Mara's chest lies on the western beach, south of the wreck. Return it to Mara in Hearthmere.","courier":"Find Jun in the north-west Reedwater Marsh, north of the mill. Clear the nearby creatures, then speak to Jun and return to Ada.","ledger":"Search the Buried Watch, through the cave mouth in the south-east Skyglass Bluffs. Bring its ledger to Ada.","memory":"Listen at the roots in the north-west Heartwood. Bring Eli's last words to Oren in Hearthmere."}[id]
func journal(ui:Control) -> void:
	ui.add_quest("The pilgrim roads","Explore in any order","Hearthmere → Crossroads → West: Strand → Marsh → Heartwood. East: Bluffs → Heartwood. North: Heartwood → Open-Sky Chapel → Bell Court.","The Buried Watch is a side cave in the south-east Quarry. Amber fires set your respawn. Trail markers use E. Compass: N points toward the northern wood. F5 saves; Alpha and Beta saves stay separate.")
	ui.add_quest("The Hollow Bell","650 XP + ending keepsake",objective(),"Explore the three interconnected roads in any order. Salvage the shore chime, defeat the bluff sentinel, and ring the forest notes LOW → HIGH → MIDDLE. Meet Sable; defeat the Bellkeeper; bring its heart home.")
	for entry in [["medicine","A remedy for the living","medicine_asked","medicine_returned"],["courier","The last lantern","courier_asked","courier_returned"],["ledger","The royal treasure ledger","ledger_asked","ledger_returned"],["memory","A brother's voice","memory_asked","memory_returned"]]:
		ui.add_quest(entry[1],"%d XP + equipment or remedies"%definition.quest_rewards[entry[0]],"Complete" if entry[3] in flags else quest_text(entry[0]) if entry[2] in flags else "Speak to "+{"medicine":"Mara","courier":"Ada","ledger":"Ada","memory":"Oren"}[entry[0]]+" in Hearthmere.","Optional. Rewards are given once; all progress survives death.")
	ui.add_quest("Forgotten reliquaries","Magic equipment + discovery XP","Six equipment caches are hidden off the pilgrim roads.","Look beyond the main paths. Equip finds in Inventory; active skills and passive bonuses use the existing skill system.")
