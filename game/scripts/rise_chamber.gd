extends "res://scripts/world.gd"
## One continuous floating arena, enclosing cavern shell and actual open drop.
const Art=preload("res://scripts/environment_art.gd")
const ENTRANCE=Vector2(-168,-125)
const ENTRANCE_YAW=-2.18
var rock:StandardMaterial3D
static func supported(at:Vector3,margin:float=0.0) -> bool:
	return Vector2(at.x/(23.0-margin),at.z/(25.0-margin)).length()<=1.0 or (absf(at.x)<3.0-margin and at.z>=21 and at.z<=40-margin)
static func return_point() -> Vector2:
	var p=Vector3(0,0,7).rotated(Vector3.UP,ENTRANCE_YAW)
	return ENTRANCE+Vector2(p.x,p.z)
static func stone_material() -> StandardMaterial3D:
	var mat=StandardMaterial3D.new();mat.albedo_color=Color("#697583");mat.roughness=.94;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mat.albedo_color=Color("#b3c0cb");mat.albedo_texture=load("res://assets/alpha2/rock_face/albedo.jpg");mat.roughness=1.0;mat.uv1_triplanar=true;mat.uv1_triplanar_sharpness=3;mat.uv1_scale=Vector3(.17,.17,.17)
	return mat
func build(data:Dictionary) -> void:
	definition=data;bounds=Rect2(-64,-64,128,128);npc_definitions=[];rock=stone_material()
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides=SurfaceTool.new();sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(96):
		var a=i*TAU/96;var b=(i+1)*TAU/96
		var pa=Vector3(sin(a)*23,0,cos(a)*25);var pb=Vector3(sin(b)*23,0,cos(b)*25)
		tri(st,Vector3.ZERO,pa,pb)
		var da=Vector3(pa.x*.74,-11-2*sin(a*5),pa.z*.74);var db=Vector3(pb.x*.74,-11-2*sin(b*5),pb.z*.74)
		quad(sides,pa,da,db,pb)
	surface(st,"FloatingArena",true)
	surface(sides,"IslandUnderside",true)
	var bridge=Props.box(self,Vector3(0,-.7,31),Vector3(6,1.4,18),"#596576");bridge.material_override=rock
	Props.collider(self,Vector3(0,-.7,31),Vector3(6,1.4,18))
	# Shared ring vertices make the sloped ceiling a sealed surface, not slabs.
	var roof=SurfaceTool.new();roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(10):
		for i in range(96):
			var a=i*TAU/96;var b=(i+1)*TAU/96
			quad(roof,ceiling(ring,a),ceiling(ring+1,a),ceiling(ring+1,b),ceiling(ring,b))
	surface(roof,"SlopedCavernCeiling",true)
	var walls=SurfaceTool.new();walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(96):
		var a=i*TAU/96;var b=(i+1)*TAU/96
		quad(walls,ceiling(10,a),Vector3(sin(a)*57,-55,cos(a)*57),Vector3(sin(b)*57,-55,cos(b)*57),ceiling(10,b))
	surface(walls,"ContinuousCavernWalls",true)
	for i in range(14):
		var a=(i+.35)*TAU/14;var r=56.5;var at=Vector3(sin(a)*r,7+2*cos(i*1.8),cos(a)*r)
		crystal_cluster(at,i)
	# Arrival arch frames the view; it is also the return route.
	for x in [-3.8,3.8]:
		var pillar=Props.box(self,Vector3(x,3.2,38.5),Vector3(1.6,6.4,3),"#475667");pillar.material_override=rock;Props.collider(self,pillar.position,Vector3(1.6,6.4,3))
	var lintel=Props.box(self,Vector3(0,6.6,38.5),Vector3(9.2,1.6,3),"#475667");lintel.material_override=rock
	crystal_cluster(Vector3(3.8,3.8,36),20)
	interactions.append({"id":"vault_return","title":"Return to Elderwood","position":Vector3(0,0,38),"lines":[],"actor":null,"wr_chamber":"leave"})
	for index in range(3):mist(-4-index*8,78+index*15,.12+index*.035,index)
func ceiling(ring:int,angle:float) -> Vector3:
	var radius=ring*5.7
	var y=27.0-18.0*pow(radius/57,1.35)+(.5*sin(angle*7)+.35*cos(angle*13))*radius/57
	return Vector3(sin(angle)*radius,y,cos(angle)*radius)
func tri(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3) -> void:
	for p in [a,b,c]:st.set_uv(Vector2(p.x,p.z)*.18);st.add_vertex(p)
func quad(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3) -> void:
	tri(st,a,b,c);tri(st,a,c,d)
func surface(st:SurfaceTool,label:String,solid:bool) -> void:
	st.generate_normals();var mesh=st.commit();var node=MeshInstance3D.new();node.name=label;node.mesh=mesh;node.material_override=rock;add_child(node)
	if solid:
		var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;var collision=CollisionShape3D.new();collision.shape=mesh.create_trimesh_shape();collision.shape.backface_collision=true;body.add_child(collision);add_child(body)
func crystal_cluster(at:Vector3,seed_value:int) -> void:
	var root=Node3D.new();root.name="BlueCrystal_%d"%seed_value;add_child(root);root.position=at
	var mat=StandardMaterial3D.new();mat.albedo_color=Color("#4095c9");mat.metallic=.25;mat.roughness=.24;mat.emission_enabled=true;mat.emission=Color("#2189e0");mat.emission_energy_multiplier=2.8
	for j in range(5):
		var mesh=CylinderMesh.new();mesh.top_radius=0;mesh.bottom_radius=.25+.08*(j%2);mesh.height=1.2+.5*(j%3);mesh.radial_segments=5
		var node=MeshInstance3D.new();node.mesh=mesh;node.material_override=mat;root.add_child(node);node.position=Vector3((j-2)*.38,absf(j-2)*.16,sin(j*2.1)*.35);node.rotation_degrees=Vector3(10*(j-2),0,16*(j-2));node.scale=Vector3.ONE*1.8
	var lamp=OmniLight3D.new();lamp.light_color=Color("#69b5ff");lamp.light_energy=12 if seed_value<20 else 5;lamp.omni_range=85 if seed_value<20 else 23;lamp.omni_attenuation=.8;lamp.light_volumetric_fog_energy=.12;lamp.shadow_enabled=seed_value in [1,5,9];root.add_child(lamp)
func mist(y:float,width:float,opacity:float,index:int) -> void:
	var mesh=PlaneMesh.new();mesh.size=Vector2(width,width);var node=MeshInstance3D.new();node.name="AbyssMist_%d"%index;node.mesh=mesh;node.position.y=y;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/vault_mist.gdshader");mat.set_shader_parameter("opacity",opacity);node.material_override=mat;add_child(node)
func lighting(game:Node) -> void:
	var env=game.environment_settings;env.background_mode=Environment.BG_COLOR;env.background_color=Color("#01040b");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("#28436a");env.ambient_light_energy=.22
	env.fog_enabled=true;env.fog_light_color=Color("#142740");env.fog_density=.018;env.fog_sky_affect=1;env.fog_aerial_perspective=0;env.volumetric_fog_enabled=RenderingServer.get_current_rendering_method()=="forward_plus";env.volumetric_fog_density=.012;env.volumetric_fog_albedo=Color("#41618a");env.volumetric_fog_emission=Color("#051020");env.volumetric_fog_length=90;env.tonemap_exposure=1.1
	game.world_root.get_node("WorldSun").light_energy=0;game.camera.far=150
func ground_height(_at:Vector3) -> float:return 0.0
func safe_position(at:Vector3) -> bool:return supported(at,1.0)
func update_details(_at:Vector3) -> void:pass
func move_grounded(body:CharacterBody3D,delta:float) -> void:
	var outside=not supported(body.position)
	if outside or body.has_meta("rise_fall"):
		var fall=float(body.get_meta("rise_fall",body.velocity.y))-18*delta;body.set_meta("rise_fall",fall);body.velocity.y=fall;body.move_and_slide()
		if body.is_on_floor() and supported(body.position):body.remove_meta("rise_fall");body.position.y=0;body.finish_jump()
		if body.position.y< -24 and body.get("controllable")==true:body.invulnerability=0;body.take_damage(999999,Vector3.ZERO)
		return
	body.motion_mode=CharacterBody3D.MOTION_MODE_GROUNDED;body.floor_snap_length=.35
	if body.jump_active:
		body.move_and_slide()
		if body.is_on_ceiling() and body.jump_velocity>0:body.jump_velocity=0
		if body.jump_velocity<=0 and body.is_on_floor():body.position.y=0;body.finish_jump()
	else:
		body.position.y=0;body.velocity.y=0;body.move_and_slide()
static func build_entrance(world:Node) -> void:
	var root=Node3D.new();root.name="HiddenVaultEntrance";world.add_child(root);root.position=Vector3(ENTRANCE.x,world.ground_height(Vector3(ENTRANCE.x,0,ENTRANCE.y)),ENTRANCE.y);root.rotation.y=ENTRANCE_YAW
	var mat=stone_material();var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(24):
		var a=i*PI/24;var b=(i+1)*PI/24
		var inner_a=Vector3(cos(a)*3.2,1.0+sin(a)*4.8,0);var inner_b=Vector3(cos(b)*3.2,1.0+sin(b)*4.8,0)
		var outer_a=Vector3(cos(a)*(6.5+.4*sin(a*13)),.5+sin(a)*(8+.5*sin(a*9)),0);var outer_b=Vector3(cos(b)*(6.5+.4*sin(b*13)),.5+sin(b)*(8+.5*sin(b*9)),0)
		for p in [inner_a,outer_a,outer_b,inner_a,outer_b,inner_b,inner_a,inner_b,inner_b+Vector3(0,0,-6),inner_a,inner_b+Vector3(0,0,-6),inner_a+Vector3(0,0,-6)]:st.set_uv(Vector2(p.x,p.y)*.15);st.add_vertex(p)
	st.generate_normals();var mesh=st.commit();var arch=MeshInstance3D.new();arch.mesh=mesh;arch.material_override=mat;root.add_child(arch)
	arch.create_trimesh_collision()
	for side in [-1,1]:
		var boulder=Art.model(Art.ROOT+"models/rock_moss_set_01_a.glb",Vector3(4,5.5,5),false)
		if boulder!=null:root.add_child(boulder);boulder.position=Vector3(side*5,-.8,0);boulder.rotation.y=side*.8
	var dark=Props.box(root,Vector3(0,2.8,-3.5),Vector3(6.4,5.6,.3),"#010207");dark.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;Props.collider(root,dark.position,Vector3(6.4,5.6,.3))
	for x in [-4.8,4.8]:Props.collider(root,Vector3(x,2.4,-2),Vector3(3,4.8,8))
	var mat_dark=StandardMaterial3D.new();mat_dark.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat_dark.albedo_color=Color("#010207");dark.material_override=mat_dark
	var crystal=Props.cone(root,Vector3(2.6,1,1),.22,1.2,"#3b9bde",.02);var glow=Props.mat("#3b9bde");glow.emission_enabled=true;glow.emission=Color("#298ce0");crystal.material_override=glow
	var lamp=OmniLight3D.new();lamp.position=Vector3(0,2.4,0);lamp.light_color=Color("#63adff");lamp.light_energy=2;lamp.omni_range=9;root.add_child(lamp)
	world.interactions.append({"id":"vault_entrance","title":"Enter the Veiled Vault?","position":root.to_global(Vector3(0,0,2.6)),"actor":null,"lines":[],"wr_chamber":"enter"})
