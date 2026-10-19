extends Control
const Profile=preload("res://scripts/appearance_profile.gd")
var game:Control
var draft:Dictionary
var original:Dictionary
var return_to=""
var section="face"
var preview:SubViewportContainer
var rail:VBoxContainer
var details:VBoxContainer
var apply_button:Button
var status:Label
var catalog:Dictionary
var pending=false
var pending_since=0
var pending_controls:Dictionary={}

func configure(owner_game:Control) -> void:
	game=owner_game;catalog=Profile.catalog()
	if game.has_signal("appearance_commit_finished"):game.connect("appearance_commit_finished",resolve_online)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
	var background=ColorRect.new();background.color=Color("#14231F");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(background)
	var margin=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,16)
	add_child(margin)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",10);margin.add_child(column)
	column.add_child(game.label("APPEARANCE",25,Color("#E9C894")))
	var main=HBoxContainer.new();main.size_flags_vertical=Control.SIZE_EXPAND_FILL;main.add_theme_constant_override("separation",12);column.add_child(main)
	var rail_panel=game.panel(main);rail_panel.custom_minimum_size.x=135;rail=VBoxContainer.new();rail_panel.add_child(rail)
	for entry in [["face","Face"],["hair","Hair"],["skin","Skin"],["body","Body"],["colors","Colors"]]:
		var id:String=entry[0];rail.add_child(game.button(entry[1],func():show_section(id)))
	var middle=VBoxContainer.new();middle.size_flags_horizontal=Control.SIZE_EXPAND_FILL;main.add_child(middle)
	preview=preload("res://scripts/appearance_preview.gd").new();preview.size_flags_vertical=Control.SIZE_EXPAND_FILL;middle.add_child(preview)
	var angles=HBoxContainer.new();middle.add_child(angles)
	for entry in [["Front",0.0],["Side",PI*.5],["Back",PI]]:
		var angle:float=entry[1];angles.add_child(game.button(entry[0],func():preview.turn(angle)))
	var hint=game.label("Drag to rotate · Scroll to zoom",12);hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;middle.add_child(hint)
	var detail_panel=game.panel(main);detail_panel.custom_minimum_size.x=250
	var scroll=ScrollContainer.new();scroll.follow_focus=true;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;detail_panel.add_child(scroll)
	details=VBoxContainer.new();details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;details.add_theme_constant_override("separation",10);scroll.add_child(details)
	status=game.label("",13);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(status)
	var footer=HBoxContainer.new();footer.add_theme_constant_override("separation",8);column.add_child(footer)
	footer.add_child(game.button("Randomize",randomize_colors))
	footer.add_child(game.button("Reset to Default",reset_default))
	var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer.add_child(spacer)
	footer.add_child(game.button("Cancel [Esc]",close))
	apply_button=game.button("Apply",apply_draft);footer.add_child(apply_button)
	visible=false

func open(origin:String="") -> void:
	if game.game_mode!="world_rise":return
	return_to=origin
	if return_to.is_empty():return_to="inventory" if game.inventory.visible else "pause" if game.pause_menu.visible else ""
	game._cancel_mouse_charge();game.player.clear_dash_attack()
	game.inventory.close();game.pause_menu.visible=false
	game.move_child(self,game.get_child_count()-1)
	original=Profile.snapshot(game.appearance);draft=original.duplicate(true)
	if preview.avatar==null:preview.configure()
	visible=true;show_section(section);game._refresh_simulation()
	for button in rail.get_children():
		if not button.disabled:button.grab_focus();break

func is_open() -> bool:
	return visible

func close() -> void:
	if not visible or pending:return
	visible=false;draft={};original={}
	if return_to=="inventory":game.inventory.visible=true;game.inventory.refresh()
	elif return_to=="pause":game.pause_menu.open()
	game._cancel_mouse_charge();game._refresh_simulation()

func show_section(id:String) -> void:
	section=id
	for child in details.get_children():details.remove_child(child);child.queue_free()
	for index in range(rail.get_child_count()):rail.get_child(index).disabled=["face","hair","skin","body","colors"][index]==id
	preview.frame(section)
	details.add_child(game.label(section.capitalize(),21,Color("#E9C894")))
	if section in ["face","hair","skin","body"]:
		for item in catalog.categories[section].options:
			var option:String=item.id
			var field=section+"_id"
			var button=game.button(item.label,func():draft[field]=option;show_section(section))
			button.disabled=draft[field]==option;details.add_child(button)
	if section=="face":add_tint("eyes","Eye tint")
	elif section=="hair":add_tint("hair","Hair tint")
	elif section=="skin":add_tint("skin","Skin tone")
	elif section=="body":add_note("Both silhouettes preserve height, movement, grip and clothing fit.")
	else:
		for entry in [["hair","Hair"],["eyes","Eyes"],["cloth","Clothing"],["leather","Leather"]]:add_tint(entry[0],entry[1])
	add_note("White restores the original baked color.")
	refresh_preview()

func add_note(text:String) -> void:
	var note=game.label(text,14,Color("#CDC8B6"));note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.custom_minimum_size.x=200;details.add_child(note)

func add_tint(channel:String,title:String) -> void:
	details.add_child(game.label(title,16))
	var swatches=HFlowContainer.new();swatches.add_theme_constant_override("h_separation",6);details.add_child(swatches)
	for value in catalog.tints[channel]:
		var tint:String=value
		var button=Button.new();button.custom_minimum_size=Vector2(32,30);button.tooltip_text="Original" if tint=="#FFFFFF" else tint
		button.add_theme_stylebox_override("normal",game.style(Color(tint),Color("#E9C894") if draft.colors[channel]==tint else Color("#657369"),4))
		button.pressed.connect(func():draft.colors[channel]=tint;show_section(section));swatches.add_child(button)
	var picker=ColorPickerButton.new();picker.color=Color(draft.colors[channel]);picker.edit_alpha=false;picker.custom_minimum_size.y=30;picker.tooltip_text="Choose "+title.to_lower();details.add_child(picker)
	picker.get_picker().deferred_mode=true
	picker.color_changed.connect(func(color:Color):draft.colors[channel]="#"+color.to_html(false).to_upper();refresh_preview())

func refresh_preview() -> void:
	if draft.is_empty():return
	preview.show_profile(draft)
	apply_button.disabled=Profile.revision_key(draft)==Profile.revision_key(original)
	status.text="Changes stay in this preview until Apply. Saved with your next normal game save."

func randomize_colors() -> void:
	for category in ["face","hair","body"]:draft[category+"_id"]=catalog.categories[category].options.pick_random().id
	for channel in Profile.COLOR_KEYS:draft.colors[channel]=catalog.tints[channel].pick_random()
	show_section(section)

func reset_default() -> void:
	draft=Profile.default_profile();show_section(section)

func apply_draft() -> void:
	if pending:return
	if not Profile.valid(draft):status.text="This appearance is not supported.";return
	var online=game.online_session_active()
	# Mark pending before dispatch: the local host can acknowledge synchronously.
	if online:set_pending(true)
	if not game.commit_appearance(draft):
		set_pending(false);status.text="Appearance could not be applied. Your preview is still available.";return
	if not online:close()

func set_pending(value:bool) -> void:
	if value==pending:return
	pending=value
	if value:
		pending_since=Time.get_ticks_msec();pending_controls.clear()
		for button in find_children("*","BaseButton",true,false):
			pending_controls[button]=button.disabled;button.disabled=true
		status.text="Applying appearance…"
	else:
		for button in pending_controls:
			if is_instance_valid(button):button.disabled=pending_controls[button]
		pending_controls.clear()

func resolve_online(accepted:bool,message:String="") -> void:
	if not pending:return
	set_pending(false)
	if accepted:close()
	else:status.text=message if not message.is_empty() else "Appearance could not be applied. Your preview is still available."

func _process(_delta:float) -> void:
	if visible and pending and Time.get_ticks_msec()-pending_since>5000:status.text="Still waiting for the host. Your changes remain in this preview."
