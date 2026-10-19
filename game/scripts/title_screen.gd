extends Control
const Frost=preload("res://scripts/frosted_backdrop.gd")
var game:Control
var artwork:TextureRect
var box:VBoxContainer
var menu_scroll:ScrollContainer
var heading:Label
var status:Label
var new_button:Button
var load_button:Button
var mode_choice:OptionButton
var import_choice:OptionButton
var custom_button:Button
var rise_actions:HBoxContainer
var fixture_path=""
var save_path:String="user://save-v1.json"

func configure(owner_game:Control) -> void:
	game=owner_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var frost=Frost.new()
	add_child(frost)
	frost.configure(game)
	var shade=ColorRect.new()
	shade.color=Color(0.035,0.08,0.075,.50)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	artwork=TextureRect.new()
	artwork.texture=load("res://assets/conversation/hero-inventory-v1.png")
	artwork.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(artwork)
	menu_scroll=ScrollContainer.new(); menu_scroll.follow_focus=true; menu_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; add_child(menu_scroll)
	box=VBoxContainer.new(); box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",20)
	menu_scroll.add_child(box)
	box.add_child(game.label("A JOURNEY BY THE SEA",17,Color("#b5c8bf")))
	heading=game.label("COASTAL\nFOUNDATION",52,Color("#e9c894"))
	box.add_child(heading)
	box.add_child(game.label("Steel, tide, and a little courage.",19))
	mode_choice=OptionButton.new()
	mode_choice.add_item("Alpha — Existing adventure")
	mode_choice.add_item("Beta — Meadow & woodland")
	mode_choice.add_item("Alpha 2 — The Hollow Bell")
	mode_choice.add_item("World Rise — Floor 1")
	mode_choice.custom_minimum_size.y=48
	mode_choice.item_selected.connect(select_mode)
	box.add_child(mode_choice)
	import_choice=OptionButton.new()
	import_choice.add_item("Copy character from Alpha save")
	import_choice.add_item("Copy character from Beta save")
	import_choice.custom_minimum_size.y=42
	import_choice.item_selected.connect(func(index): game.alpha2_import_mode="beta" if index==1 else "alpha";select_mode(mode_choice.selected))
	box.add_child(import_choice)
	new_button=game.button("Start New Game",game.start_new_game)
	new_button.custom_minimum_size.y=58
	box.add_child(new_button)
	load_button=game.button("Load Saved Game",func(): game.start_saved_game(save_path))
	load_button.custom_minimum_size.y=58
	box.add_child(load_button)
	custom_button=game.button("Play Custom World",func(): game.world_browser.open())
	box.add_child(custom_button)
	rise_actions=HBoxContainer.new(); box.add_child(rise_actions)
	for entry in [["Multiplayer",func(): game.connection_menu.open()]]:
		var action=game.button(entry[0],entry[1]); action.add_theme_font_size_override("font_size",15); action.size_flags_horizontal=Control.SIZE_EXPAND_FILL; rise_actions.add_child(action)
	box.add_child(game.button("Sound & Voice",func(): game.settings_menu.open()))
	status=game.label("",16,Color("#c3cfc5"))
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	visible=false

func show_menu(path:String="user://save-v1.json") -> void:
	game.move_child(self,game.get_child_count()-1)
	save_path=path
	fixture_path=path if path not in ["user://save-v1.json","user://beta-save-v1.json",game.current_save_path()] else ""
	mode_choice.select(3 if game.game_mode=="world_rise" else 2 if game.game_mode=="alpha2" else 1 if game.game_mode=="beta" else 0)
	if game.game_mode=="alpha2" and game.alpha2_import_path.is_empty():
		var alpha=game.Save.read("user://save-v1.json");var beta=game.Save.read("user://beta-save-v1.json")
		if alpha.is_empty() and not beta.is_empty(): game.alpha2_import_mode="beta"
	import_choice.select(1 if game.alpha2_import_mode=="beta" else 0)
	select_mode(mode_choice.selected)
	visible=true
	game._cancel_mouse_charge()
	game._refresh_simulation()
	new_button.grab_focus()

func select_mode(index:int) -> void:
	mode_choice.select(index)
	game.game_mode="world_rise" if index==3 else "alpha2" if index==2 else "beta" if index==1 else "alpha"
	save_path=fixture_path if not fixture_path.is_empty() else game.current_save_path()
	var data=game.Save.read(save_path)
	load_button.disabled=data.is_empty() or data.get("game_mode","alpha")!=game.game_mode
	custom_button.visible=index==0
	rise_actions.visible=index==3
	import_choice.visible=index==2
	status.text="Beta: begin in a quiet meadow. Slimes, sticky resin slimes, wolves and rats inhabit the sparse woodland. Separate Beta save." if index==1 else "Alpha: the existing adventure. Your original save is preserved."
	if index==2:
		var source=game.alpha2_import_path if not game.alpha2_import_path.is_empty() else "user://beta-save-v1.json" if game.alpha2_import_mode=="beta" else "user://save-v1.json"
		var imported=game.Save.read(source)
		status.text="Nine linked areas, treasure hunts, companions and a new boss. First person · Advanced graphics. About an hour, depending on exploration and imported power. Separate Alpha 2 save."
		status.text+="\nNew Game copies "+game.alpha2_import_mode.capitalize()+" level, skills and equipment. Original save stays untouched." if not imported.is_empty() else "\nNo usable "+game.alpha2_import_mode.capitalize()+" save found. New Game will use a fresh adventurer."
	if index==3:status.text="World Rise: a fresh character on a vast floating floor. Significant hills, boar valleys, Elderwood wolves and a central arrival platform. Separate save; no imports."
	if load_button.disabled: status.text+="\nNo usable save for this mode yet."

func _process(_delta:float) -> void:
	if not visible: return
	var screen=get_viewport_rect().size
	var compact=screen.y<650
	box.get_child(0).visible=not compact
	box.get_child(2).visible=not compact
	box.add_theme_constant_override("separation",8 if compact else 12)
	new_button.custom_minimum_size.y=44 if compact else 58
	load_button.custom_minimum_size.y=44 if compact else 58
	mode_choice.custom_minimum_size.y=38 if compact else 48
	import_choice.custom_minimum_size.y=36 if compact else 42
	status.add_theme_font_size_override("font_size",14 if compact else 16)
	artwork.position=Vector2(screen.x*.53,screen.y*.025)
	artwork.size=Vector2(screen.x*.45,screen.y*.95)
	heading.add_theme_font_size_override("font_size",28 if compact else clampi(int(screen.x/26),32,44))
	menu_scroll.size=Vector2(screen.x*.44,minf(screen.y-48,box.get_combined_minimum_size().y))
	menu_scroll.position=Vector2(screen.x*.09,maxf(24,(screen.y-menu_scroll.size.y)*.5))
