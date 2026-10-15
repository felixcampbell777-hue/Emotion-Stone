extends Control
# Game rules remain in magic_items.gd / monster_cores.gd. This owns the browsing UI.
const Frost=preload("res://scripts/frosted_backdrop.gd")
const ICON_ATLAS=preload("res://assets/ui/inventory/skyrim-inventory-icons-v1.png")
const CATEGORY_ORDER=["all","weapons","apparel","potions","ingredients","quest"]
const CATEGORY_NAMES={"all":"All", "weapons":"Weapons", "apparel":"Apparel", "potions":"Potions", "ingredients":"Ingredients", "quest":"Quest items"}
const SLOT_NAMES={"ring1":"Ring 1", "ring2":"Ring 2", "torso":"Torso", "leggings":"Leggings", "boots":"Boots", "headwear":"Headwear", "necklace":"Necklace"}
var game:Control
var portrait:TextureRect
var box:PanelContainer
var slots:VBoxContainer
var page="equipment"
var tabs:HBoxContainer
var selected_slot=""
var selected_item={"kind":"weapon","id":"greatsword"}
var selected_category="apparel"
var preview:Control
var detail_box:PanelContainer
var detail:VBoxContainer
var category_box:VBoxContainer
var picker_focus:Button

func configure(owner_game:Control) -> void:
	game=owner_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var frost=Frost.new(); add_child(frost); frost.configure(game)
	tabs=HBoxContainer.new(); tabs.add_theme_constant_override("separation",8); add_child(tabs)
	for entry in [["equipment","Inventory"],["skills","Skills"],["level","Level Up"],["quests","Quests"]]:
		var id:String=entry[0]; tabs.add_child(game.button(entry[1],func(): show_page(id)))
	tabs.add_child(game.button("Close [I / Esc]",close))
	category_box=VBoxContainer.new(); category_box.add_theme_constant_override("separation",5); add_child(category_box)
	portrait=TextureRect.new(); portrait.texture=load("res://assets/conversation/hero-inventory-v1.png")
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(portrait)
	preview=load("res://scripts/equipment_preview.gd").new(); add_child(preview); preview.configure(game)
	box=game.panel(self)
	var scroll=ScrollContainer.new(); scroll.follow_focus=true; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; box.add_child(scroll)
	slots=VBoxContainer.new(); slots.add_theme_constant_override("separation",7); slots.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(slots)
	detail_box=game.panel(self); detail=VBoxContainer.new(); detail.add_theme_constant_override("separation",11); detail_box.add_child(detail)
	visible=false

func _process(_delta:float) -> void:
	if not visible: return
	var screen=get_viewport_rect().size
	tabs.position=Vector2(screen.x*.035,16)
	category_box.position=Vector2(screen.x*.035,75); category_box.size=Vector2(screen.x*.19,screen.y*.32)
	portrait.position=Vector2(screen.x*.035,screen.y*.42); portrait.size=Vector2(screen.x*.19,screen.y*.54)
	preview.position=portrait.position; preview.size=portrait.size
	preview.visible=page=="equipment"; portrait.visible=page not in ["equipment","level"]
	box.position=Vector2(screen.x*.245,75); box.size=Vector2(screen.x*.35,screen.y-94)
	if page in ["skills","quests"]: box.size.x=screen.x*.72
	detail_box.position=Vector2(screen.x*.615,75); detail_box.size=Vector2(screen.x*.35,screen.y-94)
	category_box.visible=page=="equipment"; detail_box.visible=page=="equipment"

func show_page(id:String) -> void:
	page=id
	if id=="equipment" and selected_category.is_empty(): selected_category="apparel"
	refresh()

func clear(node:Node) -> void:
	for child in node.get_children(): node.remove_child(child); child.queue_free()

func refresh() -> void:
	picker_focus=null; clear(slots); clear(detail); clear(category_box)
	preview.refresh(game)
	box.visible=page!="level"
	if game.skill_tree!=null:
		game.skill_tree.visible=page=="level" and visible
		if page=="level": game.skill_tree.refresh()
	for index in range(4): tabs.get_child(index).disabled=["equipment","skills","level","quests"][index]==page
	if page=="level": return
	if page=="quests": refresh_quests(); return
	if page=="skills": refresh_skills(); return
	refresh_categories(); refresh_inventory_list(); refresh_detail()
	if picker_focus!=null: picker_focus.grab_focus()

func refresh_categories() -> void:
	category_box.add_child(game.label("INVENTORY",21,Color("#e9c894")))
	category_box.add_child(game.label("Gold 0   ·   Carry weight --",13,Color("#c9c0a2")))
	for category in CATEGORY_ORDER:
		var amount=item_count(category)
		var title=CATEGORY_NAMES[category]+("  %d" % amount if amount>0 else "")
		var button=game.button(title,func(): selected_category=category; selected_slot=""; selected_item={}; refresh())
		button.custom_minimum_size.y=34
		if category==selected_category: button.add_theme_stylebox_override("normal",game.style(Color("#5a4a2fee"),Color("#e2c277")))
		category_box.add_child(button)
	category_box.add_child(game.label("\nEquip gear through Apparel.\nSelect any item to inspect it.",13,Color("#c9c0a2")))

func icon(col:int,row:int) -> AtlasTexture:
	var texture=AtlasTexture.new(); texture.atlas=ICON_ATLAS; texture.region=Rect2(col*443.5,row*443.5,443.5,443.5); return texture

func icon_for(entry:Dictionary) -> Texture2D:
	match String(entry.get("kind","")):
		"weapon": return load("res://assets/ui/inventory/beta-longsword.png") if game.personal_character_enabled() else icon(0,1)
		"potion": return icon(0,0)
		"core":
			var id=String(entry.id)
			return icon(3,0) if id=="golem_core" else icon(2,0) if "goblin" in id or id=="foreman_core" else icon(1,0)
		"apparel":
			var category=String(entry.get("category",""))
			return icon(1,1) if category=="ring" else icon(2,1) if category=="necklace" else icon(3,1)
		_: return icon(3,1)

func item_count(category:String) -> int:
	if category=="all": return item_count("weapons")+item_count("apparel")+item_count("potions")+item_count("ingredients")+item_count("quest")
	if category=="weapons": return 1
	if category=="apparel": return game.magic_items.owned.filter(func(id): return game.magic_items.item(id).category!="consumable").size()
	if category=="potions": return game.magic_items.owned.filter(func(id): return game.magic_items.item(id).category=="consumable").size()+(1 if game.well_gift_stage=="potion_owned" else 0)
	if category=="ingredients": return game.monster_cores.quantities.size()
	if category=="quest": return game.alpha2.quest_items().size() if game.game_mode=="alpha2" else (1 if game.well_gift_stage=="coin_ready" else 0)+(1 if game.goblin_campaign.stage=="goods_ready" else 0)+(1 if "heirloom" in game.goblin_campaign.flags else 0)+(1 if game.quest_stage=="component_ready" else 0)
	return 0

func weapon_name() -> String:
	return "Blue-gem War Sword" if game.personal_character_enabled() else "Blue-gem Greatsword"

func weapon_description() -> String:
	return "A heavy broad steel blade, recessed fuller and two-handed leather grip." if game.personal_character_enabled() else "An oversized blade."

func listed_items() -> Array:
	var list=[]
	if selected_category in ["all","weapons"]: list.append({"kind":"weapon","id":"greatsword","name":weapon_name(),"description":weapon_description()+" "+("Equipped" if game.player.sword_equipped else "Stored")})
	if selected_category in ["all","apparel"]:
		for id in game.magic_items.owned:
			var item=game.magic_items.item(id)
			if item.category!="consumable": list.append({"kind":"apparel","id":id,"name":item.name,"description":item.description,"category":item.category,"code":item.code})
	if selected_category in ["all","potions"]:
		for id in game.magic_items.owned:
			var item=game.magic_items.item(id)
			if item.category=="consumable": list.append({"kind":"potion","id":id,"name":item.name,"description":item.description,"count":int(game.magic_items.quantities.get(id,0))})
		if game.well_gift_stage=="potion_owned": list.append({"kind":"potion","id":"everfull","name":"Everfull Experience Potion","description":"A bottomless well-gift. Drink for 1,000 XP.","count":"∞"})
	if selected_category in ["all","ingredients"]:
		for id in game.monster_cores.quantities:
			var item=game.monster_cores.item(id)
			list.append({"kind":"core","id":id,"name":item.name,"description":"Consume to restore %d%% of maximum health." % roundi(item.healing_percent*100),"count":int(game.monster_cores.quantities[id])})
	if selected_category in ["all","quest"]:
		if game.game_mode=="alpha2": list.append_array(game.alpha2.quest_items())
		if game.quest_stage=="component_ready": list.append({"kind":"quest","id":"golem_core","name":"Calcified Aether Core","description":"Mother needs this for her remedy. Keep it safe."})
		if game.well_gift_stage=="coin_ready": list.append({"kind":"quest","id":"wishing_coin","name":"Wishing Coin","description":"Throw it into the village well."})
		if game.goblin_campaign.stage=="goods_ready": list.append({"kind":"quest","id":"lark_goods","name":"Larks' Harvest","description":"Seed chest and brass irrigation regulator."})
		if "heirloom" in game.goblin_campaign.flags: list.append({"kind":"quest","id":"heirloom","name":"Mira's Copper Swallow","description":"A recovered family keepsake."})
	return list

func refresh_inventory_list() -> void:
	slots.add_child(game.label(CATEGORY_NAMES[selected_category].to_upper(),22,Color("#e9c894")))
	if selected_category=="apparel":
		slots.add_child(game.label("EQUIPPED",15,Color("#c9c0a2")))
		var equipment=GridContainer.new(); equipment.columns=2; equipment.add_theme_constant_override("h_separation",7); equipment.add_theme_constant_override("v_separation",7); slots.add_child(equipment)
		var weapon=game.button("WEAPON\n"+(weapon_name() if game.player.sword_equipped else "Empty"),toggle_weapon); weapon.custom_minimum_size=Vector2(155,52); equipment.add_child(weapon)
		for slot in game.magic_items.SLOTS:
			var equipped_id=String(game.magic_items.slots.get(slot,"")); var magic=game.magic_items.item(equipped_id)
			var base={"torso":"Travel dress","boots":"Walking boots"}.get(slot,"Empty")
			var cell=game.button(SLOT_NAMES[slot].to_upper()+"\n"+(magic.name if not magic.is_empty() else base),func(): selected_slot=slot; refresh())
			cell.custom_minimum_size=Vector2(155,52); cell.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			if selected_slot==slot: cell.add_theme_stylebox_override("normal",game.style(Color("#5a4a2fee"),Color("#e2c277")))
			equipment.add_child(cell)
		slots.add_child(game.label("Select a body slot, then choose an owned piece below.",13,Color("#c9c0a2")))
	for entry in listed_items(): add_item_card(entry)
	if selected_category=="apparel" and listed_items().is_empty(): slots.add_child(game.label("Find wearable gear in Menagerie [M] > Magic items.",16))
	if selected_category=="ingredients" and listed_items().is_empty(): slots.add_child(game.label("Monster cores appear here after you loot them.",16))
	slots.add_child(game.button("Return to game  /  I or Escape",close))

func add_item_card(entry:Dictionary) -> void:
	var card=game.button("",func(): selected_item=entry.duplicate(); refresh_detail())
	card.set_meta("inventory_entry",entry.duplicate())
	card.custom_minimum_size=Vector2(0,70); card.alignment=HORIZONTAL_ALIGNMENT_LEFT
	var row=HBoxContainer.new(); row.mouse_filter=Control.MOUSE_FILTER_IGNORE; card.add_child(row)
	var art=TextureRect.new(); art.texture=icon_for(entry); art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; art.custom_minimum_size=Vector2(58,58); art.mouse_filter=Control.MOUSE_FILTER_IGNORE; row.add_child(art)
	var text=VBoxContainer.new(); text.mouse_filter=Control.MOUSE_FILTER_IGNORE; text.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(text)
	var title=game.label(entry.name,17,Color("#f4e5bd")); title.mouse_filter=Control.MOUSE_FILTER_IGNORE; text.add_child(title)
	var sub=game.label(entry.description,13,Color("#c9c0a2")); sub.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; sub.max_lines_visible=2; sub.mouse_filter=Control.MOUSE_FILTER_IGNORE; text.add_child(sub)
	if entry.has("count"):
		var count=game.label("×"+str(entry.count),18,Color("#e9c894")); count.mouse_filter=Control.MOUSE_FILTER_IGNORE; row.add_child(count)
	if selected_item.get("kind","")==entry.kind and selected_item.get("id","")==entry.id: card.add_theme_stylebox_override("normal",game.style(Color("#5a4a2fee"),Color("#e2c277")))
	slots.add_child(card)

func refresh_detail() -> void:
	clear(detail)
	var entry=selected_item.duplicate()
	var available=listed_items()
	var matches=available.filter(func(candidate): return candidate.kind==entry.get("kind","") and candidate.id==entry.get("id",""))
	if not matches.is_empty(): entry=matches[0].duplicate(); selected_item=entry.duplicate()
	elif not available.is_empty(): entry=available[0].duplicate(); selected_item=entry.duplicate()
	if entry.is_empty() or not entry.has("name"):
		entry={"kind":"weapon","id":"greatsword","name":weapon_name(),"description":weapon_description()}; selected_item=entry.duplicate()
	var art=TextureRect.new(); art.texture=icon_for(entry); art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; art.custom_minimum_size=Vector2(0,190); detail.add_child(art)
	detail.add_child(game.label(String(entry.get("name","Unknown item")),25,Color("#f4e5bd")))
	var category_label={"weapon":"Weapon", "apparel":"Apparel", "potion":"Potion", "core":"Ingredient", "quest":"Quest item"}.get(String(entry.kind),"Item")
	detail.add_child(game.label(category_label,15,Color("#c9c0a2")))
	var description=game.label(String(entry.get("description","")),17); description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; detail.add_child(description)
	match String(entry.kind):
		"weapon": detail.add_child(game.button("Unequip weapon" if game.player.sword_equipped else "Equip weapon",toggle_weapon))
		"apparel": refresh_apparel_detail(entry)
		"potion":
			var action=game.button("Drink" if entry.id!="everfull" else "Drink · +1,000 XP",func():
				if entry.id=="everfull": drink_potion()
				else: game.magic_items.drink(entry.id); refresh())
			action.disabled=entry.id!="everfull" and int(game.magic_items.quantities.get(entry.id,0))<1; detail.add_child(action)
		"core":
			var consume=game.button("Consume",func(): game.monster_cores.consume(entry.id); refresh())
			if entry.id=="golem_core" and game.quest_stage!="completed": consume.text="Quest locked · inspect"; consume.tooltip_text="Mother needs this core."
			detail.add_child(consume)
		"quest": detail.add_child(game.label("This item is tracked by the quest journal.",15,Color("#c9c0a2")))
	detail.add_child(game.label("\nI closes inventory · equipment and items pause the world.",13,Color("#c9c0a2")))

func refresh_apparel_detail(entry:Dictionary) -> void:
	var target=selected_slot
	if target.is_empty():
		detail.add_child(game.label("Select an equipment slot on the left to equip this item.",15,Color("#c9c0a2"))); return
	var expected=game.magic_items.category(target)
	if entry.category!=expected:
		detail.add_child(game.label("Select a %s slot to equip this." % entry.category,15,Color("#c9c0a2"))); return
	var worn=String(game.magic_items.slots.get(target,""))==String(entry.id)
	var action=game.button("Equipped in "+SLOT_NAMES[target] if worn else "Equip to "+SLOT_NAMES[target],func(): game.magic_items.equip(target,entry.id); refresh())
	action.disabled=worn; detail.add_child(action)
	if worn: detail.add_child(game.button("Unequip "+SLOT_NAMES[target],func(): game.magic_items.equip(target,""); refresh()))

func refresh_quests() -> void:
	slots.add_child(game.label("QUEST JOURNAL",24,Color("#e9c894")))
	if game.game_mode=="alpha2": game.alpha2.journal(self);wrap_labels();return
	if game.game_mode=="beta":
		slots.add_child(game.label("Beta: explore the meadow and woodland. No story quests in this first prototype.",17)); wrap_labels(); return
	add_quest("Mother's Alchemical Remedy", "%d XP" % int(game.progression.definition.quest_xp), game.quest_objective(false), "Follow the old cobbled road, defeat the stone warden and return its calcified aether core to Mother.")
	add_quest("A Wish at the Well", "%d XP" % int(game.progression.definition.well_quest_xp), {"not_started":"Talk to the village keeper for a wishing coin.","coin_ready":"Throw your wishing coin into the village well.","potion_owned":"Complete: Everfull Experience Potion received."}[game.well_gift_stage], "The well's gift is permanent once received.")
	add_quest("The Larks' Harvest", "%d XP" % int(game.goblin_campaign.definition.quest_xp), game.goblin_campaign.objective(), "Travel the northern route through Lark Farm, the palisade, gallery and foreman vault.")
	wrap_labels()

func add_quest(title:String,reward:String,objective:String,description:String) -> void:
	slots.add_child(game.label(title+" · "+reward,20,Color("#e9c894"))); slots.add_child(game.label(objective,17)); slots.add_child(game.label(description,15,Color("#c9c0a2")))

func wrap_labels() -> void:
	for child in slots.get_children():
		if child is Label: child.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func refresh_skills() -> void:
	slots.add_child(game.label("ACTIVE SLOTS",24,Color("#e9c894")))
	slots.add_child(game.label("Learn and upgrade in Level Up. Each active slot uses its own control.",16))
	slots.add_child(game.label("MAGIC SLOT  /  Q",19,Color("#e9c894")))
	var specials=HBoxContainer.new() if get_viewport_rect().size.x>=1100 else VBoxContainer.new(); slots.add_child(specials)
	for id in ["water_sweep","water_lance","sea_dragon","undertow"]:
		if not game.skill_tree.revealed({"water_sweep":"mana","water_lance":"mana_lance","sea_dragon":"sea_dragon","undertow":"undertow"}[id]):continue
		var unlocked=game.special_unlocked(id); var title={"water_sweep":"Water Slash","water_lance":"Water Lance","sea_dragon":"Mana Sea Dragon","undertow":"Undertow"}[id]; var caption={"water_sweep":"Moving, fading water fan","water_lance":"3 sec charge; hits interrupt","sea_dragon":"Steer for 10 sec; body vulnerable","undertow":"Low surge pulls foes; 28 stamina"}[id]
		var cell=game.button(("EQUIPPED\n" if game.selected_special_attack==id and unlocked else "")+title+"\n"+(caption if unlocked else "Locked: "+("Water Lance" if id=="sea_dragon" else "Mana root" if id=="water_sweep" else "Mana")),func(): game.select_special_attack(id))
		cell.custom_minimum_size=Vector2(180,65); cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL; cell.disabled=not unlocked; specials.add_child(cell)
	slots.add_child(game.label("HEAVY ATTACK  /  HOLD LEFT CLICK",18,Color("#e9c894")))
	var heavies=HBoxContainer.new() if get_viewport_rect().size.x>=1100 else VBoxContainer.new(); slots.add_child(heavies)
	for id in ["overhead","charge_thrust"]:
		if id!="overhead" and not game.skill_tree.revealed(id):continue
		var cell=game.button(("EQUIPPED\n" if game.player.heavy_style==id else "")+("Overhead Heavy" if id=="overhead" else "Driving Thrust"),func(): game.select_heavy_attack(id))
		cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL; cell.custom_minimum_size.y=52; cell.disabled=id=="charge_thrust" and not game.progression.has(id); heavies.add_child(cell)
	var movement=HBoxContainer.new();slots.add_child(movement)
	for id in ["dash","jump"]:
		if not game.skill_tree.revealed(id):continue
		var unlocked=game.progression.has(id);var equipped=game.player.dash_equipped if id=="dash" else game.player.jump_equipped
		var caption="Dash · hold/release T" if id=="dash" else "Jump · Space"
		var cell=game.button(("EQUIPPED  " if equipped else "")+caption+("" if unlocked else " · Locked: Form"),func(): game.toggle_movement_skill(id))
		cell.disabled=not unlocked;cell.custom_minimum_size.y=45;cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL;movement.add_child(cell)
	slots.add_child(game.label("Dodge · Ctrl / tap Shift; hold Shift to sprint" if game.progression.has("belly_roll") else "Dodge · Locked: Form",16))
	var counter=game.button(("EQUIPPED  " if game.player.counter_equipped else "")+"Flowing Counter · light attack after parry",func(): game.toggle_movement_skill("flowing_counter"))
	counter.visible=game.skill_tree.revealed("flowing_counter")
	counter.disabled=not game.player.counter_unlocked;slots.add_child(counter)
	slots.add_child(game.label("PASSIVE SLOTS  /  %d of %d"%[game.progression.passives.size(),game.progression.PASSIVE_SLOTS],20,Color("#e9c894")))
	for id in ["efficient_swing","crushing_force","flowing_splash","measured_recovery","breaker"]:
		if not game.skill_tree.revealed(id):continue
		var item=game.progression.skill(id);var equipped=id in game.progression.passives
		var cell=game.button(("EQUIPPED  " if equipped else "Equip  ")+item.name+" · Rank %d/%d"%[game.progression.rank(id),item.max_rank],func(): game.toggle_passive(id))
		cell.disabled=not game.progression.has(id);slots.add_child(cell)
	wrap_labels()

func toggle_weapon() -> void:
	game.player.set_sword_equipped(not game.player.sword_equipped); selected_item={"kind":"weapon","id":"greatsword","name":weapon_name(),"description":weapon_description()+" "+("Equipped" if game.player.sword_equipped else "Stored")}; refresh()

func drink_potion() -> void:
	game.drink_experience_potion(); refresh()

func close() -> void:
	visible=false; preview.actor.set_physics_process(false)
	if game.skill_tree!=null: game.skill_tree.visible=false
	game._refresh_simulation()
