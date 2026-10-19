extends SubViewportContainer
## A cosmetic scene, never a gameplay Actor: no attacks, physics or save hooks.
const Renderer=preload("res://scripts/character_appearance.gd")
var avatar:Node3D
var camera:Camera3D
var view:SubViewport
var yaw=.15
var distance=3.2
var framing="body"

func configure() -> void:
	stretch=true;mouse_filter=Control.MOUSE_FILTER_STOP
	view=SubViewport.new();view.size=Vector2i(480,600);view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE;view.msaa_3d=Viewport.MSAA_4X
	add_child(view)
	var stage=Node3D.new();view.add_child(stage)
	var environment=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("#1D2C28")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("#EDF0E9");environment.environment.ambient_light_energy=.65;stage.add_child(environment)
	var key=DirectionalLight3D.new();key.rotation_degrees=Vector3(-28,-32,0);key.light_energy=1.1;stage.add_child(key)
	var fill=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-15,140,0);fill.light_energy=.45;stage.add_child(fill)
	avatar=load("res://assets/characters/heroine-beta.glb").instantiate();stage.add_child(avatar)
	avatar.set_meta("appearance_preview",true)
	for mixer in avatar.find_children("*","AnimationPlayer",true,false):mixer.active=false
	camera=Camera3D.new();camera.fov=35;camera.near=.04;stage.add_child(camera)
	refresh_camera()

func show_profile(profile:Dictionary) -> void:
	Renderer.apply(avatar,profile)

func frame(section:String) -> void:
	framing="face" if section in ["face","hair","skin"] else "body"
	distance=1.1 if framing=="face" else 3.2
	refresh_camera()

func turn(angle:float) -> void:
	yaw=angle;refresh_camera()

func refresh_camera() -> void:
	if camera==null:return
	avatar.rotation.y=yaw
	var height=1.47 if framing=="face" else .88
	camera.position=Vector3(0,height,distance);camera.look_at(Vector3(0,height,0))

func _gui_input(event:InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
		yaw+=event.relative.x*.012;refresh_camera();accept_event()
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		distance=clampf(distance+(-.12 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .12),.65,4.2)
		refresh_camera();accept_event()
