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
	mat.set_shader_parameter("cliff_albedo",load(ROOT+"rock_face/albedo.jpg"))
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
		var old_ocean=world.get_node_or_null("LegacyOcean")
		if old_ocean!=null:old_ocean.visible=false
		var plane=PlaneMesh.new();plane.size=Vector2(1600,1600)
		var water=Props.mesh_node(world,plane,Vector3(0,-.115,0),"#438b9d")
		var sea=ShaderMaterial.new();sea.shader=load("res://shaders/alpha2_sea.gdshader");sea.set_shader_parameter("shore_x",20.0 if id=="a2_mill" else 27.0 if id=="a2_quarry" else 19.0);water.material_override=sea
	dress(game)
	var env=game.environment_settings
	if biome in ["beach","highlands"]:
		env.fog_density=.0035;env.fog_light_color=Color("#bbcfd7");env.volumetric_fog_density=.002;env.tonemap_exposure=1.12;env.ambient_light_energy=.52;env.adjustment_saturation=1.02
		if env.sky!=null and env.sky.sky_material is ProceduralSkyMaterial:
			env.sky.sky_material.sky_top_color=Color("#497ca9");env.sky.sky_material.sky_horizon_color=Color("#cbd9de");env.sky.sky_material.sky_energy_multiplier=.8
	elif id=="a2_wood":env.fog_light_color=Color("#869d77");env.fog_density=.011;env.ambient_light_energy=.44;env.tonemap_exposure=1.03
	elif id=="a2_haven":env.tonemap_exposure=1.08;env.fog_density=.007

static func clearance(world:Node3D,plan:Dictionary,at:Vector3,radius:float=1.8) -> bool:
	var p=Vector2(at.x,at.z)
	if not world.bounds.grow(-1).has_point(p) or world.terrain_at(int(floor(at.x)),int(floor(at.z)))=="water":return false
	for line in plan.get("routes",[]):
		for i in range(1,line.size()):
			var a=Vector2(line[i-1][0],line[i-1][1]);var b=Vector2(line[i][0],line[i][1])
			if Geometry2D.get_closest_point_to_segment(p,a,b).distance_to(p)<radius:return false
	for target in world.interactions:
		if Vector2(target.position.x,target.position.z).distance_to(p)<2.5:return false
	return true
static func grounded(world:Node3D,x:float,z:float) -> Vector3:
	var at=Vector3(x,0,z);at.y=world.ground_height(at);return at
static func masonry(world:Node3D,at:Vector3,size:Vector3,turn:float=0) -> void:
	var piece=Art.model(Art.VILLAGE+"glTF/Wall_UnevenBrick_Straight.gltf",size,false);world.add_child(piece);piece.position=at;piece.rotation.y=turn
	Props.collider(piece,Vector3(0,size.y*.5,0),size)
static func dress(game:Node) -> void:
	var world=game.current_world;var id=String(game.map_id)
	var plans=JSON.parse_string(FileAccess.get_file_as_string("res://content/alpha2_regions.json"));var plan:Dictionary=plans.get(id,{})
	for landmark in plan.get("landmarks",[]):
		model(world,landmark.kind,grounded(world,landmark.at[0],landmark.at[1]),Vector3(landmark.size[0],landmark.size[1],landmark.size[2]),float(landmark.get("yaw",0)),landmark.get("solid",false))
	# Deliberate cover on the edges of fighting floors; routes remain clear.
	var cover={"a2_crossroads":[[-12,-3],[12,6]],"a2_mill":[[16,5],[-22,12],[-6,-10]],"a2_quarry":[[-13,10],[-5,-20],[5,-12],[22,-15]],"a2_wood":[[-15,4],[-5,5],[15,-10],[-20,-20]],"a2_belfry":[[-5,1],[6,-5],[-6,-10]]}
	for p in cover.get(id,[]):
		var at=grounded(world,p[0],p[1])
		if clearance(world,plan,at,1.3):model(world,"coast_rocks_01" if id=="a2_mill" else "rock_moss_set_02",at,Vector3(2.7,1.65,2.3),p[0]*.2,true)
	# A nest has clues even while its actors are concealed. These are small
	# non-colliding ground traces, not visual effects covering the combat floor.
	for group in plan.get("groups",[]):
		for i in range(group.members.size()):
			var member=group.members[i];var at=grounded(world,member.at[0],member.at[1]);var node=Node3D.new();world.add_child(node);node.position=at
			if group.behavior=="ambush":
				var mound=SphereMesh.new();mound.radius=.65;mound.height=.28
				Props.mesh_node(node,mound,Vector3(0,.04,0),"#a7997c" if id=="a2_mill" else "#797766")
				if member.kind=="library_spider":
					for j in range(5):
						var strand=Props.box(node,Vector3(0,.2+j*.15,0),Vector3(1.3,.018,.018),"#bdbca6");strand.rotation.y=.35+j*.63
			elif group.behavior in ["pack","territory"]:
				for j in range(3):
					var track=Props.box(node,Vector3(-.12+j*.12,.018,-1.2+j*.38),Vector3(.1,.018,.2),"#5e5343");track.rotation.y=.4
			elif group.behavior=="scavenge":model(world,"barrel",at+Vector3(.7,0,.6),Vector3(.45,.6,.45),i*.7)
	# Plant clusters sit at tree-bank edges rather than scatter over every tile.
	var count=0
	for prop in world.definition.props:
		if not String(prop.get("catalog_code","")).ends_with("A"):continue
		var at=grounded(world,prop.at[0]+.9,prop.at[1]+.4)
		if count>=55 or not clearance(world,plan,at,2.2):continue
		if absf(world.ground_height(at+Vector3(.6,0,0))-at.y)>.35:continue
		var plant=Art.model(Art.ROOT+"models/fern_02.glb",Vector3(1.0,.42,1.0),false);world.add_child(plant);plant.position=at;plant.rotation.y=count*2.4;count+=1
	if id=="a2_mill":
		for i in range(24):
			var at=grounded(world,5+sin(i*2.7)*4,-10+i*1.1)
			if not clearance(world,plan,at,2):continue
			var grass=Art.model(Art.ROOT+"models/grass_medium_01.glb",Vector3(.7,.45,.7),false);world.add_child(grass);grass.position=at;grass.rotation.y=i*1.37
	elif id=="a2_fen":
		for region in world.definition.terrain_regions:
			if region.kind!="water":continue
			var r=region.rect;var pool=Props.box(world,Vector3(r[0]+r[2]/2,-.055,r[1]+r[3]/2),Vector3(r[2],.04,r[3]),"#528a92");pool.material_override=load("res://shaders/realistic_water.tres")
	elif id=="a2_sanctum":
		# Ruined side walls frame the quiet refuge, leaving both entrances open.
		for z in [-9,-4,1]:
			masonry(world,grounded(world,-7,z),Vector3(4,1.8,.65),PI/2)
			masonry(world,grounded(world,7,z),Vector3(4,1.2,.65),PI/2)
		for x in [-4,4]:masonry(world,grounded(world,x,-11),Vector3(4,2.8,.7))
	elif id=="a2_belfry":
		for p in [[-8,-5],[8,-10],[-8,-14]]:masonry(world,grounded(world,p[0],p[1]),Vector3(3,1.7,1),.3)
