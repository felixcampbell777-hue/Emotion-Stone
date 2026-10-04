extends Node3D
const Props = preload("res://scripts/props.gd")
var definition: Dictionary
var interactions: Array = []
var npc_definitions: Array = []
var bounds: Rect2

func terrain_at(x: int, z: int) -> String:
	var kind = "grass"
	for region in definition.terrain_regions:
		var r = region.rect
		if Rect2(r[0],r[1],r[2],r[3]).has_point(Vector2(x,z)):
			kind = region.kind
	return kind

func build(data: Dictionary) -> void:
	definition = data
	var b = data.bounds
	bounds = Rect2(b[0],b[1],b[2]-b[0],b[3]-b[1])
	var rng = RandomNumberGenerator.new()
	rng.seed = int(data.seed)
	var tiles = MeshLibrary.new()
	var colors = ["#819f70","#839f72","#809c6e","#c6b692","#cdbd9c"]
	for i in range(colors.size()):
		tiles.create_item(i)
		var mesh = BoxMesh.new()
		mesh.size = Vector3(1,.24,1)
		mesh.material = Props.mat(colors[i])
		tiles.set_item_mesh(i,mesh)
	var grid = GridMap.new()
	grid.name = "Terrain"
	grid.mesh_library = tiles
	grid.cell_size = Vector3(1,1,1)
	grid.cell_center_y = false
	grid.position.y = -.12
	add_child(grid)
	for x in range(b[0],b[2]):
		for z in range(b[1],b[3]):
			var kind = terrain_at(x,z)
			if kind == "water":
				Props.collider(self,Vector3(x+.5,.75,z+.5),Vector3(1,1.5,1))
				continue
			var tile = rng.randi_range(0,2) if kind=="grass" else 3 if kind=="path" else 4
			grid.set_cell_item(Vector3i(x,0,z),tile)
			if data.sea and (terrain_at(x+1,z)=="water" or terrain_at(x,z+1)=="water"):
				Props.box(self,Vector3(x+.5,-.66,z+.5),Vector3(1.01,1.3,1.01),"#8c9484")
	if data.sea:
		var ocean = Props.box(self,Vector3(0,-1.15,0),Vector3(85,.08,85),"#719da4")
		var shader = Shader.new()
		shader.code = "shader_type spatial; render_mode unshaded; void fragment(){ float stripe=step(0.94,sin((VERTEX.x+VERTEX.z)*4.0+TIME*0.8)); ALBEDO=mix(vec3(0.39,0.57,0.61),vec3(0.60,0.73,0.72),stripe*0.27); }"
		var water = ShaderMaterial.new()
		water.shader = shader
		ocean.material_override = water
	else:
		Props.box(self,Vector3(0,-.2,0),Vector3(85,.1,85),"#69815c")
	Props.collider(self,Vector3(b[0]-.1,1,0),Vector3(.2,2,80))
	Props.collider(self,Vector3(b[2]+.1,1,0),Vector3(.2,2,80))
	Props.collider(self,Vector3(0,1,b[1]-.1),Vector3(80,2,.2))
	Props.collider(self,Vector3(0,1,b[3]+.1),Vector3(80,2,.2))
	for prop in data.props:
		add_child(Props.create(prop))
	for item in data.interactions:
		add_child(Props.create(item))
		interactions.append({"id":item.id,"title":item.title,"lines":item.lines,"position":Vector3(item.at[0],0,item.at[1]),"actor":null})
	npc_definitions = data.npcs
	# Seeded grass tufts: one batched draw, no bespoke assets per map.
	var grass_mesh = BoxMesh.new()
	grass_mesh.size = Vector3(.055,.17,.11)
	grass_mesh.material = Props.mat("#a0b986")
	var multi = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = grass_mesh
	multi.instance_count = 130
	for i in range(130):
		var x = rng.randf_range(b[0]+1,b[2]-1)
		var z = rng.randf_range(b[1]+1,b[3]-1)
		var location = Vector3(x,.08,z) if terrain_at(int(floor(x)),int(floor(z)))=="grass" else Vector3(0,-4,0)
		multi.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf()*TAU),location))
	var tufts = MultiMeshInstance3D.new()
	tufts.multimesh = multi
	add_child(tufts)

func safe_position(at: Vector3) -> bool:
	if not bounds.grow(-.30).has_point(Vector2(at.x,at.z)):
		return false
	for offset in [Vector2(.23,0),Vector2(-.23,0),Vector2(0,.23),Vector2(0,-.23)]:
		if terrain_at(int(floor(at.x+offset.x)),int(floor(at.z+offset.y)))=="water":
			return false
	for prop in definition.props+definition.interactions:
		var dimensions={"house":Vector2(3.15,2.45),"tree":Vector2(.35,.35),"rock":Vector2(.8,.7),"bench":Vector2(1.35,.48),"well":Vector2(1.35,1.35),"sign":Vector2(.2,.2),"wall":Vector2(prop.get("length",3),.4)}
		if not dimensions.has(prop.kind):
			continue
		var local=(Vector2(at.x,at.z)-Vector2(prop.at[0],prop.at[1])).rotated(-deg_to_rad(float(prop.get("rotation",0))))
		var size:Vector2=dimensions[prop.kind]*float(prop.get("scale",1))+Vector2(.46,.46)
		if Rect2(-size/2,size).has_point(local):
			return false
	for npc in definition.npcs:
		if Vector2(at.x,at.z).distance_to(Vector2(npc.at[0],npc.at[1]))<.46:
			return false
	return true
