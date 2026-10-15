extends Control
## Full-resolution story UI, independent of the pixelated world viewport.
const Frost=preload("res://scripts/frosted_backdrop.gd")
var game: Control
var portrait: TextureRect
var text: Label
var choices: VBoxContainer
var box: PanelContainer
var portrait_frame: Control
var hero_portrait: TextureRect
var title: Label
var target: Dictionary={}

func configure(owner_game: Control) -> void:
	game=owner_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var backdrop=Frost.new()
	add_child(backdrop)
	backdrop.configure(game)
	portrait_frame=Control.new()
	add_child(portrait_frame)
	portrait=TextureRect.new()
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_frame.add_child(portrait)
	hero_portrait=TextureRect.new()
	hero_portrait.texture=load("res://assets/conversation/hero-inventory-v1.png")
	hero_portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	hero_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(hero_portrait)
	box=game.panel(self)
	box.add_theme_stylebox_override("panel",game.style(Color("#142b2af5"),Color("#caa56b"),12))
	var layout=VBoxContainer.new()
	layout.add_theme_constant_override("separation",14)
	box.add_child(layout)
	title=game.label("",20,Color("#e9c894"))
	layout.add_child(title)
	text=game.label("",23)
	text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size=Vector2(0,95)
	layout.add_child(text)
	choices=VBoxContainer.new()
	choices.add_theme_constant_override("separation",8)
	layout.add_child(choices)
	visible=false

func _process(_delta: float) -> void:
	if not visible:
		return
	var available=get_viewport_rect().size
	portrait_frame.position=Vector2(available.x*.015,available.y*.02)
	portrait_frame.size=Vector2(available.x*.36,available.y*.96)
	hero_portrait.position=Vector2(available.x*.70,available.y*.02)
	hero_portrait.size=Vector2(available.x*.28,available.y*.96)
	box.size=Vector2(available.x*.60,0)
	box.position=Vector2(available.x*.385,maxf(available.y*.35,available.y*.96-box.get_combined_minimum_size().y))

func show_mother() -> void:
	show_character(game.dialogue_target)

func show_character(character: Dictionary) -> void:
	target=character
	visible=true
	menu()

func clear_choices() -> void:
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	portrait.texture=load("res://assets/conversation/mother-revealed-cutout-v2.png" if game.mother_unwrapped else "res://assets/conversation/mother-wrapped-cutout-v2.png") if target.get("role","") in ["mother","a2_mother"] else load("res://assets/conversation/friendly-villager-v1.png")
	portrait_frame.visible=target.get("role","") not in ["well","a2_forest_chime"]
	title.text=target.get("title","Mother").to_upper()

func say(line: String) -> void:
	clear_choices()
	text.text=line
	choices.add_child(game.button("Continue",menu))
	choices.get_child(0).grab_focus()

func menu() -> void:
	clear_choices()
	if game.game_mode=="alpha2" and String(target.get("role","")).begins_with("a2_"):
		game.alpha2.dialogue(self,target);return
	if String(target.get("role","")).begins_with("farm_"):
		game.goblin_campaign.dialogue(self,target)
		return
	if target.get("role","")=="well":
		text.text="A glimmer stirs beneath the water. Perhaps a wish needs a coin."
		if game.well_gift_stage=="coin_ready":
			choices.add_child(game.button("Throw the keeper's coin into the well.",throw_coin))
		elif game.well_gift_stage=="potion_owned":
			text.text="The well has granted your wish. Your Everfull Experience Potion never runs dry. Drink it from your inventory."
		else:
			text.text="An old wishing well. The male keeper beside the green might have a spare coin."
		choices.add_child(game.button("Leave the well.  /  E to leave",close))
		choices.get_child(0).grab_focus()
		return
	if target.get("role","")!="mother":
		text.text="Good to see a friendly face. How can I help?"
		if target.get("id","")=="keeper_green":
			choices.add_child(game.button("Could I have a coin for the well?" if game.well_gift_stage=="not_started" else "About your wishing coin...",receive_coin))
		choices.add_child(game.button("Tell me about this place.",villager_story))
		choices.add_child(game.button("Any advice for the forest?",func(): say("The boars charge together. Keep moving through the trees, then face the warden's rock and parry it back. Mother needs a component from its core.")))
		choices.add_child(game.button("Goodbye.  /  E to leave",close))
		choices.get_child(0).grab_focus()
		return
	if game.map_id=="home_downstairs" and not game.home_intro_complete:
		text.text="Good morning, love. Come warm yourself by the fire before you go. Did you sleep well?"
		choices.add_child(game.button("Good morning, Mom. I'm ready to head out.",morning_farewell))
		choices.add_child(game.button("Stay a little longer.",close))
		choices.get_child(0).grab_focus()
		return
	text.text="You've come back. Come, catch your breath. There is something I could use your help with."
	if game.quest_stage=="not_started":
		choices.add_child(game.button("Do you need anything from the forest?",accept_quest))
	elif game.quest_stage=="active":
		text.text="Follow the old cobbled road to the stone warden. Defeat it, then search its remains for a calcified aether core."
		choices.add_child(game.button("Remind me about the stone warden.",func(): say("Face its thrown rock. Right-click just before it reaches you. The parried stone breaks its shell open; strike while the cracks glow.")))
	elif game.quest_stage=="component_ready":
		text.text="That glow—did you recover a calcified aether core? You made it through the forest!"
		choices.add_child(game.button("Give Mother the calcified aether core.",complete_quest))
	else:
		text.text="This core will catalyze my restorative tincture. Thank you for bringing it safely home."
	if not game.mother_unwrapped:
		choices.add_child(game.button("Could you take off the arm wrap?",reveal_arm))
	else:
		choices.add_child(game.button("How is your arm holding up?",func(): say("Rough iron, simple hinges, and that cracked flame gem. It aches some days, but it still holds together.")))
	choices.add_child(game.button("I'll be back soon.  /  E to leave",close))
	choices.get_child(0).grab_focus()

func morning_farewell() -> void:
	game.home_intro_complete=true
	say("There's bread on the table. Take care on the coastal path, and come home when you need a rest. Before you go, I could use your help with an alchemical component from the forest.")
	game.notify("Mother has seen you off. You can leave through the front door.")

func villager_story() -> void:
	say(" ".join(target.get("lines",["Welcome to our village by the sea."])))

func receive_coin() -> void:
	if game.receive_wishing_coin():
		say("Here, take my wishing coin. Toss it into the well beside us. They say its gift never runs dry.")
	else:
		say("I gave you my wishing coin already. Take it to the well, then drink its gift from your inventory whenever you need experience.")

func throw_coin() -> void:
	if game.throw_wishing_coin():
		say("Your coin drops into the water. A blue bottle rises from the depths: the Everfull Experience Potion! Each drink grants 1,000 XP, and the bottle refills itself. Open inventory with I to drink it. Spend your skill points with P.")
	else:
		menu()

func accept_quest() -> void:
	game.quest_stage="active"
	say("I need a calcified aether core for an alchemical tincture. Follow the old cobbled road through the forest. The boars charge together; parry the stone warden's rock to open its armor. After it falls, search its remains and bring the core home.")
	game.notify("Quest accepted: Aether Core for Mother")

func reveal_arm() -> void:
	game.mother_unwrapped=true
	if is_instance_valid(game.dialogue_target.get("actor")):
		game.dialogue_target.actor.set_arm_wrapped(false)
	say("All right. Let me loosen these wraps. There: rough iron, simple hinges, and a cracked flame gem. It still works, most days.")

func complete_quest() -> void:
	if game.quest_stage!="component_ready":
		return
	game.quest_stage="completed"
	game.monster_cores.remove("golem_core")
	game.gain_xp(int(game.progression.definition.quest_xp))
	game.player.restore_health(game.player.max_health)
	game.player.restore_stamina(game.player.max_stamina)
	say("Just the catalyst I needed. Sit a moment while I prepare a restorative tincture. You did well out there. Your health and stamina are restored.")
	game.notify("Quest complete: Aether Core for Mother +80 XP")

func close() -> void:
	visible=false
