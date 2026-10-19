extends Control
var game:Control
var box:PanelContainer
var status:Label
var character_options:HBoxContainer
var custom_worlds:Button
var performance_quality:OptionButton
var frame_limit:OptionButton
var heading:Label
var save_button:Button
var load_button:Button
var appearance_button:Button
var multiplayer_button:Button
var resume_button:Button
var adventure_button:Button
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
	heading=game.label("PAUSED",28,Color("#e9c894")); column.add_child(heading)
	resume_button=game.button("Resume [Esc]",close); column.add_child(resume_button)
	column.add_child(game.button("Inventory [I]",func(): game.toggle_inventory()))
	var saves=HBoxContainer.new()
	column.add_child(saves)
	save_button=game.button("Save Game [F5]",save_current); saves.add_child(save_button)
	load_button=game.button("Load Saved Game [F9]",load_saved); saves.add_child(load_button)
	status=game.label("",16)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	custom_worlds=game.button("Custom Worlds",func(): game.world_browser.open()); column.add_child(custom_worlds)
	appearance_button=game.button("Appearance",func(): game.appearance_menu.open()); column.add_child(appearance_button)
	column.add_child(game.button("Sound & Voice",func(): game.settings_menu.open()))
	multiplayer_button=game.button("Multiplayer",func(): game.connection_menu.open()); column.add_child(multiplayer_button)
	column.add_child(game.label("GRAPHICS & VIEW",20,Color("#e9c894")))
	column.add_child(game.view_button)
	var quality=HBoxContainer.new()
	column.add_child(quality)
	for option in [[0,"Full"],[960,"Detailed"],[640,"Fine"],[320,"Chunky"]]:
		var width:int=option[0]
		quality.add_child(game.button(option[1],func(): game.set_resolution(width)))
	var performance=HBoxContainer.new();column.add_child(performance)
	performance.add_child(game.label("Detail",16));performance_quality=OptionButton.new();performance.add_child(performance_quality)
	for name in ["Low","Balanced","High"]:performance_quality.add_item(name)
	performance_quality.item_selected.connect(func(index):game.render_budget.select_quality(["low","balanced","high"][index]))
	performance.add_child(game.label("FPS cap",16));frame_limit=OptionButton.new();performance.add_child(frame_limit)
	for limit in [30,60,90,120]:frame_limit.add_item(str(limit))
	frame_limit.item_selected.connect(func(index):game.render_budget.select_fps([30,60,90,120][index]))
	var hint=game.label("Distant scenery uses less detail; background capped at 15 FPS.",14);hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(hint)
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
	adventure_button=game.button("Choose adventure",choose_adventure); column.add_child(adventure_button)
	visible=false
func _process(_delta:float) -> void:
	if not visible: return
	var screen=get_viewport_rect().size
	box.size=Vector2(minf(540,screen.x-36),minf(760,screen.y-36))
	box.position=(screen-box.size)*.5
func open() -> void:
	performance_quality.select(["low","balanced","high"].find(game.render_budget.quality))
	frame_limit.select([30,60,90,120].find(game.render_budget.fps))
	character_options.visible=game.game_mode=="alpha"
	custom_worlds.visible=game.game_mode=="alpha"
	visible=true
	var online=game.online_session_active()
	heading.text="MENU · WORLD CONTINUES" if online else "PAUSED"
	save_button.disabled=online;load_button.disabled=online;adventure_button.disabled=online
	adventure_button.tooltip_text="Disconnect through Multiplayer before choosing another adventure." if online else ""
	appearance_button.visible=game.game_mode=="world_rise";multiplayer_button.visible=game.game_mode=="world_rise"
	status.text="The server saves your character. Disconnect through Multiplayer to export your checkpoint. Your character remains vulnerable while this menu is open." if online else "F5 saves your current progress. Load restores your last save."
	game._cancel_mouse_charge()
	game.camera_driver.orbiting=false
	game._refresh_simulation()
	resume_button.grab_focus()
func close() -> void:
	visible=false
	game._refresh_simulation()
func save_current(path:String="") -> void:
	if game.online_session_active():status.text="The server saves your online character. Disconnect through Multiplayer to export it.";return
	if path.is_empty(): path=game.current_save_path()
	if game.player.state!="free" or game.recovering:
		status.text="Resume and finish the current action before saving."
		return
	status.text="Game saved." if game.Save.write(game.save_data(),path)==OK else "Could not save the game."
func load_saved(path:String="") -> void:
	if game.online_session_active():status.text="Disconnect through Multiplayer before loading an offline save.";return
	if path.is_empty(): path=game.current_save_path()
	if game.player.state!="free" or game.recovering:
		status.text="Resume and finish the current action before loading."
		return
	if game.apply_save(game.Save.read(path)):
		close()
		game.notify("Saved game loaded.")
	else:
		status.text="No valid saved game. Your current progress is unchanged."

func choose_adventure()->void:
	if game.online_session_active():
		game.connection_menu.open()
		game.connection_menu.update_status("Disconnect to export your character before choosing another adventure.")
		return
	close()
	game.title_screen.show_menu(game.current_save_path())
