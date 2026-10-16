extends Node3D
var camera:Camera3D
func _ready() -> void:
	var environment=WorldEnvironment.new();var env=Environment.new();environment.environment=env;add_child(environment)
	env.background_mode=Environment.BG_SKY;var sky=Sky.new();var mat=ProceduralSkyMaterial.new();mat.sky_top_color=Color("#4f91c5");mat.sky_horizon_color=Color("#dce9e6");mat.ground_bottom_color=Color("#fff0c9");mat.ground_horizon_color=Color("#dce9e6");mat.sky_curve=.22;sky.sky_material=mat;env.sky=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("#d9e5e6");env.ambient_light_energy=.7;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-38,-30,0);sun.light_energy=1.6;sun.light_color=Color("#fff3d5");add_child(sun)
	var floor_mesh=CylinderMesh.new();floor_mesh.top_radius=240;floor_mesh.bottom_radius=236;floor_mesh.height=14;floor_mesh.radial_segments=128
	var floor_node=MeshInstance3D.new();floor_node.mesh=floor_mesh;floor_node.position.y=-7;var grass=StandardMaterial3D.new();grass.albedo_color=Color("#718653");floor_node.material_override=grass;add_child(floor_node)
	var rim_mesh=TorusMesh.new();rim_mesh.inner_radius=236;rim_mesh.outer_radius=242;rim_mesh.rings=128;rim_mesh.ring_segments=12
	var rim=MeshInstance3D.new();rim.mesh=rim_mesh;rim.position.y=-1.0;var metal=StandardMaterial3D.new();metal.albedo_color=Color("#a9a9a0");metal.metallic=.65;metal.roughness=.55;rim.material_override=metal;add_child(rim)
	var ring=preload("res://assets/environment/world_rise_backdrop/ring.tscn").instantiate();add_child(ring)
	camera=Camera3D.new();camera.far=12000;camera.near=.1;camera.fov=78;add_child(camera);camera.current=true;set_view(0)
func set_view(index:int) -> void:
	var yaw=index*PI/8
	camera.position=Vector3(sin(yaw)*232,6,-cos(yaw)*232);camera.look_at(Vector3(sin(yaw)*2400,180,-cos(yaw)*2400))
