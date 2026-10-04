extends Control
const World = preload("res://scripts/world.gd")
const Actor = preload("res://scripts/actor.gd")
const Save = preload("res://scripts/save_store.gd")
var config: Dictionary
var world_view: SubViewport
var image_view: TextureRect
var world_root: Node3D
var current_world: Node3D
var player: CharacterBody3D
var npcs: Array = []
var camera: Camera3D
var camera_target = Vector3.ZERO
var camera_offset = Vector3(0,16,12)
var map_id = ""
var exit_cooldown = 1.0
var world_rect: Rect2
var location_panel: PanelContainer
var location_title: Label
var location_subtitle: Label
var menu: HBoxContainer
var controls: PanelContainer
var interaction_panel: PanelContainer
var interaction_label: Label
var toast: Label
var toast_time = 0.0
var dialog: PanelContainer
var dialog_title: Label
var dialog_text: Label
var dialog_next: Button
var dialog_lines: Array = []
var dialog_index = 0
var help_panel: PanelContainer
var nearest: Dictionary = {}
var view_button: Button
var gallery_mode=false

func read_data(path: String) -> Dictionary:
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	if value is Dictionary:
		return value
	push_error("Invalid content definition: "+path)
	return {}

func _ready() -> void:
	DisplayServer.window_set_min_size(Vector2i(960,540))
	config=read_data("res://content/platform.json")
	_bind_inputs()
	_build_view()
	_build_ui()
	set_resolution(int(config.world_resolution[0]))
	player=Actor.new()
	player.name="Player"
	player.controllable=true
	player.walk_speed=config.walk_speed
	player.configure(read_data("res://content/characters/"+config.player_character+".json"))
	world_root.add_child(player)
	load_map(config.start_map)
	resized.connect(_layout)
	_layout()
	var args=OS.get_cmdline_user_args()
	if "--verify" in args:
		call_deferred("_verify")
	elif "--capture" in args:
		call_deferred("_capture",args[args.find("--capture")+1])

func _bind_inputs() -> void:
	var bindings={"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN],"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"interact":[KEY_E,KEY_SPACE,KEY_ENTER],"save_game":[KEY_F5],"load_game":[KEY_F9],"help":[KEY_H],"fullscreen":[KEY_F11]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event=InputEventKey.new()
			event.physical_keycode=key
			InputMap.action_add_event(action,event)

func _build_view() -> void:
	var backdrop=ColorRect.new()
	backdrop.color=Color("#172523")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	world_view=SubViewport.new()
	world_view.size=Vector2i(640,360)
	world_view.own_world_3d=true
	world_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	world_view.msaa_3d=Viewport.MSAA_DISABLED
	add_child(world_view)
	world_root=Node3D.new()
	world_view.add_child(world_root)
	var environment=WorldEnvironment.new()
	var env=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("#a1b8b7")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("#d8e0c8")
	env.ambient_light_energy=.25
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	environment.environment=env
	world_root.add_child(environment)
	var light=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-58,-28,0)
	light.light_color=Color("#fff0d2")
	light.light_energy=.60
	light.shadow_enabled=true
	light.directional_shadow_max_distance=45
	world_root.add_child(light)
	camera=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=config.camera_size
	camera.current=true
	camera.far=160
	camera_offset=Vector3(config.camera_offset[0],config.camera_offset[1],config.camera_offset[2])
	world_root.add_child(camera)
	image_view=TextureRect.new()
	image_view.texture=world_view.get_texture()
	image_view.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	image_view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image_view.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(image_view)

func style(background: Color, border: Color=Color.TRANSPARENT, radius: int=8) -> StyleBoxFlat:
	var box=StyleBoxFlat.new()
	box.bg_color=background
	box.border_color=border
	box.set_border_width_all(1 if border.a>0 else 0)
	box.set_corner_radius_all(radius)
	box.content_margin_left=18
	box.content_margin_right=18
	box.content_margin_top=12
	box.content_margin_bottom=12
	return box

func panel(parent: Node) -> PanelContainer:
	var box=PanelContainer.new()
	box.add_theme_stylebox_override("panel",style(Color("#203630ed"),Color("#c6c6a74a")))
	parent.add_child(box)
	return box

func label(text: String,font_size: int=18,color: Color=Color("#f2ecd9")) -> Label:
	var node=Label.new()
	node.text=text
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	return node

func button(text: String,callback: Callable) -> Button:
	var node=Button.new()
	node.text=text
	node.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	node.add_theme_font_size_override("font_size",17)
	node.add_theme_color_override("font_color",Color("#f0ead7"))
	node.add_theme_stylebox_override("normal",style(Color("#213a32ee"),Color("#bbc2a54a")))
	node.add_theme_stylebox_override("hover",style(Color("#45644eee"),Color("#ddd5af")))
	node.add_theme_stylebox_override("pressed",style(Color("#5b795aff")))
	node.add_theme_stylebox_override("focus",style(Color("#45644eee"),Color("#ddd5af")))
	node.pressed.connect(callback)
	return node

func _build_ui() -> void:
	location_panel=panel(self)
	var location=VBoxContainer.new()
	location.add_theme_constant_override("separation",3)
	location_panel.add_child(location)
	location_title=label("Coastal Path",25)
	location_subtitle=label("The village by the sea",15,Color("#c3c7ad"))
	location.add_child(location_title)
	location.add_child(location_subtitle)
	menu=HBoxContainer.new()
	menu.add_theme_constant_override("separation",8)
	add_child(menu)
	menu.add_child(button("Save",save_game))
	menu.add_child(button("Load",load_game))
	view_button=button("Fine pixels",toggle_resolution)
	menu.add_child(view_button)
	menu.add_child(button("Help",toggle_help))
	controls=panel(self)
	controls.add_child(label("WASD / Arrows  Move     E  Interact     F5  Save     F9  Load",16,Color("#dfdfc7")))
	interaction_panel=panel(self)
	interaction_label=label("E  ·  Read",18)
	interaction_panel.add_child(interaction_label)
	interaction_panel.visible=false
	toast=label("",18,Color("#fff3cd"))
	toast.add_theme_color_override("font_shadow_color",Color("#20362c"))
	toast.add_theme_constant_override("shadow_offset_x",2)
	toast.add_theme_constant_override("shadow_offset_y",2)
	add_child(toast)
	dialog=panel(self)
	dialog.visible=false
	var dialogue_layout=VBoxContainer.new()
	dialogue_layout.add_theme_constant_override("separation",12)
	dialog.add_child(dialogue_layout)
	dialog_title=label("",22,Color("#e7cca0"))
	dialog_text=label("",21)
	dialog_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	dialog_text.custom_minimum_size=Vector2(560,65)
	dialog_next=button("Continue  ·  E",advance_dialogue)
	dialogue_layout.add_child(dialog_title)
	dialogue_layout.add_child(dialog_text)
	dialogue_layout.add_child(dialog_next)
	help_panel=panel(self)
	help_panel.visible=false
	var help=VBoxContainer.new()
	help_panel.add_child(help)
	help.add_theme_constant_override("separation",14)
	help.add_child(label("A quiet walk by the sea",27,Color("#e8d0a5")))
	help.add_child(label("WASD or arrows    Move\nE / Space / Enter    Talk, read, continue\nF5    Save your place\nF9    Return to your saved place\nF11    Toggle fullscreen\nH / Escape    Help or close\n\nFollow the path north to the village green.\nFine / Chunky pixels changes the visual scale.",19))
	help.add_child(button("Return to the path",toggle_help))

func _layout() -> void:
	if image_view==null:
		return
	var available=get_viewport_rect().size
	var factor=maxi(1,int(floor(min(available.x/world_view.size.x,available.y/world_view.size.y))))
	var rendered=Vector2(world_view.size)*factor
	world_rect=Rect2((available-rendered)/2,rendered)
	image_view.position=world_rect.position
	image_view.size=rendered
	location_panel.position=world_rect.position+Vector2(24,22)
	menu.position=world_rect.position+Vector2(rendered.x-menu.get_combined_minimum_size().x-24,24)
	controls.position=world_rect.position+Vector2((rendered.x-controls.get_combined_minimum_size().x)/2,rendered.y-64)
	interaction_panel.position=world_rect.position+Vector2((rendered.x-interaction_panel.get_combined_minimum_size().x)/2,rendered.y-126)
	toast.position=world_rect.position+Vector2(rendered.x-toast.get_combined_minimum_size().x-28,rendered.y-102)
	dialog.size=Vector2(620,0)
	dialog.position=world_rect.position+Vector2((rendered.x-620)/2,rendered.y-285)
	help_panel.size=Vector2(530,0)
	help_panel.position=(available-Vector2(530,440))/2

func load_map(id: String, at: Vector2=Vector2(INF,INF)) -> void:
	if current_world!=null:
		world_root.remove_child(current_world)
		current_world.queue_free()
	for npc in npcs:
		npc.queue_free()
	npcs.clear()
	var data=read_data("res://content/maps/"+id+".json")
	current_world=World.new()
	world_root.add_child(current_world)
	current_world.build(data)
	map_id=id
	var spawn=Vector2(data.spawn[0],data.spawn[1]) if not is_finite(at.x) else at
	player.position=Vector3(spawn.x,0,spawn.y)
	player.velocity=Vector3.ZERO
	camera_target=player.position
	for npc_data in current_world.npc_definitions:
		var npc=Actor.new()
		npc.name=npc_data.id
		npc.configure(read_data("res://content/characters/"+npc_data.character+".json"))
		npc.position=Vector3(npc_data.at[0],0,npc_data.at[1])
		world_root.add_child(npc)
		npcs.append(npc)
		current_world.interactions.append({"id":npc_data.id,"title":npc.definition.display_name,"lines":npc_data.dialogue,"position":npc.position,"actor":npc})
	location_title.text=data.display_name
	location_subtitle.text=data.subtitle
	exit_cooldown=.8
	nearest={}
	_layout()

func _process(delta: float) -> void:
	if player==null:
		return
	player.input_enabled=not dialog.visible and not help_panel.visible
	var offset=config.camera_focus_offset
	var focus=player.position+Vector3(offset[0],offset[1],offset[2]) if not gallery_mode else Vector3(.75,.7,0)
	camera_target=camera_target.lerp(focus,1-exp(-delta*8))
	camera.position=camera_target+camera_offset
	camera.look_at(camera_target,Vector3.UP)
	var step=camera.size/float(world_view.size.y)
	for axis in [camera.basis.x,camera.basis.y]:
		var coordinate=camera.position.dot(axis)
		camera.position+=axis*(snappedf(coordinate,step)-coordinate)
	nearest={}
	var distance=float(config.interaction_distance)
	for target in current_world.interactions:
		var test_distance=player.position.distance_to(target.position)
		if test_distance<distance:
			distance=test_distance
			nearest=target
	interaction_panel.visible=not nearest.is_empty() and player.input_enabled
	if interaction_panel.visible:
		interaction_label.text="E  ·  "+("Talk" if nearest.actor!=null else "Read")
	toast_time=maxf(0,toast_time-delta)
	toast.visible=toast_time>0
	exit_cooldown=maxf(0,exit_cooldown-delta)
	if exit_cooldown<=0 and player.input_enabled:
		for exit in current_world.definition.exits:
			var r=exit.rect
			if Rect2(r[0],r[1],r[2],r[3]).has_point(Vector2(player.position.x,player.position.z)):
				load_map(exit.target,Vector2(exit.spawn[0],exit.spawn[1]))
				break
	_layout()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if dialog.visible:
			advance_dialogue()
		elif not help_panel.visible:
			open_nearest()
	elif event.is_action_pressed("save_game"):
		save_game()
	elif event.is_action_pressed("load_game"):
		load_game()
	elif event.is_action_pressed("help") or (event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE):
		if dialog.visible:
			dialog.visible=false
		else:
			toggle_help()
	elif event.is_action_pressed("fullscreen"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_WINDOWED else DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func open_nearest() -> void:
	if nearest.is_empty():
		return
	dialog_title.text=nearest.title
	dialog_lines=nearest.lines
	dialog_index=0
	dialog.visible=true
	player.input_enabled=false
	player.play_clip("interact")
	if nearest.actor!=null:
		var toward=player.position-nearest.actor.position
		nearest.actor.visual.rotation.y=atan2(toward.x,toward.z)
	_show_line()

func _show_line() -> void:
	dialog_text.text=dialog_lines[dialog_index]
	dialog_next.text="Close  ·  E" if dialog_index==dialog_lines.size()-1 else "Continue  ·  E"

func advance_dialogue() -> void:
	dialog_index+=1
	if dialog_index>=dialog_lines.size():
		dialog.visible=false
	else:
		_show_line()

func toggle_help() -> void:
	help_panel.visible=not help_panel.visible
	dialog.visible=false

func set_resolution(width: int) -> void:
	world_view.size=Vector2i(width,int(width*9/16))
	view_button.text="Fine pixels" if width==640 else "Chunky pixels"
	_layout()

func toggle_resolution() -> void:
	set_resolution(320 if world_view.size.x==640 else 640)

func save_data() -> Dictionary:
	return {"version":1,"map":map_id,"position":[player.position.x,player.position.z],"facing":player.visual.rotation.y,"resolution":world_view.size.x}

func save_game() -> void:
	notify("Your place is saved." if Save.write(save_data())==OK else "Could not save your place.")

func apply_save(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var test_world=World.new()
	test_world.definition=read_data("res://content/maps/"+data.map+".json")
	var b=test_world.definition.bounds
	test_world.bounds=Rect2(b[0],b[1],b[2]-b[0],b[3]-b[1])
	var at=Vector3(data.position[0],0,data.position[1])
	var safe=test_world.safe_position(at)
	test_world.free()
	if not safe:
		return false
	dialog.visible=false
	help_panel.visible=false
	load_map(data.map,Vector2(at.x,at.z))
	player.visual.rotation.y=float(data.get("facing",0))
	set_resolution(int(data.get("resolution",640)))
	return true

func load_game() -> void:
	notify("Welcome back." if apply_save(Save.read()) else "No valid saved place yet.")

func notify(text: String) -> void:
	toast.text=text
	toast_time=3.0

func _verify() -> void:
	var suite=load("res://scripts/verification.gd").new()
	await suite.run(self)

func _capture(directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var arguments=OS.get_cmdline_user_args()
	var view="all"
	if "--capture-view" in arguments:
		view=arguments[arguments.find("--capture-view")+1]
	if view=="characters":
		await _capture_characters(directory)
		print("CAPTURE_OK "+directory)
		get_tree().quit()
		return
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory+"/coastal-game.png")
	world_view.get_texture().get_image().save_png(directory+"/coastal-world.png")
	player.position=Vector3(2,0,1.55)
	await get_tree().create_timer(.2).timeout
	open_nearest()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory+"/dialogue-game.png")
	dialog.visible=false
	load_map("village_green",Vector2(0,3.5))
	await get_tree().create_timer(.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory+"/village-game.png")
	set_resolution(320)
	await get_tree().create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory+"/chunky-game.png")
	set_resolution(640)
	var frame_times:Array=[]
	var previous=Time.get_ticks_usec()
	for i in range(180):
		await get_tree().process_frame
		var now=Time.get_ticks_usec()
		frame_times.append((now-previous)/1000.0)
		previous=now
	frame_times.sort()
	var total=0.0
	for value in frame_times:
		total+=value
	var result={"average_fps":180000.0/total,"frame_ms_p50":frame_times[90],"frame_ms_p95":frame_times[171],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"renderer":"Compatibility","godot":Engine.get_version_info().string,"sample_frames":180,"loading_excluded":true}
	var file=FileAccess.open(directory+"/render-metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	if view=="all":
		await _capture_characters(directory)
	print("CAPTURE_OK "+directory)
	get_tree().quit()

func _capture_characters(directory: String) -> void:
	gallery_mode=true
	current_world.visible=false
	for npc in npcs:
		npc.visible=false
	player.position=Vector3(-.85,0,0)
	camera.size=4.4
	camera_offset=Vector3(0,7,13)
	var variant=Actor.new()
	variant.configure(read_data("res://content/characters/keeper.json"))
	variant.position=Vector3(1.7,0,0)
	world_root.add_child(variant)
	await get_tree().create_timer(.8).timeout
	await RenderingServer.frame_post_draw
	world_view.get_texture().get_image().save_png(directory+"/character-kit.png")
	player.visual.rotation.y=PI
	await get_tree().create_timer(.2).timeout
	await RenderingServer.frame_post_draw
	world_view.get_texture().get_image().save_png(directory+"/character-back.png")
	player.controllable=false
	player.animator.play(player.clips.walk_loop,0.0)
	for view in [{"name":"front","angle":0},{"name":"right","angle":PI/2},{"name":"back","angle":PI},{"name":"left","angle":PI*1.5}]:
		player.visual.rotation.y=view.angle
		player.animator.seek(.20,true)
		player.animator.pause()
		await RenderingServer.frame_post_draw
		world_view.get_texture().get_image().save_png(directory+"/walk-"+view.name+".png")
