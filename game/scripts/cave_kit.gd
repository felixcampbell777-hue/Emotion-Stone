extends RefCounted
const Props=preload("res://scripts/props.gd")
static func feature(node:Node3D,style:String) -> void:
	if style in ["cave_mouth","arch"]:
		for sign in [-1,1]:
			for tier in range(3):
				var rock=Props.box(node,Vector3(sign*(1.6-tier*.12),.5+tier*.85,0),Vector3(.95,1,.9),"#717b79" if tier%2 else "#8b9185")
				rock.rotation.z=sign*.10
			Props.collider(node,Vector3(sign*1.45,1.15,0),Vector3(.85,2.3,.9))
		Props.box(node,Vector3(0,2.7,0),Vector3(2.4,.7,1.1),"#7c857f")
		Props.camera_occluder(node,Vector3(0,2.7,0),Vector3(2.4,.7,1.1))
		if style=="cave_mouth":
			for sign in [-1,1]: Props.box(node,Vector3(sign*2.35,1.15,-.7),Vector3(1.5,2.3,1.8),"#66756a")
			Props.box(node,Vector3(0,1.2,-.6),Vector3(2.0,2.4,.06),"#283a39")
	elif style=="stalagmites":
		for i in range(6):
			var at=Vector3(sin(i*2.4)*.75,0,cos(i*2.4)*.6)
			var h=.6+i*.18
			Props.cone(node,at+Vector3.UP*h/2,.23,h,"#909389",.025)
		Props.collider(node,Vector3(0,.65,0),Vector3(1.7,1.3,1.5))
	else:
		for i in range(6):
			var crystal=Props.cone(node,Vector3(sin(i*2.4)*.5,.4,cos(i*2.4)*.4),.17,.8+i*.07,"#64b2c4",0)
			crystal.rotation.z=sin(i)*.3
		Props.collider(node,Vector3(0,.35,0),Vector3(1.1,.7,1.1))
		var glow=OmniLight3D.new(); glow.position.y=1; glow.light_color=Color("#62bbdf"); glow.light_energy=1.7; glow.omni_range=5; node.add_child(glow)
static func room(node:Node3D) -> void:
	Props.box(node,Vector3(0,-.15,0),Vector3(16,.25,17),"#687271")
	# Cave walls are physical; overhead cuts only their upper foreground pieces.
	for x in [-7.7,7.7]:
		wall(node,Vector3(x,1.5,-.5),Vector3(.6,3,17))
	wall(node,Vector3(0,1.5,-8.7),Vector3(16,3,.6))
	for x in [-4.7,4.7]: wall(node,Vector3(x,1.5,7.7),Vector3(6.6,3,.6))
	# Alternating buttresses form the winding passage and open crystal chamber.
	wall(node,Vector3(-4.4,1.4,2.6),Vector3(5.9,2.8,1.2))
	wall(node,Vector3(4.5,1.4,-.7),Vector3(5.7,2.8,1.2))
	for i in range(10):
		var at=Vector3((-1 if i%2 else 1)*6.8,1.1,-7+i*1.45)
		Props.cone(node,at,.7,2.2,"#7f8780",.25)
	# Irregular rock planes break the room kit into a natural cave silhouette.
	for i in range(22):
		var sign=-1 if i%2 else 1
		var mesh=SphereMesh.new(); mesh.radius=.7+(i%3)*.16; mesh.height=2.8; mesh.radial_segments=6; mesh.rings=3
		Props.mesh_node(node,mesh,Vector3(sign*7.35,1.1,-8+(i/2)*1.45),"#65756f" if i%3 else "#7c8980")
		Props.collider(node,Vector3(sign*7.1,1.1,-8+(i/2)*1.45),Vector3(.8,2.2,1.2))
	for i in range(90):
		var at=Vector3(sin(i*2.4)*6.6,.012,-7+fmod(i*1.73,14))
		Props.cone(node,at,.06+(i%4)*.02,.024,"#79887e" if i%2 else "#475b57",.05)
	var ceiling=Props.box(node,Vector3(0,3.3,-.5),Vector3(16,.25,17),"#5f6a67")
	ceiling.name="CaveCeiling"
	Props.camera_occluder(node,Vector3(0,3.3,-.5),Vector3(16,.25,17))
	for at in [Vector3(-2,1.5,5),Vector3(2,1.5,-2),Vector3(0,1.5,-7)]:
		var light=OmniLight3D.new(); light.position=at; light.light_color=Color("#c9b18d"); light.light_energy=.65; light.omni_range=6; node.add_child(light)
static func wall(node:Node3D,at:Vector3,size:Vector3) -> void:
	var mesh=Props.box(node,at,size,"#747e78"); mesh.name="CaveWall"
	Props.collider(node,at,size)
