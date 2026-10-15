extends Control
const World = preload("res://scripts/world.gd")
const EnvironmentArt=preload("res://scripts/environment_art.gd")
const Actor = preload("res://scripts/actor.gd")
const WorldPacks=preload("res://scripts/world_pack.gd")
const Save = preload("res://scripts/save_store.gd")
const Slime = preload("res://scripts/slime.gd")
const Progression=preload("res://scripts/progression.gd")
const SkillTree=preload("res://scripts/skill_tree.gd")
var progression=Progression.new()
var skill_tree: Control
var title_screen: Control
var xp_label: Label
var xp_bar: ProgressBar
const Inventory=preload("res://scripts/inventory.gd")
const Conversation=preload("res://scripts/conversation.gd")
var monster_cores=preload("res://scripts/monster_cores.gd").new()
var magic_items=preload("res://scripts/magic_items.gd").new()
var alpha2=preload("res://scripts/alpha2_campaign.gd").new()
var alpha2_import_mode="alpha"
var alpha2_import_path="" # Private fixture override; never populated by normal gameplay.
var goblin_campaign=preload("res://scripts/goblin_campaign.gd").new()
const GoblinEnemy=preload("res://scripts/goblin_enemy.gd")
const ForestEnemy=preload("res://scripts/forest_enemy.gd")
const BetaEnemy=preload("res://scripts/beta_enemy.gd")
const BetaHero=preload("res://scripts/beta_hero.gd")
var game_mode="alpha"
const MAGICNOW_KEYS=[KEY_M,KEY_A,KEY_G,KEY_I,KEY_C,KEY_N,KEY_O,KEY_W]
var magicnow_index=0
var magicnow_deadline=0
const WaterWave=preload("res://scripts/water_wave.gd")
var combat_skills=preload("res://scripts/combat_skills.gd").new()
var sea_dragon:Node3D
const SeaDragon=preload("res://scripts/mana_sea_dragon.gd")
const WaterLance=preload("res://scripts/water_lance.gd")
const WardenRemains=preload("res://scripts/warden_remains.gd")
const RockProjectile=preload("res://scripts/rock_projectile.gd")
var warden_remains: Node3D
var inventory: Control
var conversation: Control
var death_screen: PanelContainer
var death_veil: ColorRect
var quest_label: Label
var well_gift_stage: String="not_started"
var quest_stage="not_started"
var home_intro_complete=true
var defeated_enemies: Array=[]
var projectiles: Array=[]
var config: Dictionary
var world_view: SubViewport
var image_view: TextureRect
var world_root: Node3D
var current_world: Node3D
var player: CharacterBody3D
var npcs: Array = []
var camera_driver=preload("res://scripts/follow_camera.gd").new()
var camera_mode="first_person"
var camera_button:Button
var pause_menu:Control
var environment_settings:Environment
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
var graphics_preset=320
var environment_profile="original"
var character_profile="game"
const StandaloneHero=preload("res://scripts/standalone_hero.gd")
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
var enemies: Array=[]
var wolf_packs=preload("res://scripts/wolf_packs.gd").new()
var enemy_bars: Array=[]
var enemy_states: Dictionary={}
var health_panel: PanelContainer
var health_bar: ProgressBar
var health_label: Label
var weapon_label: Label
var dialogue_choices: VBoxContainer
var dialogue_target: Dictionary={}
var mother_unwrapped=false
var recovering=false
var menagery
var world_browser
var world_id=""
var world_defeats:Array=[]
var respawn_timers:Dictionary={}
var stamina_bar: ProgressBar
var stamina_label: Label
var hud_feedback=preload("res://scripts/hud_feedback.gd").new()
var water_waves: Array=[]
var selected_special_attack="water_sweep"
var mouse_attack_pending=false
var keyboard_thrust_pending=false
var mouse_hold_time=0.0
var parry_after_draw=false

func read_data(path: String) -> Dictionary:
	if path.begins_with("res://content/maps/"):
		return WorldPacks.definition(path.get_file().get_basename(),world_id)
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	if value is Dictionary:
		return value
	push_error("Invalid content definition: "+path)
	return {}

func _ready() -> void:
	alpha2.game=self
	magic_items.game=self
	monster_cores.game=self
	DisplayServer.window_set_title("Coastal Foundation v"+str(read_data("res://content/release.json").version))
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	DisplayServer.window_set_min_size(Vector2i(960,540))
	config=read_data("res://content/platform.json")
	_bind_inputs()
	_build_view()
	camera_driver.configure(self)
	_build_ui()
	set_resolution(int(config.world_resolution[0]))
	player=Actor.new()
	player.name="Player"
	player.controllable=true
	player.walk_speed=config.walk_speed
	player.configure(read_data("res://content/characters/"+config.player_character+".json"))
	world_root.add_child(player)
	# The world is displayed as a texture, not a SubViewportContainer.
	# Route keyboard events from the root window exactly once.
	player.set_process_input(false)
	player.dodge_rejected.connect(notify)
	player.stamina_denied.connect(hud_feedback.denied)
	player.attack_contact.connect(_attack_contact)
	player.ground_slam.connect(_ground_slam)
	player.thrust_stopped.connect(_thrust_stopped)
	player.water_cast.connect(_water_cast)
	player.vertical_water_cast.connect(_vertical_water_cast)
	player.lance_fired.connect(_water_lance_fired)
	player.health_changed.connect(_health_changed)
	player.stamina_changed.connect(_stamina_changed)
	player.parry_succeeded.connect(_parry_succeeded)
	combat_skills.game=self
	player.defeated.connect(_player_defeated)
	_health_changed(player.health,player.max_health)
	_stamina_changed(player.stamina,player.max_stamina)
	get_window().focus_exited.connect(func(): _cancel_mouse_charge();player.clear_dash_attack();magicnow_index=0)
	get_window().focus_exited.connect(func(): camera_driver.orbiting=false; camera_driver.refresh_pointer())
	conversation=Conversation.new()
	add_child(conversation)
	conversation.configure(self)
	inventory=Inventory.new()
	add_child(inventory)
	inventory.configure(self)
	skill_tree=SkillTree.new()
	add_child(skill_tree)
	skill_tree.configure(self)
	skill_tree.reparent(inventory)
	skill_tree.get_child(0).visible=false
	skill_tree.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skill_tree.offset_left=24
	skill_tree.offset_right=-24
	skill_tree.offset_top=84
	skill_tree.offset_bottom=-16
	pause_menu=load("res://scripts/pause_menu.gd").new()
	add_child(pause_menu)
	pause_menu.configure(self)
	menagery=load("res://scripts/menagery.gd").new()
	add_child(menagery)
	magic_items.game=self
	menagery.configure(self)
	world_browser=load("res://scripts/world_browser.gd").new(); add_child(world_browser); world_browser.configure(self)
	title_screen=load("res://scripts/title_screen.gd").new()
	add_child(title_screen)
	title_screen.configure(self)
	monster_cores.configure_ui()
	apply_skill_stats()
	update_progression_ui()
	camera_driver.set_mode(camera_mode)
	var launch_args=OS.get_cmdline_user_args()
	if "--art-profile" in launch_args:
		environment_profile=launch_args[launch_args.find("--art-profile")+1]
		if environment_profile=="darkwood": set_resolution(0)
	if DisplayServer.get_name()!="headless" and "--verify" not in launch_args and "--capture" not in launch_args:
		environment_profile="darkwood"
		set_resolution(0)
	load_map("coastal_path" if "--verify" in launch_args or "--capture" in launch_args else config.start_map)
	resized.connect(_layout)
	_layout()
	var args=OS.get_cmdline_user_args()
	if "--verify" in args:
		camera_driver.set_mode("overhead")
		call_deferred("_verify")
	elif "--capture" in args:
		camera_driver.set_mode("overhead")
		call_deferred("_capture",args[args.find("--capture")+1])
	else:
		if game_mode=="alpha" and DisplayServer.get_name()!="headless": game_mode="alpha2"
		title_screen.show_menu()
	if "--play-world" in args and args.find("--play-world")+1<args.size(): start_world(args[args.find("--play-world")+1])

func start_new_game(show_wakeup:bool=true) -> void:
	var imported={}
	if game_mode=="alpha2":
		var source=alpha2_import_path if not alpha2_import_path.is_empty() else "user://beta-save-v1.json" if alpha2_import_mode=="beta" else "user://save-v1.json"
		imported=Save.read(source)
		if imported.get("game_mode","alpha")!=alpha2_import_mode: imported={}
	cancel_sea_dragon()
	if game_mode in ["beta","alpha2"]: environment_profile="darkwood"; character_profile="game"
	world_id=""; world_defeats.clear(); respawn_timers.clear()
	if world_browser!=null: world_browser.visible=false
	set_resolution(0 if environment_profile=="darkwood" else int(config.world_resolution[0]))
	conversation.close()
	inventory.close()
	skill_tree.close()
	dialog.visible=false
	help_panel.visible=false
	dialogue_choices.visible=false
	death_screen.visible=false
	death_veil.visible=false
	recovering=false
	mother_unwrapped=false
	home_intro_complete=false
	quest_stage="not_started"
	well_gift_stage="not_started"
	magicnow_index=0
	magic_items.reset()
	monster_cores.reset()
	goblin_campaign.reset()
	alpha2.reset()
	defeated_enemies.clear()
	progression.restore({"tree_version":2,"xp":0,"learned":[]})
	selected_special_attack="water_sweep"
	player.heavy_style="overhead"
	apply_skill_stats()
	update_progression_ui()
	player.set_sword_equipped(true)
	player.set_sword_drawn(false)
	player.restore_health(player.max_health)
	player.restore_stamina(player.max_stamina)
	player.invulnerability=0
	player.shift_pending=false
	player.visual.rotation.y=0
	gallery_mode=false
	pause_menu.visible=false
	if camera_mode!="overhead": camera_driver.recenter()
	if game_mode=="alpha2":
		alpha2.start(imported)
		camera_driver.set_mode("first_person")
		player.restore_health(player.max_health);player.restore_stamina(player.max_stamina)
	load_map("a2_haven" if game_mode=="alpha2" else "beta_meadow" if game_mode=="beta" else config.start_map,Vector2(INF,INF),true)
	title_screen.visible=false
	toast_time=0
	if game_mode=="alpha2": notify("THE HOLLOW BELL · Character copied from "+alpha2_import_mode.capitalize()+" save. Speak to Mother." if not imported.is_empty() else "THE HOLLOW BELL · No usable import save found; starting with Dodge, Jump and three remedies. Speak to Mother.")
	if show_wakeup and game_mode=="alpha":
		dialog_title.text="A new morning"
		dialog_lines=["You wake to gulls outside your upstairs window and the smell of bread from below. Mother is tending the hearth. Talk to her before heading out."]
		dialog_index=0
		dialogue_target={}
		dialog.visible=true
		_show_line()
	_refresh_simulation()

func start_saved_game(path:String="user://save-v1.json") -> bool:
	var data=Save.read(path)
	if data.is_empty() or not apply_save(data):
		title_screen.status.text="This save could not be loaded. You can start a new game; the saved file will be kept."
		return false
	title_screen.visible=false
	_refresh_simulation()
	notify("Welcome back.")
	return true

func _bind_inputs() -> void:
	var bindings={"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN],"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"skills":[KEY_P],"inventory":[KEY_I],"pause":[KEY_ESCAPE],"sprint":[KEY_SHIFT],"dodge":[KEY_CTRL],"dash":[KEY_T],"jump":[KEY_SPACE],"camera_mode":[],"camera_recenter":[KEY_V],"interact":[KEY_E,KEY_ENTER],"save_game":[KEY_F5],"load_game":[KEY_F9],"help":[KEY_H],"fullscreen":[KEY_F11]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event=InputEventKey.new()
			event.physical_keycode=key
			InputMap.action_add_event(action,event)
	for action in {"draw_sword":KEY_R,"light_attack":KEY_J,"heavy_attack":KEY_K,"parry":KEY_F,"dialogue_choice":KEY_1,"water_attack":KEY_Q}:
		InputMap.add_action(action)
		var key=InputEventKey.new()
		key.physical_keycode={"draw_sword":KEY_R,"light_attack":KEY_J,"heavy_attack":KEY_K,"parry":KEY_F,"dialogue_choice":KEY_1,"water_attack":KEY_Q}[action]
		InputMap.action_add_event(action,key)

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
	world_view.msaa_3d=Viewport.MSAA_2X
	add_child(world_view)
	world_root=Node3D.new()
	world_view.add_child(world_root)
	var environment=WorldEnvironment.new()
	var env=Environment.new()
	environment_settings=env
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("#a1b8b7")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("#d8e0c8")
	env.ambient_light_energy=.32
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	environment.environment=env
	world_root.add_child(environment)
	var light=DirectionalLight3D.new()
	light.name="WorldSun"
	light.rotation_degrees=Vector3(-58,-28,0)
	light.light_color=Color("#fff9ef")
	light.light_energy=.55
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

func bounded_camera_target(target: Vector3) -> Vector3:
	# Orthographic frustum projected onto ground; leave one pixel inside the map.
	var aspect=float(world_view.size.x)/world_view.size.y
	var vertical_slope=camera_offset.y/camera_offset.length()
	var pixel_padding=4.0/world_view.size.y
	camera.size=minf(camera.size,minf(current_world.bounds.size.x/(aspect+pixel_padding),current_world.bounds.size.y/(1.0/vertical_slope+pixel_padding)))
	var half_height=camera.size*.5
	var half_width=half_height*aspect
	var ground_depth=half_height/(camera_offset.y/camera_offset.length())
	var b=current_world.bounds
	var pad=camera.size/world_view.size.y*2
	var shift=Vector2(camera_offset.x,camera_offset.z)*(target.y/maxf(camera_offset.y,.01))
	target.x=clampf(target.x-shift.x,b.position.x+half_width+pad,b.end.x-half_width-pad)+shift.x
	target.z=clampf(target.z-shift.y,b.position.y+ground_depth+pad,b.end.y-ground_depth-pad)+shift.y
	return target

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
	hud_feedback.configure(self)
	location_panel=panel(self)
	var location=VBoxContainer.new()
	location.add_theme_constant_override("separation",3)
	location_panel.add_child(location)
	location_title=label("Coastal Path",25)
	location_subtitle=label("The village by the sea",15,Color("#c3c7ad"))
	location.add_child(location_title)
	location.add_child(location_subtitle)
	location_subtitle.hide()
	health_panel=panel(self)
	var health_layout=VBoxContainer.new()
	health_panel.add_child(health_layout)
	health_label=label("HEALTH  100 / 100",21,Color("#fff0ed"))
	health_layout.add_child(health_label)
	health_bar=_make_health_bar(Color("#f26772"),300,30)
	health_layout.add_child(health_bar)
	stamina_label=label("STAMINA  100 / 100",18,Color("#defff2"))
	health_layout.add_child(stamina_label)
	stamina_bar=_make_health_bar(Color("#55e2bc"),300,24)
	health_layout.add_child(stamina_bar)
	weapon_label=label("Sword sheathed · R to draw",14,Color("#c3c7ad"))
	health_layout.add_child(weapon_label)
	weapon_label.hide()
	menu=HBoxContainer.new()
	menu.add_theme_constant_override("separation",8)
	add_child(menu)
	view_button=button("Fine pixels",toggle_resolution)
	camera_button=null
	menu.add_child(button("Inventory [I]",toggle_inventory))
	menu.add_child(button("Pause [Esc]",toggle_pause))
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
	dialogue_choices=VBoxContainer.new()
	dialogue_layout.add_child(dialogue_choices)
	dialogue_choices.add_child(button("1  ·  Could you take off the arm wrap?",_unwrap_mother))
	dialogue_choices.visible=false
	dialogue_layout.add_child(dialog_next)
	help_panel=panel(self)
	help_panel.visible=false
	var help=VBoxContainer.new()
	help_panel.add_child(help)
	help.add_theme_constant_override("separation",14)
	help.add_child(label("A sword too heavy",27,Color("#e8d0a5")))
	help.add_child(label("WASD / arrows    Move\nMouse    Look (first-person gameplay)\nV    Recenter view\nHold Shift    Sprint / Rush with the sword drawn\nCtrl / Tap Shift    Dodge (unlock in Form)\nT (hold/release)    Dash (learn and equip in Form)\nSpace    Jump (learn and equip in Form)\nE / Enter    Talk / Continue\nR    Draw or sheathe the sword\nTap Left-click / J    Light swing\nTap again during a swing    Return cut, then spin\nHold Left-click / K    Equipped heavy attack\nRight-click / F    Timed parry\nQ    Equipped water attack (unlock in Mana; equip in Inventory)\nI    Inventory       P    Level Up\nF5 / F9    Save / Load\nF11    Fullscreen       H    Help       Esc    Pause / Close\n\nRush into a swing for a faster wind-up.\nFace the slime and parry just as its lunge lands.\nSlime Forest is south; Mother is by the west cottage.",17))
	help.add_child(button("Return to the path",toggle_help))
	_build_story_ui()

func _build_story_ui() -> void:
	xp_label=label("",15,Color("#c8b3ed"))
	health_panel.get_child(0).add_child(xp_label)
	xp_bar=_make_health_bar(Color("#a58bd5"),255,6)
	health_panel.get_child(0).add_child(xp_bar)
	quest_label=label("",15,Color("#e9d8ac"))
	quest_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	quest_label.custom_minimum_size=Vector2(255,0)
	health_panel.get_child(0).add_child(quest_label)
	quest_label.hide()
	death_veil=ColorRect.new()
	death_veil.color=Color(0.025,.045,.04,.65)
	death_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_veil.z_index=11
	death_veil.visible=false
	add_child(death_veil)
	death_screen=panel(self)
	death_screen.z_index=12
	death_screen.visible=false
	death_screen.add_theme_stylebox_override("panel",style(Color("#172423fa"),Color("#bd8368"),12))
	var layout=VBoxContainer.new()
	layout.add_theme_constant_override("separation",20)
	death_screen.add_child(layout)
	layout.add_child(label("Your journey falters",32,Color("#e5b598")))
	var message=label("You fell in the forest. Rest in the village square, then continue your journey.

Recovered components and defeated creatures are kept.",20)
	message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size=Vector2(460,0)
	layout.add_child(message)
	layout.add_child(button("Wake in the village square",respawn_player))

func _layout() -> void:
	if image_view==null:
		return
	var available=get_viewport_rect().size
	if graphics_preset==0:
		var native_scale=minf(available.x/16.0,available.y/9.0)
		var native_size=Vector2i(floori(native_scale*16),floori(native_scale*9))
		if world_view.size!=native_size:
			world_view.size=native_size
	var factor=maxi(1,int(floor(min(available.x/world_view.size.x,available.y/world_view.size.y))))
	var rendered=Vector2(world_view.size)*factor
	if world_view.size.x>=960:
		# Detailed mode fills the window while the legacy pixel presets retain integer scaling.
		rendered=Vector2(world_view.size)*minf(available.x/world_view.size.x,available.y/world_view.size.y)
	world_rect=Rect2((available-rendered)/2,rendered)
	image_view.position=world_rect.position
	image_view.size=rendered
	location_panel.position=world_rect.position+Vector2(24,22)
	health_panel.position=world_rect.position+Vector2(24,84)
	for child in menu.get_children():
		child.add_theme_font_size_override("font_size",14 if rendered.x<1150 else 17)
	menu.position=world_rect.position+Vector2(rendered.x-menu.get_combined_minimum_size().x-24,24)
	interaction_panel.position=world_rect.position+Vector2((rendered.x-interaction_panel.get_combined_minimum_size().x)/2,rendered.y-70)
	toast.custom_minimum_size.x=minf(620,rendered.x-48)
	toast.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast.position=world_rect.position+Vector2((rendered.x-toast.get_combined_minimum_size().x)/2,rendered.y-140)
	dialog.size=Vector2(620,0)
	dialog.position=Vector2(available.x-644,110)
	help_panel.size=Vector2(530,0)
	help_panel.position=(available-help_panel.size)/2
	if death_screen!=null:
		death_screen.size=Vector2(520,0)
		death_screen.position=(available-death_screen.size)/2

func load_map(id: String, at: Vector2=Vector2(INF,INF), reset_states: bool=false) -> void:
	goblin_campaign.game=self
	var data=read_data("res://content/maps/"+id+".json")
	if data.is_empty():
		notify("This area is unavailable. Reinstall its world file.")
		return
	cancel_sea_dragon()
	player.slow_sources.clear()
	player.finish_jump()
	if menagery!=null: menagery.forget()
	for projectile in projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	projectiles.clear()
	if reset_states:
		enemy_states.clear()
	for wave in water_waves:
		if is_instance_valid(wave):
			wave.queue_free()
	water_waves.clear()
	_cancel_mouse_charge()
	for enemy in enemies:
		if not reset_states and not enemy.definition.get("transient",false):
			enemy_states[map_id+"/"+enemy.definition.id]=enemy.snapshot()
		world_root.remove_child(enemy)
		enemy.queue_free()
	enemies.clear()
	for bar in enemy_bars:
		bar.root.queue_free()
	enemy_bars.clear()
	if current_world!=null:
		world_root.remove_child(current_world)
		current_world.queue_free()
	for npc in npcs:
		world_root.remove_child(npc)
		npc.queue_free()
	npcs.clear()
	current_world=World.new()
	current_world.environment_profile=environment_profile
	world_root.add_child(current_world)
	current_world.build(data)
	map_id=id
	environment_settings.ambient_light_energy=.16 if data.get("cave",false) else .32
	environment_settings.background_color=Color("#223638" if data.get("cave",false) else "#819a87" if data.get("biome","")=="jungle" else "#a1b8b7")
	environment_settings.fog_light_color=environment_settings.background_color
	EnvironmentArt.configure_lighting(self,data)
	apply_character_art(player)
	if camera_mode=="first_person":
		camera_driver.visuals.rig_id=0
		camera_driver.visuals.prepare(player)
	camera.size=5.0 if data.has("interior") else float(config.camera_size)
	var spawn=Vector2(data.spawn[0],data.spawn[1]) if not is_finite(at.x) else at
	player.ground_world=current_world
	player.position=Vector3(spawn.x,0,spawn.y)
	player.position.y=current_world.ground_height(player.position)
	player.velocity=Vector3.ZERO
	player.knockback=Vector3.ZERO
	for particle in player.scrape_nodes:
		particle.life=0
		particle.node.visible=false
	player.set_sword_drawn(player.sword_drawn)
	player.combo_stage=0
	player.combo_remaining=0
	player.combo_queued=false
	camera_target=player.position+Vector3(0,float(config.follow_camera.focus_height),0) if camera_mode=="follow" else player.position
	camera_driver.orbiting=false
	alpha2.prepare_npcs()
	for npc_data in current_world.npc_definitions:
		var npc=Actor.new()
		npc.name=npc_data.id
		npc.configure(read_data("res://content/characters/"+npc_data.character+".json"))
		EnvironmentArt.actor_quality(npc,environment_profile)
		npc.ground_world=current_world
		npc.position=Vector3(npc_data.at[0],0,npc_data.at[1])
		npc.position.y=current_world.ground_height(npc.position)
		world_root.add_child(npc)
		npcs.append(npc)
		var role=npc_data.get("role","")
		if role in ["mother","a2_mother"]:
			npc.set_arm_wrapped(not mother_unwrapped)
		current_world.interactions.append({"id":npc_data.id,"title":npc.definition.display_name,"lines":npc_data.dialogue,"position":npc.position,"actor":npc,"role":role})
	for enemy_data in data.get("enemies",[]):
		var enemy=load("res://scripts/bellkeeper.gd").new() if enemy_data.kind=="bellkeeper" else BetaEnemy.new() if String(enemy_data.kind).begins_with("beta_") else GoblinEnemy.new() if String(enemy_data.kind).begins_with("goblin_") else Slime.new() if enemy_data.kind=="slime" else ForestEnemy.new()
		enemy.name=enemy_data.id
		var encounter_id=id+"/"+enemy_data.id
		var saved_enemy={"health":0} if encounter_id in defeated_enemies else enemy_states.get(encounter_id,{})
		enemy.configure(enemy_data,player,saved_enemy)
		if not String(enemy_data.kind).begins_with("beta_"): EnvironmentArt.creature_quality(enemy,environment_profile)
		if enemy_data.kind!="slime":
			enemy.game=self
		world_root.add_child(enemy)
		enemies.append(enemy)
		enemy.defeated.connect(func(): _enemy_defeated(encounter_id,enemy_data.kind,enemy))
		if enemy_data.kind=="warden" and enemy.health<=0:
			spawn_warden_remains(enemy.position)
		add_enemy_bar(enemy)
	for encounter in data.get("catalog_enemies",[]):
		var matches=WorldPacks.catalog().monsters.filter(func(entry): return entry.code==encounter.code)
		if matches.is_empty(): continue
		if encounter.get("respawn_seconds",0)>0:
			var point=load("res://scripts/mob_respawn.gd").new()
			point.setup(self,matches[0],encounter,id+"/"+encounter.id)
			current_world.add_child(point)
			continue
		var enemy=spawn_catalog_creature(matches[0],Vector3(encounter.at[0],0,encounter.at[1])); enemy.definition.id=encounter.id
		enemy.configure_placement(encounter)
		var key=id+"/"+encounter.id
		var ledger=world_defeats if not world_id.is_empty() else defeated_enemies
		if key in ledger: enemy.take_damage(99999,Vector3.ZERO)
		enemy.defeated.connect(func():
			if not key in ledger: ledger.append(key); _catalog_enemy_defeated(matches[0].style,matches[0].name,enemy)
		)
	wolf_packs.build(self)
	goblin_campaign.build_map()
	alpha2.build_map()
	if environment_profile=="darkwood": EnvironmentArt._retexture(current_world)
	monster_cores.build_map()
	location_title.text=data.display_name
	location_subtitle.text=data.subtitle
	exit_cooldown=.8
	nearest={}
	_layout()

func spawn_catalog_creature(entry:Dictionary,at:Vector3) -> Node3D:
	var script="res://scripts/queen_slime.gd" if entry.style=="queen_slime" else "res://scripts/menagery_enemy.gd"
	var enemy=load(script).new(); world_root.add_child(enemy); enemy.setup(self,entry,at)
	EnvironmentArt.creature_quality(enemy,environment_profile)
	enemies.append(enemy); add_enemy_bar(enemy)
	enemy.simulation_enabled=player.input_enabled and not gallery_mode
	return enemy

func impact_blocked(from:Vector3,to:Vector3) -> bool:
	var ray=PhysicsRayQueryParameters3D.create(from+Vector3.UP*.5,to+Vector3.UP*.5,1)
	return not player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func retire_transient(enemy:Node3D) -> void:
	if not is_instance_valid(enemy): return
	enemies.erase(enemy)
	for bar in enemy_bars.duplicate():
		if bar.enemy==enemy: bar.root.queue_free(); enemy_bars.erase(bar)
	enemy.queue_free()

func add_enemy_bar(enemy:Node3D) -> void:
	var root=VBoxContainer.new()
	root.visible=false
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation",2)
	add_child(root)
	var title=label("Forest slime",13,Color("#f0edce"))
	title.mouse_filter=Control.MOUSE_FILTER_IGNORE
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color",Color("#183126"))
	title.add_theme_constant_override("shadow_offset_x",1)
	title.add_theme_constant_override("shadow_offset_y",1)
	root.add_child(title)
	var bar=_make_health_bar(Color("#98be68"),100,9)
	root.add_child(bar)
	enemy_bars.append({"root":root,"title":title,"bar":bar,"enemy":enemy})

func _process(delta: float) -> void:
	if player==null:
		return
	player.input_enabled=not dialog.visible and not conversation.visible and not inventory.visible and not skill_tree.visible and not help_panel.visible and (pause_menu==null or not pause_menu.visible) and not recovering and (title_screen==null or not title_screen.visible) and (menagery==null or not menagery.opened) and (world_browser==null or not world_browser.visible) and (monster_cores.warning==null or not monster_cores.warning.visible)
	if not player.input_enabled:
		_cancel_mouse_charge()
	for enemy in enemies:
		enemy.simulation_enabled=player.input_enabled and not gallery_mode
	camera_driver.refresh_pointer()
	if camera_mode!="overhead" and not gallery_mode:
		camera_driver.update(delta)
	else:
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL
		var offset=[0,0,-.7] if current_world.definition.has("interior") else config.camera_focus_offset
		var focus=player.position+Vector3(offset[0],offset[1],offset[2]) if not gallery_mode else Vector3(.75,.7,0)
		camera_target=camera_target.lerp(focus,1-exp(-delta*8))
		if not gallery_mode:
			camera_target=bounded_camera_target(camera_target)
		camera.position=camera_target+camera_offset
		camera.look_at(camera_target,Vector3.UP)
		if graphics_preset!=0:
			var step=camera.size/float(world_view.size.y)
			for axis in [camera.basis.x,camera.basis.y]:
				var coordinate=camera.position.dot(axis)
				camera.position+=axis*(snappedf(coordinate,step)-coordinate)
	goblin_campaign.tick()
	alpha2.tick(delta)
	current_world.update_interior_walls(camera.position,player.position,camera_mode)
	if current_world.definition.get("cave",false):
		for piece in current_world.get_children():
			if piece is MeshInstance3D and String(piece.name).begins_with("CaveCeiling"): piece.visible=camera_mode!="overhead" and camera.position.y<3.1
			elif piece is MeshInstance3D and String(piece.name).begins_with("CaveWall"): piece.visible=camera_mode!="overhead" or piece.position.z<player.position.z-1
	nearest={}
	var distance=float(config.interaction_distance)
	for target in current_world.interactions:
		var test_distance=player.position.distance_to(target.position)
		if test_distance<distance:
			distance=test_distance
			nearest=target
	interaction_panel.visible=not nearest.is_empty() and player.input_enabled and player.state=="free"
	if interaction_panel.visible:
		if nearest.has("travel"):
			interaction_label.text="E  ·  "+nearest.title
		elif map_id=="village_green" and nearest.id=="well":
			interaction_label.text="E  ·  Wishing well"
		elif nearest.has("loot_core"):
			interaction_label.text="E  ·  "+nearest.title
		elif nearest.id=="warden_remains":
			interaction_label.text="E  ·  Loot aether core" if warden_remains.component.visible else "E  ·  Search empty remains"
		else:
			interaction_label.text="E  ·  "+(nearest.title if nearest.has("campaign_action") or nearest.has("a2_action") else "Talk" if nearest.actor!=null else "Read")
	hud_feedback.update(delta)
	toast_time=maxf(0,toast_time-delta)
	toast.visible=toast_time>0
	exit_cooldown=maxf(0,exit_cooldown-delta)
	if exit_cooldown<=0 and player.input_enabled and player.state=="free":
		for exit in current_world.definition.exits:
			if exit.get("interact",false): continue
			var r=exit.rect
			if Rect2(r[0],r[1],r[2],r[3]).has_point(Vector2(player.position.x,player.position.z)):
				if map_id=="home_downstairs" and exit.id=="front_door" and not home_intro_complete:
					notify("Say good morning to Mother before leaving.")
					exit_cooldown=2
					break
				if exit.target=="herb_glade" and not "slime_forest/forest_slime" in defeated_enemies:
					notify("Defeat the forest slime before taking the deeper trail.")
					exit_cooldown=2
					break
				if not alpha2.can_travel(exit): exit_cooldown=2;break
				load_map(exit.target,Vector2(exit.spawn[0],exit.spawn[1]))
				break
	_update_combat_ui()
	_layout()

func _unhandled_key_input(event: InputEvent) -> void:
	if world_browser!=null and world_browser.visible:
		if event.is_action_pressed("pause"): world_browser.close()
		return
	if title_screen!=null and title_screen.visible and not event.is_action_pressed("fullscreen"):
		return
	if event is InputEventKey and event.echo:
		return
	if is_instance_valid(sea_dragon) and sea_dragon.active and (event.is_action_pressed("interact") or event.is_action_pressed("camera_recenter") or event.is_action_pressed("draw_sword") or event.is_action_pressed("water_attack") or event.is_action_pressed("light_attack") or event.is_action_pressed("heavy_attack") or event.is_action_pressed("parry")): return
	if event.is_action_pressed("dialogue_choice") and dialogue_choices.visible:
		_unwrap_mother()
	elif event.is_action_pressed("camera_mode"):
		if player.input_enabled: toggle_camera()
	elif event.is_action_pressed("camera_recenter"):
		if player.input_enabled and camera_mode!="overhead": camera_driver.recenter()
	elif event.is_action_pressed("skills"):
		toggle_skills()
	elif event is InputEventKey and event.physical_keycode==KEY_M and event.pressed:
		menagery.toggle()
	elif event.is_action_pressed("inventory"):
		toggle_inventory()
	elif event.is_action_pressed("draw_sword"):
		player.toggle_sword()
	elif event.is_action_pressed("water_attack"):
		if player.input_enabled:
			var started=player.begin_water(true) if selected_special_attack=="undertow" else begin_sea_dragon() if selected_special_attack=="sea_dragon" else player.begin_water_lance() if selected_special_attack=="water_lance" else player.begin_water()
			if not started:
				if not player.water_unlocked or not player.sword_drawn: notify("Learn the special in Skills and draw the sword.")
	elif event.is_action_pressed("light_attack"):
		_request_attack("light")
	elif event.is_action_pressed("heavy_attack"):
		if player.heavy_style=="charge_thrust" and player.thrust_unlocked:
			keyboard_thrust_pending=player.begin_charge()
		else:
			_request_attack("heavy")
	elif event.is_action_pressed("parry"):
		_request_parry()
	elif event.is_action_pressed("interact"):
		if recovering or pause_menu.visible or menagery.opened:
			return
		if skill_tree.visible:
			skill_tree.close()
		elif inventory.visible:
			inventory.close()
		elif conversation.visible:
			conversation.close()
		elif dialog.visible:
			advance_dialogue()
		elif not help_panel.visible:
			open_nearest()
	elif event.is_action_pressed("save_game"):
		if pause_menu.visible: pause_menu.save_current()
		else: save_game()
	elif event.is_action_pressed("load_game"):
		if pause_menu.visible: pause_menu.load_saved()
		else: load_game()
	elif event.is_action_pressed("pause"):
		if menagery.opened:
			menagery.close()
			return
		elif recovering:
			return
		if inventory.visible:
			inventory.close()
		elif conversation.visible:
			conversation.close()
		elif dialog.visible:
			dialog.visible=false
		elif help_panel.visible:
			help_panel.visible=false
		else:
			toggle_pause()
	elif event.is_action_pressed("help"):
		toggle_help()
	elif event.is_action_pressed("fullscreen"):
		toggle_fullscreen()

func toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()!=DisplayServer.WINDOW_MODE_WINDOWED else DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func toggle_pause() -> void:
	if menagery!=null: menagery.close()
	if recovering or title_screen.visible: return
	if pause_menu.visible:
		pause_menu.close()
		return
	_cancel_mouse_charge()
	conversation.close()
	inventory.close()
	dialog.visible=false
	help_panel.visible=false
	pause_menu.open()

func open_nearest() -> void:
	if nearest.is_empty() or player.state!="free" or recovering:
		return
	if nearest.has("loot_core"): monster_cores.collect(int(nearest.loot_core)); return
	if alpha2.interact(nearest): return
	if goblin_campaign.interact(nearest): return
	if nearest.has("travel"):
		var route=nearest.travel
		if not alpha2.can_travel(route): return
		if map_id=="home_downstairs" and route.id=="front_door" and not home_intro_complete:
			notify("Say good morning to Mother before leaving.")
			return
		load_map(route.target,Vector2(route.spawn[0],route.spawn[1]))
		return
	dialogue_target=nearest
	if nearest.actor!=null or (map_id=="village_green" and nearest.id=="well"):
		var target=nearest.duplicate()
		if nearest.id=="well": target["role"]="well"
		conversation.show_character(target)
		player.input_enabled=false
		_cancel_mouse_charge()
		return
	if nearest.id=="warden_remains":
		loot_warden_core()
		return
	dialog_title.text=nearest.title
	dialog_lines=nearest.lines
	if nearest.get("role","")=="mother" and mother_unwrapped:
		dialog_lines=["A crude first attempt, bolts and all. The crack in that flame gem has been there for years.","Mind your footing in the forest. Your sword will carry you farther than you expect."]
	dialog_index=0
	dialog.visible=true
	player.input_enabled=false
	interaction_panel.visible=false
	if not player.sword_drawn:
		player.play_clip("interact")
	if nearest.actor!=null:
		var toward=player.position-nearest.actor.position
		nearest.actor.visual.rotation.y=0.0 if nearest.get("role","")=="mother" else atan2(toward.x,toward.z)
	_show_line()

func _show_line() -> void:
	dialog_text.text=dialog_lines[dialog_index]
	dialog_next.text="Close  ·  E" if dialog_index==dialog_lines.size()-1 else "Continue  ·  E"
	dialogue_choices.visible=dialogue_target.get("role","")=="mother" and not mother_unwrapped and dialog_index==dialog_lines.size()-1

func advance_dialogue() -> void:
	dialog_index+=1
	if dialog_index>=dialog_lines.size():
		dialog.visible=false
		dialogue_choices.visible=false
	else:
		_show_line()

func toggle_inventory() -> void:
	if menagery!=null: menagery.close()
	if recovering:
		return
	if inventory.visible:
		inventory.close()
		return
	_cancel_mouse_charge()
	if player.state!="free":
		return
	conversation.close()
	skill_tree.close()
	dialog.visible=false
	help_panel.visible=false
	pause_menu.visible=false
	inventory.visible=true
	inventory.show_page("equipment")
	_refresh_simulation()

func toggle_help() -> void:
	if menagery!=null: menagery.close()
	if recovering:
		return
	conversation.close()
	pause_menu.visible=false
	inventory.close()
	skill_tree.close()
	help_panel.visible=not help_panel.visible
	dialog.visible=false
	dialogue_choices.visible=false

func set_resolution(width: int) -> void:
	graphics_preset=width
	if width!=0:
		world_view.size=Vector2i(width,int(width*9/16))
	world_view.msaa_3d=Viewport.MSAA_8X if width==0 else Viewport.MSAA_2X
	image_view.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR if width==0 or width>=960 else CanvasItem.TEXTURE_FILTER_NEAREST
	view_button.text={0:"Full resolution",960:"Detailed",640:"Fine pixels",320:"Chunky pixels"}[width]
	_layout()

func toggle_camera() -> void:
	camera_driver.set_mode("first_person")

func toggle_resolution() -> void:
	set_resolution({960:0,0:640,640:320,320:960}[graphics_preset])

func personal_character_enabled() -> bool:
	return game_mode=="beta" or (environment_profile=="darkwood" and character_profile=="game")

func apply_character_art(target:Node3D) -> void:
	var personal=personal_character_enabled()
	target.set_beta_sword(personal)
	EnvironmentArt.actor_quality(target,"original" if personal else environment_profile)
	if personal: target.set_sword_art(environment_profile)
	StandaloneHero.apply(target,character_profile)
	BetaHero.apply(target,personal)
	magic_items.Visuals.apply(target,magic_items)

func set_environment_profile(profile:String) -> void:
	if profile not in ["original","darkwood"]:
		return
	if player.state!="free":
		notify("Finish the current action before changing world art.")
		return
	if profile==environment_profile:
		if profile=="darkwood" and game_mode=="alpha": camera_driver.set_mode("first_person")
		return
	environment_profile=profile
	set_resolution(0 if profile=="darkwood" else int(config.world_resolution[0]))
	if current_world!=null:
		load_map(map_id,Vector2(player.position.x,player.position.z))
	if profile=="darkwood" and game_mode=="alpha": camera_driver.set_mode("first_person")
	notify("Advanced world graphics enabled." if profile=="darkwood" else "Original environment restored.")

func set_character_profile(profile:String) -> void:
	if game_mode=="beta": return
	if profile not in ["game","standalone"] or profile==character_profile: return
	if player.state!="free":
		notify("Finish the current action before changing character art."); return
	character_profile=profile
	apply_character_art(player)
	if camera_mode=="first_person":
		camera_driver.visuals.rig_id=0
		camera_driver.visuals.prepare(player)
	if profile=="standalone": set_resolution(0)
	inventory.preview.signature="!"
	notify("Standalone character: fixed Blender pose and outfit." if profile=="standalone" else "Animated game character restored.")

func save_data() -> Dictionary:
	# Mode is serialized below and selects a separate Beta file.
	return {"alpha2":alpha2.snapshot(),"game_mode":game_mode,"environment_revision":1,"monster_cores":monster_cores.snapshot(),"magic_items":magic_items.snapshot(),"goblin_campaign":goblin_campaign.snapshot(),"respawn_timers":respawn_timers.duplicate(),"world_id":world_id,"world_defeats":world_defeats.duplicate(),"version":1,"home_layout":2,"home_intro_complete":home_intro_complete,"camera_mode":camera_mode,"first_person_pitch":camera_driver.first_pitch,"camera_yaw":camera_driver.yaw,"camera_pitch":camera_driver.pitch,"camera_distance":camera_driver.distance,"map":map_id,"ground_y":player.position.y,"position":[player.position.x,player.position.z],"facing":player.visual.rotation.y,"resolution":graphics_preset,"environment_profile":environment_profile,"character_profile":character_profile,"health":player.health,"stamina":player.stamina,"sword_drawn":player.sword_drawn,"sword_equipped":player.sword_equipped,"special_attack":selected_special_attack,"heavy_attack":player.heavy_style,"mother_unwrapped":mother_unwrapped,"well_gift_stage":well_gift_stage,"quest_stage":quest_stage,"defeated_enemies":defeated_enemies.duplicate(),"progression":progression.snapshot(),"skill_loadout":{"dash":player.dash_equipped,"jump":player.jump_equipped,"flowing_counter":player.counter_equipped}}

func save_game() -> void:
	if player.state!="free" or recovering:
		notify("Finish the swing before saving.")
		return
	notify("Your place is saved." if Save.write(save_data(),current_save_path())==OK else "Could not save your place.")

func current_save_path() -> String:
	return "user://alpha2-save-v1.json" if game_mode=="alpha2" else "user://beta-save-v1.json" if game_mode=="beta" else WorldPacks.save_path(world_id)

func apply_save(data: Dictionary) -> bool:
	if data.get("special_attack","water_sweep") not in ["water_sweep","water_lance","sea_dragon","undertow"]: return false
	var mode=String(data.get("game_mode","alpha"))
	if not alpha2.valid_mode(mode,data.get("map",""),data.get("world_id","")): return false
	if not alpha2.valid_save(data.get("alpha2",{}),data.get("defeated_enemies",[])): return false
	if data.get("character_profile","game") not in ["game","standalone"]: return false
	if data.is_empty() or data.get("well_gift_stage","not_started") not in ["not_started","coin_ready","potion_owned"]:
		return false
	if not magic_items.valid_save(data.get("magic_items",{})): return false
	if not monster_cores.valid_save(data.get("monster_cores",{}),str(data.get("world_id",""))): return false
	if not goblin_campaign.valid_save(data.get("goblin_campaign",{}),data.get("defeated_enemies",[])): return false
	var test_world=World.new()
	var saved_world=String(data.get("world_id",""))
	test_world.definition=WorldPacks.definition(data.map,saved_world)
	if test_world.definition.is_empty(): test_world.free(); return false
	var b=test_world.definition.bounds
	test_world.bounds=Rect2(b[0],b[1],b[2]-b[0],b[3]-b[1])
	var at=Vector3(data.position[0],float(data.get("ground_y",0)),data.position[1])
	if data.map in ["home_upstairs","home_downstairs"] and int(data.get("home_layout",1))<2:
		var entrance=test_world.definition.spawn
		at=Vector3(entrance[0],0,entrance[1])
	var safe=test_world.safe_position(at)
	test_world.free()
	if not safe:
		return false
	dialog.visible=false
	help_panel.visible=false
	game_mode=mode
	world_id=saved_world; world_defeats=data.get("world_defeats",[]).duplicate(); respawn_timers=data.get("respawn_timers",{}).duplicate()
	environment_profile=String(data.get("environment_profile","darkwood")) if data.get("environment_revision",0)==1 else "darkwood"
	character_profile=String(data.get("character_profile","game"))
	if world_browser!=null: world_browser.visible=false
	home_intro_complete=bool(data.get("home_intro_complete",true))
	mother_unwrapped=bool(data.get("mother_unwrapped",false))
	selected_special_attack=String(data.get("special_attack","water_sweep"))
	player.heavy_style=String(data.get("heavy_attack","overhead"))
	conversation.close()
	inventory.close()
	skill_tree.close()
	magicnow_index=0
	well_gift_stage=data.get("well_gift_stage","not_started")
	quest_stage=data.get("quest_stage","not_started")
	defeated_enemies=data.get("defeated_enemies",[]).duplicate()
	var growth=data.get("progression",{})
	if not data.has("progression"):
		var legacy_xp=80 if quest_stage=="completed" else 0
		for id in defeated_enemies:
			legacy_xp+=35 if "slime" in id else 120 if "warden" in id else 60
		growth={"xp":legacy_xp,"learned":[]}
	if not Progression.valid(growth):
		return false
	if not Progression.valid_loadout(growth,data.get("skill_loadout",{})): return false
	progression.restore(growth)
	player.dash_equipped=bool(data.get("skill_loadout",{}).get("dash",false))
	player.jump_equipped=bool(data.get("skill_loadout",{}).get("jump",false))
	player.counter_equipped=bool(data.get("skill_loadout",{}).get("flowing_counter",false))
	magic_items.restore(data.get("magic_items",{}))
	monster_cores.restore(data.get("monster_cores",{}))
	goblin_campaign.restore(data.get("goblin_campaign",{}))
	alpha2.restore(data.get("alpha2",{}))
	magic_items.migrate_windstep(data.get("goblin_campaign",{}))
	apply_skill_stats()
	update_progression_ui()
	load_map(data.map,Vector2(at.x,at.z),true)
	player.position.y=current_world.ground_height(at)
	player.restore_health(int(data.get("health",player.max_health)))
	player.restore_stamina(float(data.get("stamina",player.max_stamina)))
	player.set_sword_equipped(bool(data.get("sword_equipped",true)))
	player.set_sword_drawn(bool(data.get("sword_drawn",false)))
	player.invulnerability=0
	player.visual.rotation.y=float(data.get("facing",0))
	camera_driver.restore(data)
	set_resolution(0 if not data.has("environment_revision") else int(data.get("resolution",640)))
	return true

func load_game() -> void:
	if player.state!="free" or recovering:
		return
	notify("Welcome back." if apply_save(Save.read(current_save_path())) else "No valid saved place yet.")

func _unhandled_input(event: InputEvent) -> void:
	if monster_cores.warning!=null and monster_cores.warning.visible: return
	if title_screen!=null and title_screen.visible:
		return
	if event is InputEventMouseButton and event.pressed and world_rect.has_point(event.position):
		if event.button_index==MOUSE_BUTTON_LEFT:
			if player.state=="dash_charge":
				if not player.queue_dash_attack() and player.input_enabled and not player.sword_drawn: notify("Draw the sword before queuing a dash attack.")
			elif player.begin_charge():
				mouse_attack_pending=true
				mouse_hold_time=0
			elif player.input_enabled and player.state=="free":
				notify("R to draw the sword." if not player.sword_drawn else "Rest to recover stamina.")
		elif event.button_index==MOUSE_BUTTON_RIGHT:
			_request_parry()

# Observe M normally (its Menagerie shortcut is unchanged), then swallow matching
# prefix presses so I cannot open Inventory halfway through the code.
func _magicnow_input(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	if game_mode!="beta" or not player.input_enabled or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		magicnow_index=0
		return false
	var now=Time.get_ticks_msec()
	if now>magicnow_deadline: magicnow_index=0
	var code=event.keycode if event.keycode!=0 else event.physical_keycode
	if code!=MAGICNOW_KEYS[magicnow_index]:
		magicnow_index=0
		if code!=KEY_M: return false
	magicnow_index+=1
	magicnow_deadline=now+4000
	if magicnow_index==MAGICNOW_KEYS.size():
		magicnow_index=0
		well_gift_stage="potion_owned"
		notify("MAGICNOW: Everfull Experience Potion added. Inventory [I] > Potions.")
	return code!=KEY_M

func _input(event: InputEvent) -> void:
	if player!=null:
		_refresh_simulation()
		if _magicnow_input(event):
			get_viewport().set_input_as_handled()
			return
	if monster_cores.warning!=null and monster_cores.warning.visible:
		if event.is_action_pressed("pause") or event.is_action_pressed("inventory"): monster_cores.close_warning()
		return
	if player!=null:
		_refresh_simulation()
		if event is InputEventKey: player._input(event)
		if camera_driver.handle_input(event):
			get_viewport().set_input_as_handled()
			return
	if event.is_action_released("heavy_attack") and keyboard_thrust_pending:
		keyboard_thrust_pending=false
		if player.input_enabled and player.state=="charge": player.release_charge("heavy")
		else: player.cancel_charge()
		get_viewport().set_input_as_handled()
	# Capture releases even when the pointer has crossed a UI panel since pressing.
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and mouse_attack_pending:
		mouse_attack_pending=false
		if player.input_enabled and world_rect.has_point(event.position) and not event.canceled:
			var kind="heavy" if player.thrust_charging and mouse_hold_time>=float(player.combat.heavy_hold_seconds) else "light"
			if not player.release_charge(kind):
				notify("Not enough stamina for this attack.")
		else:
			player.cancel_charge()
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	_refresh_simulation()
	combat_skills.tick(delta)
	wolf_packs.tick(delta)
	if parry_after_draw:
		if not player.input_enabled or player.state not in ["draw","free"]:
			parry_after_draw=false
		elif player.state=="free":
			parry_after_draw=false
			_request_parry()
	if not mouse_attack_pending:
		return
	if not player.input_enabled or player.state not in ["charge","light","roll","stand"]:
		_cancel_mouse_charge()
		return
	mouse_hold_time+=delta
	if player.state=="charge" and player.thrust_charging: return
	if mouse_hold_time>=float(player.combat.heavy_hold_seconds):
		mouse_attack_pending=false
		if player.state in ["light","roll","stand"]:
			return
		if not player.release_charge("heavy"):
			notify("Not enough stamina for a heavy swing.")

func _refresh_simulation() -> void:
	player.input_enabled=not dialog.visible and not conversation.visible and not inventory.visible and not skill_tree.visible and not help_panel.visible and (pause_menu==null or not pause_menu.visible) and not recovering and (title_screen==null or not title_screen.visible) and (menagery==null or not menagery.opened) and (world_browser==null or not world_browser.visible) and (monster_cores.warning==null or not monster_cores.warning.visible)
	if not player.input_enabled: magicnow_index=0
	camera_driver.refresh_pointer()
	for enemy in enemies:
		enemy.simulation_enabled=player.input_enabled and not gallery_mode

func _cancel_mouse_charge() -> void:
	parry_after_draw=false
	mouse_attack_pending=false
	keyboard_thrust_pending=false
	mouse_hold_time=0
	if player!=null:
		player.cancel_charge()

func _request_parry() -> void:
	_refresh_simulation()
	if not player.input_enabled:
		return
	_cancel_mouse_charge()
	if player.state=="draw":
		parry_after_draw=true
	elif not player.sword_equipped:
		notify("Equip the sword in Inventory [I] before parrying.")
	elif not player.sword_drawn:
		notify("R to draw the sword before parrying.")
	elif player.state!="free":
		notify("Finish the current action before parrying.")
	elif player.state=="free" and not player.begin_parry():
		notify("Rest to recover stamina before parrying.")

func _request_attack(kind: String) -> void:
	if not player.input_enabled:
		return
	if kind=="light" and player.counter_ready():
		player.begin_counter();return
	if not player.sword_drawn:
		notify("R to draw the sword first.")
		return
	if player.state in ["free","light","roll","stand","dash_charge"] and not player.begin_attack(kind):
		notify("Not enough stamina for a "+kind+" swing.")

func _make_health_bar(color: Color, width: int, height: int) -> ProgressBar:
	var bar=ProgressBar.new()
	bar.custom_minimum_size=Vector2(width,height)
	bar.show_percentage=false
	bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var background=StyleBoxFlat.new()
	background.bg_color=Color("#192a24")
	background.border_color=Color("#ddd0a0")
	background.set_border_width_all(1)
	bar.add_theme_stylebox_override("background",background)
	var fill=StyleBoxFlat.new()
	fill.bg_color=color
	fill.border_color=Color("#ead5aa")
	fill.set_border_width_all(1)
	bar.add_theme_stylebox_override("fill",fill)
	return bar

func _health_changed(value: int, maximum: int) -> void:
	health_bar.max_value=maximum
	health_bar.value=value
	health_label.text="HEALTH  %d / %d" % [value,maximum]

func _stamina_changed(value: float, maximum: float) -> void:
	stamina_bar.max_value=maximum
	stamina_bar.value=value
	stamina_label.text="STAMINA  %d / %d" % [ceili(value),int(maximum)]

func _parry_succeeded(enemy: Node3D) -> void:
	combat_skills.parried(enemy)
	magic_items.parried()
	var away=enemy.position-player.position
	away.y=0
	enemy.repel(away,float(player.combat.parry.knockback),float(player.combat.parry.stun_seconds))
	if not (enemy is RockProjectile):
		notify("Parried!")

func _update_combat_ui() -> void:
	for item in enemy_bars:
		var enemy=item.enemy
		var point=enemy.position+Vector3(0,float(enemy.definition.get("label_height",3.4 if enemy.definition.kind=="warden" else 1.35)),0)
		var screen=camera.unproject_position(point)
		item.root.visible=enemy.health>0 and enemy.health<enemy.max_health and enemy.visible and not pause_menu.visible and not skill_tree.visible and not inventory.visible and not conversation.visible and not recovering and not help_panel.visible and not dialog.visible and (menagery==null or not menagery.opened) and (world_browser==null or not world_browser.visible) and (monster_cores.warning==null or not monster_cores.warning.visible) and not camera.is_position_behind(point) and Rect2(Vector2.ZERO,Vector2(world_view.size)).has_point(screen)
		item.root.position=world_rect.position+screen*(world_rect.size/Vector2(world_view.size))-Vector2(50,30)
		item.bar.max_value=enemy.max_health
		item.bar.value=enemy.health
		item.bar.visible=enemy.health>0
		item.title.text={"slime":"Forest slime","boar":"Briar boar","wisp":"Thorn wisp","warden":"Stone warden"}.get(enemy.definition.kind,enemy.definition.get("display_name",enemy.definition.kind))
	quest_label.text=quest_objective()

func _water_cast(origin: Vector3, direction: Vector3) -> void:
	if player.undertow_cast:
		var pull=load("res://scripts/undertow.gd").new();world_root.add_child(pull);pull.configure(self,origin,direction);projectiles.append(pull);return
	water_waves=water_waves.filter(func(wave): return is_instance_valid(wave))
	var wave=WaterWave.new()
	world_root.add_child(wave)
	wave.configure(self,origin,direction,player.combat.water)
	water_waves.append(wave)

func _vertical_water_cast(origin:Vector3,direction:Vector3) -> void:
	water_waves=water_waves.filter(func(wave): return is_instance_valid(wave))
	var wave=load("res://scripts/vertical_water_wave.gd").new();world_root.add_child(wave)
	wave.configure(self,origin,direction,player.combat.water);water_waves.append(wave)

func _water_lance_fired(origin: Vector3, direction: Vector3) -> void:
	projectiles=projectiles.filter(func(item): return is_instance_valid(item))
	var lance=WaterLance.new()
	world_root.add_child(lance)
	lance.configure(self,origin,direction,player.combat.lance,player)
	projectiles.append(lance)

func begin_sea_dragon() -> bool:
	if is_instance_valid(sea_dragon) or camera_mode!="first_person" or not player.begin_dragon_channel(): return false
	projectiles=projectiles.filter(func(item): return is_instance_valid(item))
	sea_dragon=SeaDragon.new();world_root.add_child(sea_dragon)
	sea_dragon.configure(self,player.sword_gem_position(),camera_driver.sample_first_person(0,false),player.combat.sea_dragon)
	projectiles.append(sea_dragon)
	notify("Sea Dragon · mouse to steer · 10 seconds · your body is vulnerable")
	return true

func cancel_sea_dragon() -> void:
	combat_skills.reset()
	if is_instance_valid(sea_dragon): sea_dragon.finish(false,true)
	sea_dragon=null

func special_unlocked(id: String) -> bool:
	if id=="undertow": return progression.has("undertow")
	if id=="sea_dragon": return progression.has("sea_dragon")
	return progression.has("mana_lance") if id=="water_lance" else progression.has("mana")

func select_heavy_attack(id: String) -> void:
	if id not in ["overhead","charge_thrust"] or (id=="charge_thrust" and not progression.has("charge_thrust")): return
	player.heavy_style=id
	inventory.refresh()
	notify("Equipped "+("Driving Thrust" if id=="charge_thrust" else "Overhead Heavy")+" as your heavy attack.")

func select_special_attack(id: String) -> void:
	if id not in ["water_sweep","water_lance","sea_dragon","undertow"] or not special_unlocked(id):
		return
	selected_special_attack=id
	if inventory.visible:
		inventory.refresh()
	if skill_tree.visible:
		skill_tree.refresh()
	notify("Equipped "+{"water_sweep":"Water Slash","water_lance":"Water Lance","sea_dragon":"Mana Sea Dragon","undertow":"Undertow"}[id]+" on Q.")

func _ground_slam(at:Vector3, heavy:bool) -> void:
	var impact=load("res://scripts/ground_slam.gd").new()
	current_world.add_child(impact)
	impact.configure(self,Vector3(at.x,current_world.ground_height(at)+.018,at.z),heavy)

func _attack_contact(kind: String, direction: Vector3, already_hit: Dictionary) -> void:
	goblin_campaign.sword_contact(already_hit)
	var tuning=player.attack_tuning()
	for enemy in enemies:
		if enemy.health<=0 or already_hit.has(enemy.get_instance_id()):
			continue
		var toward=enemy.position-player.position
		toward.y=0
		if not player.blade_hits(enemy):
			continue
		var query=PhysicsRayQueryParameters3D.create(player.position+Vector3(0,.65,0),enemy.position+Vector3(0,.65,0),1)
		if not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		already_hit[enemy.get_instance_id()]=true
		var previous_health=enemy.health
		var weakspot=enemy.sword_weakspot_open()
		enemy.take_sword_damage(roundi(float(tuning.damage)*(1.2 if combat_skills.exposed.has(enemy.get_instance_id()) else 1.0)),toward.normalized(),kind in ["heavy","thrust"] or (kind=="light" and player.combo_stage==3 and player.attack_phase()>=.60),(float(player.combat.thrust_charge.recoil_multiplier) if kind=="thrust" else 1.0)*(1+magic_items.bonus("sword_recoil")))
		magic_items.sword_hit(enemy,previous_health)
		combat_skills.sword_hit(enemy,previous_health,weakspot,kind in ["heavy","thrust"] or (kind=="light" and player.combo_stage==3 and player.attack_phase()>=.60))

func _thrust_stopped(at:Vector3,direction:Vector3) -> void:
	var gust=load("res://scripts/thrust_gust.gd").new()
	current_world.add_child(gust)
	gust.configure(self,Vector3(at.x,current_world.ground_height(at)+.35,at.z),direction)

func _unwrap_mother() -> void:
	if not dialog.visible or not dialogue_choices.visible or mother_unwrapped:
		return
	mother_unwrapped=true
	dialogue_target.actor.set_arm_wrapped(false)
	dialogue_choices.visible=false
	dialog_lines=["All right. Let me loosen these wraps.","There. Rough iron, simple hinges… and a cracked flame gem in the palm. It still works, most days."]
	dialog_index=0
	_show_line()

func _player_defeated() -> void:
	cancel_sea_dragon()
	if menagery!=null: menagery.close()
	if recovering:
		return
	recovering=true
	magic_items.healing.clear()
	pause_menu.visible=false
	player.input_enabled=false
	_cancel_mouse_charge()
	conversation.close()
	inventory.close()
	skill_tree.close()
	dialog.visible=false
	help_panel.visible=false
	var death_layout=death_screen.get_child(0)
	death_layout.get_child(1).text="You fell. Return to this world's starting area. Defeated creatures are kept." if not world_id.is_empty() else "You fell in the forest. Rest in the village square, then continue your journey.\n\nRecovered components and defeated creatures are kept."
	death_layout.get_child(2).text="Return to world start" if not world_id.is_empty() else "Wake in the village square"
	if game_mode=="alpha2":
		death_layout.get_child(1).text="Return to your last pilgrim fire. Your discoveries, equipment and defeated enemies are kept."
		death_layout.get_child(2).text="Return to pilgrim fire"
	death_screen.visible=true
	death_veil.visible=true
	death_screen.get_child(0).get_child(2).grab_focus()

func respawn_player() -> void:
	if not recovering:
		return
	player.set_sword_drawn(false)
	if game_mode=="alpha2": load_map(alpha2.checkpoint,Vector2(alpha2.checkpoint_at[0],alpha2.checkpoint_at[1]))
	elif game_mode=="beta": load_map("beta_meadow")
	elif world_id.is_empty(): load_map("village_green",Vector2(0,3.5))
	else:
		var pack=WorldPacks.installed(world_id); load_map(WorldPacks.runtime_id(world_id,pack.start_map))
	player.restore_health(player.max_health)
	player.restore_stamina(player.max_stamina)
	player.invulnerability=1.0
	recovering=false
	death_screen.visible=false
	death_veil.visible=false
	notify("You return to the last pilgrim fire. Your discoveries are kept." if game_mode=="alpha2" else "You return to the meadow. Your journey continues." if game_mode=="beta" else "You return to the starting area. Your journey continues." if not world_id.is_empty() else "You wake in the village square. Your journey continues.")

func _enemy_defeated(id: String, kind: String, slain_enemy:Node3D=null) -> void:
	if id in defeated_enemies: return
	defeated_enemies.append(id)
	gain_xp(int(progression.definition.enemy_xp.get(kind,0))+monster_cores.boss_bonus(kind))
	if is_instance_valid(slain_enemy): monster_cores.defeated(kind,slain_enemy.position,kind=="warden" and map_id=="herb_glade")
	if kind=="bellkeeper": alpha2.boss_fell()
	if kind=="warden" and map_id=="herb_glade":
		for enemy in enemies:
			if enemy.definition.kind=="warden" and enemy.health<=0:
				spawn_warden_remains(enemy.position)
	if monster_cores.boss_bonus(kind)>0:
		notify(kind.capitalize()+" defeated · +%d XP (%d boss bonus)" % [int(progression.definition.enemy_xp.get(kind,0))+monster_cores.boss_bonus(kind),monster_cores.boss_bonus(kind)])
	else:
		notify({"slime":"The deeper forest trail is clear.","boar":"Briar boar defeated.","wisp":"Thorn wisp defeated.","warden":"The stone warden falls. Search its remains for the alchemical core."}.get(kind,"Goblin defeated.")+" +%d XP · Level %d" % [int(progression.definition.enemy_xp.get(kind,0))+monster_cores.boss_bonus(kind),progression.level()])

func quest_objective(include_side:bool=true) -> String:
	if game_mode=="alpha2": return alpha2.objective()
	if game_mode=="beta": return "Explore the sparse woodland: slimes, sticky slimes, wolves and rats."
	if include_side and world_id.is_empty() and map_id in ["lark_farm","goblin_approach","goblin_cave","goblin_depths"]: return goblin_campaign.objective()
	if not world_id.is_empty(): return "Custom world - explore linked areas. F5 saves this world separately."
	if not home_intro_complete:
		return "Go downstairs and talk to Mother before leaving."
	if quest_stage=="not_started":
		return "Talk to Mother at home in the west cottage."
	if quest_stage=="completed":
		return "Aether Core for Mother - Complete"
	if quest_stage=="component_ready":
		return "Return the calcified aether core to Mother."
	if "herb_glade/stone_warden" in defeated_enemies:
		return "Loot the aether core from the warden's remains (E)."
	for task in [["slime_forest/forest_slime","Defeat the slime; take the south forest trail."],["herb_glade/briar_boar","Defeat the briar boar in the deeper forest."],["herb_glade/briar_boar_second","Defeat the second briar boar."],["herb_glade/stone_warden","Parry the warden's rock back, then attack."]]:
		if not task[0] in defeated_enemies:
			return "Aether Core: "+task[1]
	return "Loot the aether core from the warden's remains (E)."

func loot_warden_core() -> bool:
	if quest_stage!="active":
		notify("Talk to Mother first." if quest_stage=="not_started" else "You already recovered the core.")
		return false
	if map_id!="herb_glade" or not "herb_glade/stone_warden" in defeated_enemies or not is_instance_valid(warden_remains) or player.position.distance_to(warden_remains.position)>2.2:
		notify("Defeat the stone warden, then search its remains nearby.")
		return false
	quest_stage="component_ready"
	monster_cores.give("golem_core")
	warden_remains.component.visible=false
	notify("Calcified aether core recovered. Return it to Mother.")
	return true

func spawn_warden_remains(at: Vector3) -> void:
	if is_instance_valid(warden_remains) and warden_remains.get_parent()==current_world:
		return
	warden_remains=WardenRemains.new()
	current_world.add_child(warden_remains)
	warden_remains.position=Vector3(at.x,0,at.z)
	warden_remains.build(quest_stage not in ["component_ready","completed"])
	current_world.interactions.append({"id":"warden_remains","title":"Stone warden remains · Loot core","lines":[],"position":warden_remains.position,"actor":null})

func notify(text: String) -> void:
	if "stamina" in text.to_lower():
		hud_feedback.denied(); return
	if text=="Parried!" or ("defeated." in text and "warden" not in text): return
	toast.text=text
	toast_time=3.0

func _verify() -> void:
	var args=OS.get_cmdline_user_args()
	if "--suite" in args and args[args.find("--suite")+1]=="alpha2":
		await load("res://scripts/alpha2_verification.gd").new().run(self);return
	if "--suite" in args and args[args.find("--suite")+1]=="unarmed":
		await load("res://scripts/unarmed_verification.gd").new().run(self);return
	if "--suite" in args and args[args.find("--suite")+1]=="dash-uppercut":
		await load("res://scripts/uppercut_verification.gd").new().run(self);return
	if "--suite" in args and args[args.find("--suite")+1]=="combat-skills":
		await load("res://scripts/skills_verification.gd").new().run(self);return
	if "--suite" in args and args[args.find("--suite")+1]=="sea-dragon":
		await load("res://scripts/sea_dragon_verification.gd").new().run(self);return
	var suite=load("res://scripts/verification.gd").new()
	await suite.run(self)

func _capture(directory: String) -> void:
	# Renderer fixtures demonstrate authored casts independently of player saves.
	player.water_unlocked=true
	player.lance_unlocked=true
	DirAccess.make_dir_recursive_absolute(directory)
	var arguments=OS.get_cmdline_user_args()
	var view="all"
	if "--capture-view" in arguments:
		view=arguments[arguments.find("--capture-view")+1]
	if view=="alpha2":
		await load("res://scripts/alpha2_capture.gd").new().run(self,directory)
		get_tree().quit();return
	if view=="hero":
		await load("res://scripts/hero_capture.gd").new().run(self,directory)
		get_tree().quit(); return
	if view=="beta":
		await load("res://scripts/beta_capture.gd").new().run(self,directory)
		get_tree().quit(); return
	if view=="standalone":
		await load("res://scripts/standalone_capture.gd").new().run(self,directory)
		get_tree().quit(); return
	if view=="cores":
		await load("res://scripts/core_capture.gd").new().run(self,directory)
		get_tree().quit(); return
	if view=="hud":
		await load("res://scripts/hud_capture.gd").new().run(self,directory)
		get_tree().quit(); return
	if view=="magic":
		await load("res://scripts/magic_item_capture.gd").new().run(self,directory)
		get_tree().quit()
		return
	if view=="goblins":
		await load("res://scripts/goblin_capture.gd").new().run(self,directory)
		get_tree().quit()
		return
	if view=="queen":
		await load("res://scripts/queen_capture.gd").new().run(self,directory)
		get_tree().quit()
		return
	if view=="resin":
		await load("res://scripts/resin_capture.gd").new().run(self,directory)
		get_tree().quit()
		return
	if view=="terrain":
		await load("res://scripts/terrain_capture.gd").new().run(self,directory)
		get_tree().quit()
		return
	if view=="menagery":
		await load("res://scripts/menagery_capture.gd").new().run(self,directory)
		get_tree().quit()
		return
	if view=="knockback":
		await load("res://scripts/knockback_capture.gd").new().run(self,directory)
		get_tree().quit()
		return
	if view=="home":
		await load("res://scripts/home_capture.gd").new().run(self,directory)
		get_tree().quit()
		return
	if view=="unarmed":
		await load("res://scripts/unarmed_capture.gd").new().run(self,directory)
		get_tree().quit();return
	if view=="dash-uppercut":
		await load("res://scripts/uppercut_capture.gd").new().run(self,directory)
		get_tree().quit();return
	if view=="combat-skills":
		await load("res://scripts/skills_capture.gd").new().run(self,directory)
		get_tree().quit();return
	if view=="sea-dragon":
		await load("res://scripts/sea_dragon_capture.gd").new().run(self,directory)
		get_tree().quit();return
	if view=="potion":
		await load("res://scripts/potion_capture.gd").new().run(self,directory)
		get_tree().quit()
		return
	if view=="title":
		await load("res://scripts/title_capture.gd").new().run(self,directory)
		get_tree().quit()
		return
	if view=="camera":
		await load("res://scripts/camera_capture.gd").new().run(self,directory)
		get_tree().quit()
		return
	if view=="menus":
		await load("res://scripts/menu_capture.gd").new().run(self,directory)
		get_tree().quit()
		return
	if view=="parry":
		await load("res://scripts/parry_contact_capture.gd").new().run(self,directory)
		get_tree().quit()
		return
	if view=="graphics":
		await load("res://scripts/graphics9_capture.gd").new().run(self,directory)
		print("CAPTURE_OK "+directory)
		get_tree().quit()
		return
	if view=="environment":
		await load("res://scripts/environment_capture.gd").new().run(self,directory)
		get_tree().quit()
		return
	if view=="progression":
		await load("res://scripts/progression_capture.gd").new().run(self,directory)
		print("CAPTURE_OK "+directory)
		get_tree().quit()
		return
	if view=="quest":
		await load("res://scripts/quest_capture.gd").new().run(self,directory)
		print("CAPTURE_OK "+directory)
		get_tree().quit()
		return
	if view=="combat":
		await load("res://scripts/combat_capture.gd").new().run(self,directory)
		print("CAPTURE_OK "+directory)
		get_tree().quit()
		return
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
	set_resolution(960)
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
		await load("res://scripts/combat_capture.gd").new().run(self,directory)
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
	DirAccess.make_dir_recursive_absolute(directory+"/character-walk-cycle")
	player.visual.rotation.y=PI/5
	var walk_samples=[]
	var walk_started=Time.get_ticks_msec()
	for sample in range(36):
		await get_tree().physics_frame
		await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		world_view.get_texture().get_image().save_png(directory+"/character-walk-cycle/frame-%03d.png" % sample)
		walk_samples.append(Time.get_ticks_msec()-walk_started)
	var walk_timings=FileAccess.open(directory+"/character-walk-cycle/timings.json",FileAccess.WRITE)
	walk_timings.store_string(JSON.stringify(walk_samples))
	walk_timings.close()
	for view in [{"name":"front","angle":0},{"name":"right","angle":PI/2},{"name":"back","angle":PI},{"name":"left","angle":PI*1.5}]:
		player.visual.rotation.y=view.angle
		player.animator.seek(.20,true)
		player.animator.pause()
		await RenderingServer.frame_post_draw
		world_view.get_texture().get_image().save_png(directory+"/walk-"+view.name+".png")

func toggle_skills() -> void:
	if menagery!=null: menagery.close()
	if recovering: return
	if inventory.visible and inventory.page=="level":
		inventory.close()
		return
	if player.state!="free": return
	if not inventory.visible: toggle_inventory()
	inventory.show_page("level")
	_refresh_simulation()

func _catalog_enemy_defeated(kind:String,display_name:String,enemy:Node3D=null) -> void:
	var amount=int(progression.definition.enemy_xp.get(kind,0))+monster_cores.boss_bonus(kind)
	if is_instance_valid(enemy): monster_cores.defeated(kind,enemy.position)
	gain_xp(amount)
	if monster_cores.boss_bonus(kind)>0: notify(display_name+" defeated · +%d XP (%d boss bonus)" % [amount,monster_cores.boss_bonus(kind)])
	else: notify(display_name+" defeated. +%d XP - Level %d (%d points)" % [amount,progression.level(),progression.points()])

func gain_xp(amount: int) -> void:
	amount=roundi(amount*(1+magic_items.bonus("xp")))
	var levels=progression.award(amount)
	update_progression_ui()
	if levels>0:
		notify("Level %d! %d skill points available - P to learn." % [progression.level(),progression.points()])

func receive_wishing_coin() -> bool:
	if well_gift_stage!="not_started" or map_id!="village_green" or conversation.target.get("id","")!="keeper_green":
		return false
	if player.position.distance_to(conversation.target.position)>float(config.interaction_distance):
		return false
	well_gift_stage="coin_ready"
	notify("Wishing coin received. Take it to the village well.")
	return true

func throw_wishing_coin() -> bool:
	if well_gift_stage!="coin_ready" or map_id!="village_green" or conversation.target.get("id","")!="well":
		return false
	var well_position=Vector3(0,0,-.5)
	if player.position.distance_to(well_position)>float(config.interaction_distance):
		return false
	well_gift_stage="potion_owned"
	gain_xp(int(progression.definition.well_quest_xp))
	var coin=MeshInstance3D.new()
	var mesh=CylinderMesh.new()
	mesh.top_radius=.10
	mesh.bottom_radius=.10
	mesh.height=.035
	coin.mesh=mesh
	var material=StandardMaterial3D.new()
	material.albedo_color=Color("#f7c765")
	material.metallic=.7
	coin.material_override=material
	current_world.add_child(coin)
	coin.position=player.position+Vector3(0,1.1,0)
	var tween=coin.create_tween()
	tween.tween_property(coin,"position",well_position+Vector3(0,2,0),.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(coin,"position",well_position+Vector3(0,.25,0),.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(coin.queue_free)
	notify("Well quest complete: +40 XP and an Everfull Experience Potion! Open inventory [I].")
	return true

func drink_experience_potion() -> int:
	if well_gift_stage!="potion_owned":
		return 0
	var before=int(progression.xp)
	gain_xp(1000)
	var gained=int(progression.xp)-before
	notify("Drank Everfull Potion: +%d XP. The bottle refills itself." % gained if gained>0 else "Current XP limit reached. The potion remains full.")
	return gained

func update_progression_ui() -> void:
	xp_label.text="LEVEL %d  ·  XP %d / %d" % [progression.level(),progression.xp,progression.next_threshold()]
	var thresholds=progression.definition.level_thresholds
	var floor_xp=int(thresholds[progression.level()-1])
	xp_bar.max_value=maxi(1,progression.next_threshold()-floor_xp)
	xp_bar.value=progression.xp-floor_xp if progression.level()<thresholds.size() else xp_bar.max_value

func learn_skill(id: String) -> void:
	if not progression.learn(id):
		return
	apply_skill_stats()
	if id=="dash": player.dash_equipped=true
	if id=="jump": player.jump_equipped=true
	if id=="flowing_counter": player.counter_equipped=true
	update_progression_ui()
	skill_tree.refresh()
	notify("Learned "+progression.skill(id).name+". F5 saves your progress.")

func toggle_passive(id:String) -> void:
	if not progression.toggle_passive(id): return
	if id=="breaker": combat_skills.pressure.clear();combat_skills.exposed.clear()
	apply_skill_stats();inventory.refresh()

func toggle_movement_skill(id:String) -> void:
	if id=="flowing_counter" and player.counter_unlocked: player.counter_equipped=not player.counter_equipped
	if id=="dash" and player.dash_unlocked: player.dash_equipped=not player.dash_equipped
	if id=="jump" and player.jump_unlocked: player.jump_equipped=not player.jump_equipped
	inventory.refresh()

func apply_skill_stats() -> void:
	player.combat=read_data("res://content/combat.json")
	player.max_health=int(player.combat.max_health+progression.bonus("health"))
	player.max_stamina=float(player.combat.max_stamina)+progression.bonus("stamina")
	var damage_scale=1.0+progression.bonus("melee_multiplier")
	var swing_scale=1.0-progression.bonus("swing_saving")
	for kind in ["light","heavy","thrust"]:
		player.combat[kind].damage=roundi((player.combat[kind].damage+progression.bonus("melee"))*damage_scale)
		player.combat[kind].stamina_cost*=swing_scale
	for attack in player.combat.combo:
		attack.damage=roundi((attack.damage+progression.bonus("melee"))*damage_scale)
		attack.stamina_cost*=swing_scale
	player.combat.light.damage=roundi(player.combat.light.damage*(1+progression.bonus("opening_damage")))
	for index in range(player.combat.combo.size()):
		player.combat.combo[index].damage=roundi(player.combat.combo[index].damage*(1+progression.bonus("return_damage" if index==0 else "spin_damage")))
	for kind in ["heavy","thrust","water","lance"]:
		player.combat[kind].damage=roundi(player.combat[kind].damage*(1+progression.bonus(kind+"_damage")))
	player.combat.lance.splash_damage=roundi(player.combat.lance.splash_damage*(1+progression.bonus("lance_damage")))
	var control=progression.bonus("thrust_control")
	player.thrust_charge_rate=1+control
	for key in ["release_windup_seconds","unprepared_windup_seconds","hold_base_seconds","recovery_seconds"]: player.combat.thrust_charge[key]*=1-control
	player.combat.lance.charge_seconds*=1-progression.bonus("lance_control")
	player.lance_stability=clampf(progression.bonus("lance_stability"),0,.75)
	player.dash_distance_multiplier=1+progression.bonus("dash_distance")
	var base_walk=float(JSON.parse_string(FileAccess.get_file_as_string("res://content/beta.json")).locomotion.walk_speed) if game_mode=="beta" else 2.4
	player.walk_speed=base_walk*(1+progression.bonus("speed"))*(1+goblin_campaign.speed_bonus())
	for speed in ["drawn_walk_speed","sprint_speed","drawn_sprint_speed"]:
		player.combat[speed]*=(1+progression.bonus("speed"))*(1+goblin_campaign.speed_bonus())
	for drain in ["sprint_drain","drawn_sprint_drain"]:
		player.combat[drain]*=1-progression.bonus("sprint_saving")
	player.combat.water.stamina_cost*=1-progression.bonus("water_saving")
	player.water_unlocked=progression.has("mana")
	player.dash_water_unlocked=progression.has("mana") and progression.has("flowing_splash")
	player.lance_unlocked=progression.has("mana_lance")
	player.counter_unlocked=progression.has("flowing_counter")
	if not player.counter_unlocked: player.counter_equipped=false
	player.counter_damage=progression.bonus("counter_damage")
	player.measured_bonus=progression.bonus("measured_recovery")
	if player.measured_bonus<=0: player.measured_remaining=0
	player.undertow_unlocked=progression.has("undertow")
	player.dragon_unlocked=progression.has("sea_dragon")
	player.roll_unlocked=progression.has("belly_roll")
	player.thrust_unlocked=progression.has("charge_thrust")
	player.dash_unlocked=progression.has("dash")
	player.jump_unlocked=progression.has("jump")
	if not player.dash_unlocked: player.dash_equipped=false
	if not player.jump_unlocked: player.jump_equipped=false
	if selected_special_attack in ["water_lance","sea_dragon","undertow"] and not special_unlocked(selected_special_attack):
		selected_special_attack="water_sweep"
	if player.heavy_style=="charge_thrust" and not player.thrust_unlocked:
		player.heavy_style="overhead"
	magic_items.apply_stats()
	player.restore_health(mini(player.health,player.max_health))
	player.restore_stamina(minf(player.stamina,player.max_stamina))

func start_world(id:String) -> bool:
	var pack=WorldPacks.installed(id)
	if pack.is_empty(): notify("No valid installed world was found."); return false
	start_new_game(false)
	world_id=id; world_defeats.clear(); respawn_timers.clear(); home_intro_complete=true
	load_map(WorldPacks.runtime_id(id,pack.start_map),Vector2(INF,INF),true)
	title_screen.visible=false; pause_menu.visible=false
	if world_browser!=null: world_browser.visible=false
	_refresh_simulation(); notify(pack.name+" - custom world")
	return true

