extends RefCounted
# Original modular construction; surfaces reuse the project's verified CC0 maps.
const Props=preload("res://scripts/props.gd")
static func solid_rects(data:Dictionary) -> Array[Rect2]:
	match data.kind:
		"castle_wall": return [Rect2(-float(data.get("length",10))/2,-.6,float(data.get("length",10)),1.2)]
		"castle_tower": return [Rect2(-2.25,-2.25,4.5,4.5)]
		"castle_gate": return [Rect2(-6,-1.6,3.5,3.2),Rect2(2.5,-1.6,3.5,3.2)]
		"castle_keep": return [Rect2(-6.7,-4.7,13.4,9.4)]
		"market_stall": return [Rect2(-1.6,-.7,3.2,1.4)]
	return []

static func stone(parent:Node3D,at:Vector3,size:Vector3) -> MeshInstance3D:
	var mesh=Props.box(parent,at,size,"#9a9d93")
	mesh.material_override=load("res://scripts/environment_art.gd").village_material("UnevenBrick",.65)
	return mesh

static func battlements(parent:Node3D,length:float,y:float,z:float) -> void:
	for i in range(ceili(length/1.5)):
		stone(parent,Vector3(-length/2+.45+i*1.5,y,z),Vector3(.8,.85,.7))

static func tower(parent:Node3D,at:Vector3,height:float,radius:float) -> void:
	Props.camera_occluder(parent,at+Vector3(0,height/2,0),Vector3(radius*2,height+1,radius*2))
	var mesh=Props.cone(parent,at+Vector3(0,height/2,0),radius,height,"#92988b",radius)
	mesh.mesh.radial_segments=20
	mesh.material_override=load("res://scripts/environment_art.gd").village_material("UnevenBrick",.7)
	for y in [.35,height-.25]:
		var rim=Props.cone(parent,at+Vector3(0,y,0),radius+.13,.32,"#a7aa9d",radius+.13)
		rim.mesh.radial_segments=20;rim.material_override=mesh.material_override
	for i in range(12):
		var angle=i*TAU/12
		var merlon=stone(parent,at+Vector3(sin(angle)*radius,height+.35,cos(angle)*radius),Vector3(.7,.85,.65));merlon.rotation.y=angle
	for y in [height*.40,height*.72]:
		for i in range(4):
			var a=i*PI/2
			var slit=Props.box(parent,at+Vector3(sin(a)*(radius+.015),y,cos(a)*(radius+.015)),Vector3(.16,.8,.045),"#283033");slit.rotation.y=a

static func furnish(node:Node3D,data:Dictionary) -> void:
	match data.kind:
		"castle_wall":
			var length=float(data.get("length",10))
			stone(node,Vector3(0,2.15,0),Vector3(length,4.3,1.2))
			stone(node,Vector3(0,4.23,0),Vector3(length,.24,1.4));battlements(node,length,4.72,0)
			Props.collider(node,Vector3(0,2.5,0),Vector3(length,5,1.2))
		"castle_tower": tower(node,Vector3.ZERO,7.2,2.15)
		"castle_gate":
			for x in [-4.25,4.25]:
				stone(node,Vector3(x,2.9,0),Vector3(3.5,5.8,3.2))
				tower(node,Vector3(x,0,0),7.8,1.7)
			stone(node,Vector3(0,5.2,0),Vector3(5,1.2,3.2));battlements(node,12,6.2,0)
			# Stepped voussoirs frame the opening without closing its five metre route.
			for x in [-2.35,2.35]: stone(node,Vector3(x,4.1,0),Vector3(.3,.9,3.25))
			Props.camera_occluder(node,Vector3(0,5.2,0),Vector3(5,1.2,3.2))
			banner(node,Vector3(-3.5,4.9,1.76));banner(node,Vector3(3.5,4.9,1.76))
		"castle_keep":
			Props.camera_occluder(node,Vector3(0,4.1,0),Vector3(12,8.2,8))
			stone(node,Vector3(0,4.1,0),Vector3(12,8.2,8))
			stone(node,Vector3(0,.22,0),Vector3(12.2,.44,8.2))
			for x in [-5,5]:
				for z in [-3,3]: tower(node,Vector3(x,0,z),11.2,1.65)
			battlements(node,12,8.7,-3.8);battlements(node,12,8.7,3.8)
			var roof=load("res://scripts/environment_art.gd").model(load("res://scripts/environment_art.gd").VILLAGE+"glTF/Roof_RoundTiles_4x4.gltf",Vector3(8,2.8,6),false)
			roof.position.y=8.2;node.add_child(roof)
			Props.camera_occluder(node,Vector3(0,9.2,0),Vector3(8,3,6))
			var door=Props.box(node,Vector3(0,1.7,4.025),Vector3(2.4,3.4,.14),"#73523c")
			door.material_override=load("res://scripts/environment_art.gd").texture_material("brown_planks_05",1,Color("#8c7860"))
			for x in [-1.35,1.35]: stone(node,Vector3(x,1.85,4.13),Vector3(.3,3.7,.45))
			stone(node,Vector3(0,3.7,4.13),Vector3(3,.35,.45))
			for y in [1,2.5]: Props.box(node,Vector3(0,y,4.13),Vector3(2.35,.12,.08),"#434b4d")
			for x in [-3.6,0,3.6]:
				for y in [5.1,6.8]:
					stone(node,Vector3(x,y,4.06),Vector3(.95,1.3,.15))
					Props.box(node,Vector3(x,y,4.16),Vector3(.6,1.05,.05),"#35444b")
			banner(node,Vector3(-2.4,4.1,4.22));banner(node,Vector3(2.4,4.1,4.22))
		"market_stall":
			for x in [-1.45,1.45]:
				for z in [-.65,.65]: Props.box(node,Vector3(x,1.35,z),Vector3(.12,2.7,.12),"#72573d")
			Props.box(node,Vector3(0,.8,0),Vector3(3.2,.2,1.4),"#896b47")
			for i in range(6):
				var awning=Props.box(node,Vector3(-1.5+i*.6,2.55,0),Vector3(.6,.10,2.1),"#496b74" if i%2 else "#d6c7a6");awning.rotation.x=.10
			for i in range(3):
				Props.box(node,Vector3(-1+i,.98,0),Vector3(.72,.18,.68),"#665039")
				for j in range(5):
					var fruit=SphereMesh.new();fruit.radius=.1;fruit.height=.2
					Props.mesh_node(node,fruit,Vector3(-1+i+sin(j*2.4)*.2,1.15,cos(j*2.4)*.2),"#b78848" if i==1 else "#728d52")
			Props.camera_occluder(node,Vector3(0,2.55,0),Vector3(3.6,.3,2.1))
	for rect in solid_rects(data):
		var center=rect.get_center();Props.collider(node,Vector3(center.x,2,center.y),Vector3(rect.size.x,4,rect.size.y))
	Props.batch_kit(node,"castle/%s/%s"%[data.kind,data.get("length",10)])

static func banner(parent:Node3D,at:Vector3) -> void:
	Props.box(parent,at,Vector3(.8,1.8,.045),"#355a6b")
	Props.box(parent,at+Vector3(0,.45,.03),Vector3(.13,.55,.02),"#d3b56e")
	Props.box(parent,at+Vector3(0,.35,.035),Vector3(.4,.1,.02),"#d3b56e")
