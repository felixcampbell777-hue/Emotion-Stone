extends RefCounted
## Region-specific silhouettes, photographed materials and imported scenery.
const Props=preload("res://scripts/props.gd")
const Art=preload("res://scripts/environment_art.gd")
const ROOT="res://assets/alpha2/"
static func model(world:Node3D,id:String,at:Vector3,size:Vector3,turn:float=0,solid:bool=false) -> Node3D:
	var node=Art.model(ROOT+id+".glb",size,false);node.name="Library_"+id;world.add_child(node);node.position=at;node.rotation.y=turn
	if id in ["wreck","dock","watchtower","barrel"]:
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			mesh.material_override=Art.village_material("UnevenBrick",.8) if id=="watchtower" else Art.texture_material("brown_planks_05",.85,Color("#c2ad8d"))
	if solid:Props.collider(node,Vector3(0,size.y*.4,0),Vector3(size.x*.65,size.y*.8,size.z*.65))
	return node
static func ground(world:Node3D) -> void:
	var mat=ShaderMaterial.new();mat.shader=load("res://shaders/alpha2_ground.gdshader")
	var biome=world.definition.get("biome","");var id=String(world.definition.id)
	var soil=ROOT+"rock_face/" if biome=="highlands" else Art.ROOT+"leafy_grass/" if id=="a2_haven" else Art.ROOT+"forest_leaves_02/"
	for pair in [["soil",soil],["trail",Art.ROOT+"rocky_trail/"],["sand",ROOT+"coast_sand_01/"]]:
		mat.set_shader_parameter(pair[0]+"_albedo",load(pair[1]+"albedo.jpg"));mat.set_shader_parameter(pair[0]+"_normal",load(pair[1]+"normal.jpg"))
	mat.set_shader_parameter("soil_tint",Vector3(.83,1.03,.8) if id=="a2_wood" else Vector3.ONE)
	var mask=Image.create(int(world.bounds.size.x),int(world.bounds.size.y),false,Image.FORMAT_RGB8)
	for x in range(mask.get_width()):
		for z in range(mask.get_height()):
			var kind=world.terrain_at(int(world.bounds.position.x)+x,int(world.bounds.position.y)+z);mask.set_pixel(x,z,Color(1 if kind in ["path","cobble"] else 0,1 if kind=="sand" else 0,0))
	mat.set_shader_parameter("mask_texture",ImageTexture.create_from_image(mask));mat.set_shader_parameter("map_origin",world.bounds.position);mat.set_shader_parameter("map_size",world.bounds.size)
	var grid=world.get_node_or_null("Terrain")
	if grid!=null:
		for i in grid.mesh_library.get_item_list():grid.mesh_library.get_item_mesh(i).material=mat
	for child in world.get_children():
		if child is MeshInstance3D and child.mesh is ArrayMesh:child.material_override=mat
		elif child is MeshInstance3D and child.mesh is BoxMesh and child.mesh.size.y<.3 and absf(child.mesh.size.x-world.bounds.size.x)<1:child.material_override=mat
static func build(game:Node) -> void:
	var world=game.current_world;var id=String(game.map_id);var biome=String(world.definition.get("biome","woodland"))
	if not world.definition.get("cave",false):ground(world)
	if world.definition.sea:
		var plane=PlaneMesh.new();plane.size=Vector2(1600,1600)
		var water=Props.mesh_node(world,plane,Vector3(0,-.115,0),"#438b9d")
		var sea=ShaderMaterial.new();sea.shader=load("res://shaders/alpha2_sea.gdshader");sea.set_shader_parameter("shore_x",20.0 if id=="a2_mill" else 27.0 if id=="a2_quarry" else 19.0);water.material_override=sea
	if id=="a2_mill":
		model(world,"wreck",Vector3(-14,0,3),Vector3(6,3,10),-.22,true)
		model(world,"dock",Vector3(-14,.02,-6),Vector3(2,.22,8))
		for at in [Vector3(-20,0,20),Vector3(-23,-.5,-2),Vector3(16,-.4,-18),Vector3(17,-.3,3)]:model(world,"coast_rocks_01",at,Vector3(5,2.8,5),at.z*.1,true)
		for z in [-20,0,20]:model(world,"coastal_cliff_01",Vector3(-30,-5,z),Vector3(12,14,20),PI/2)
		for z in [-25,-5,15,34]:model(world,"boulder_01",Vector3(-33,-3,z),Vector3(14,13,26),.2)
		for i in range(4):model(world,"barrel",Vector3(-10+i*1.1,0,6),Vector3(.6,.9,.6),i*.3,true)
		for i in range(32):
			var at=Vector3(11+sin(i*2.7)*4,0,-23+i*1.5);at.y=world.ground_height(at)
			var grass=Art.model(Art.ROOT+"models/grass_medium_01.glb",Vector3(.65,.3,.65),false);world.add_child(grass);grass.position=at;grass.rotation.y=i*1.37
	elif id=="a2_quarry":
		for z in [-22,-5,13,29]:model(world,"coastal_cliff_01",Vector3(31,-8,z),Vector3(12,20,20),-PI/2)
		for z in [-25,-5,15,33]:model(world,"boulder_01",Vector3(36,-8,z),Vector3(12,18,22),-.3)
		model(world,"watchtower",Vector3(12,world.ground_height(Vector3(12,0,-17)),-17),Vector3(5,10,5),.25,true)
		for at in [Vector3(-20,0,-18),Vector3(18,0,5),Vector3(-16,0,14)]:model(world,"boulder_01",at,Vector3(5,3.5,4),at.x*.1,true)
	elif id=="a2_wood":
		for at in [Vector3(-12,0,10),Vector3(15,0,3),Vector3(-18,0,-12)]:
			at.y=world.ground_height(at);model(world,"rock_moss_set_02",at,Vector3(5,1.6,4))
		for i in range(10):
			var at=Vector3(sin(i*2.4)*18,0,-22+i*4.5);at.y=world.ground_height(at)
			model(world,"nettle_plant",at,Vector3(1.8,.85,1.8));model(world,"flower_heliophila",at+Vector3(1,0,1),Vector3(1.5,.6,1.5))
	elif id=="a2_fen":
		for region in world.definition.terrain_regions:
			if region.kind!="water":continue
			var r=region.rect;var pool=Props.box(world,Vector3(r[0]+r[2]/2,-.035,r[1]+r[3]/2),Vector3(r[2],.04,r[3]),"#528a92");pool.material_override=load("res://shaders/realistic_water.tres")
		for at in [Vector3(-18,0,5),Vector3(16,0,5),Vector3(-14,0,-12)]:model(world,"nettle_plant",at,Vector3(3,1.1,3))
	elif id in ["a2_sanctum","a2_belfry"]:
		for x in [-10,10]:model(world,"watchtower",Vector3(x,0,-11),Vector3(4,8,4),x*.05,true)
		for at in [Vector3(-15,-3,-20),Vector3(18,-4,-10)]:model(world,"coastal_cliff_01",at,Vector3(9,12,12))
		for x in [-6,-3,3,6]:
			var arch=Art.model(Art.VILLAGE+"glTF/Wall_UnevenBrick_Straight.gltf",Vector3(2.6,3.4,.7),false);world.add_child(arch);arch.position=Vector3(x,0,-14);Props.collider(arch,Vector3(0,1.7,0),Vector3(2.6,3.4,.7))
	var env=game.environment_settings
	if biome in ["beach","highlands"]:
		env.fog_density=.0035;env.fog_light_color=Color("#bbcfd7");env.volumetric_fog_density=.002;env.tonemap_exposure=1.12;env.ambient_light_energy=.52;env.adjustment_saturation=1.02
		if env.sky!=null and env.sky.sky_material is ProceduralSkyMaterial:
			env.sky.sky_material.sky_top_color=Color("#497ca9");env.sky.sky_material.sky_horizon_color=Color("#cbd9de");env.sky.sky_material.sky_energy_multiplier=.8
	elif id=="a2_wood":env.fog_light_color=Color("#869d77");env.fog_density=.011;env.ambient_light_energy=.44;env.tonemap_exposure=1.03
	elif id=="a2_haven":env.tonemap_exposure=1.08;env.fog_density=.007
