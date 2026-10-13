extends Node3D
## Reusable faceted guardian kit. Animation is driven by the existing combat clock.
const Props=preload("res://scripts/props.gd")
var torso: MeshInstance3D
var core: MeshInstance3D
var arms: Array=[]
var plates: Array=[]
var glow: StandardMaterial3D
static var shared_stone_mesh: ArrayMesh

func stone(parent: Node3D, at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	if shared_stone_mesh!=null:
		var cached=Props.mesh_node(parent,shared_stone_mesh,at,color)
		cached.scale=size
		return cached
	var sphere=SphereMesh.new()
	sphere.radial_segments=7
	sphere.rings=3
	sphere.radius=.5
	sphere.height=1
	var source=sphere.get_mesh_arrays()
	var surface=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices=source[Mesh.ARRAY_VERTEX]
	var indices=source[Mesh.ARRAY_INDEX]
	for i in range(0,indices.size(),3):
		var a: Vector3=vertices[indices[i]]
		var b: Vector3=vertices[indices[i+1]]
		var c: Vector3=vertices[indices[i+2]]
		var normal=(c-a).cross(b-a).normalized()
		for point in [a,b,c]:
			surface.set_normal(normal)
			surface.add_vertex(point)
	shared_stone_mesh=surface.commit()
	var result=Props.mesh_node(parent,shared_stone_mesh,at,color)
	result.scale=size
	return result

func build() -> void:
	glow=StandardMaterial3D.new()
	glow.albedo_color=Color("#61efd1")
	glow.emission_enabled=true
	glow.emission=Color("#36cfae")
	glow.emission_energy_multiplier=1.5
	for x in [-.43,.43]:
		stone(self,Vector3(x,.25,.12),Vector3(.75,.5,.95),"#454e50")
		stone(self,Vector3(x,.72,0),Vector3(.5,.8,.5),"#65716a")
	torso=stone(self,Vector3(0,1.55,0),Vector3(1.55,1.5,.9),"#536562")
	core=stone(self,Vector3(0,1.7,.46),Vector3(.42,.68,.23),"#61efd1")
	core.material_override=glow
	for x in [-1,1]:
		var plate=stone(self,Vector3(x*.32,1.65,.46),Vector3(.55,1.05,.3),"#8b9586")
		plate.rotation.z=x*.15
		plates.append(plate)
		var arm=Node3D.new()
		arm.position=Vector3(x*.91,2.06,0)
		add_child(arm)
		arms.append(arm)
		stone(arm,Vector3(0,0,0),Vector3(.9,.72,.86),"#738174")
		stone(arm,Vector3(x*.12,-.52,.02),Vector3(.47,.8,.48),"#455b56")
		stone(arm,Vector3(x*.17,-.92,.13),Vector3(.68,.62,.72),"#859084")
		for z in [-.2,.14]:
			var spike=Props.cone(arm,Vector3(x*.17,.45,z),.17,.65 if z<0 else .4,"#b0b49d")
			spike.rotation.z=-x*.35
		var moss=stone(arm,Vector3(-x*.1,.29,.05),Vector3(.58,.15,.5),"#536839")
		moss.rotation.z=x*.2
		var rune=Props.box(self,Vector3(x*.53,1.9,.49),Vector3(.055,.35,.035),"#61efd1")
		rune.material_override=glow
		for i in range(3):
			var fissure=Props.box(plate,Vector3(.08*side_sign(x)*(i%2),-.35+i*.24,.47),Vector3(.06,.22,.04),"#61efd1")
			fissure.rotation.z=x*(.3 if i%2==0 else -.3)
			fissure.material_override=glow
	stone(self,Vector3(0,2.48,.02),Vector3(.83,.68,.7),"#7a857b")
	Props.box(self,Vector3(0,2.49,.38),Vector3(.68,.11,.07),"#192f30")
	for x in [-.18,.18]:
		var eye=Props.box(self,Vector3(x,2.49,.426),Vector3(.16,.055,.04),"#61efd1")
		eye.material_override=glow
	for i in range(5):
		var angle=(i-2)*.65
		var crown=Props.cone(self,Vector3(sin(angle)*.38,2.98,cos(angle)*.15),.13,.65 if i%2==0 else .38,"#b0b49d")
		crown.rotation.z=-angle*.38
	for x in [-.6,.6]:
		var root=Props.box(self,Vector3(x,.97,-.32),Vector3(.08,1.8,.1),"#554932")
		root.rotation.z=x*.35

func animate(state: String, remaining: float, armor: float, phase: float) -> void:
	var opening=1.0 if armor>0 else 0.0
	for i in range(plates.size()):
		var side=-1 if i==0 else 1
		plates[i].position.x=lerpf(plates[i].position.x,side*(.32+opening*.27),.15)
		plates[i].rotation.z=side*(.15+opening*.35)
	glow.emission_energy_multiplier=(2.4 if armor>0 else 1.1)+sin(phase*3)*.3
	core.scale=Vector3(.42,.68,.23)*(1+sin(phase*3)*.04)
	var lift=clampf((1.15-remaining)/.8,0,1) if state=="windup" else -.5*clampf(remaining/2.3,0,1) if state=="recover" else 0.0
	arms[1].rotation.x=-lift*1.8
	arms[0].rotation.z=sin(phase*1.8)*.045

func side_sign(value: float) -> float:
	return signf(value)
