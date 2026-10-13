extends Control
const Frost=preload("res://scripts/frosted_backdrop.gd")
var game:Control
var artwork:TextureRect
var box:VBoxContainer
var heading:Label
var status:Label
var new_button:Button
var load_button:Button
var mode_choice:OptionButton
var custom_button:Button
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
	box=VBoxContainer.new()
	box.add_theme_constant_override("separation",20)
	add_child(box)
	box.add_child(game.label("A JOURNEY BY THE SEA",17,Color("#b5c8bf")))
	heading=game.label("COASTAL\nFOUNDATION",52,Color("#e9c894"))
	box.add_child(heading)
	box.add_child(game.label("Steel, tide, and a little courage.",19))
	mode_choice=OptionButton.new()
	mode_choice.add_item("Alpha — Existing adventure")
	mode_choice.add_item("Beta — Meadow & woodland")
	mode_choice.custom_minimum_size.y=48
	mode_choice.item_selected.connect(select_mode)
	box.add_child(mode_choice)
	new_button=game.button("Start New Game",game.start_new_game)
	new_button.custom_minimum_size.y=58
	box.add_child(new_button)
	load_button=game.button("Load Saved Game",func(): game.start_saved_game(save_path))
	load_button.custom_minimum_size.y=58
	box.add_child(load_button)
	custom_button=game.button("Play Custom World",func(): game.world_browser.open())
	box.add_child(custom_button)
	status=game.label("",16,Color("#c3cfc5"))
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	visible=false

func show_menu(path:String="user://save-v1.json") -> void:
	game.move_child(self,game.get_child_count()-1)
	save_path=path
	fixture_path=path if path not in ["user://save-v1.json","user://beta-save-v1.json",game.current_save_path()] else ""
	mode_choice.select(1 if game.game_mode=="beta" else 0)
	select_mode(mode_choice.selected)
	visible=true
	game._cancel_mouse_charge()
	game._refresh_simulation()
	new_button.grab_focus()

func select_mode(index:int) -> void:
	mode_choice.select(index)
	game.game_mode="beta" if index==1 else "alpha"
	save_path=fixture_path if not fixture_path.is_empty() else game.current_save_path()
	var data=game.Save.read(save_path)
	load_button.disabled=data.is_empty() or data.get("game_mode","alpha")!=game.game_mode
	custom_button.visible=index==0
	status.text="Beta: begin in a quiet meadow. Slimes, sticky resin slimes, wolves and rats inhabit the sparse woodland. Separate Beta save." if index==1 else "Alpha: the existing adventure. Your original save is preserved."
	if load_button.disabled: status.text+="\nNo usable save for this mode yet."

func _process(_delta:float) -> void:
	if not visible: return
	var screen=get_viewport_rect().size
	artwork.position=Vector2(screen.x*.53,screen.y*.025)
	artwork.size=Vector2(screen.x*.45,screen.y*.95)
	heading.add_theme_font_size_override("font_size",clampi(int(screen.x/26),32,58))
	box.size=Vector2(screen.x*.40,0)
	box.position=Vector2(screen.x*.09,maxf(24,(screen.y-box.get_combined_minimum_size().y)*.5))
