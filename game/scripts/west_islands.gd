extends RefCounted
## Shared geometry/support contract for the western stepping islands.
const P=preload("res://scripts/props.gd")
const Art=preload("res://scripts/environment_art.gd")
const ISLANDS=[
	{"center":Vector3(-278,34,48),"radius":22.0,"rise":5.0},
	{"center":Vector3(-331,37,16),"radius":19.0,"rise":4.0},
	{"center":Vector3(-376,35,65),"radius":22.0,"rise":5.5},
	{"center":Vector3(-437,35,55),"radius":34.0,"rise":3.5}]
const GROVE=Vector3(-437,35,55)
const BRIDGE_WIDTH=4.8
static var link_cache:Array=[]
static var cached_level:float=NAN
static func bridge_level() -> float:
	if is_nan(cached_level):cached_level=load("res://scripts/rise_shape.gd").height(Vector3(-233.4,0,55))
	return cached_level
static func island_height(island:Dictionary,at:Vector3) -> float:
	var d=Vector2(at.x-island.center.x,at.z-island.center.z)/float(island.radius)
	# A shallow rolling mound with a level outer metal verge and a broad fighting floor.
	return bridge_level()+float(island.rise)*pow(maxf(0,1-d.length_squared()),2)
static func links() -> Array:
	if not link_cache.is_empty():return link_cache
	var result=[]
	for i in range(ISLANDS.size()):
		var next:Dictionary=ISLANDS[i];var a:Vector3
		if i==0:
			a=Vector3(-233.4,bridge_level(),55)
		else:
			var prev:Dictionary=ISLANDS[i-1];a=prev.center+((next.center-prev.center)*Vector3(1,0,1)).normalized()*float(prev.radius);a.y=island_height(prev,a)
		var b:Vector3=next.center+((a-next.center)*Vector3(1,0,1)).normalized()*float(next.radius);a.y=bridge_level();b.y=bridge_level()
		result.append([a,b])
	link_cache=result;return result
static func support(at:Vector3) -> float:
	for island in ISLANDS:
		if Vector2(at.x-island.center.x,at.z-island.center.z).length()<=float(island.radius):return island_height(island,at)
	for link in links():
		var a:Vector3=link[0];var b:Vector3=link[1];var d=Vector2(b.x-a.x,b.z-a.z);var v=Vector2(at.x-a.x,at.z-a.z);var t=v.dot(d)/d.length_squared()
		if t>=0 and t<=1 and absf(v.cross(d.normalized()))<=BRIDGE_WIDTH*.5:return lerpf(a.y,b.y,t)
	return NAN
static func grove_trees() -> Array:
	var result=[]
	for i in range(22):
		var angle=i*TAU/22.0
		# The eastern gap frames the approach and leaves a readable entrance.
		if absf(wrapf(angle,-PI,PI))<.32:continue
		result.append(GROVE+Vector3(cos(angle),0,sin(angle))*(25.0+1.2*sin(i*2.4)))
	return result
static func safe(at:Vector3) -> bool:
	if is_nan(support(at)):return false
	for tree in grove_trees():
		if Vector2(at.x-tree.x,at.z-tree.z).length()<1.05:return false
	return true
static func vertex(st:SurfaceTool,p:Vector3) -> void:st.set_uv(Vector2(p.x,p.z));st.add_vertex(p)
static func triangle(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3) -> void:
	st.set_normal((b-a).cross(c-a).normalized())
	for p in [a,b,c]:vertex(st,p)
static func surface(world:Node,st:SurfaceTool,label:String,mat:Material) -> void:
	var mesh=st.commit();var n=MeshInstance3D.new();n.name=label;n.mesh=mesh;n.material_override=mat;world.add_child(n)
	var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;var c=CollisionShape3D.new();c.shape=mesh.create_trimesh_shape();c.shape.backface_collision=true;body.add_child(c);world.add_child(body)
static func build(world:Node,ground:ShaderMaterial) -> void:
	var rock=preload("res://scripts/rise_chamber.gd").stone_material()
	for i in range(ISLANDS.size()):
		var island:Dictionary=ISLANDS[i];var center:Vector3=island.center;center.y=bridge_level();var r:float=island.radius
		var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for ring in range(8):
			for sector in range(96):
				var points=[]
				for pair in [[ring,sector],[ring+1,sector],[ring,sector+1],[ring+1,sector+1]]:
					var angle=pair[1]*TAU/96;var p=center+Vector3(cos(angle),0,sin(angle))*r*pair[0]/8.0;p.y=island_height(island,p);points.append(p)
				if ring>0:triangle(st,points[0],points[2],points[1])
				triangle(st,points[1],points[2],points[3])
		var mat=ground.duplicate();mat.set_shader_parameter("terrain_center",Vector2(center.x,center.z));mat.set_shader_parameter("terrain_radius",r);mat.set_shader_parameter("arrival_enabled",false)
		surface(world,st,"WesternHill_%d"%i,mat)
		var sides=SurfaceTool.new();sides.begin(Mesh.PRIMITIVE_TRIANGLES)
		for sector in range(96):
			var a=sector*TAU/96;var b=(sector+1)*TAU/96;var pa=center+Vector3(cos(a)*r,0,sin(a)*r);var pb=center+Vector3(cos(b)*r,0,sin(b)*r)
			var da=center+Vector3(cos(a)*r*.3,-24-3*sin(a*5),sin(a)*r*.3);var db=center+Vector3(cos(b)*r*.3,-24-3*sin(b*5),sin(b)*r*.3)
			triangle(sides,pa,pb,da);triangle(sides,pb,db,da)
		surface(world,sides,"WesternRockUnderside_%d"%i,rock)
	for i in range(links().size()):
		var link=links()[i];var a:Vector3=link[0];var b:Vector3=link[1];var direction=(b-a).normalized();var side=direction.cross(Vector3.UP).normalized()*BRIDGE_WIDTH*.5
		var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);triangle(st,a-side,a+side,b-side);triangle(st,a+side,b+side,b-side)
		var metal=P.mat("#7d8985").duplicate();metal.metallic=.65;metal.roughness=.44;metal.cull_mode=BaseMaterial3D.CULL_DISABLED;surface(world,st,"WesternBridge_%d"%i,metal)
		# Timber decking and metal edge beams follow the actual sloped walking surface.
		for j in range(ceili(a.distance_to(b)/.75)):
			var pos=a.lerp(b,(j+.5)/ceili(a.distance_to(b)/.75))
			var plank=P.box(world,pos-Vector3.UP*.09,Vector3(BRIDGE_WIDTH-.3,.16,.72),"#80694d");plank.basis=Basis(side.normalized(),direction.cross(side.normalized()),direction).orthonormalized()
	for i in range(grove_trees().size()):
		var at:Vector3=grove_trees()[i];at.y=support(at);var h=14.0+(i%4)*1.5
		var tree=Art.model(Art.ROOT+"models/fir_a.glb",Vector3(7,h,7),false)
		if tree!=null:world.add_child(tree);tree.position=at;tree.rotation.y=i*2.4;Art.add_canopy(tree,h,i%3)
		var trunk=StaticBody3D.new();trunk.collision_layer=1;trunk.collision_mask=0;var c=CollisionShape3D.new();var shape=CylinderShape3D.new();shape.radius=.8;shape.height=5;c.shape=shape;trunk.add_child(c);world.add_child(trunk);trunk.position=at+Vector3.UP*2.5
	var moon=OmniLight3D.new();moon.name="WesternGroveMoonlight";moon.position=Vector3(GROVE.x+4,bridge_level()+10,GROVE.z);moon.light_color=Color("#9bb9db");moon.light_energy=5.5;moon.omni_range=45;moon.shadow_enabled=true;world.add_child(moon)
