extends RefCounted
## Small modular scenery kit. Coordinates and palette are independent of map layouts.

static var materials: Dictionary = {}

static func mat(hex: String) -> StandardMaterial3D:
	if materials.has(hex):
		return materials[hex]
	var result = StandardMaterial3D.new()
	result.albedo_color = Color(hex)
	result.roughness = 1.0
	materials[hex] = result
	return result

static func mesh_node(parent: Node3D, mesh: Mesh, at: Vector3, color: String) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat(color)
	node.position = at
	parent.add_child(node)
	return node

static func box(parent: Node3D, at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	return mesh_node(parent, mesh, at, color)

static func cone(parent: Node3D, at: Vector3, radius: float, height: float, color: String, top: float = 0.0) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	return mesh_node(parent, mesh, at, color)

static func collider(parent: Node3D, at: Vector3, size: Vector3) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body

static func roof(parent: Node3D, width: float, depth: float, y: float, color: String) -> void:
	var a = Vector3(-width/2,y,depth/2)
	var b = Vector3(width/2,y,depth/2)
	var c = Vector3(0,y+.95,depth/2)
	var d = Vector3(-width/2,y,-depth/2)
	var e = Vector3(width/2,y,-depth/2)
	var f = Vector3(0,y+.95,-depth/2)
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle in [[a,c,b],[d,e,f],[a,d,f],[a,f,c],[c,f,e],[c,e,b]]:
		for vertex in triangle:
			surface.add_vertex(vertex)
	surface.generate_normals()
	mesh_node(parent, surface.commit(), Vector3.ZERO, color)

static func create(definition: Dictionary) -> Node3D:
	var node = Node3D.new()
	node.name = definition.get("id", "Prop")
	var at = definition.get("at", [0,0])
	node.position = Vector3(at[0],0,at[1])
	node.rotation.y = deg_to_rad(float(definition.get("rotation",0)))
	node.scale = Vector3.ONE * float(definition.get("scale",1))
	var kind = definition.get("kind", "tree")
	match kind:
		"tree":
			cone(node,Vector3(0,.45,0),.13,.9,"#70523d",.1)
			cone(node,Vector3(0,1.35,0),1.05,1.35,"#416654",.10)
			cone(node,Vector3(0,1.98,0),.82,1.3,"#50765c",.04)
			cone(node,Vector3(0,2.57,0),.56,1.22,"#63886a")
			collider(node,Vector3(0,.7,0),Vector3(.35,1.4,.35))
		"house":
			var variant = int(definition.get("variant",0))
			box(node,Vector3(0,.17,0),Vector3(3.3,.34,2.6),"#90978c")
			box(node,Vector3(0,1.10,0),Vector3(3.05,1.85,2.4),"#e4d5b8" if variant==0 else "#d4c7ae")
			roof(node,3.65,2.95,2.02,"#b56e57" if variant==0 else "#798b8b")
			box(node,Vector3(.88,2.72,-.35),Vector3(.38,.9,.45),"#a69b87")
			box(node,Vector3(0,.62,1.215),Vector3(.68,1.25,.035),"#685241")
			box(node,Vector3(0,1.30,1.24),Vector3(.82,.14,.11),"#b8ab90")
			box(node,Vector3(.18,.62,1.25),Vector3(.055,.055,.025),"#e9c37b")
			for x in [-1.02,1.02]:
				box(node,Vector3(x,1.17,1.217),Vector3(.6,.67,.04),"#827863")
				box(node,Vector3(x,1.17,1.249),Vector3(.47,.54,.04),"#79a5aa")
				box(node,Vector3(x,1.17,1.277),Vector3(.035,.54,.018),"#eee3ca")
				box(node,Vector3(x,1.17,1.277),Vector3(.47,.035,.018),"#eee3ca")
				box(node,Vector3(x,.70,1.29),Vector3(.72,.18,.25),"#795c47")
				cone(node,Vector3(x,.90,1.29),.33,.18,"#6e9161",.22)
			box(node,Vector3(0,.095,1.42),Vector3(.9,.19,.44),"#c1ba9f")
			collider(node,Vector3(0,1.0,0),Vector3(3.15,2.0,2.45))
		"wall":
			var length = float(definition.get("length",3))
			box(node,Vector3(0,.30,0),Vector3(length,.6,.33),"#abb1a0")
			for i in range(int(ceil(length/.55))):
				box(node,Vector3(-length/2+.25+i*.55,.60,0),Vector3(.52,.13,.40),"#c5c6af")
			collider(node,Vector3(0,.4,0),Vector3(length,.8,.4))
		"rock":
			var sphere = SphereMesh.new()
			sphere.radius = .68
			sphere.height = .85
			sphere.radial_segments = 7
			sphere.rings = 3
			mesh_node(node,sphere,Vector3(0,.28,0),"#939b91")
			collider(node,Vector3(0,.3,0),Vector3(.8,.6,.7))
		"flowers":
			for i in range(7):
				var x = sin(i*2.4)*.45
				var z = cos(i*2.4)*.34
				box(node,Vector3(x,.15,z),Vector3(.028,.3,.028),"#5b7e51")
				box(node,Vector3(x,.30,z),Vector3(.15,.08,.15),"#dfa59f" if i%2==0 else "#ead5a0")
		"bench":
			box(node,Vector3(0,.44,0),Vector3(1.35,.10,.43),"#a1855d")
			box(node,Vector3(0,.79,-.2),Vector3(1.35,.35,.08),"#947b56")
			for x in [-.48,.48]:
				box(node,Vector3(x,.22,0),Vector3(.10,.44,.35),"#665344")
			collider(node,Vector3(0,.4,0),Vector3(1.35,.8,.48))
		"well":
			cone(node,Vector3(0,.25,0),.72,.5,"#a9b1a2",.72)
			cone(node,Vector3(0,.505,0),.50,.015,"#55747a",.50)
			for x in [-.57,.57]:
				box(node,Vector3(x,1.04,0),Vector3(.12,1.75,.14),"#8e7354")
			roof(node,1.7,1.3,1.85,"#b98060")
			collider(node,Vector3(0,.5,0),Vector3(1.35,1,1.35))
		"sign":
			box(node,Vector3(0,.49,0),Vector3(.10,.98,.10),"#786248")
			box(node,Vector3(0,.97,0),Vector3(.73,.43,.10),"#b9a078")
			box(node,Vector3(0,.97,.058),Vector3(.41,.042,.01),"#705c42")
			collider(node,Vector3(0,.4,0),Vector3(.2,.8,.2))
	return node
