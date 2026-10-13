extends Control
const Packs=preload("res://scripts/world_pack.gd")
var game:Control
var box:PanelContainer
var column:VBoxContainer
var list:ItemList
var info:Label
var packs:Array=[]
var importer:FileDialog
func configure(owner:Control) -> void:
	game=owner; set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); z_index=30
	var frost=load("res://scripts/frosted_backdrop.gd").new(); add_child(frost); frost.configure(game)
	box=game.panel(self)
	var scroll=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; box.add_child(scroll)
	column=VBoxContainer.new(); column.add_theme_constant_override("separation",12); column.size_flags_horizontal=SIZE_EXPAND_FILL; scroll.add_child(column)
	column.add_child(game.label("YOUR WORLDS",28,Color("#e9c894")))
	var explanation=game.label("Install from Map Builder, or import a shared .coastworld.json file.",17); explanation.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; column.add_child(explanation)
	list=ItemList.new(); list.custom_minimum_size=Vector2(0,240); column.add_child(list)
	list.item_selected.connect(func(_index): update_info())
	info=game.label("",16); info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; info.custom_minimum_size.y=50; column.add_child(info)
	var row=HBoxContainer.new(); column.add_child(row)
	row.add_child(game.button("Play from start",func(): play(false)))
	row.add_child(game.button("Continue world",func(): play(true)))
	row.add_child(game.button("Import world",func(): importer.popup_centered_ratio(.75)))
	column.add_child(game.button("Close [Esc]",close))
	importer=FileDialog.new(); importer.access=FileDialog.ACCESS_FILESYSTEM; importer.file_mode=FileDialog.FILE_MODE_OPEN_FILE; importer.filters=PackedStringArray(["*.coastworld.json ; Coastal world"]); add_child(importer)
	importer.file_selected.connect(func(path):
		var data=Packs.read_file(path)
		if data.is_empty(): info.text="World file is invalid. Import canceled."; return
		var error=Packs.install(data)
		open(); info.text="World installed." if error==OK else "Could not install this world."
	)
	visible=false
func open() -> void:
	packs=Packs.list_installed(); list.clear()
	for pack in packs: list.add_item(pack.name+"  -  "+str(pack.maps.size())+" areas")
	visible=true; game._cancel_mouse_charge(); game._refresh_simulation()
	if not packs.is_empty(): list.select(0)
	update_info(); _layout()
func close() -> void:
	visible=false; game._refresh_simulation()
func update_info() -> void:
	var selection=list.get_selected_items()
	info.text="No installed worlds. Open Map Builder to create and install one." if selection.is_empty() else "World: "+packs[selection[0]].id+". Custom saves are separate from your main journey."
func play(continue_save:bool) -> void:
	var selection=list.get_selected_items()
	if selection.is_empty(): return
	var id=packs[selection[0]].id
	if continue_save:
		var saved=game.Save.read(Packs.save_path(id))
		if saved.is_empty() or not game.apply_save(saved): info.text="No usable save for this world. Play from start first."; return
		game.title_screen.visible=false; game.pause_menu.visible=false; close()
	else:
		if game.start_world(id): close()
func _unhandled_key_input(event:InputEvent) -> void:
	if visible and event.is_action_pressed("pause"): close(); accept_event()

func _layout() -> void:
	var screen=game.get_viewport_rect().size
	box.size=Vector2(minf(700,screen.x-32),minf(520,screen.y-32)); box.position=(screen-box.size)*.5
func _process(_delta:float) -> void:
	if visible: _layout()
