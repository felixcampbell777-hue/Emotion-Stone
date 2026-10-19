extends Control
# Audio/voice services own their controls and persistence; this supplies overlay navigation.
var game:Control
var box:PanelContainer
var sections:VBoxContainer
var return_focus:Control
var content_scroll:ScrollContainer
var back:Button

func configure(owner_game:Control) -> void:
	game=owner_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var frost=load("res://scripts/frosted_backdrop.gd").new(); add_child(frost); frost.configure(game)
	box=game.panel(self)
	box.add_theme_stylebox_override("panel",game.style(Color("#203630"),Color("#c6c6a74a")))
	var frame=VBoxContainer.new(); frame.add_theme_constant_override("separation",12); box.add_child(frame)
	frame.add_child(game.label("SOUND & VOICE",24,Color("#e9c894")))
	back=game.button("Back [Esc]",close); frame.add_child(back)
	content_scroll=ScrollContainer.new(); content_scroll.follow_focus=true; content_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; content_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; frame.add_child(content_scroll)
	sections=VBoxContainer.new(); sections.size_flags_horizontal=Control.SIZE_EXPAND_FILL; sections.add_theme_constant_override("separation",12); content_scroll.add_child(sections)
	visible=false

func open() -> void:
	return_focus=get_viewport().gui_get_focus_owner()
	for child in sections.get_children(): sections.remove_child(child); child.queue_free()
	var audio=game.get("audio")
	if audio!=null and audio.has_method("settings_panel"): sections.add_child(audio.settings_panel())
	else: sections.add_child(game.label("Sound settings are unavailable in this build.",16))
	var voice=game.get("voice")
	if voice!=null and voice.has_method("settings_panel"): sections.add_child(voice.settings_panel())
	else: sections.add_child(game.label("Voice is unavailable in this build. You can still play and join servers.",16))
	fit_labels(sections)
	game.move_child(self,game.get_child_count()-1)
	visible=true
	game._cancel_mouse_charge()
	game._refresh_simulation()
	back.grab_focus()

func close() -> void:
	visible=false
	game._refresh_simulation()
	if is_instance_valid(return_focus) and return_focus.is_visible_in_tree(): return_focus.grab_focus()

func _process(_delta:float) -> void:
	if not visible:return
	var screen=get_viewport_rect().size
	box.size=Vector2(minf(680,screen.x-36),minf(780,screen.y-36))
	box.position=(screen-box.size)*.5

func fit_labels(node:Node) -> void:
	if node is Label:node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for child in node.get_children():fit_labels(child)
