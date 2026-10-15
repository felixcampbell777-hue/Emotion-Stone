extends Control
var game:Control
var box:PanelContainer
var status:Label
var character_options:HBoxContainer
var custom_worlds:Button
func configure(owner_game:Control) -> void:
	game=owner_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var frost=load("res://scripts/frosted_backdrop.gd").new()
	add_child(frost)
	frost.configure(game)
	box=game.panel(self)
	var scroll=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus=true
	box.add_child(scroll)
	var column=VBoxContainer.new()
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",10)
	scroll.add_child(column)
	column.add_child(game.label("PAUSED",28,Color("#e9c894")))
	column.add_child(game.button("Resume [Esc]",close))
	column.add_child(game.button("Inventory [I]",func(): game.toggle_inventory()))
	var saves=HBoxContainer.new()
	column.add_child(saves)
	saves.add_child(game.button("Save Game [F5]",save_current))
	saves.add_child(game.button("Load Saved Game [F9]",load_saved))
	status=game.label("",16)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	custom_worlds=game.button("Custom Worlds",func(): game.world_browser.open()); column.add_child(custom_worlds)
	column.add_child(game.label("GRAPHICS & VIEW",20,Color("#e9c894")))
	column.add_child(game.view_button)
	var quality=HBoxContainer.new()
	column.add_child(quality)
	for option in [[0,"Full"],[960,"Detailed"],[640,"Fine"],[320,"Chunky"]]:
		var width:int=option[0]
		quality.add_child(game.button(option[1],func(): game.set_resolution(width)))
	var environment=HBoxContainer.new()
	column.add_child(environment)
	environment.add_child(game.label("World art",16))
	environment.add_child(game.button("Original",func(): game.set_environment_profile("original")))
	environment.add_child(game.button("Advanced",func(): game.set_environment_profile("darkwood")))
	var character=HBoxContainer.new()
	character_options=character
	column.add_child(character)
	character.add_child(game.label("Character",16))
	character.add_child(game.button("Animated heroine",func(): game.set_character_profile("game")))
	character.add_child(game.button("Standalone (static)",func(): game.set_character_profile("standalone")))
	column.add_child(game.label("First-person view  ·  Mouse to look",16))
	column.add_child(game.button("Toggle Fullscreen [F11]",game.toggle_fullscreen))
	column.add_child(game.button("Controls & Help [H]",func(): close(); game.toggle_help()))
	column.add_child(game.button("Choose adventure",func(): close(); game.title_screen.show_menu(game.current_save_path())))
	visible=false
func _process(_delta:float) -> void:
	if not visible: return
	var screen=get_viewport_rect().size
	box.size=Vector2(500,minf(680,screen.y-36))
	box.position=(screen-box.size)*.5
func open() -> void:
	character_options.visible=game.game_mode=="alpha"
	custom_worlds.visible=game.game_mode=="alpha"
	visible=true
	status.text="F5 saves your current progress. Load restores your last save."
	game.camera_driver.orbiting=false
	game._refresh_simulation()
func close() -> void:
	visible=false
	game._refresh_simulation()
func save_current(path:String="") -> void:
	if path.is_empty(): path=game.current_save_path()
	if game.player.state!="free" or game.recovering:
		status.text="Resume and finish the current action before saving."
		return
	status.text="Game saved." if game.Save.write(game.save_data(),path)==OK else "Could not save the game."
func load_saved(path:String="") -> void:
	if path.is_empty(): path=game.current_save_path()
	if game.player.state!="free" or game.recovering:
		status.text="Resume and finish the current action before loading."
		return
	if game.apply_save(game.Save.read(path)):
		close()
		game.notify("Saved game loaded.")
	else:
		status.text="No valid saved game. Your current progress is unchanged."
