extends Node3D
## Authored reusable seawyrm: continuous water body, fins, horns, jaws and whiskers.
var water:ShaderMaterial
var foam:ShaderMaterial
var body:MeshInstance3D
var head:Node3D
var splash:Node3D
var droplets:Array[MeshInstance3D]=[]
var spine:Array[MeshInstance3D]=[]
var impact_ring:MeshInstance3D
var impact_core:MeshInstance3D

func material(tint:Color) -> ShaderMaterial:
	var result=ShaderMaterial.new();result.shader=load("res://shaders/mana_water.gdshader");result.set_shader_parameter("tint",tint);return result
func mesh_node(mesh:Mesh,where:Vector3,mat:Material,parent:Node3D=null) -> MeshInstance3D:
	if parent==null: parent=self
	var node=MeshInstance3D.new();node.mesh=mesh;node.material_override=mat;node.position=where;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(node);return node
func ellipsoid(where:Vector3,size:Vector3,mat:Material,parent:Node3D) -> MeshInstance3D:
	var mesh=SphereMesh.new();mesh.radius=.5;mesh.height=1;mesh.radial_segments=24;mesh.rings=12
	var node=mesh_node(mesh,where,mat,parent);node.scale=size;return node
func tube(points:Array,radii:Array,mat:Material,parent:Node3D) -> MeshInstance3D:
	return mesh_node(tube_mesh(points,radii),Vector3.ZERO,mat,parent)
func tube_mesh(points:Array,radii:Array) -> ArrayMesh:
	var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings:Array=[];var count=points.size()
	for i in range(count):
		var tangent:Vector3=(points[mini(i+1,count-1)]-points[maxi(0,i-1)]).normalized()
		if tangent.length_squared()<.01: tangent=Vector3.BACK
		var right=tangent.cross(Vector3.UP).normalized()
		if right.length_squared()<.01: right=Vector3.RIGHT
		var up=right.cross(tangent).normalized();var ring=[]
		for j in range(13): ring.append(points[i]+(right*cos(TAU*j/12)+up*sin(TAU*j/12))*float(radii[i]))
		rings.append(ring)
	for i in range(count-1):
		for j in range(12):
			for corner in [[i,j],[i+1,j],[i,j+1],[i,j+1],[i+1,j],[i+1,j+1]]:
				surface.set_uv(Vector2(float(corner[1])/12,float(corner[0])/(count-1)));surface.add_vertex(rings[corner[0]][corner[1]])
	surface.generate_normals();return surface.commit()
func fin(size:Vector3,mat:Material,parent:Node3D) -> MeshInstance3D:
	var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points=[Vector3.ZERO,Vector3(size.x,size.y,size.z*.6),Vector3(0,0,size.z),Vector3.ZERO,Vector3(size.x,size.y,size.z*.6),Vector3(size.x*.6,size.y*.55,-size.z*.25)]
	for i in range(points.size()): surface.set_uv(Vector2(float(i%3)/2,float(i/3)));surface.add_vertex(points[i])
	surface.generate_normals();return mesh_node(surface.commit(),Vector3.ZERO,mat,parent)
func build() -> void:
	water=material(Color(.015,.32,.57,.9));foam=material(Color(.32,.88,1,.83))
	head=Node3D.new();add_child(head)
	ellipsoid(Vector3(0,0,-.2),Vector3(.82,.58,1.2),water,head)
	ellipsoid(Vector3(0,-.08,-.83),Vector3(.55,.24,.94),water,head)
	ellipsoid(Vector3(0,-.23,-.74),Vector3(.53,.10,.83),foam,head)
	ellipsoid(Vector3(0,-.02,-1.12),Vector3(.52,.16,.18),foam,head)
	for side in [-1,1]:
		ellipsoid(Vector3(side*.32,.11,-.43),Vector3(.11,.10,.18),foam,head)
		ellipsoid(Vector3(side*.27,.18,-.37),Vector3(.22,.07,.34),water,head)
		tube([Vector3(side*.26,.18,.1),Vector3(side*.32,.40,.35),Vector3(side*.43,.65,.63),Vector3(side*.55,.77,.79)],[.10,.075,.045,.003],foam,head)
		tube([Vector3(side*.20,-.02,-1.1),Vector3(side*.55,.01,-.94),Vector3(side*.93,.10,-.48),Vector3(side*1.13,.24,.25)],[.025,.022,.015,.003],foam,head)
		var ear=fin(Vector3(side*.55,.14,.65),foam,head);ear.position=Vector3(side*.27,-.10,.02)
		var wing=fin(Vector3(side*1.0,-.22,1.6),water,head);wing.position=Vector3(side*.3,-.13,.65)
	body=mesh_node(ArrayMesh.new(),Vector3.ZERO,water)
	for i in range(9):
		var dorsal=fin(Vector3(.025,.30*(1-float(i)/12),.48),foam,self);spine.append(dorsal)
	splash=Node3D.new();add_child(splash);splash.visible=false
	var rim=TorusMesh.new();rim.inner_radius=.83;rim.outer_radius=1;rim.rings=32;rim.ring_segments=12
	impact_ring=mesh_node(rim,Vector3(0,.12,0),foam,splash)
	impact_core=ellipsoid(Vector3.ZERO,Vector3.ONE,water,splash)
	for i in range(30): droplets.append(ellipsoid(Vector3.ZERO,Vector3(.10,.25,.10),foam,splash))
func update_shape(centers:Array,clock:float,birth:float) -> void:
	water.set_shader_parameter("clock",clock);foam.set_shader_parameter("clock",clock)
	head.scale=Vector3.ONE*maxf(.04,birth)
	var points=[];var radii=[]
	for i in range(centers.size()):
		points.append(to_local(centers[i]));var phase=float(i)/(centers.size()-1)
		radii.append(maxf(.007,.38*(1-phase)*smoothstep(0,.08,phase+.08))*maxf(.04,birth))
	body.mesh=tube_mesh(points,radii)
	for i in range(spine.size()):
		var index=mini(centers.size()-2,1+i*2);spine[i].position=points[index]+Vector3(0,radii[index]*.8,0)
		spine[i].scale=Vector3.ONE*birth
		var toward:Vector3=points[index+1]-points[index]
		if toward.length_squared()>.001: spine[i].quaternion=Quaternion(Vector3.BACK,toward.normalized())
func show_impact(progress:float,radius:float) -> void:
	head.visible=false;body.visible=false
	for fin_node in spine: fin_node.visible=false
	splash.visible=true
	impact_ring.scale=Vector3.ONE*(.2+radius*smoothstep(0,.5,progress))
	impact_core.scale=Vector3.ONE*(.3+radius*.65*smoothstep(0,.4,progress))
	water.set_shader_parameter("dissolve",1-progress);foam.set_shader_parameter("dissolve",1-progress)
	for i in range(droplets.size()):
		var angle=TAU*i/droplets.size();var up=sin(i*2.7)*.6+.3
		droplets[i].position=Vector3(cos(angle),up,sin(angle))*radius*smoothstep(0,1,progress)*1.2
		droplets[i].scale=Vector3(.10,.25,.10)*(1-progress)*2
