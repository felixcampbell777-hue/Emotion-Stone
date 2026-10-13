extends Control
const Packs = preload("res://scripts/world_pack.gd")
const Document = preload("res://scripts/builder_document.gd")
const Geometry=preload("res://scripts/builder_geometry.gd")
var pending_fit=false
var overlay:Control
var resizing=false
var resize_index=-1
var resize_original:Dictionary={}
var geometry_dirty=false
var geometry_clock=0.0
var creating_terrain=false
var creation_from=Vector2.ZERO
var creation_to=Vector2.ZERO
var creation_y=0.0
const Sculpt=preload("res://scripts/sculpt_terrain.gd")
const Fragments=preload("res://scripts/builder_fragments.gd")
var fragment_path=""
var fragment_dialog:AcceptDialog
var fragment_list:ItemList
var fragment_name:LineEdit
var fragment_info:Label
var fragment_entries:Array=[]
var pending_fragment:Dictionary={}
const Props = preload("res://scripts/props.gd")
var pack: Dictionary
var area_index = 0
var selected: Dictionary = {}
var selected_kind = ""
var undo_stack: Array = []
var redo_stack: Array = []
var dirty = false
var path = ""
var canvas
var viewport: SubViewport
var stage: Node3D
var world
var environment_profile="darkwood"
var camera: Camera3D
var inspector: VBoxContainer
var area_list: OptionButton
var status: Label
var file_dialog: FileDialog
var file_action = ""
var focus = Vector3.ZERO
var zoom = 38.0
var dragging = false
var drag_saved = false
var drag_offset=Vector2.ZERO
var drag_plane_y=0.0
var snap = 0.5
var count = 0
var updating = false
var orbit_yaw=0.0
var orbit_pitch=.907
var terrain_profile="smooth"
var brush_radius=4.0
var hover_pixel=Vector2.ZERO
var hover_active=false
var profile_menu:OptionButton
var inspector_tabs:TabBar
var inspector_section=0
var mode_menu:OptionButton
var edit_mode=0
var active_piece:Dictionary={}
var palette_group=ButtonGroup.new()
var brush_controls:Array=[]
var context_hint:Label
var document_label:Label
var help_dialog:AcceptDialog
func _ready() -> void :
	get_window().title = "Coastal Map Builder"
	get_tree().auto_accept_quit = false;get_window().close_requested.connect( func():
		if dirty: confirm("Exit without saving your changes?", func(): get_tree().quit())
		else: get_tree().quit())
	theme = Theme.new();theme.default_font_size = 16
	var bg = ColorRect.new();bg.color = Color("#17232a");bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT);add_child(bg)
	var layout = VBoxContainer.new();layout.set_anchors_and_offsets_preset(PRESET_FULL_RECT);layout.add_theme_constant_override("separation", 8);add_child(layout)
	layout.offset_left=12; layout.offset_top=12; layout.offset_right=-12; layout.offset_bottom=-12
	var toolbar=HFlowContainer.new(); layout.add_child(toolbar)
	menu(toolbar,"File",[["New world",new_document],["Open example",open_example],["Fragment library",show_fragments],["Open world",func(): choose_file("open")],["Save draft",save_document],["Save draft as...",func(): choose_file("save")],["Export world",func(): choose_file("export")]])
	button(toolbar,"Save",save_document); button(toolbar,"Fragments",show_fragments); button(toolbar,"Undo",undo); button(toolbar,"Redo",redo)
	menu(toolbar,"View",[["Top view",func(): orbit_yaw=0; orbit_pitch=1.55; position_camera()],["Angled view",func(): orbit_yaw=0; orbit_pitch=.907; position_camera()],["Fit area",fit_camera],["Advanced art",func(): environment_profile="darkwood"; rebuild()],["Original art",func(): environment_profile="original"; rebuild()]])
	button(toolbar,"Check map",validate_world); button(toolbar,"Play world",play_world)
	menu(toolbar,"Publish",[["Install locally",install_world],["Export world",func(): choose_file("export")]])
	button(toolbar,"Help",func(): help_dialog.popup_centered(Vector2i(640,430)))
	document_label=Label.new(); document_label.add_theme_font_size_override("font_size",14); toolbar.add_child(document_label)
	var area_bar=HFlowContainer.new(); layout.add_child(area_bar)
	var area_caption=Label.new(); area_caption.text="AREA"; area_bar.add_child(area_caption)
	area_list=OptionButton.new(); area_list.fit_to_longest_item=false; area_list.clip_text=true; area_list.custom_minimum_size.x=170; area_bar.add_child(area_list); area_list.item_selected.connect(func(index): area_index=index; selected={}; fit_camera(); rebuild(); inspect())
	menu(area_bar,"Area",[["Add outdoor area",func(): add_area(false)],["Add cave area",func(): add_area(true)],["Area settings",func(): inspector_tabs.current_tab=1],["Select START",select_start]])
	var terrain_bar=HFlowContainer.new(); layout.add_child(terrain_bar)
	var tool_label=Label.new(); tool_label.text="TOOL"; terrain_bar.add_child(tool_label)
	mode_menu=OptionButton.new()
	for mode in ["Select & transform","Place from palette","Sculpt height"]: mode_menu.add_item(mode)
	terrain_bar.add_child(mode_menu); mode_menu.item_selected.connect(set_mode)
	profile_menu=OptionButton.new(); profile_menu.add_item("Smooth slope"); profile_menu.add_item("Bluff + walk-up"); profile_menu.add_item("Overhang + walk-up"); terrain_bar.add_child(profile_menu); brush_controls.append(profile_menu)
	profile_menu.item_selected.connect(func(i): terrain_profile=["smooth","bluff","overhang"][i]; if edit_mode!=5: apply_hover_profile())
	var radius_label=Label.new(); radius_label.text="Brush radius"; terrain_bar.add_child(radius_label); brush_controls.append(radius_label)
	var radius=SpinBox.new(); radius.min_value=1; radius.max_value=8; radius.step=.5; radius.value=brush_radius; terrain_bar.add_child(radius); brush_controls.append(radius); radius.value_changed.connect(func(v): brush_radius=v)
	for control in brush_controls: control.visible=false
	var row = HBoxContainer.new();row.size_flags_vertical = SIZE_EXPAND_FILL;layout.add_child(row)
	var palette_scroll = ScrollContainer.new();palette_scroll.custom_minimum_size.x = 240;row.add_child(palette_scroll)
	var palette = VBoxContainer.new();palette.size_flags_horizontal = SIZE_EXPAND_FILL;palette_scroll.add_child(palette)
	var label = Label.new();label.text = "PIECES - click or drag";palette.add_child(label)
	var search = LineEdit.new();search.placeholder_text = "Find name or code...";palette.add_child(search)
	var names={"terrain":"Terrain surfaces", "A":"Trees", "B":"Rocks", "C":"Wilderness", "D":"Paths", "E":"Creatures", "F":"Hills & bluffs", "G":"Caves", "tools":"Area tools & paint"}
	var groups=[]
	for category in names:
		var header=Button.new(); header.text="- "+names[category]; header.alignment=HORIZONTAL_ALIGNMENT_LEFT; palette.add_child(header)
		var body=VBoxContainer.new(); body.visible=category in ["A","terrain"]; header.text=("- " if body.visible else "+ ")+names[category]; palette.add_child(body)
		header.pressed.connect(func(): body.visible=not body.visible; header.text=("- " if body.visible else "+ ")+names[category])
		var cards=[]
		if category=="terrain":
			for shape in ["smooth","bluff","overhang"]:
				var card=load("res://scripts/builder_drag.gd").new(); card.text={"smooth":"Smooth hill","bluff":"Bluff with walk-up","overhang":"Overhang with walk-up"}[shape]; card.payload={"tool":"terrain","profile":shape}; card.toggle_mode=true; card.button_group=palette_group; body.add_child(card); cards.append(card)
				card.pressed.connect(func(): active_piece=card.payload.duplicate(true); selected={}; set_mode(1); show_selection(); inspect(); status.text="Drag a rectangle on the map to create "+card.text+". A click places the default size.")
		for item in Packs.catalog().features+Packs.catalog().monsters:
			if not item.code.ends_with(category): continue
			var card=load("res://scripts/builder_drag.gd").new(); card.text=item.code+"  "+item.name; card.alignment=HORIZONTAL_ALIGNMENT_LEFT; card.tooltip_text=item.get("description",""); card.payload={"tool":"mob" if category=="E" else "prop","code":item.code}; body.add_child(card); cards.append(card); card.clip_text=true; card.toggle_mode=true; card.button_group=palette_group; card.pressed.connect(func(): active_piece=card.payload.duplicate(true); selected={}; set_mode(1); show_selection(); inspect(); status.text="Click the map to place "+card.text+". Escape returns to selection.")
		if category=="tools":
			for tool in ["transition","spawn","grass","path","cobble","sand","water"]:
				var card=load("res://scripts/builder_drag.gd").new(); card.text="Move START" if tool=="spawn" else tool.capitalize(); card.payload={"tool":tool}; body.add_child(card); cards.append(card); card.clip_text=true; card.toggle_mode=true; card.button_group=palette_group; card.pressed.connect(func(): active_piece=card.payload.duplicate(true); selected={}; set_mode(1); show_selection(); inspect(); status.text="Click the map to place "+card.text+". Escape returns to selection.")
		groups.append({"header":header,"body":body,"cards":cards})
	search.text_changed.connect(func(value):
		for group in groups:
			var found=false
			for card in group.cards:
				card.visible=value.to_lower() in card.text.to_lower(); found=found or card.visible
			group.header.visible=found; group.body.visible=found)
	canvas=load("res://scripts/builder_drop.gd").new(); canvas.editor=self; canvas.focus_mode=Control.FOCUS_ALL; canvas.clip_contents=true; canvas.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; canvas.stretch_mode=TextureRect.STRETCH_SCALE; canvas.size_flags_horizontal=SIZE_EXPAND_FILL; canvas.size_flags_vertical=SIZE_EXPAND_FILL; row.add_child(canvas)
	viewport=SubViewport.new(); viewport.size=Vector2i(800,650); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; canvas.add_child(viewport); canvas.texture=viewport.get_texture()
	canvas.mouse_entered.connect(func(): hover_active=true)
	canvas.mouse_exited.connect(func(): hover_active=false)
	overlay=load("res://scripts/builder_handles.gd").new(); overlay.editor=self; overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE; canvas.add_child(overlay); overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	canvas.resized.connect(func():
		viewport.size=Vector2i(maxi(1,int(canvas.size.x)),maxi(1,int(canvas.size.y)))
		if pending_fit: call_deferred("fit_camera"))
	stage = Node3D.new();viewport.add_child(stage)
	var environment = WorldEnvironment.new(); environment.name="ArtEnvironment"; var env = Environment.new();env.background_mode = Environment.BG_COLOR;env.background_color = Color("#35434a");env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color = Color.WHITE;env.ambient_light_energy = 0.65;environment.environment = env;stage.add_child(environment)
	var light = DirectionalLight3D.new();light.name="WorldSun";light.rotation_degrees = Vector3(-55, -35, 0);light.light_energy = 1.2;light.shadow_enabled=true;stage.add_child(light)
	camera = Camera3D.new();camera.projection = Camera3D.PROJECTION_ORTHOGONAL;camera.far = 400;stage.add_child(camera)
	var right=VBoxContainer.new(); right.custom_minimum_size.x=300; row.add_child(right)
	inspector_tabs=TabBar.new(); inspector_tabs.add_tab("Selection"); inspector_tabs.add_tab("Area"); inspector_tabs.add_tab("World"); inspector_tabs.add_tab("Objects"); inspector_tabs.add_theme_font_size_override("font_size",14); right.add_child(inspector_tabs); inspector_tabs.tab_changed.connect(func(i): inspector_section=i; inspect())
	var scroll=ScrollContainer.new(); scroll.size_flags_vertical=SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; right.add_child(scroll)
	inspector=VBoxContainer.new(); inspector.size_flags_horizontal=SIZE_EXPAND_FILL; scroll.add_child(inspector)
	status=Label.new(); status.custom_minimum_size.y=28; status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; layout.add_child(status)
	context_hint=Label.new(); context_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; layout.add_child(context_hint)
	help_dialog=AcceptDialog.new(); help_dialog.title="Map Builder controls"; help_dialog.dialog_autowrap=true; var help_text=RichTextLabel.new(); help_text.text="Choose an area or add an outdoor area / cave.\nClick a piece on the left, then click the map to place it. Dragging also works.\nSelect & transform: click any existing object, zone or START. Drag to move; selected zones/terrain show resize handles.\nSculpt: click raises; Ctrl+click lowers. Up/Down changes height; Shift makes larger steps; Left/Right changes profile.\nSelect: drag the body to move, yellow sides/corners to resize; edges snap to area bounds.\nTerrain surfaces: choose a shape from the palette and drag its footprint. Placement returns to Select. Hold Shift for repeated pieces.\n\nWheel: zoom | Middle-drag: pan | Right-drag: orbit\nEscape: select mode | Delete: remove | Ctrl+Z/Y: undo/redo\nSave keeps your draft. Check map finds errors. Play world installs a valid world and opens the game.\nSelection: object controls. Area: boundaries and biome. World: name and starting area."; add_child(help_dialog)
	help_dialog.add_child(help_text); help_text.set_anchors_and_offsets_preset(PRESET_FULL_RECT); help_text.offset_left=16; help_text.offset_top=12; help_text.offset_right=-16; help_text.offset_bottom=-56; help_text.scroll_active=true; help_dialog.min_size=Vector2i(620,400)
	set_mode(0)
	file_dialog = FileDialog.new();file_dialog.access = FileDialog.ACCESS_FILESYSTEM;file_dialog.filters = PackedStringArray(["*.coastworld.json ; Coastal world"]);add_child(file_dialog);file_dialog.file_selected.connect(file_selected)
	DirAccess.make_dir_recursive_absolute("user://world-drafts");file_dialog.current_dir = ProjectSettings.globalize_path("user://world-drafts")
	new_document()
	var args = OS.get_cmdline_user_args()
	if "--builder-checks" in args: call_deferred("run_checks")
	if "--builder-capture" in args: call_deferred("capture", args[args.find("--builder-capture") + 1])
func button(parent: Node, text: String, action: Callable) -> Button:
	var b = Button.new();b.text = text
	if parent == inspector: b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;b.custom_minimum_size = Vector2(260, 32)
	parent.add_child(b);b.pressed.connect(action);return b
func area() -> Dictionary: return pack.maps[area_index]
func checkpoint() -> void :
	undo_stack.append(pack.duplicate(true)); if undo_stack.size() > 100: undo_stack.pop_front()
	redo_stack.clear();dirty = true
func undo() -> void :
	if undo_stack.is_empty(): return
	redo_stack.append(pack.duplicate(true));pack = undo_stack.pop_back();reset_selection()
func redo() -> void :
	if redo_stack.is_empty(): return
	undo_stack.append(pack.duplicate(true));pack = redo_stack.pop_back();reset_selection()
func reset_selection() -> void :
	area_index = mini(area_index, pack.maps.size() - 1);selected = {};refresh_areas();rebuild();inspect();dirty = true
func new_document() -> void :
	if dirty:
		confirm("Discard unsaved changes?", reset_document);return
	reset_document()
func confirm(message: String, action: Callable) -> void :
	var dialog = ConfirmationDialog.new();dialog.dialog_text = message;add_child(dialog);dialog.confirmed.connect(action);dialog.popup_centered();dialog.confirmed.connect(dialog.queue_free);dialog.canceled.connect(dialog.queue_free)
func reset_document() -> void :
	fragment_path=""; pending_fragment={}
	pack = Document.blank();area_index = 0;selected = {};undo_stack.clear();redo_stack.clear();path = "";dirty = false;refresh_areas();fit_camera();rebuild();inspect();status.text = "Ready. Save a draft, then Check map and Play world. Caves are optional. Save reusable areas in Fragments."
func refresh_areas() -> void :
	area_list.clear()
	for map in pack.maps: area_list.add_item(map.display_name)
	area_list.select(area_index)
func remove_area() -> void :
	if pack.maps.size() == 1: status.text = "Keep at least one area.";return
	confirm("Remove this area and all gates that lead to it?", func():
		checkpoint(); var id = area().id;pack.maps.remove_at(area_index);area_index = 0
		for map in pack.maps: map.exits = map.exits.filter( func(gate): return gate.target != id)
		if pack.start_map == id: pack.start_map = area().id
		reset_selection())
func add_area(cave: bool) -> void :
	if not fragment_path.is_empty(): fragment_path=""; path=""
	checkpoint(); var id = "area_" + str(pack.maps.size() + 1)
	while pack.maps.any( func(map): return map.id == id): id += "_new"
	pack.maps.append(Document.area(id, cave));area_index = pack.maps.size() - 1;selected = {};refresh_areas();fit_camera();rebuild();inspect()
func fit_camera() -> void:
	if canvas.size.x<100 or canvas.size.y<100: pending_fit=true; return
	pending_fit=false
	var b=area().bounds; var low=0.0; var high=0.0
	for patch in area().get("sculpted_terrain",[]): low=minf(low,patch.height); high=maxf(high,patch.height)
	for prop in area().props:
		if prop.get("catalog_code","").ends_with("F"): high=maxf(high,3*float(prop.get("scale",1)))
	focus=Vector3((b[0]+b[2])*.5,(low+high)*.5,(b[1]+b[3])*.5); position_camera()
	var horizontal=0.0; var vertical=0.0
	var right=Vector3(cos(orbit_yaw),0,-sin(orbit_yaw)); var up=Vector3(-sin(orbit_yaw)*sin(orbit_pitch),cos(orbit_pitch),-cos(orbit_yaw)*sin(orbit_pitch))
	for x in [b[0],b[2]]:
		for z in [b[1],b[3]]:
			for y in [low,high]:
				var delta=Vector3(x,y,z)-focus
				horizontal=maxf(horizontal,absf(right.dot(delta))*2)
				vertical=maxf(vertical,absf(up.dot(delta))*2)
	zoom=maxf(vertical,horizontal/(maxf(1,canvas.size.x)/maxf(1,canvas.size.y)))*1.12; position_camera()
func position_camera() -> void :
	if world != null:
		for child in world.get_children():
			if child is Label3D: child.pixel_size = zoom * 0.0007
	camera.size = zoom;camera.position = focus + Vector3(sin(orbit_yaw)*cos(orbit_pitch),sin(orbit_pitch),cos(orbit_yaw)*cos(orbit_pitch))*41;camera.look_at(focus)
func marker(at: Vector2, text: String, color: String, dimensions: Vector2 = Vector2(0.7, 0.7), altitude:float=0) -> void :
	var y = world.ground_height(Vector3(at.x, altitude, at.y)) + 0.08
	Props.box(world, Vector3(at.x, y, at.y), Vector3(dimensions.x, 0.08, dimensions.y), color)
	var label = Label3D.new();label.text = text;label.position = Vector3(at.x, y + 0.8, at.y);label.billboard = BaseMaterial3D.BILLBOARD_ENABLED;label.font_size = 48;label.pixel_size = zoom * 0.0007;label.no_depth_test = true;world.add_child(label)
func rebuild() -> void :
	if world != null: stage.remove_child(world);world.free()
	world = load("res://scripts/world.gd").new();world.environment_profile=environment_profile;stage.add_child(world);world.build(Packs.normalized(area()));world.update_interior_walls(camera.position, focus, "overhead")
	load("res://scripts/environment_art.gd").configure_scene(stage.get_node("ArtEnvironment").environment,stage.get_node("WorldSun"),world.definition,environment_profile)
	for piece in world.get_children():
		if String(piece.name).begins_with("CaveCeiling"): piece.visible = false
	var b = area().bounds
	for line in [[Vector2(b[0], b[1]), Vector2(b[2] - b[0], 0.12)], [Vector2(b[0], b[3]), Vector2(b[2] - b[0], 0.12)], [Vector2(b[0], b[1]), Vector2(0.12, b[3] - b[1])], [Vector2(b[2], b[1]), Vector2(0.12, b[3] - b[1])]]: marker(line[0] + line[1] * 0.5, "", "#e3b75a", line[1])
	marker(Vector2(area().spawn[0], area().spawn[1]), "START", "#72df9e")
	for exit in area().exits:
		var r = exit.rect;marker(Vector2(r[0] + r[2] * 0.5, r[1] + r[3] * 0.5), exit.label + " > " + exit.target, "#6ba9ea", Vector2(r[2], r[3]))
	for patch in area().get("sculpted_terrain",[]): marker(Vector2(patch.at[0],patch.at[1]),patch.profile.to_upper()+" %.2fm" % patch.height,"#c4ae78",Vector2(.4,.4),patch.height)
	for mob in area().catalog_enemies: marker(Vector2(mob.at[0], mob.at[1]), mob.code + (" TREE DROP" if mob.get("spawn_mode", "ground") == "tree_drop" else " CREATURE"), "#e78181")
	if not selected.is_empty(): marker(object_at(selected), "", "#f5d986", Vector2(0.4, 0.4))
	position_camera()
func ground_point(pixel: Vector2) -> Vector2:
	var origin = camera.project_ray_origin(pixel); var ray = camera.project_ray_normal(pixel); var hit = origin + ray * ( - origin.y / ray.y)
	var query=PhysicsRayQueryParameters3D.create(origin,origin+ray*500,8)
	for attempt in range(12):
		var contact=stage.get_world_3d().direct_space_state.intersect_ray(query)
		if contact.is_empty(): break
		if contact.collider.has_meta("terrain_surface"):
			return Vector2(snappedf(contact.position.x,snap),snappedf(contact.position.z,snap))
		query.exclude=query.exclude+[contact.rid]

	for iteration in range(8): hit = origin + ray * ((world.ground_height(hit) - origin.y) / ray.y)
	return Vector2(snappedf(hit.x, snap), snappedf(hit.z, snap))
func object_at(item: Dictionary) -> Vector2:
	if item.has("at"): return Vector2(item.at[0], item.at[1])
	var r = item.rect;return Vector2(r[0] + r[2] * 0.5, r[1] + r[3] * 0.5)
func place(data: Dictionary, at: Vector2) -> void :
	if data.tool=="terrain": terrain_profile=data.profile; create_terrain_patch(at); set_mode(0); return
	if not Packs.bounds_rect(area()).has_point(at): status.text = "Drop inside the gold boundary.";return
	checkpoint();count += 1; var tool = data.tool; var id = "piece_" + str(Time.get_ticks_usec()) + "_" + str(count)
	if tool == "spawn": area().spawn = [at.x, at.y]; selected={"kind":"Start","at":area().spawn}; selected_kind="spawn"
	elif tool == "prop":
		selected = {"id": id, "kind": "catalog_feature", "catalog_code": data.code, "at": [at.x, at.y], "rotation": 0, "scale": 1};area().props.append(selected);selected_kind = "props"
	elif tool == "mob":
		selected = {"id": id, "code": data.code, "at": [at.x, at.y]};area().catalog_enemies.append(selected);selected_kind = "catalog_enemies"
	elif tool == "transition":
		var target = pack.maps[(area_index + 1) % pack.maps.size()];selected = {"id": id, "rect": [at.x - 1, at.y - 1, 2, 2], "target": target.id, "spawn": target.spawn.duplicate(), "label": "Travel to " + target.display_name, "interact": true};area().exits.append(selected);selected_kind = "exits"
	else:
		selected = {"rect": [at.x - 1, at.y - 1, 2, 2], "kind": tool};area().terrain_regions.append(selected);selected_kind = "terrain_regions"
	show_selection(); rebuild();inspect();status.text = "Placed " + tool + ". Drag to move; use edge handles to resize. Shift places another."
	if not Input.is_key_pressed(KEY_SHIFT): set_mode(0)
func canvas_input(event: InputEvent) -> void :
	if event is InputEventMouseMotion: hover_pixel=event.position; hover_active=true
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: zoom = maxf(8, zoom * 0.9);position_camera()
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: zoom = minf(150, zoom * 1.1);position_camera()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed and resizing:
				resizing=false; geometry_dirty=false; rebuild(); inspect(); dragging=false; return
			if not event.pressed and creating_terrain:
				finish_terrain_creation(); dragging=false; return
			dragging = event.pressed;drag_saved = false
			if event.pressed:
				canvas.grab_focus()
				if edit_mode==0:
					var index=transform_handle_at(event.position)
					if index>=0:
						resizing=true; resize_index=index; resize_original=selected.duplicate(true); drag_plane_y=transform_height(); checkpoint(); dragging=false; return
				if edit_mode==1 and active_piece.get("tool","")=="terrain":
					creation_y=world.ground_height(Vector3(ground_point(event.position).x,0,ground_point(event.position).y)); creation_from=plane_point(event.position,creation_y); creation_to=creation_from; creating_terrain=true; dragging=false; return
				var handle=pick_handle(event.position) if edit_mode not in [1,4,5] else {}
				if not handle.is_empty(): set_mode(0)
				if edit_mode==1 and active_piece.is_empty(): status.text="Choose a piece on the left first."; dragging=false; return
				if edit_mode==1 and not active_piece.is_empty(): place(active_piece,ground_point(event.position)); dragging=false; return
				if edit_mode==5: create_terrain_patch(ground_point(event.position)); dragging=false; return
				if edit_mode==4: insert_fragment(ground_point(event.position)); dragging=false; return
				if edit_mode==2: hover_pixel=event.position; sculpt_hover((-1 if event.ctrl_pressed else 1)*(1.0 if event.shift_pressed else .25)); dragging=false; return
				if edit_mode==3 and selected_kind=="sculpted_terrain" and not selected.is_empty(): extend_plateau(ground_point(event.position)); dragging=false; return
				var at = ground_point(event.position); var distance = 2.5;selected = {}
				for key in ["sculpted_terrain", "terrain_regions", "exits", "catalog_enemies", "props"]:
					for item in area().get(key,[]):
						var d = at.distance_to(object_at(item))
						if d < distance: distance = d;selected = item;selected_kind = key
				for patch in area().get("sculpted_terrain",[]):
					if Sculpt.contains(patch,at) and (selected.is_empty() or distance>.8): selected=patch; selected_kind="sculpted_terrain"
				show_selection()
				if at.distance_to(Vector2(area().spawn[0],area().spawn[1]))<.9:
					selected={"kind":"Start","at":area().spawn}; selected_kind="spawn"
				if not handle.is_empty(): selected=handle.item; selected_kind=handle.kind
				if not selected.is_empty():
					var anchor=object_at(selected); drag_plane_y=world.ground_height(Vector3(anchor.x,selected.get("height",0),anchor.y))
					drag_offset=anchor-plane_point(event.position,drag_plane_y)
				rebuild();inspect()
			elif not selected.is_empty(): rebuild();inspect()
	if event is InputEventMouseMotion:
		if resizing:
			var candidate=Geometry.bounded_resize(resize_original,selected_kind,resize_index,plane_point(event.position,drag_plane_y),Packs.bounds_rect(area()),snap)
			selected.merge(candidate,true); geometry_dirty=true; status.text="Drag edge to resize. It snaps at the boundary; opposite edge stays fixed."; return
		if creating_terrain: creation_to=plane_point(event.position,creation_y); return
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			orbit_yaw-=event.relative.x*.008; orbit_pitch=clampf(orbit_pitch+event.relative.y*.008,.18,1.55); position_camera()
		elif event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			focus += Vector3( - event.relative.x, 0, - event.relative.y) * zoom / maxf(canvas.size.y, 1);position_camera()
		elif dragging and not selected.is_empty():
			if not drag_saved: checkpoint();drag_saved = true
			var raw=plane_point(event.position,drag_plane_y)+drag_offset
			var at=Vector2(snappedf(raw.x,snap),snappedf(raw.y,snap))
			var candidate=Geometry.moved(selected,selected_kind,at,Packs.bounds_rect(area()))
			selected.merge(candidate,true)
			if selected_kind=="spawn": area().spawn=selected.at
			geometry_dirty=true
func heading(text: String) -> void :
	var l = Label.new();l.text = text;l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;l.custom_minimum_size.x = 260;inspector.add_child(l)
func text_field(label: String, value: String, action: Callable) -> void :
	heading(label); var edit = LineEdit.new();edit.text = value;inspector.add_child(edit);edit.text_submitted.connect( func(text): edit.release_focus(); checkpoint();action.call(text);refresh_areas();rebuild();inspect())
func number(label: String, value: float, action: Callable, minimum: float = -100, maximum: float = 100, step: float = 0.1) -> void :
	var row = HBoxContainer.new();inspector.add_child(row); var l = Label.new();l.text = label;l.size_flags_horizontal = SIZE_EXPAND_FILL;row.add_child(l)
	var n = SpinBox.new();n.min_value = minimum;n.max_value = maximum;n.step = step;n.value = value;n.custom_minimum_size.x = 120;row.add_child(n);n.value_changed.connect( func(v): checkpoint();action.call(v);rebuild())
func select_start() -> void:
	selected={"kind":"Start","at":area().spawn}; selected_kind="spawn"; set_mode(0); show_selection(); rebuild(); inspect()
func inspect() -> void :
	for child in inspector.get_children(): inspector.remove_child(child);child.queue_free()
	if inspector_section==0 and selected_kind=="spawn" and not selected.is_empty():
		heading("SELECTED START")
		heading("Drag the green START marker to move it, or enter its coordinates below.")
		for i in range(2): number(["Start X","Start Z"][i],area().spawn[i],func(v): area().spawn[i]=v; selected.at=area().spawn,area().bounds[i]+.5,area().bounds[i+2]-.5,.5)
		button(inspector,"Use this area as starting area",func(): checkpoint(); pack.start_map=area().id; inspect())
		heading("Save the world to keep this position. Validate checks that the start is clear of water, scenery and cliff edges.")
		return
	if inspector_section==2:
		heading("WORLD SETTINGS")
		text_field("World name",pack.name,func(v): pack.name=v)
		text_field("World ID",pack.id,func(v): pack.id=v)
		heading("Starting area")
		var start_area=OptionButton.new(); inspector.add_child(start_area)
		for i in range(pack.maps.size()):
			start_area.add_item(pack.maps[i].display_name)
			if pack.maps[i].id==pack.start_map: start_area.select(i)
		start_area.item_selected.connect(func(i): checkpoint(); pack.start_map=pack.maps[i].id)
		button(inspector,"Check map",validate_world); button(inspector,"Install locally",install_world)
		return
	if inspector_section==3:
		heading("OBJECTS IN THIS AREA")
		heading("Select any entry to edit it, including overlapping pieces.")
		var entries=[{"kind":"spawn","item":{"kind":"Start","at":area().spawn},"label":"START"}]
		var labels={"sculpted_terrain":"Terrain","props":"Scenery","catalog_enemies":"Creature","exits":"Transition","terrain_regions":"Paint"}
		for kind in labels:
			var n=0
			for item in area().get(kind,[]):
				n+=1; entries.append({"kind":kind,"item":item,"label":labels[kind]+" "+str(n)+" - "+str(item.get("label",item.get("profile",item.get("catalog_code",item.get("code",item.get("kind",""))))))})
		for entry in entries:
			button(inspector,entry.label,func(): select_object(entry.kind,entry.item))
		return
	if inspector_section==1:
		heading("AREA SETTINGS")
		text_field("Area name", area().display_name, func(v): area().display_name = v)
		heading("Area ID: " + area().id)
		if not area().get("cave", false):
			for i in range(4):
				var minimum = area().bounds[i - 2] + 12 if i >= 2 else -100
				var maximum = area().bounds[i + 2] - 12 if i < 2 else 100
				number(["West X", "North Z", "East X", "South Z"][i], area().bounds[i], func(v):
					var b = area().bounds.duplicate();b[i] = int(v);area().bounds = b;call_deferred("inspect"), minimum, maximum, 1)
		else: heading("Cave template: fixed chamber boundaries")
		for i in range(2): number(["Start X", "Start Z"][i], area().spawn[i], func(v): area().spawn[i] = v)
		var sea = CheckBox.new();sea.text = "Animated water for water paint";sea.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;sea.button_pressed = area().sea;inspector.add_child(sea);sea.toggled.connect( func(v): checkpoint();area().sea = v;rebuild())
		var jungle = CheckBox.new();jungle.text = "Jungle ground palette";jungle.button_pressed = area().get("biome", "woodland") == "jungle";inspector.add_child(jungle);jungle.toggled.connect( func(v): checkpoint();area().biome = "jungle" if v else "woodland";rebuild())
		button(inspector,"Remove this area",remove_area)
		return
	if selected.is_empty() and edit_mode==1 and not active_piece.is_empty():
		heading("READY TO PLACE "+active_piece.get("code",active_piece.tool).to_upper())
		heading("Click to place this piece, or drag a rectangle for terrain. Placement returns to Select; hold Shift to repeat. Escape cancels.")
		return
	if selected.is_empty():
		heading("NOTHING SELECTED")
		heading("Click an object or START to edit it. Click a piece on the left, then click the map to place it.")
		button(inspector,"Select START",select_start); button(inspector,"Area settings",func(): inspector_tabs.current_tab=1)
		return
	heading("SELECTED " + selected.get("catalog_code", selected.get("code", selected.get("kind", selected.get("profile","Transition").capitalize()))))
	if selected.has("at"):
		for i in range(2): number(["X", "Z"][i], selected.at[i], func(v): selected.at[i] = v)
		if selected_kind == "props":
			number("Rotation", selected.get("rotation", 0), func(v): selected.rotation = v, -360, 360, 5)
			number("Scale", selected.get("scale", 1), func(v): selected.scale = v, 0.1, 4, 0.1)
			if selected.get("catalog_code","") in ["3F","4F"]:
				button(inspector,"Convert to editable flat-top bluff",convert_bluff)
				heading("Replace the fixed template with a plateau and ramp you can extend.")
	elif selected_kind=="exits":
		heading("Travel zone - drag its blue label or any part of the blue rectangle.")
		var centre=object_at(selected)
		number("Centre X",centre.x,func(v): set_transition_rect(0,v))
		number("Centre Z",centre.y,func(v): set_transition_rect(1,v))
		number("Zone width",selected.rect[2],func(v): set_transition_rect(2,v),.1,Packs.bounds_rect(area()).size.x,.1)
		number("Zone depth",selected.rect[3],func(v): set_transition_rect(3,v),.1,Packs.bounds_rect(area()).size.y,.1)
		heading("Drag the yellow side or corner handles to resize this zone.")
	else:
		for i in range(4): number(["West X", "North Z", "Width", "Depth"][i], selected.rect[i], func(v): selected.rect[i] = v, 0.1 if i >= 2 else -100, 200 if i>=2 else 100, 0.1)
	if selected_kind=="sculpted_terrain":
		terrain_profile=selected.profile; profile_menu.select(["smooth","bluff","overhang"].find(terrain_profile))
		number("Height",selected.height,func(v): selected.height=v,2.6 if selected.profile=="overhang" else -6,10,.05 if selected.profile=="overhang" else .25)
		number("Radius" if selected.profile=="smooth" else "Ramp length",selected.radius,func(v): selected.radius=v,1,8,.5)
		if selected.profile!="smooth":
			number("Plateau width",selected.get("plateau_width",selected.radius*2),func(v): set_plateau_dimension("plateau_width",v),1,Packs.bounds_rect(area()).size.length(),.5)
			number("Plateau depth",selected.get("plateau_depth",selected.radius),func(v): set_plateau_dimension("plateau_depth",v),1,Packs.bounds_rect(area()).size.length(),.5)
			heading("Drag yellow edges/corners to grow or shrink. Blue front edge is the walk-up. Boundaries snap automatically.")
		number("Walk-up rotation",selected.get("rotation",0),func(v): selected.rotation=v,-360,360,15)
		var shape=OptionButton.new(); shape.add_item("Smooth slope / hollow"); shape.add_item("Bluff + walk-up"); shape.add_item("Overhang + walk-up"); shape.select(["smooth","bluff","overhang"].find(selected.profile)); inspector.add_child(shape)
		shape.item_selected.connect(func(i):
			checkpoint(); selected.profile=["smooth","bluff","overhang"][i]
			if i==2: selected.height=maxf(2.6,selected.height)
			rebuild(); inspect())
		heading("Rotate the walk-up side toward a path. Overhangs have a solid underside; tall ledges allow passage below.")
	if selected_kind == "catalog_enemies":
		var repeat=CheckBox.new(); repeat.text="Timed respawn (invisible in game)"; repeat.button_pressed=selected.get("respawn_seconds",0)>0; repeat.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; inspector.add_child(repeat)
		repeat.toggled.connect(func(enabled): checkpoint(); selected.respawn_seconds=10 if enabled else 0; rebuild(); inspect())
		if repeat.button_pressed:
			number("Seconds after death",selected.respawn_seconds,func(v): selected.respawn_seconds=v,1,3600,1)
			heading("Countdown begins on death; menus pause it. Saves and area travel preserve remaining time.")
		var entry = Packs.catalog().monsters.filter( func(mob): return mob.code == selected.code)[0]
		if entry.style in ["green_slime", "moss_slime", "resin_slime", "bramble_slime"]:
			heading("Slime arrival")
			var mode = OptionButton.new();mode.add_item("On the ground");mode.add_item("Drop from a tree onto player");mode.select(1 if selected.get("spawn_mode", "ground") == "tree_drop" else 0);inspector.add_child(mode)
			mode.item_selected.connect( func(i): checkpoint();selected.spawn_mode = "tree_drop" if i == 1 else "ground";rebuild();inspect())
			if selected.get("spawn_mode", "ground") == "tree_drop":
				number("Perch height", selected.get("drop_height", 3.8), func(v): selected.drop_height = v, 2, 8, 0.1)
				number("Trigger range", selected.get("trigger_radius", 6), func(v): selected.trigger_radius = v, 2, 12, 0.1)
				text_field("Ambush group (optional)", selected.get("ambush_group", ""), func(v): selected.ambush_group = v)
				heading("Place beside a canopy tree. Landing locks onto the player when triggered; the ring warns before descent.")
	if selected_kind == "exits":
		text_field("Gate label", selected.label, func(v): selected.label = v)
		heading("Destination area"); var target = OptionButton.new();inspector.add_child(target)
		for i in range(pack.maps.size()):
			target.add_item(pack.maps[i].display_name)
			if pack.maps[i].id == selected.target: target.select(i)
		target.item_selected.connect( func(i): checkpoint();selected.target = pack.maps[i].id;selected.spawn = pack.maps[i].spawn.duplicate();rebuild();inspect())
		for i in range(2): number(["Landing X", "Landing Z"][i], selected.spawn[i], func(v): selected.spawn[i] = v)
		var interact = CheckBox.new();interact.text = "Press E to travel (otherwise automatic)";interact.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;interact.button_pressed = selected.get("interact", false);inspector.add_child(interact);interact.toggled.connect( func(v): checkpoint();selected.interact = v)
		button(inspector, "Add return gate at destination", return_gate)
	button(inspector,"Delete selection",delete_selected)
func return_gate() -> void :
	checkpoint()
	for target in pack.maps:
		if target.id == selected.target:
			var p = selected.spawn;target.exits.append({"id": "return_" + str(Time.get_ticks_usec()), "rect": [p[0] - 1, p[1] + 2, 2, 2], "target": area().id, "spawn": area().spawn.duplicate(), "label": "Return to " + area().display_name, "interact": true});status.text = "Return gate added 3m south of the landing. Validate its placement."
func delete_selected() -> void :
	if selected_kind=="spawn": status.text="An area needs its START point. Drag it to move it."; return
	if selected.is_empty(): return
	checkpoint();area()[selected_kind].erase(selected);selected = {};rebuild();inspect()
func _input(event:InputEvent) -> void:
	if (file_dialog!=null and file_dialog.visible) or (help_dialog!=null and help_dialog.visible) or (fragment_dialog!=null and fragment_dialog.visible): return
	if event is InputEventKey and event.pressed and event.keycode in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT] and hover_active:
		if get_viewport().gui_get_focus_owner() is LineEdit: return
		set_mode(2)
		if event.keycode in [KEY_UP,KEY_DOWN]: sculpt_hover((1 if event.keycode==KEY_UP else -1)*(1.0 if event.shift_pressed else .25))
		elif not event.echo:
			profile_menu.select(posmod(profile_menu.selected+(1 if event.keycode==KEY_RIGHT else -1),3)); terrain_profile=["smooth","bluff","overhang"][profile_menu.selected]; apply_hover_profile()
		get_viewport().set_input_as_handled(); return
func _unhandled_key_input(event: InputEvent) -> void :
	if not event is InputEventKey or not event.pressed or event.echo: return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	if event.keycode == KEY_ESCAPE: set_mode(0); return
	if event.keycode == KEY_DELETE: delete_selected()
	if event.ctrl_pressed and event.keycode == KEY_Z: undo()
	if event.ctrl_pressed and event.keycode == KEY_Y: redo()
	if event.ctrl_pressed and event.keycode == KEY_S: save_document()
func validate_world() -> bool:
	var errors = Packs.validate(pack);status.text = "VALID: all areas, boundaries, spawn points and transitions checked." if errors.is_empty() else "FIX BEFORE INSTALL: " + " / ".join(errors.slice(0,3))+(" (and %d more)" % (errors.size()-3) if errors.size()>3 else "");return errors.is_empty()
func install_world() -> bool:
	if not validate_world(): return false
	var result = Packs.install(pack);status.text = "Installed " + pack.name + ". Open the game > Play Custom World." if result == OK else "Install failed: " + error_string(result);return result == OK
func play_world() -> void :
	if not install_world(): return
	var executable = OS.get_executable_path()
	if executable.get_file().to_lower() == "mapbuilder.exe": executable = executable.get_base_dir().path_join("CoastalFoundation.exe")
	var args = PackedStringArray(["--", "--play-world", pack.id])
	if executable.get_file().to_lower() not in ["mapbuilder.exe", "coastalfoundation.exe"]: args = PackedStringArray(["--path", ProjectSettings.globalize_path("res://"), "--", "--play-world", pack.id])
	OS.create_process(executable, args)
func choose_file(action: String) -> void :
	if action == "open" and dirty:
		confirm("Discard unsaved changes and open another world?", func(): dirty = false;choose_file("open"));return
	if action == "export" and not validate_world(): return
	if action == "save":
		var errors = Packs.validate(pack, true)
		if not errors.is_empty(): status.text = "Fix required fields before saving: " + " / ".join(errors.slice(0,3))+(" (and %d more)" % (errors.size()-3) if errors.size()>3 else "");return
	file_action = action;file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if action == "open" else FileDialog.FILE_MODE_SAVE_FILE;file_dialog.current_file = pack.id + ".coastworld.json";file_dialog.popup_centered_ratio(0.75)
func file_selected(filename: String) -> void :
	if file_action == "open":
		if FileAccess.get_file_as_bytes(filename).size() > Packs.MAX_BYTES: status.text = "World file is too large.";return
		var data = JSON.parse_string(FileAccess.get_file_as_string(filename))
		if not data is Dictionary or data.get("format") != "coastal_world" or not data.get("maps") is Array or data.maps.is_empty(): status.text = "Not a Coastal world file.";return
		var errors = Packs.validate(data, true)
		if not errors.is_empty(): status.text = "Cannot open malformed world: " + " / ".join(errors.slice(0,3))+(" (and %d more)" % (errors.size()-3) if errors.size()>3 else "");return
		fragment_path=""
		pack = data;area_index = 0;selected = {};undo_stack.clear();redo_stack.clear();path = filename;dirty = false;refresh_areas();rebuild();inspect();fit_camera()
	else:
		if not filename.ends_with(".coastworld.json"): filename += ".coastworld.json"
		var result = Packs.write_file(filename, pack)
		if result == OK: fragment_path=""; path = filename;dirty = false;status.text = "Saved " + filename
		else: status.text = "Save failed: " + error_string(result)
func run_checks() -> void :
	get_window().size = Vector2i(1366, 768); await get_tree().process_frame; await get_tree().process_frame
	var errors = []
	await direct_transform_checks(errors)
	if pack.maps.size()!=1 or not Packs.validate(pack).is_empty(): errors.append("Blank outdoor world must work without a cave")
	pack=Document.example(); refresh_areas(); rebuild(); inspect(); fit_camera()
	fragment_checks(errors)
	show_fragments(); await get_tree().process_frame; await get_tree().process_frame
	if fragment_dialog.size.x>get_window().size.x or fragment_dialog.size.y>get_window().size.y: errors.append("Fragment library must fit the desktop window: "+str(fragment_dialog.size))
	fragment_dialog.hide()
	var original = pack.duplicate(true)
	if canvas.size.y < 300 or canvas.size.x < 400 or inspector.size.x > 320: errors.append("Editor panels do not fit the desktop window")
	if not Packs.validate(pack).is_empty(): errors.append("Example invalid: " + str(Packs.validate(pack)))
	var card=find_palette_card(self,"1A")
	var from=card.get_global_rect().get_center()
	var target=canvas.global_position+camera.unproject_position(Vector3(10,0,4))
	var move=InputEventMouseMotion.new(); move.position=from; move.global_position=move.position; Input.parse_input_event(move)
	var click=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true; click.position=from; click.global_position=click.position; Input.parse_input_event(click)
	move=InputEventMouseMotion.new(); move.position=from+Vector2(20,0); move.relative=Vector2(20,0); move.button_mask=MOUSE_BUTTON_MASK_LEFT; move.global_position=move.position; Input.parse_input_event(move)
	await get_tree().process_frame
	if not get_viewport().gui_is_dragging(): errors.append("Real palette mouse drag did not start")
	move=InputEventMouseMotion.new(); move.position=target; move.relative=target-from; move.button_mask=MOUSE_BUTTON_MASK_LEFT; move.global_position=move.position; Input.parse_input_event(move)
	await get_tree().process_frame
	click=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.position=target; click.pressed=false; click.global_position=click.position; Input.parse_input_event(click)
	await get_tree().process_frame
	if area().props.size()!=4: errors.append("Real palette mouse drop did not place a piece")
	pack=original.duplicate(true); selected={}; undo_stack.clear(); redo_stack.clear(); rebuild(); inspect()
	var data = {"tool": "prop", "code": "1A"}; var pixel = camera.unproject_position(Vector3(10, 0, 4))
	if not canvas._can_drop_data(pixel, data): errors.append("Palette drop rejected")
	canvas._drop_data(pixel, data)
	if area().props.size() != 4 or Vector2(selected.at[0], selected.at[1]).distance_to(Vector2(10, 4)) > 0.1: errors.append("Drop failed to place at the projected ground")
	var press = InputEventMouseButton.new();press.button_index = MOUSE_BUTTON_LEFT;press.pressed = true;press.position = pixel;canvas_input(press)
	var motion = InputEventMouseMotion.new();motion.position = camera.unproject_position(Vector3(12, 0, 6));motion.button_mask = MOUSE_BUTTON_MASK_LEFT;canvas_input(motion)
	if selected.is_empty() or selected.at != [12.0, 6.0]: errors.append("Dragging placed scenery did not move it")
	dragging = false;undo()
	if area().props[-1].at != [10.0, 4.0]: errors.append("Move undo failed")
	undo(); if area().props.size() != 3: errors.append("Drop undo failed")
	redo(); if area().props.size() != 4: errors.append("Redo failed")
	pack = original;selected = {}
	rebuild(); inspect()
	var terrain_mouse=InputEventMouseMotion.new(); terrain_mouse.position=canvas.global_position+camera.unproject_position(Vector3(0,0,-5)); terrain_mouse.global_position=terrain_mouse.position; Input.parse_input_event(terrain_mouse)
	await get_tree().process_frame
	var arrow=InputEventKey.new(); arrow.keycode=KEY_UP; arrow.pressed=true; Input.parse_input_event(arrow)
	await get_tree().process_frame
	if area().get("sculpted_terrain",[]).size()!=1 or selected.height!=.25: errors.append("Hover + Up failed to sculpt terrain")
	arrow=InputEventKey.new(); arrow.keycode=KEY_DOWN; arrow.pressed=true; Input.parse_input_event(arrow)
	await get_tree().process_frame
	if selected.height!=0: errors.append("Hover + Down failed to lower terrain")
	arrow=InputEventKey.new(); arrow.keycode=KEY_RIGHT; arrow.pressed=true; Input.parse_input_event(arrow)
	await get_tree().process_frame
	if selected.profile!="bluff": errors.append("Right arrow failed to change terrain profile")
	arrow=InputEventKey.new(); arrow.keycode=KEY_RIGHT; arrow.pressed=true; Input.parse_input_event(arrow)
	await get_tree().process_frame
	if selected.profile!="overhang" or selected.height<2.6: errors.append("Overhang profile failed to preserve underside clearance")
	if not Packs.validate(pack).is_empty(): errors.append("Sculpted draft does not validate")
	await get_tree().physics_frame; await get_tree().physics_frame
	var top=Vector3(selected.at[0],selected.height,selected.at[1]-selected.radius*.75)
	var picked=ground_point(camera.unproject_position(top))
	if picked.distance_to(Vector2(top.x,top.z))>.4: errors.append("Hover did not pick the visible overhang roof")
	undo(); if area().sculpted_terrain[0].profile!="bluff": errors.append("Terrain profile undo failed")
	pack=original.duplicate(true); selected={}; undo_stack.clear(); redo_stack.clear(); rebuild(); inspect()
	set_mode(0)
	# New placement and plateau workflows use the same input route as native clicks.
	card.pressed.emit()
	if edit_mode!=1 or active_piece.get("code","")!="1A": errors.append("Palette click did not enter placement mode")
	var click_place=InputEventMouseButton.new(); click_place.button_index=MOUSE_BUTTON_LEFT; click_place.pressed=true; click_place.position=camera.unproject_position(Vector3(10,0,4)); canvas_input(click_place)
	if area().props.size()!=original.maps[0].props.size()+1: errors.append("Click-to-place failed")
	set_mode(0); pack=original.duplicate(true); selected={}; rebuild(); inspect()
	var plateau={"id":"plateau_check","at":[0,-5],"height":3,"radius":4,"profile":"bluff","rotation":0}
	area().sculpted_terrain=[plateau]; selected=plateau; selected_kind="sculpted_terrain"; rebuild(); inspect(); set_mode(3)
	var extend_click=InputEventMouseButton.new(); extend_click.button_index=MOUSE_BUTTON_LEFT; extend_click.pressed=true; extend_click.position=camera.unproject_position(Vector3(7,0,-7)); canvas_input(extend_click)
	if not Sculpt.contains(selected,Vector2(7,-7)) or selected.radius!=4 or selected.height!=3: errors.append("Map-click plateau extension changed its ramp/height or missed the clicked point")
	extend_plateau(Vector2(0,-12))
	if selected.plateau_depth<=4 or not Packs.validate(pack).is_empty(): errors.append("Plateau depth extension failed validation")
	var depth=selected.plateau_depth; undo()
	if area().sculpted_terrain[0].get("plateau_depth",4)>=depth: errors.append("Plateau extension undo failed")
	redo(); if area().sculpted_terrain[0].plateau_depth!=depth: errors.append("Plateau extension redo failed")
	pack=original.duplicate(true); selected={}; set_mode(0); rebuild(); inspect()
	var template={"id":"convert_check","kind":"catalog_feature","catalog_code":"3F","at":[0,-4],"rotation":0,"scale":1}; area().props.append(template); selected=template; selected_kind="props"; convert_bluff()
	if selected_kind!="sculpted_terrain" or selected.plateau_width!=7 or area().props.has(template): errors.append("Catalog bluff cannot convert to an editable plateau")
	pack=original.duplicate(true); selected={}; selected_kind=""; rebuild(); inspect()
	for tab in [1,2,0]:
		inspector_tabs.current_tab=tab; await get_tree().process_frame
		if inspector_section!=tab or inspector.get_child_count()==0: errors.append("Inspector tab failed to show its settings")
	get_window().size=Vector2i(960,640); await get_tree().process_frame; await get_tree().process_frame
	if canvas.size.x<300 or canvas.size.y<240 or not Rect2(Vector2.ZERO,Vector2(960,640)).encloses(inspector_tabs.get_global_rect()): errors.append("Builder layout does not fit a smaller desktop window")
	get_window().size=Vector2i(1366,768); await get_tree().process_frame; await get_tree().process_frame
	terrain_creation_checks(errors)
	await transition_checks(errors)
	await handle_drag_checks(errors)
	var old_start=area().spawn.duplicate()
	var start_press=InputEventMouseButton.new(); start_press.button_index=MOUSE_BUTTON_LEFT; start_press.pressed=true; start_press.position=camera.unproject_position(Vector3(old_start[0],0,old_start[1])); canvas_input(start_press)
	if selected_kind!="spawn": errors.append("Green START marker cannot be selected")
	var start_motion=InputEventMouseMotion.new(); start_motion.position=camera.unproject_position(Vector3(2,0,8)); start_motion.button_mask=MOUSE_BUTTON_MASK_LEFT; canvas_input(start_motion)
	if area().spawn!=[2.0,8.0]: errors.append("Dragging START failed to move the actual spawn")
	dragging=false; undo()
	if area().spawn!=old_start: errors.append("START drag undo failed")
	redo(); if area().spawn!=[2.0,8.0]: errors.append("START drag redo failed")
	select_start(); delete_selected()
	if area().spawn!=[2.0,8.0]: errors.append("START deletion was not protected")
	place({"tool":"spawn"},Vector2(3,8))
	if area().spawn!=[3.0,8.0] or selected_kind!="spawn": errors.append("Move START palette placement failed")
	pack=original.duplicate(true); selected={}; selected_kind=""; rebuild(); inspect()
	help_dialog.popup_centered(Vector2i(640,430)); await get_tree().process_frame; await get_tree().process_frame
	if help_dialog.size.x>1366 or help_dialog.size.y>768: errors.append("Help dialog does not fit the desktop window")
	help_dialog.hide()
	var bad = pack.duplicate(true);bad.maps[0].exits[0].target = "missing"
	if Packs.validate(bad).is_empty(): errors.append("Dangling transition accepted")
	bad = pack.duplicate(true);bad.maps[0].spawn = [5, 0]
	if Packs.validate(bad).is_empty(): errors.append("Blocked spawn accepted")
	var draft_path = "user://builder-check-draft.coastworld.json";file_action = "save";file_selected(draft_path)
	var expected = pack.duplicate(true);pack.name = "Changed";file_action = "open";file_selected(draft_path)
	if pack.name != expected.name or pack.id != expected.id or pack.maps.size() != expected.maps.size() or not Packs.validate(pack).is_empty(): errors.append("Draft save/open failed")
	bad = pack.duplicate(true);bad.maps.append(Document.area("unfinished"))
	if not Packs.validate(bad, true).is_empty() or Packs.validate(bad).is_empty(): errors.append("Incomplete drafts cannot be reopened safely")
	Packs.directory = "user://builder-test-worlds"; var result = Packs.install(pack)
	if result != OK or Packs.installed(pack.id).is_empty(): errors.append("Install/read failed")
	var runtime = Packs.definition(Packs.runtime_id(pack.id, "meadow"), pack.id)
	if runtime.is_empty() or runtime.exits[0].target != Packs.runtime_id(pack.id, "cave"): errors.append("Runtime transition conversion failed")
	DirAccess.remove_absolute(Packs.file_path(pack.id));DirAccess.remove_absolute(Packs.directory);DirAccess.remove_absolute(draft_path)
	print("MAP_BUILDER_CHECKS: ", "PASS" if errors.is_empty() else str(errors));get_tree().quit(0 if errors.is_empty() else 1)
func capture(directory: String) -> void :
	var review_args=OS.get_cmdline_user_args()
	if "--review-draft" in review_args: await capture_review(directory,review_args[review_args.find("--review-draft")+1]); get_tree().quit(); return
	reset_document(); await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("map-builder-blank.png"))
	var old_library=Fragments.directory; Fragments.directory="user://fragment-capture-private"
	var template=Document.area(); template.display_name="Forest bluff and ambush"; template.bounds=[-60,-60,60,60]
	template.sculpted_terrain=[{"id":"long_bluff","at":[0,0],"height":3,"radius":4,"profile":"bluff","plateau_width":80,"plateau_depth":50}]
	template.props=[{"id":"tree","kind":"catalog_feature","catalog_code":"1A","at":[8,8]}]
	var saved=Fragments.save(Fragments.create(template,"Forest bluff and ambush"))
	show_fragments(); fragment_list.select(0); fragment_list.item_selected.emit(0)
	await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("map-builder-fragments.png"))
	fragment_dialog.hide()
	if saved.has("path"): DirAccess.remove_absolute(saved.path)
	Fragments.directory=old_library
	pack=Document.blank(); pack.maps[0]=template; selected=template.sculpted_terrain[0]; selected_kind="sculpted_terrain"; refresh_areas(); show_selection(); rebuild(); inspect(); orbit_pitch=.7; fit_camera()
	await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("map-builder-long-plateau.png"))
	pack=Document.example(); area_index=0; refresh_areas(); rebuild(); inspect(); fit_camera()
	await get_tree().process_frame; await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("map-builder.png"))
	help_dialog.popup_centered(Vector2i(640,430)); await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("map-builder-help.png")); help_dialog.hide()
	select_start(); await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("map-builder-start.png"))
	inspector_tabs.current_tab=1; await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("map-builder-area.png"))
	inspector_tabs.current_tab=2; await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("map-builder-world.png")); inspector_tabs.current_tab=0
	selected = area().exits[0];selected_kind = "exits";set_transition_rect(0,13);set_transition_rect(2,8);set_transition_rect(3,3);inspect();rebuild()
	await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("map-builder-links.png"))
	area_index = 1;selected = {};refresh_areas();rebuild();inspect();fit_camera()
	await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("map-builder-cave.png"))
	area_index = 0;selected = {};refresh_areas()
	area().props.append({"id": "canopy_demo", "kind": "catalog_feature", "catalog_code": "5A", "at": [9, 4], "rotation": 0, "scale": 1})
	selected = {"id": "tree_slime_demo", "code": "9E", "at": [9, 3], "spawn_mode": "tree_drop", "drop_height": 3.8, "trigger_radius": 6, "ambush_group": "canopy", "respawn_seconds": 10};area().catalog_enemies.append(selected);selected_kind = "catalog_enemies"
	rebuild();inspect();fit_camera()
	await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("map-builder-tree-drop.png"))
	area().sculpted_terrain=[{"id":"smooth_demo","at":[-10,0],"height":2,"radius":4,"profile":"smooth","rotation":0},{"id":"bluff_demo","at":[0,0],"height":3,"radius":4,"profile":"bluff","rotation":0,"plateau_width":12,"plateau_depth":8},{"id":"overhang_demo","at":[10,0],"height":3,"radius":4,"profile":"overhang","rotation":0,"plateau_width":8,"plateau_depth":8}]
	selected=area().sculpted_terrain[2]; selected_kind="sculpted_terrain"; show_selection(); rebuild(); inspect(); orbit_yaw=2.5; orbit_pitch=.45; fit_camera()
	await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("map-builder-terrain.png"))
	selected=area().sculpted_terrain[1]; selected_kind="sculpted_terrain"; inspect(); set_mode(0)
	await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("map-builder-plateau.png"))
	inspector_tabs.current_tab=3; await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("map-builder-objects.png")); inspector_tabs.current_tab=0
	for child in world.get_children():
		if child is Label3D: child.visible=false
	camera.position=Vector3(18,6,-12); camera.look_at(Vector3(10,1,0)); camera.size=16
	await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("map-builder-overhang.png")); get_tree().quit()

func find_palette_card(node:Node,code:String):
	if node is Button and "payload" in node and node.payload.get("code","")==code: return node
	for child in node.get_children():
		var result=find_palette_card(child,code)
		if result!=null: return result
	return null

func hovered_terrain() -> Dictionary:
	var at=ground_point(hover_pixel); var closest={}; var distance=INF
	for piece in area().get("sculpted_terrain",[]):
		var d=at.distance_to(Vector2(piece.at[0],piece.at[1]))
		if Sculpt.contains(piece,at) and d<distance: closest=piece; distance=d
	return closest
func apply_hover_profile() -> void:
	if not hover_active: return
	var piece=hovered_terrain()
	if piece.is_empty(): return
	checkpoint(); piece.profile=terrain_profile
	if terrain_profile=="overhang": piece.height=maxf(2.6,piece.height)
	selected=piece; selected_kind="sculpted_terrain"; show_selection(); rebuild(); inspect()
func sculpt_hover(change:float) -> void:
	if area().get("cave",false): status.text="Sculpt outdoor areas; cave floors keep their room collision."; return
	var at=ground_point(hover_pixel); var piece=hovered_terrain(); var fresh=piece.is_empty()
	if fresh:
		if area().get("sculpted_terrain",[]).size()>=64: status.text="Maximum 64 terrain patches per area."; return
		piece={"id":"terrain_"+str(Time.get_ticks_usec()),"at":[at.x,at.y],"height":0.0,"radius":brush_radius,"rotation":0,"profile":terrain_profile}
		if not Sculpt.fits(piece,Packs.bounds_rect(area())): status.text="Draw a terrain footprint from the palette to fit this edge, or sculpt an existing patch."; return
	checkpoint()
	if fresh:
		if not area().has("sculpted_terrain"): area().sculpted_terrain=[]
		area().sculpted_terrain.append(piece)
	piece.height=clampf(piece.height+change,2.6 if piece.profile=="overhang" else -6,10)
	selected=piece; selected_kind="sculpted_terrain"; show_selection(); rebuild(); inspect(); status.text="Terrain height %.2fm. Left/Right changes profile; Shift+Up/Down changes by 1m." % piece.height

func menu(parent:Node,title:String,actions:Array) -> void:
	var control=MenuButton.new(); control.text=title; parent.add_child(control)
	for entry in actions: control.get_popup().add_item(entry[0])
	control.get_popup().id_pressed.connect(func(i): actions[i][1].call())
func set_mode(mode:int) -> void:
	edit_mode=mode; mode_menu.select(mode if mode<=2 else 0)
	if mode==0:
		active_piece={}
		for card in palette_group.get_buttons(): card.button_pressed=false
	for control in brush_controls: control.visible=mode in [2,5]
	if context_hint!=null: context_hint.text=["Select: click / drag objects or START. Wheel zoom | Middle-drag pan | Right-drag orbit.","Place: click a palette piece, then click the map. Escape returns to selection.","Terrain: click raises / Ctrl+click lowers. Up/Down: height | Shift: larger steps | Left/Right: profile.","Select terrain: drag yellow edge/corner handles to resize in either direction; cyan edge marks the ramp.","Fragment: click to stamp its centre here. Escape cancels. Enlarge area boundaries if needed.","New terrain: click to create a separate patch. Choose profile/radius above. Existing patches stay unchanged."][mode]
func show_selection() -> void:
	inspector_section=0
	if inspector_tabs!=null: inspector_tabs.current_tab=0
func resize_plateau(dimension:String,amount:float) -> void:
	if selected_kind!="sculpted_terrain" or selected.is_empty() or selected.profile=="smooth": return
	var candidate=selected.duplicate(true); candidate[dimension]=maxf(1,float(candidate.get(dimension,candidate.radius*2 if dimension=="plateau_width" else candidate.radius))+amount)
	if not Sculpt.fits(candidate,Packs.bounds_rect(area())): status.text="Plateau would cross the area boundary. Move it inward or enlarge the area."; return
	checkpoint(); selected[dimension]=candidate[dimension]; rebuild(); inspect(); status.text="Flat top resized; ramp and height preserved."
func extend_plateau(at:Vector2) -> void:
	if selected_kind!="sculpted_terrain" or selected.is_empty() or selected.profile=="smooth": status.text="Select a bluff or overhang first."; return
	var candidate=selected.duplicate(true); var local=Sculpt.local_point(candidate,Vector3(at.x,0,at.y))
	var width=float(candidate.get("plateau_width",candidate.radius*2)); var depth=float(candidate.get("plateau_depth",candidate.radius))
	if absf(local.x)<=width*.5 and local.y<=0 and -local.y<=depth:
		if depth+local.y<=width*.5-absf(local.x): candidate.plateau_depth=maxf(1,snappedf(-local.y,.5))
		else:
			var narrower=maxf(1,snappedf(width*.5+absf(local.x),.5))
			var shift=Vector2(signf(local.x)*(narrower-width)*.5,0).rotated(-deg_to_rad(float(candidate.get("rotation",0))))
			candidate.at=[candidate.at[0]+shift.x,candidate.at[1]+shift.y]; candidate.plateau_width=narrower
		checkpoint(); selected.merge(candidate,true); rebuild(); inspect(); status.text="Plateau trimmed to the clicked edge. Ctrl+Z undoes."; return
	if local.y>0: status.text="Extend the flat top at its sides or back. Ramp length controls the walk-up side."; return
	if absf(local.x)>width*.5:
		var extra=ceilf((absf(local.x)-width*.5+.5)*2)*.5
		var offset=Vector2(signf(local.x)*extra*.5,0).rotated(-deg_to_rad(float(candidate.get("rotation",0))))
		candidate.at=[candidate.at[0]+offset.x,candidate.at[1]+offset.y]; width+=extra
	candidate.plateau_width=width; candidate.plateau_depth=maxf(depth,ceilf((-local.y+.5)*2)*.5)
	if not Sculpt.fits(candidate,Packs.bounds_rect(area())): status.text="Keep the extended plateau inside the area. Enlarge Area settings > boundaries for more room."; return
	checkpoint(); selected.merge(candidate,true); show_selection(); rebuild(); inspect(); status.text="Plateau extended to the clicked point. Ctrl+Z undoes."
func _process(_delta:float) -> void:
	geometry_clock+=_delta
	if geometry_dirty and geometry_clock>=.10: geometry_clock=0; geometry_dirty=false; rebuild()
	if document_label!=null and not pack.is_empty():
		document_label.text=pack.name.left(28)+(" * Unsaved" if dirty else " - New draft" if path.is_empty() else " - Saved")
		get_window().title="Coastal Map Builder - "+pack.name+(" *" if dirty else "")

func convert_bluff() -> void:
	if selected_kind!="props" or selected.get("catalog_code","") not in ["3F","4F"]: return
	var scale=float(selected.get("scale",1))
	if scale>2: status.text="Reduce this template's scale to 2 or less before converting."; return
	if area().get("sculpted_terrain",[]).size()>=64: status.text="Maximum 64 terrain patches per area."; return
	var patch={"id":selected.id,"at":selected.at.duplicate(),"rotation":selected.get("rotation",0),"profile":"bluff","height":(2.8 if selected.catalog_code=="3F" else 2.4)*scale,"radius":maxf(1,4*scale),"plateau_width":maxf(1,7*scale),"plateau_depth":maxf(1,4*scale)}
	if not Sculpt.fits(patch,Packs.bounds_rect(area())): status.text="Move the bluff farther inside the area before converting."; return
	checkpoint(); area().props.erase(selected)
	if not area().has("sculpted_terrain"): area().sculpted_terrain=[]
	area().sculpted_terrain.append(patch); selected=patch; selected_kind="sculpted_terrain"; show_selection(); rebuild(); inspect(); status.text="Bluff is now editable. Adjust its flat top or choose Extend plateau."

func open_example() -> void:
	if dirty: confirm("Discard unsaved changes and open the optional cave example?",func(): dirty=false; open_example()); return
	reset_document(); pack=Document.example(); refresh_areas(); rebuild(); inspect(); fit_camera()
func save_document() -> void:
	if not fragment_path.is_empty():
		var result=Fragments.save(Fragments.create(area(),pack.name),fragment_path)
		if result.has("error"): status.text=result.error
		else: dirty=false; status.text="Fragment updated in your library."
	elif path.is_empty(): choose_file("save")
	else:
		var errors=Packs.validate(pack,true)
		if not errors.is_empty(): status.text="Cannot save: "+" / ".join(errors.slice(0,3)); return
		file_action="save"; file_selected(path)
func show_fragments() -> void:
	if fragment_dialog==null:
		fragment_dialog=AcceptDialog.new(); fragment_dialog.title="Reusable map fragments"; fragment_dialog.min_size=Vector2i(600,460); fragment_dialog.get_ok_button().text="Close"; add_child(fragment_dialog)
		var holder=Control.new(); fragment_dialog.add_child(holder); holder.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		var body=VBoxContainer.new(); holder.add_child(body); body.set_anchors_and_offsets_preset(PRESET_FULL_RECT); body.offset_left=16; body.offset_top=12; body.offset_right=-16; body.offset_bottom=-54
		var description=Label.new(); description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; description.text="Save this area as a reusable section. Gates are excluded.\nOpen to edit it, add it as an area, or stamp its pieces into a map."; body.add_child(description)
		var name_label=Label.new(); name_label.text="Fragment name (new or selected fragment)"; body.add_child(name_label)
		fragment_name=LineEdit.new(); fragment_name.max_length=80; fragment_name.placeholder_text="Fragment name, e.g. Long bluff with forest trail"; body.add_child(fragment_name)
		button(body,"Save current area as a new fragment",save_new_fragment)
		fragment_list=ItemList.new(); fragment_list.size_flags_vertical=SIZE_EXPAND_FILL; fragment_list.custom_minimum_size.y=170; body.add_child(fragment_list)
		fragment_info=Label.new(); fragment_info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; body.add_child(fragment_info)
		fragment_list.item_selected.connect(func(i): fragment_name.text=fragment_entries[i].data.name; var a=fragment_entries[i].data.area; fragment_info.text="%d scenery | %d creatures | %d terrain patches | %s" % [a.props.size(),a.catalog_enemies.size(),a.get("sculpted_terrain",[]).size(),"Cave room" if a.get("cave",false) else "Outdoor section"])
		var actions=HFlowContainer.new(); body.add_child(actions)
		button(actions,"Rename selected",rename_fragment); button(actions,"Open to edit",func(): use_fragment("open")); button(actions,"Add as area",func(): use_fragment("area")); button(actions,"Stamp on map",func(): use_fragment("stamp"))
	fragment_name.text=area().display_name; refresh_fragments(); fragment_dialog.popup_centered(Vector2i(640,490))
func refresh_fragments() -> void:
	fragment_entries=Fragments.entries(); fragment_list.clear()
	for entry in fragment_entries: fragment_list.add_item(entry.data.name)
	fragment_info.text="Your library is stored locally outside game releases." if not fragment_entries.is_empty() else "No fragments yet. Give this section a name and save it above."
func save_new_fragment() -> void:
	var result=Fragments.save(Fragments.create(area(),fragment_name.text))
	if result.has("error"): fragment_info.text=result.error; return
	refresh_fragments(); fragment_info.text="Saved. Your world draft is unchanged; reuse this fragment whenever you need it."
func use_fragment(action:String) -> void:
	var indices=fragment_list.get_selected_items()
	if indices.is_empty(): fragment_info.text="Choose a saved fragment first."; return
	var entry=fragment_entries[indices[0]]
	if action=="open" and dirty:
		confirm("Discard unsaved changes and edit this fragment?",func(): dirty=false; use_fragment(action)); return
	if action=="open":
		reset_document(); pack=Fragments.document(entry.data); fragment_path=entry.path; path=entry.path; refresh_areas(); rebuild(); inspect(); fit_camera(); status.text="Editing fragment. Save updates this library entry; Save as creates a world draft."
	elif action=="area":
		if pack.maps.size()>=32: fragment_info.text="Maximum 32 areas per world."; return
		if not fragment_path.is_empty(): fragment_path=""; path=""
		checkpoint(); var a=entry.data.area.duplicate(true); a.id="section_"+str(Time.get_ticks_usec()); pack.maps.append(a); area_index=pack.maps.size()-1; selected={}; refresh_areas(); rebuild(); inspect(); fit_camera(); status.text="Fragment added as an area. Add travel gates when you want to link it."
	else:
		pending_fragment=entry.data.area.duplicate(true); set_mode(4); status.text="Click the map to stamp "+entry.data.name+". Escape cancels."
	fragment_dialog.hide()
func insert_fragment(at:Vector2) -> void:
	if pending_fragment.is_empty(): return
	var result=Fragments.stamp(pending_fragment,area(),at,"stamp_"+str(Time.get_ticks_usec()))
	if result.has("error"): status.text=result.error; return
	checkpoint(); pack.maps[area_index]=result.area; selected={}; rebuild(); inspect(); status.text="Fragment stamped. Click again for another copy; Ctrl+Z undoes."

func fragment_checks(errors:Array) -> void:
	var old_directory=Fragments.directory; Fragments.directory="user://fragment-verification"
	var a=Document.area(); a.bounds=[-60,-60,60,60]; a.spawn=[0,45]
	a.props=[{"id":"tree","kind":"catalog_feature","catalog_code":"1A","at":[0,40]}]
	a.catalog_enemies=[{"id":"slime","code":"9E","at":[2,40],"respawn_seconds":12,"ambush_group":"tree_pack","spawn_mode":"tree_drop","drop_height":4,"trigger_radius":6}]
	a.sculpted_terrain=[{"id":"long_bluff","at":[0,0],"profile":"bluff","height":3,"radius":4,"plateau_width":80,"plateau_depth":50}]
	a.exits=[{"id":"external","rect":[1,40,2,2],"target":"missing","spawn":[0,0],"label":"External"}]
	var fragment=Fragments.create(a,"Long forest bluff")
	if not Fragments.validate(fragment).is_empty() or not fragment.area.exits.is_empty(): errors.append("Long plateau fragment must save without cave or external links")
	var result=Fragments.save(fragment)
	if result.has("error"): errors.append("Fragment save failed: "+result.error)
	else:
		var loaded=Fragments.read(result.path)
		if loaded.is_empty() or loaded.area.sculpted_terrain[0].plateau_width!=80 or Fragments.entries().size()!=1: errors.append("Fragment library round trip failed")
		var renamed=Fragments.rename(result.path,"Northern ridge template")
		var after=Fragments.read(result.path)
		if renamed.has("error") or after.name!="Northern ridge template" or after.area.display_name!=after.name or after.area.sculpted_terrain!=loaded.area.sculpted_terrain or after.area.catalog_enemies!=loaded.area.catalog_enemies: errors.append("Fragment rename must persist while preserving content")
		if not Fragments.rename(result.path,"   ").has("error") or Fragments.read(result.path).name!="Northern ridge template": errors.append("Empty fragment name must be rejected without modifying the file")
		var target=Document.area(); target.bounds=[-100,-100,100,100]
		var stamped=Fragments.stamp(fragment.area,target,Vector2(0,0),"first")
		if stamped.has("error"): errors.append("Fragment stamp failed: "+stamped.error)
		else:
			var twice=Fragments.stamp(fragment.area,stamped.area,Vector2(2,0),"second")
			if twice.has("error") or twice.area.props.size()!=2 or twice.area.catalog_enemies[0].respawn_seconds!=12 or twice.area.catalog_enemies[0].ambush_group==twice.area.catalog_enemies[1].ambush_group: errors.append("Repeated fragment stamp did not preserve settings/fresh IDs")
		if not Fragments.stamp(fragment.area,Document.area(),Vector2.ZERO,"outside").has("error"): errors.append("Oversized fragment stamp must be rejected atomically")
		DirAccess.remove_absolute(result.path)
	Fragments.directory=old_directory

func set_plateau_dimension(dimension:String,value:float) -> void:
	var candidate=selected.duplicate(true); candidate[dimension]=value
	if not Sculpt.fits(candidate,Packs.bounds_rect(area())): status.text="Plateau crosses the area boundary. Enlarge Area settings > boundaries first."; inspect(); return
	selected[dimension]=value

func plane_point(pixel:Vector2,height:float) -> Vector2:
	var origin=camera.project_ray_origin(pixel); var ray=camera.project_ray_normal(pixel)
	var point=origin+ray*((height-origin.y)/ray.y)
	return Vector2(point.x,point.z)
func pick_handle(pixel:Vector2) -> Dictionary:
	var entries=[{"item":{"kind":"Start","at":area().spawn},"kind":"spawn","text":"START"}]
	for mob in area().catalog_enemies: entries.append({"item":mob,"kind":"catalog_enemies","text":mob.code+(" TREE DROP" if mob.get("spawn_mode", "ground")=="tree_drop" else " CREATURE")})
	for gate in area().exits: entries.append({"item":gate,"kind":"exits","text":gate.label+" > "+gate.target})
	for piece in area().get("sculpted_terrain",[]): entries.append({"item":piece,"kind":"sculpted_terrain","text":piece.profile.to_upper()+" %.2fm" % piece.height})
	for entry in entries:
		var at=object_at(entry.item); var y=world.ground_height(Vector3(at.x,entry.item.get("height",0),at.y))
		var label=camera.unproject_position(Vector3(at.x,y+.88,at.y))
		var height=maxf(20,canvas.size.y*.0336)
		var label_box=Rect2(label-Vector2(maxf(25,height*.3*entry.text.length()),height*.7),Vector2(maxf(50,height*.6*entry.text.length()),height*1.4))
		var anchor=camera.unproject_position(Vector3(at.x,y+.08,at.y))
		if label_box.has_point(pixel) or pixel.distance_to(anchor)<12: return entry
	if edit_mode==0:
		var scenery=pick_scenery(pixel)
		if not scenery.is_empty(): return scenery
		var at=ground_point(pixel)
		for gate in area().exits:
			if Rect2(gate.rect[0],gate.rect[1],gate.rect[2],gate.rect[3]).has_point(at): return {"item":gate,"kind":"exits"}
		for region in area().terrain_regions:
			if Rect2(region.rect[0],region.rect[1],region.rect[2],region.rect[3]).has_point(at): return {"item":region,"kind":"terrain_regions"}
	return {}

func handle_drag_checks(errors:Array) -> void:
	var saved=pack.duplicate(true)
	area().spawn=[0,8]; area().sculpted_terrain=[{"id":"drag_bluff","at":[0,-5],"height":3,"radius":4,"profile":"bluff","rotation":0,"plateau_width":12,"plateau_depth":8}]
	for kind in ["spawn","sculpted_terrain"]:
		selected={}; rebuild(); inspect(); set_mode(2); await get_tree().process_frame; await get_tree().physics_frame
		var a=Vector3(0,.88,8) if kind=="spawn" else Vector3(0,3.88,-5)
		var from=canvas.global_position+camera.unproject_position(a); var to=canvas.global_position+camera.unproject_position(a+Vector3(2,0,0))
		var motion=InputEventMouseMotion.new(); motion.position=from; motion.global_position=from; Input.parse_input_event(motion)
		await get_tree().process_frame
		var press=InputEventMouseButton.new(); press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; press.position=from; press.global_position=from; Input.parse_input_event(press)
		await get_tree().process_frame
		if selected_kind!=kind or edit_mode!=0: errors.append("Raised "+kind+" label must select and leave Sculpt mode: mode="+str(edit_mode)+" selected="+selected_kind+" handle="+str(pick_handle(from-canvas.global_position))+" canvas="+str(canvas.get_global_rect().has_point(from)))
		motion=InputEventMouseMotion.new(); motion.position=to; motion.global_position=to; motion.relative=to-from; motion.button_mask=MOUSE_BUTTON_MASK_LEFT; Input.parse_input_event(motion)
		await get_tree().process_frame
		press=InputEventMouseButton.new(); press.button_index=MOUSE_BUTTON_LEFT; press.pressed=false; press.position=to; press.global_position=to; Input.parse_input_event(press)
		await get_tree().process_frame
		var moved=area().spawn if kind=="spawn" else area().sculpted_terrain[0].at
		if moved!=[2.0,a.z]: errors.append("Native label drag must move "+kind+" without jumping: "+str(moved))
		undo()
		var restored=area().spawn if kind=="spawn" else area().sculpted_terrain[0].at
		if Vector2(restored[0],restored[1]).distance_to(Vector2(0,a.z))>.01: errors.append("Native label drag undo failed for "+kind+": "+str(restored))
	pack=saved; selected={}; set_mode(0); refresh_areas(); rebuild(); inspect()

func set_transition_rect(index:int,value:float) -> void:
	if selected_kind!="exits" or selected.is_empty(): return
	var centre=object_at(selected); var rect=selected.rect.duplicate()
	if index==0: rect[0]=value-rect[2]*.5
	elif index==1: rect[1]=value-rect[3]*.5
	elif index==2: rect[2]=value; rect[0]=centre.x-value*.5
	else: rect[3]=value; rect[1]=centre.y-value*.5
	if value<.1 and index>=2 or not Packs.bounds_rect(area()).encloses(Rect2(rect[0],rect[1],rect[2],rect[3])):
		status.text="Travel zone must stay inside the area boundary. Move its centre inward or enlarge Area settings."
		call_deferred("inspect"); return
	selected.rect=rect; status.text="Travel zone resized; its centre and destination landing are preserved."

func transition_checks(errors:Array) -> void:
	var original=pack.duplicate(true); var gate={"id":"wide_gate","rect":[-7,-2,14,4],"target":"cave","spawn":[0,5.5],"label":"Wide gate","interact":true}
	area().exits=[gate]; selected={}; set_mode(2); rebuild(); inspect(); await get_tree().process_frame; await get_tree().physics_frame
	var centre=Vector3(0,.88,0); var from=canvas.global_position+camera.unproject_position(centre)
	var move=InputEventMouseMotion.new(); move.position=from; move.global_position=from; Input.parse_input_event(move); await get_tree().process_frame
	var click=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true; click.position=from; click.global_position=from; Input.parse_input_event(click); await get_tree().process_frame
	if selected_kind!="exits" or selected.is_empty() or edit_mode!=0: errors.append("Transition label must be selectable from Sculpt mode")
	click.pressed=false; Input.parse_input_event(click); await get_tree().process_frame
	selected=gate; selected_kind="exits"; var landing=gate.spawn.duplicate(); checkpoint(); set_transition_rect(2,18); set_transition_rect(3,6)
	if absf(gate.rect[0]+9)>.01 or absf(gate.rect[1]+3)>.01 or gate.rect[2]!=18 or gate.rect[3]!=6 or object_at(gate)!=Vector2.ZERO or gate.spawn!=landing: errors.append("Transition resizing must preserve centre and destination")
	undo(); if area().exits[0].rect!=[-7,-2,14,4]: errors.append("Transition resize undo failed")
	set_mode(0); selected={}; var edge=camera.unproject_position(Vector3(6,0,0))
	var picked=pick_handle(edge)
	if picked.is_empty() or picked.kind!="exits": errors.append("Wide transition edge must select its full footprint")
	pack=original; selected={}; set_mode(0); refresh_areas(); rebuild(); inspect()
	await get_tree().process_frame
	var tree=area().props[1]; var picked_tree=pick_scenery(camera.unproject_position(Vector3(tree.at[0],2.2,tree.at[1])))
	if picked_tree.is_empty() or picked_tree.item.id!=tree.id: errors.append("Select tool must pick visible tree geometry above its ground anchor")

func pick_scenery(pixel:Vector2) -> Dictionary:
	var origin=camera.project_ray_origin(pixel); var ray=camera.project_ray_normal(pixel)
	var nearest=INF; var result={}
	for prop in area().props:
		var root=world.get_node_or_null(NodePath(prop.id))
		if root==null: continue
		for mesh in root.find_children("*","MeshInstance3D",true,false):
			if mesh.mesh==null or not mesh.visible: continue
			var local=mesh.global_transform.affine_inverse()
			var hit=mesh.mesh.get_aabb().intersects_ray(local*origin,local.basis*ray)
			if hit==null: continue
			var distance=origin.distance_to(mesh.global_transform*hit)
			if distance<nearest: nearest=distance; result={"item":prop,"kind":"props"}
	return result

func create_terrain_patch(at:Vector2) -> void:
	if area().get("cave",false): status.text="Create terrain in outdoor areas."; return
	if area().get("sculpted_terrain",[]).size()>=64: status.text="Maximum 64 patches per area."; return
	var patch={"id":"terrain_"+str(Time.get_ticks_usec()),"at":[at.x,at.y],"height":3.0 if terrain_profile!="smooth" else 1.0,"radius":brush_radius,"rotation":0,"profile":terrain_profile}
	if not Sculpt.fits(patch,Packs.bounds_rect(area())): status.text="Keep the new patch inside the area boundary."; return
	checkpoint()
	if not area().has("sculpted_terrain"): area().sculpted_terrain=[]
	area().sculpted_terrain.append(patch); selected=patch; selected_kind="sculpted_terrain"; show_selection(); rebuild(); inspect(); status.text="Separate terrain patch created. Select edits it; New bluff creates another."

func terrain_creation_checks(errors:Array) -> void:
	var original=pack.duplicate(true); area().sculpted_terrain=[{"id":"first_bluff","at":[0,0],"height":3,"radius":4,"profile":"bluff","plateau_width":12,"plateau_depth":12}]
	selected=area().sculpted_terrain[0]; selected_kind="sculpted_terrain"; var first=selected.duplicate(true); rebuild(); resize_plateau("plateau_depth",-2)
	if selected.plateau_depth!=10 or selected.radius!=4 or selected.height!=3: errors.append("Shorten bluff must reduce length while preserving ramp/height")
	undo(); if area().sculpted_terrain[0].plateau_depth!=12: errors.append("Shorten bluff undo failed")
	selected=area().sculpted_terrain[0]; selected_kind="sculpted_terrain"; extend_plateau(Vector2(0,-6))
	if selected.plateau_depth!=6: errors.append("Clicking inside back edge must shorten bluff")
	undo()
	terrain_profile="bluff"; brush_radius=4; set_mode(5); create_terrain_patch(Vector2(0,-8))
	if area().sculpted_terrain.size()!=2 or area().sculpted_terrain[0]!=first or selected.id==first.id: errors.append("New bluff behind existing bluff must create an independent patch")
	undo(); if area().sculpted_terrain.size()!=1: errors.append("Second bluff undo failed")
	pack=original; selected={}; set_mode(0); refresh_areas(); rebuild(); inspect()

func rename_fragment() -> void:
	var indices=fragment_list.get_selected_items()
	if indices.is_empty(): fragment_info.text="Choose a saved fragment, edit its name above, then click Rename selected."; return
	var entry=fragment_entries[indices[0]]
	var result=Fragments.rename(entry.path,fragment_name.text)
	if result.has("error"): fragment_info.text=result.error; return
	if fragment_path==entry.path: pack.name=fragment_name.text.strip_edges(); area().display_name=pack.name; refresh_areas()
	refresh_fragments()
	for i in range(fragment_entries.size()):
		if fragment_entries[i].path==entry.path: fragment_list.select(i); fragment_name.text=fragment_entries[i].data.name
	fragment_info.text="Renamed to "+fragment_name.text+". All saved terrain and creature settings are preserved."

func transform_height() -> float:
	if selected_kind=="sculpted_terrain": return maxf(0,float(selected.height))+.12
	var at=object_at(selected); return world.ground_height(Vector3(at.x,0,at.y))+.12
func transform_screen_points() -> Array:
	if selected.is_empty() or edit_mode!=0: return []
	var result=[]
	for at in Geometry.points(selected,selected_kind): result.append(camera.unproject_position(Vector3(at.x,transform_height(),at.y)))
	return result
func transform_handle_at(pixel:Vector2) -> int:
	var points=transform_screen_points()
	if points.is_empty(): return -1
	for i in range(points.size()):
		if pixel.distance_to(points[i])<=11: return i
	# Edges are draggable anywhere, not only the square grips.
	for pair in [[0,2,1],[2,4,3],[4,6,5],[6,0,7]]:
		if Geometry2D.get_closest_point_to_segment(pixel,points[pair[0]],points[pair[1]]).distance_to(pixel)<=6: return pair[2]
	return -1
func finish_terrain_creation() -> void:
	creating_terrain=false
	terrain_profile=active_piece.get("profile","bluff")
	var a=Vector2(snappedf(creation_from.x,snap),snappedf(creation_from.y,snap)); var b=Vector2(snappedf(creation_to.x,snap),snappedf(creation_to.y,snap))
	if a.distance_to(b)<1: create_terrain_patch(a); set_mode(0); return
	var rect=Rect2(a,b-a).abs(); var patch={"id":"terrain_"+str(Time.get_ticks_usec()),"at":[rect.get_center().x,rect.get_center().y],"height":1.0 if terrain_profile=="smooth" else 3.0,"radius":clampf(minf(rect.size.x,rect.size.y)*.5,1,8),"profile":terrain_profile,"rotation":0}
	if terrain_profile!="smooth":
		patch.radius=clampf(rect.size.y*.35,1,4); patch.plateau_width=maxf(1,rect.size.x); patch.plateau_depth=maxf(1,rect.size.y-patch.radius); patch.at[1]=rect.end.y-patch.radius
	if not Sculpt.fits(patch,Packs.bounds_rect(area())): status.text="Draw the footprint inside the gold boundary."; return
	if area().get("sculpted_terrain",[]).size()>=64: status.text="Maximum 64 patches per area."; return
	checkpoint()
	if not area().has("sculpted_terrain"): area().sculpted_terrain=[]
	area().sculpted_terrain.append(patch); selected=patch; selected_kind="sculpted_terrain"; set_mode(0); show_selection(); rebuild(); inspect(); status.text="Terrain created. Drag its body to move, edges to resize; edit height/profile at right."

func direct_transform_checks(errors:Array) -> void:
	var old_pack=pack.duplicate(true); var old_profile=terrain_profile
	pack=Document.blank(); area().bounds=[-20,-2,20,10]; area().spawn=[-16.5,4]
	var patch={"id":"rotated_user_bluff","at":[12.5,4.0],"height":5.75,"plateau_depth":32.0,"plateau_width":10.0,"profile":"bluff","radius":4.0,"rotation":90.0}
	area().sculpted_terrain=[patch]; selected=patch; selected_kind="sculpted_terrain"; set_mode(0); refresh_areas(); rebuild(); inspect(); fit_camera(); await get_tree().process_frame
	# Same layout as the user's draft: rotated width must reach both Z boundaries.
	for point in transform_screen_points():
		if not Rect2(Vector2.ZERO,canvas.size).has_point(point): errors.append("Fit area must show all rotated bluff transform handles")
	var before=patch.duplicate(true)
	for index in [7,3]:
		var points=Geometry.points(selected,selected_kind); var to=points[index]; to.y=10 if index==7 else -2
		var from=canvas.global_position+transform_screen_points()[index]; var target=canvas.global_position+camera.unproject_position(Vector3(to.x,transform_height(),to.y))
		var move=InputEventMouseMotion.new(); move.position=from; move.global_position=from; Input.parse_input_event(move); await get_tree().process_frame
		var click=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true; click.position=from; click.global_position=from; Input.parse_input_event(click); await get_tree().process_frame
		if not resizing: errors.append("Visible rotated bluff edge must begin a direct resize")
		move=InputEventMouseMotion.new(); move.position=target; move.global_position=target; move.relative=target-from; move.button_mask=MOUSE_BUTTON_MASK_LEFT; Input.parse_input_event(move); await get_tree().process_frame
		click=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=false; click.position=target; click.global_position=target; Input.parse_input_event(click); await get_tree().process_frame
	if absf(selected.plateau_width-12)>.01 or not Sculpt.fits(selected,Packs.bounds_rect(area())): errors.append("Rotated bluff must resize exactly to both map boundaries")
	var old_height=selected.height; hover_pixel=camera.unproject_position(Vector3(0,old_height,9.5)); sculpt_hover(.25)
	if selected.height!=old_height+.25 or area().sculpted_terrain.size()!=1: errors.append("Height editing at boundary must edit existing full-width terrain, not reject its brush margin")
	undo(); selected=area().sculpted_terrain[0]; selected_kind="sculpted_terrain"
	var over=Geometry.bounded_resize(selected,selected_kind,7,Vector2(-1.5,40),Packs.bounds_rect(area()))
	if not Sculpt.fits(over,Packs.bounds_rect(area())) or absf(over.plateau_width-12)>.02: errors.append("Dragging beyond boundary must clamp instead of reject or overshoot")
	var shortened=Geometry.resized(selected,selected_kind,1,Geometry.to_world(Geometry.frame(selected,selected_kind),Vector2(0,-20)))
	if shortened.plateau_depth!=20 or shortened.radius!=4 or shortened.height!=5.75: errors.append("Direct back-edge resize must preserve ramp and height")
	undo(); undo(); if area().sculpted_terrain[0]!=before: errors.append("Direct edge undo must restore the user's original rotated bluff")
	# Terrain palette drag creates an independent overlapping piece and returns to selection.
	set_mode(1); active_piece={"tool":"terrain","profile":"bluff"}
	var from=canvas.global_position+camera.unproject_position(Vector3(-8,5.75,1)); var to=canvas.global_position+camera.unproject_position(Vector3(0,5.75,8))
	var move=InputEventMouseMotion.new(); move.position=from; move.global_position=from; Input.parse_input_event(move); await get_tree().process_frame
	var press=InputEventMouseButton.new(); press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; press.position=from; press.global_position=from; Input.parse_input_event(press); await get_tree().process_frame
	if not creating_terrain: errors.append("Terrain palette press must begin footprint creation")
	move=InputEventMouseMotion.new(); move.position=to; move.global_position=to; move.relative=to-from; move.button_mask=MOUSE_BUTTON_MASK_LEFT; Input.parse_input_event(move); await get_tree().process_frame
	press=InputEventMouseButton.new(); press.button_index=MOUSE_BUTTON_LEFT; press.pressed=false; press.position=to; press.global_position=to; Input.parse_input_event(press); await get_tree().process_frame
	if area().sculpted_terrain.size()!=2 or edit_mode!=0 or area().sculpted_terrain[0]!=before: errors.append("Palette rectangle creation must preserve existing bluff and return to selection")
	pack=old_pack; selected={}; terrain_profile=old_profile; profile_menu.select(["smooth","bluff","overhang"].find(old_profile)); set_mode(0); refresh_areas(); rebuild(); inspect(); fit_camera()

func capture_review(directory:String,draft:String) -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string(draft))
	if not data is Dictionary or not Packs.validate(data,true).is_empty(): push_error("Cannot inspect malformed draft"); return
	pack=data; area_index=0; selected=area().sculpted_terrain[0]; selected_kind="sculpted_terrain"; set_mode(0); refresh_areas(); rebuild(); inspect(); orbit_yaw=0; orbit_pitch=1.30
	await get_tree().process_frame; await get_tree().process_frame; fit_camera(); await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("map-builder-user-before.png"))
	for index in [7,3]:
		var f=Geometry.frame(selected,selected_kind); var start=Geometry.points(selected,selected_kind)[index]
		var destination=start+Vector2(-1000 if index==7 else 1000,0).rotated(-f.angle)
		selected.merge(Geometry.bounded_resize(selected,selected_kind,index,destination,Packs.bounds_rect(area())),true)
	rebuild(); inspect(); status.text="Read-only demonstration: edges resized to the area boundary. Your saved draft was not modified."
	await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("map-builder-user-resized.png"))

func select_object(kind:String,item:Dictionary) -> void:
	selected_kind=kind; selected=item; set_mode(0); show_selection(); rebuild(); inspect()
