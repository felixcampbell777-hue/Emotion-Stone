extends SubViewportContainer
var actor:Node3D
var camera:Camera3D
var view:SubViewport
var signature="!"
func configure(game:Node) -> void:
	stretch=true
	mouse_filter=Control.MOUSE_FILTER_STOP
	view=SubViewport.new(); view.size=Vector2i(450,550); view.msaa_3d=Viewport.MSAA_8X
	view.mesh_lod_threshold=0.0
	view.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE; view.own_world_3d=true; add_child(view)
	var world=Node3D.new(); view.add_child(world)
	var environment=WorldEnvironment.new(); environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color("#23362e")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color("#e4ede0"); environment.environment.ambient_light_energy=.7
	world.add_child(environment)
	var light=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-35,-30,0); light.light_energy=1.5; world.add_child(light)
	actor=game.Actor.new(); actor.configure(game.read_data("res://content/characters/hero.json")); world.add_child(actor)
	actor.set_meta("equipment_preview",true)
	actor.set_sword_equipped(false)
	actor.set_physics_process(false)
	actor.weapon_runtime=preload("res://scripts/weapon_runtime.gd").new()
	actor.weapon_runtime.configure(game,actor)
	camera=Camera3D.new(); camera.position=Vector3(0,1.1,3.4); camera.fov=38; world.add_child(camera); camera.look_at(Vector3(0,.94,0))
	actor.visual.rotation.y=.2
func refresh(game:Node) -> void:
	actor.set_physics_process(game.inventory.visible and game.inventory.page=="equipment")
	var appearance_key=preload("res://scripts/appearance_profile.gd").revision_key(game.appearance)
	var key=JSON.stringify(game.magic_items.slots)+str(game.player.sword_equipped)+game.magic_items.weapon_id+game.environment_profile+game.character_profile+game.game_mode+appearance_key
	if key==signature: return
	signature=key
	actor.set_sword_equipped(game.player.sword_equipped)
	actor.set_weapon_visual(game.magic_items.weapon_id)
	game.apply_character_art(actor)
	if actor.weapon_runtime.enabled():
		actor.set_sword_drawn(true)
		actor.movement_camera_yaw=actor.visual.rotation.y+PI
		actor.weapon_runtime.pose("ready",0.0)

func _process(_delta:float) -> void:
	if actor==null or not is_visible_in_tree() or actor.weapon_runtime==null:return
	if actor.weapon_runtime.enabled():
		actor.movement_camera_yaw=actor.visual.rotation.y+PI
		actor.weapon_runtime.pose("ready",0.0)
func _gui_input(event:InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
		actor.visual.rotation.y+=event.relative.x*.012
