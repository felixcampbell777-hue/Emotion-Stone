extends Node
## Render-only settings. Never change actor activation, terrain or collisions.
const PATH="user://graphics.cfg"
var game:Control
var spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://content/render_budget.json"))
var quality="balanced"
var fps=60
var clock=0.0
var focused=true
var base_effects:Dictionary={}
func configure(owner_game:Control) -> void:
	game=owner_game
	var settings=ConfigFile.new()
	if settings.load(PATH)==OK:
		var saved_quality=settings.get_value("graphics","quality","balanced")
		if saved_quality in spec.profiles:quality=saved_quality
		var saved_fps=settings.get_value("graphics","fps",60)
		if saved_fps in [30,60,90,120]:fps=saved_fps
	focused=DisplayServer.window_is_focused() or DisplayServer.get_name()=="headless"
	apply_view();apply_frame_cap()
func profile() -> Dictionary:return spec.profiles[quality]
func persist() -> void:
	var settings=ConfigFile.new()
	settings.set_value("graphics","quality",quality);settings.set_value("graphics","fps",fps);settings.save(PATH)
func select_quality(value:String,save_setting:bool=true) -> void:
	if not spec.profiles.has(value):return
	quality=value;apply_view();apply_environment();update_streaming();update_scenery()
	if save_setting:persist()
func select_fps(value:int,save_setting:bool=true) -> void:
	if value not in [30,60,90,120]:return
	fps=value;apply_frame_cap()
	if save_setting:persist()
func apply_frame_cap() -> void:
	Engine.max_fps=fps if focused else mini(fps,15)
func _notification(what:int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_IN:focused=true;apply_frame_cap()
	elif what==NOTIFICATION_APPLICATION_FOCUS_OUT:focused=false;apply_frame_cap()
func apply_view() -> void:
	if game==null or game.world_view==null:return
	var p=profile()
	game.world_view.msaa_3d=int(p.msaa) if game.graphics_preset==0 or game.graphics_preset>=960 else Viewport.MSAA_DISABLED
	game.world_view.mesh_lod_threshold=p.lod
	game.world_view.scaling_3d_mode=Viewport.SCALING_3D_MODE_FSR
	game.world_view.scaling_3d_scale=p.scale if game.graphics_preset==0 else 1.0
func scene_changed() -> void:
	var env:Environment=game.environment_settings
	base_effects={"ssao":env.ssao_enabled,"glow":env.glow_enabled,"volume":env.volumetric_fog_enabled}
	apply_view();apply_environment();update_streaming();update_scenery()
func update_streaming() -> void:
	if game.current_world!=null and game.current_world.has_method("configure_render"):game.current_world.configure_render(profile())
func apply_environment() -> void:
	if base_effects.is_empty():return
	var env:Environment=game.environment_settings
	env.ssao_enabled=base_effects.ssao and quality=="high"
	env.glow_enabled=base_effects.glow and quality!="low"
	env.volumetric_fog_enabled=base_effects.volume and quality!="low"
	# Ordinary depth fog is retained in Low, preserving obscured canyon routes.
	var sun=game.world_root.get_node_or_null("WorldSun")
	if sun!=null:sun.directional_shadow_max_distance=profile().sun
func _process(delta:float) -> void:
	clock+=delta
	if clock<.25:return
	clock=0;update_scenery()
func update_scenery() -> void:
	if game==null or game.player==null:return
	var p=profile();var eye:Vector3=game.player.global_position
	for mesh in get_tree().get_nodes_in_group("budget_scenery"):
		if not mesh is GeometryInstance3D or not mesh.is_inside_tree():continue
		var kind:String=mesh.get_meta("budget_kind","detail")
		var distance=eye.distance_to(mesh.global_position)
		var limit:float=p.skyline if kind=="skyline" else p.grass if kind=="grass" else p.detail
		if not mesh.has_meta("budget_shadow"):mesh.set_meta("budget_shadow",mesh.cast_shadow)
		mesh.visibility_range_end=limit;mesh.visibility_range_end_margin=6
		mesh.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		mesh.lod_bias=1.0 if distance<24 else .55 if distance<48 else .25
		mesh.cast_shadow=mesh.get_meta("budget_shadow") if distance<p.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
