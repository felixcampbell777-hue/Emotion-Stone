extends RefCounted
## Self-contained northern side campaign. Stable IDs are saved; no player-save writes here.
const Props=preload("res://scripts/props.gd")
var game:Node
var definition:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://content/goblin_campaign.json"))
var stage="not_started"
var flags:Array=[]
var charm_equipped=false
var objects:Dictionary={}
var barricade_hits=0

static func valid_save(data:Variant,defeated:Array) -> bool:
	if not data is Dictionary or data.get("stage","not_started") not in ["not_started","active","goods_ready","completed"]: return false
	var allowed=["gate","alarm","barricade","shortcut","secret_wall","windstep","heirloom","ambush_road","ambush_cave"]
	var found=data.get("flags",[])
	if not found is Array or found.size()>allowed.size(): return false
	var seen=[]
	for flag in found:
		if not flag is String or flag not in allowed or flag in seen: return false
		seen.append(flag)
	if not data.get("charm_equipped",false) is bool: return false
	if data.get("charm_equipped",false) and "windstep" not in found: return false
	if "windstep" in found and "secret_wall" not in found: return false
	if data.get("stage","") in ["goods_ready","completed"] and "goblin_depths/foreman" not in defeated: return false
	return true

func reset() -> void:
	stage="not_started"; flags.clear(); charm_equipped=false; objects.clear()
func snapshot() -> Dictionary:
	return {"stage":stage,"flags":flags.duplicate(),"charm_equipped":charm_equipped}
func restore(data:Dictionary) -> void:
	stage=data.get("stage","not_started"); flags=data.get("flags",[]).duplicate(); charm_equipped=data.get("charm_equipped",false)
func speed_bonus() -> float:
	return 0.0 # Speed is now owned by the canonical necklace equipment system.
func objective() -> String:
	return {"not_started":"North of town: speak to Rowan Lark at the farm.","active":"Recover the Larks' seed chest and irrigation regulator from the goblin foreman.","goods_ready":"Return the stolen farm supplies to Rowan at Lark Farm.","completed":"The Larks' Harvest - Complete"}[stage]

func build_map() -> void:
	objects.clear(); barricade_hits=0
	if not game.world_id.is_empty(): return
	var world=game.current_world
	if game.map_id=="lark_farm":
		# Low fences, planted rows, scarecrow and handcart share the native scenery kit.
		for x in [-6,-5,-4,4,5,6]:
			Props.box(world,Vector3(x,.03,-2),Vector3(.46,.06,7),"#73573c")
			for z in range(-5,2):
				Props.cone(world,Vector3(x,.22,z),.16,.4,"#b1ad55",.035)
		for x in [-8,8]:
			for z in range(-7,7,2):
				Props.box(world,Vector3(x,.5,z),Vector3(.14,1,.14),"#806044")
			Props.box(world,Vector3(x,.65,0),Vector3(.10,.12,14),"#9b8059")
		Props.box(world,Vector3(5,.8,4),Vector3(.16,1.6,.16),"#92704d")
		Props.box(world,Vector3(5,1.15,4),Vector3(1.1,.38,.30),"#a47e55")
		Props.cone(world,Vector3(5,1.58,4),.35,.25,"#d1ad68",.04)
	if game.map_id.begins_with("goblin_"):
		for at in [Vector3(-5,.15,-6),Vector3(5,.15,4),Vector3(-4,.15,-2)]:
			for i in range(3):
				Props.box(world,at+Vector3(i*.35,0,0),Vector3(.24,.28,.25),"#b96d4d")
		for at in [Vector3(-1,1,4),Vector3(-2,1,-5)]:
			Props.box(world,at,Vector3(.12,.9,.12),"#67503c")
			Props.cone(world,at+Vector3.UP*.55,.12,.4,"#e8b764",0)
			var light=OmniLight3D.new(); light.position=at; light.light_color=Color("#ffd093"); light.light_energy=1.3; light.omni_range=6; world.add_child(light)
	for item in definition.actions:
		if item.map!=game.map_id: continue
		if item.type=="return_shortcut" and "shortcut" not in flags: continue
		var node=Node3D.new(); node.position=Vector3(item.at[0],0,item.at[1]); world.add_child(node)
		objects[item.id]=node
		if item.type in ["gate","barricade","secret_wall"]:
			if item.id not in flags:
				var color="#697572" if item.type=="secret_wall" else "#8c6649"
				for i in range(7):
					var plank=Props.box(node,Vector3((i-3)*(.66 if item.type=="secret_wall" else .45),.8,0),Vector3(.36,1.6,.22),color)
					plank.rotation.z=.08*sin(i*2)
				Props.box(node,Vector3(0,.45,.16),Vector3(3.2,.15,.13),"#493d31")
				Props.collider(node,Vector3(0,.8,0),Vector3(4.6 if item.type=="secret_wall" else 3.3,1.6,.35))
		elif item.type=="lever":
			Props.box(node,Vector3(0,.35,0),Vector3(.4,.7,.4),"#646d62")
			var handle=Props.box(node,Vector3(0,.85,0),Vector3(.10,.65,.10),"#c1ab7c"); handle.rotation.z=.5 if "gate" not in flags else -.5
		elif item.type=="alarm":
			Props.box(node,Vector3(0,.6,0),Vector3(.12,1.2,.12),"#796044")
			Props.cone(node,Vector3(0,1.0,.10),.25,.25,"#b6a16b",.06)
		elif item.type in ["goods","heirloom"]:
			Props.box(node,Vector3(0,.3,0),Vector3(.8,.6,.55),"#987249")
			for x in [-.26,.26]: Props.box(node,Vector3(x,.32,.29),Vector3(.09,.6,.04),"#b9ad84")
		elif item.type=="charm":
			Props.box(node,Vector3(0,.22,0),Vector3(.7,.44,.6),"#676e6a")
			Props.cone(node,Vector3(0,.72,0),.20,.5,"#7ae0c6",0)
			var glow=OmniLight3D.new(); glow.position.y=1; glow.light_color=Color("#78e0cb"); glow.light_energy=1.4; glow.omni_range=3; node.add_child(glow)
		elif item.type=="rest":
			Props.cone(node,Vector3(0,.16,0),.55,.25,"#76634a",.3)
			Props.cone(node,Vector3(0,.45,0),.22,.6,"#e5a464",0)
		elif item.type=="return_shortcut":
			Props.box(node,Vector3(0,.6,0),Vector3(1.5,1.2,.15),"#374342")
			for sign in [-1,1]: Props.box(node,Vector3(sign*.8,.6,0),Vector3(.20,1.4,.35),"#927a56")
			Props.box(node,Vector3(0,1.3,0),Vector3(1.9,.18,.35),"#927a56")
		elif item.type=="shortcut":
			for i in range(5): Props.box(node,Vector3(0,.04,i*.25),Vector3(1.9,.08,.22),"#8c7051")
		if item.type=="charm": node.visible="secret_wall" in flags and "windstep" not in flags
		if item.type=="heirloom": node.visible="heirloom" not in flags
		world.interactions.append({"id":"campaign_"+item.id,"title":item.title,"position":node.position,"actor":null,"lines":[],"campaign_action":item.id})
	if game.map_id=="goblin_approach":
		# The gate spans the sole opening; the flank walls cannot be walked around.
		for x in [-5,5]:
			for i in range(9): Props.box(world,Vector3(x+(i-4)*.65,1,-1),Vector3(.45,2,.35),"#65503b")
			Props.collider(world,Vector3(x,1,-1),Vector3(6.6,2,.4))
	for group in definition.ambushes:
		if group.map!=game.map_id or group.id in flags: continue
		for enemy in game.enemies:
			if enemy.definition.id in group.enemies:
				enemy.dormant=true; enemy.visible=false; enemy.collision_layer=0; enemy.collision.set_deferred("disabled",true)

func tick() -> void:
	if not is_instance_valid(game) or not game.player.input_enabled or game.gallery_mode or not game.world_id.is_empty(): return
	for group in definition.ambushes:
		if group.map!=game.map_id or group.id in flags: continue
		if game.player.position.distance_to(Vector3(group.at[0],0,group.at[1]))>group.radius: continue
		flags.append(group.id)
		var quiet=group.id=="ambush_road" and "alarm" in flags
		for enemy in game.enemies:
			if enemy.definition.id in group.enemies and enemy.health>0:
				# A disabled bell gives the same enemies a slower, individually visible patrol.
				enemy.dormant=false; enemy.visible=true; enemy.collision_layer=4; enemy.collision.set_deferred("disabled",false)
				enemy.state="recover"; enemy.state_time=2.0 if quiet else .55
		game.notify("The silenced bell buys you time: goblin patrol ahead." if quiet else "Ambush! Goblins rush from the hiding places.")

func mark(id:String,xp:int=0) -> bool:
	if id in flags: return false
	flags.append(id)
	if xp>0: game.gain_xp(xp)
	return true
func clear_barrier(id:String) -> void:
	mark(id)
	if objects.has(id):
		for child in objects[id].get_children():
			if child is StaticBody3D: child.collision_layer=0
			child.queue_free()

func interact(target:Dictionary) -> bool:
	if not target.has("campaign_action"): return false
	var id:String=target.campaign_action
	match id:
		"gate_lever":
			clear_barrier("gate"); game.notify("The palisade gate lifts. The north trail is open.")
		"gate": game.notify("A winch beside the south face opens this gate.")
		"alarm":
			game.notify("You unhook the alarm bell. The patrol will react more slowly." if mark("alarm") else "The bell is already silent.")
		"barricade":
			if enemies_near(target.position,4): game.notify("Clear the guards, or break the barricade with sword strikes.")
			else: clear_barrier("barricade"); game.notify("You pull the loose barricade boards aside.")
		"secret_wall":
			clear_barrier("secret_wall"); objects.windstep.visible="windstep" not in flags; game.notify("Loose stones give way. A cool green light glows behind them.")
		"windstep":
			if "secret_wall" not in flags: game.notify("A glow leaks through the loose stone wall.")
			elif mark("windstep",int(definition.secret_xp)):
				game.magic_items.found_windstep(); game.apply_skill_stats(); objects.windstep.visible=false
				game.notify("Found Windstep Charm! Equipped: +20%% movement speed. +%d XP" % int(definition.secret_xp))
			else: game.notify("You already found the Windstep Charm.")
		"heirloom":
			if mark("heirloom",int(definition.secret_xp)): objects.heirloom.visible=false; game.notify("Found Mira's copper swallow. Return it to her at the farm. +%d XP" % int(definition.secret_xp))
			else: game.notify("The little chest is empty.")
		"goods":
			if stage=="not_started": game.notify("Speak to the farm family about these stolen supplies first.")
			elif "goblin_depths/foreman" not in game.defeated_enemies: game.notify("Defeat the goblin foreman before recovering the supplies.")
			elif stage=="active": stage="goods_ready"; game.notify("Recovered the seed chest and brass irrigation regulator. Return to Rowan!")
			else: game.notify("The farm supplies are already recovered.")
		"rest":
			if enemies_near(target.position,8): game.notify("It is not safe to rest while goblins are nearby.")
			else: game.player.restore_health(game.player.max_health); game.player.restore_stamina(game.player.max_stamina); game.notify("You catch your breath by the sheltered fire. Health and stamina restored.")
		"shortcut_back":
			if "shortcut" in flags: game.load_map("goblin_depths",Vector2(4,-6))
		"shortcut":
			if "goblin_depths/foreman" not in game.defeated_enemies: game.notify("The foreman holds the shortcut's latch key.")
			else: mark("shortcut"); game.load_map("lark_farm",Vector2(0,-7)); game.notify("You open the supply tunnel: a shortcut back to the farm.")
	return true
func enemies_near(at:Vector3,radius:float) -> bool:
	return game.enemies.any(func(enemy): return enemy.health>0 and not enemy.dormant and enemy.position.distance_to(at)<radius)
func sword_contact(already_hit:Dictionary) -> void:
	if not objects.has("barricade") or "barricade" in flags: return
	var at:Vector3=objects.barricade.global_position
	if game.player.position.distance_to(at)>2.6: return
	var segment=game.player.blade_segment()
	if Geometry3D.get_closest_point_to_segment(at+Vector3.UP*.8,segment[0],segment[1]).distance_to(at+Vector3.UP*.8)>.9: return
	var key="campaign/barricade"
	if key in already_hit: return
	already_hit[key]=true; barricade_hits+=1
	if barricade_hits>=2: clear_barrier("barricade"); game.notify("The barricade breaks apart!")
	else: game.notify("The boards splinter. One more strike will break through.")

func dialogue(ui:Control,target:Dictionary) -> void:
	match target.get("role",""):
		"farm_parent":
			ui.text.text="Goblins stole our winter seed chest and the brass regulator for the irrigation pump. Without them, the whole harvest is lost. Their caves lie along the north trail."
			if stage=="not_started": ui.choices.add_child(game.button("I'll recover your supplies.",func(): stage="active"; ui.say("Thank you. Use their winch to open the palisade. Silence the bell before moving farther in. The foreman keeps our supplies deep inside.")))
			elif stage=="goods_ready": ui.choices.add_child(game.button("Return the seed chest and regulator.  +%d XP" % int(definition.quest_xp),func(): stage="completed"; game.gain_xp(int(definition.quest_xp)); ui.say("Our harvest is saved! We'll never forget this. The supply tunnel remains open if you want to search the caves again.")))
			elif stage=="completed": ui.text.text="The fields are drinking again, and the seed is safe. You will always have a place at our table."
			else: ui.choices.add_child(game.button("What should I look for?",func(): ui.say("Two heavy guards protect the caves. Their shields face forward: bait the thrust, parry, then strike during recovery. Our chest is behind their foreman.")))
		"farm_partner":
			ui.text.text="I'm Tessa Lark. Rowan worries about the pump; I worry about all of you. Goblins leave long pauses after a rush. Don't fight them all at once."
			ui.choices.add_child(game.button("Any secrets along the trail?",func(): ui.say("The old miners left a shrine behind loose stones in the deepest cave. A draft whistles through them. Mira says the treasure inside can make your steps lighter.")))
		"farm_child":
			ui.text.text="I'm Mira! They stole my copper swallow too. I hid it in a little box, but they took the whole box. Look in the first cave's western nook."
			if "heirloom" in flags: ui.text.text="My copper swallow! You found it! I'll hang it above the seedlings to keep them safe. Thank you!"
	ui.choices.add_child(game.button("Goodbye.  /  E to leave",ui.close))
	ui.choices.get_child(0).grab_focus()

func toggle_charm() -> void:
	game.magic_items.equip("necklace","" if game.magic_items.slots.get("necklace","")=="windstep" else "windstep"); game.inventory.refresh()
