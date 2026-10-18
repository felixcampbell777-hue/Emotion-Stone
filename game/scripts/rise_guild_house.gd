extends RefCounted
const P=preload("res://scripts/props.gd")
const Art=preload("res://scripts/environment_art.gd")
const Shape=preload("res://scripts/rise_shape.gd")
static var materials:Dictionary={}
static func material(kind:String) -> Material:
	if materials.has(kind):return materials[kind]
	var mat:StandardMaterial3D
	match kind:
		"wood":mat=Art.texture_material("brown_planks_05",.65,Color("#705039"))
		"plaster":mat=Art.village_material("Plaster",.5);mat.albedo_color=Color("#e4cfab")
		"stone":mat=Art.village_material("UnevenBrick",.6);mat.albedo_color=Color("#94938a")
		"floor":mat=Art.texture_material("brown_planks_05",.8,Color("#aa8864"))
		"iron":mat=P.mat("#343b3e");mat.metallic=.7;mat.roughness=.42
		"glass":mat=P.mat("#536361");mat.metallic=.25;mat.roughness=.25
		_:mat=P.mat(kind)
	materials[kind]=mat;return mat
static func box(parent:Node3D,at:Vector3,size:Vector3,kind:String,solid:bool=true) -> MeshInstance3D:
	var n=P.box(parent,at,size,"#9d947c");n.material_override=material(kind)
	if solid:P.collider(parent,at,size)
	return n
static func beam(parent:Node3D,a:Vector3,b:Vector3,width:float=.18,kind:String="wood") -> void:
	var n=box(parent,(a+b)*.5,Vector3(width,a.distance_to(b),width),kind,false)
	n.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
static func placard(parent:Node3D,at:Vector3,text:String,size:int=40) -> void:
	var label=Label3D.new();label.text=text;label.font_size=size;label.pixel_size=.006 if size<=26 else .01;label.position=at;label.rotation.y=PI;label.modulate=Color("#f1d5a0");parent.add_child(label)
static func lantern(parent:Node3D,at:Vector3) -> void:
	beam(parent,at+Vector3(0,.5,0),at,.04,"iron")
	var glow=StandardMaterial3D.new();glow.albedo_color=Color("#ffe2a4");glow.emission_enabled=true;glow.emission=Color("#ffb354");glow.emission_energy_multiplier=2.3
	var pane=box(parent,at,Vector3(.22,.34,.22),"glass",false);pane.material_override=glow
	for y in [-.2,.2]:box(parent,at+Vector3(0,y,0),Vector3(.34,.07,.34),"iron",false)
	for x in [-.13,.13]:
		for z in [-.13,.13]:beam(parent,at+Vector3(x,-.2,z),at+Vector3(x,.2,z),.035,"iron")
	var light=OmniLight3D.new();light.position=at+Vector3(0,-.25,0);light.light_color=Color("#ffd29a");light.light_energy=2.4;light.omni_range=8;parent.add_child(light)
static func window(parent:Node3D,at:Vector3,yaw:float,width:float=2.3) -> void:
	var r=Node3D.new();parent.add_child(r);r.position=at;r.rotation.y=yaw
	box(r,Vector3.ZERO,Vector3(width,1.9,.12),"glass")
	for x in [-width/2,0,width/2]:box(r,Vector3(x,0,-.1),Vector3(.12,2.14,.18),"wood",false)
	for y in [-1,0,1]:box(r,Vector3(0,y,-.1),Vector3(width+.3,.12,.22),"wood",false)
	box(r,Vector3(0,-1.07,-.15),Vector3(width+.55,.16,.5),"stone",false)
	for x in [-width/2-.4,width/2+.4]:
		box(r,Vector3(x,0,-.05),Vector3(.5,1.95,.16),"wood",false)
		for y in [-.65,.65]:box(r,Vector3(x,y,-.15),Vector3(.55,.07,.06),"iron",false)
	# Fine lead diamonds make glass read as a window rather than a blue panel.
	for face in [-1,1]:
		for x in [-width/2,0,width/2]:box(r,Vector3(x,0,face*.13),Vector3(.12,2.14,.12),"wood",false)
		for y in [-1,0,1]:box(r,Vector3(0,y,face*.13),Vector3(width+.3,.12,.12),"wood",false)
		for x in range(-3,4):
			for tilt in [-1,1]:beam(r,Vector3(x*.5-.24*tilt,-.85,face*.14),Vector3(x*.5+.24*tilt,.85,face*.14),.018,"iron")
static func roof(parent:Node3D,half_width:float,depth:float,eave:float,ridge:float,at:Vector3=Vector3.ZERO) -> void:
	var r=Node3D.new();parent.add_child(r);r.position=at
	var angle=atan2(ridge-eave,half_width)
	for side in [-1,1]:
		var cover=box(r,Vector3(side*half_width*.5,(ridge+eave)*.5,0),Vector3(half_width/cos(angle),.16,depth),"#38434c",false);cover.rotation.z=-side*angle
		var roof_body=P.collider(r,cover.position,cover.mesh.size);roof_body.rotation.z=-side*angle
		var lining=box(r,Vector3(side*half_width*.5,(ridge+eave)*.5-.12,0),Vector3(half_width/cos(angle),.07,depth),"wood",false);lining.rotation.z=-side*angle
		for row in range(ceili(half_width/.72)):
			var x=minf((row+.5)*.72,half_width-.1)
			for col in range(ceili(depth/.92)):
				var z=-depth/2+(col+.5)*.92+(row%2)*.19
				if z>depth/2:continue
				var tint=["#4c5b63","#56636b","#44535d","#607079"][(row*7+col*3)%4]
				var tile=box(r,Vector3(side*x,ridge-x*tan(angle)+.13,z),Vector3(.85/cos(angle),.09,.88),tint,false);tile.rotation.z=-side*angle
		for z in [-depth/2,depth/2]:beam(r,Vector3(0,ridge+.2,z),Vector3(side*half_width,eave+.2,z),.25)
		beam(r,Vector3(side*half_width,eave,-depth/2),Vector3(side*half_width,eave,depth/2),.28)
	beam(r,Vector3(0,ridge+.2,-depth/2-.2),Vector3(0,ridge+.2,depth/2+.2),.32)
	P.batch_kit(r,"rise_guild_roof_%s_%s_%s"%[half_width,depth,ridge])
static func gable(parent:Node3D,z:float) -> void:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [Vector3(-11,4.8,z),Vector3(0,10.95,z),Vector3(11,4.8,z)]:st.add_vertex(point)
	st.generate_normals();var n=MeshInstance3D.new();n.mesh=st.commit();n.material_override=material("plaster").duplicate();n.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED;parent.add_child(n)
	for x in [-8,-5,0,5,8]:beam(parent,Vector3(x,4.8,z-.12),Vector3(x,10.95-absf(x)*.559,z-.12),.23)
	for side in [-1,1]:beam(parent,Vector3(0,5,z-.15),Vector3(side*8,6.3,z-.15),.2)
static func build(world:Node3D) -> void:
	var root=Node3D.new();root.name="AdventurersGuild";world.add_child(root);root.position=Vector3(Shape.spec.guild.at[0],Shape.spec.guild.height,Shape.spec.guild.at[1]);root.rotation.y=Shape.spec.guild.rotation
	# The doorway remains open for the player, but an enemy-only boundary keeps hostile actors outside.
	var barrier=preload("res://scripts/guild_safe_barrier.gd").new();barrier.build(root,Vector3(0,0,-9.05),3.35)
	box(root,Vector3(0,.012,0),Vector3(22,.02,18),"floor",false)
	# Real openings in the stone-and-plaster envelope, with matching solid sills.
	for x in [-11,11]:
		box(root,Vector3(x,.6,0),Vector3(.5,1.2,18),"stone")
		box(root,Vector3(x,4.2,0),Vector3(.4,1.2,18),"plaster")
		for z in [-8.4,-2.8,2.8,8.4]:box(root,Vector3(x,2.4,z),Vector3(.4,2.4,1.2),"plaster")
		for z in [-5.6,0,5.6]:window(root,Vector3(x,2.55,z),PI/2 if x<0 else -PI/2,3.9)
		for z in [-8.8,-2.8,2.8,8.8]:
			box(root,Vector3(x,2.4,z),Vector3(.55,4.8,.32),"wood",false)
		for y in [1.2,3.65,4.8]:box(root,Vector3(x,y,0),Vector3(.58,.23,18),"wood",false)
	box(root,Vector3(0,2.4,9),Vector3(22,4.8,.45),"plaster")
	box(root,Vector3(0,.6,9.03),Vector3(22,1.2,.5),"stone",false)
	for x in [-6.3,6.3]:
		# Front window panels, framed between heavy timber bays.
		box(root,Vector3(x,.6,-9),Vector3(9.4,1.2,.5),"stone")
		box(root,Vector3(x,4.2,-9),Vector3(9.4,1.2,.4),"plaster")
		for dx in [-3.65,3.65]:box(root,Vector3(x+dx,2.4,-9),Vector3(2.1,2.4,.4),"plaster")
		window(root,Vector3(x,2.55,-9.05),0,4.7)
	for z in [-9,9]:
		gable(root,z)
		for y in [1.2,3.65,4.8]:
			if z<0 and y<2:
				for x in [-6.3,6.3]:box(root,Vector3(x,y,z-.1),Vector3(9.4,.25,.55),"wood",false)
			else:box(root,Vector3(0,y,z-.1),Vector3(22.5,.25,.55),"wood",false)
		for x in [-10.8,-1.65,1.65,10.8]:box(root,Vector3(x,2.4,z),Vector3(.35,4.8,.6),"wood",false)
		for side in [-1,1]:beam(root,Vector3(side*1.9,3.7,z-.3),Vector3(side*3.3,4.7,z-.3),.24)
	# Clear the entrance band while retaining the continuous upper tie beam.
	# Central door remains a 3.2m open portal; none of the trim has collision.
	roof(root,12,20,4.8,11.5)
	# A lower cross-gable porch breaks the box silhouette and shelters arrival.
	box(root,Vector3(0,.018,-11.2),Vector3(9,.03,4.4),"stone",false)
	for x in [-4.2,4.2]:
		box(root,Vector3(x,1.95,-13.1),Vector3(.35,3.9,.35),"wood")
		box(root,Vector3(x,.3,-13.1),Vector3(.6,.6,.6),"stone",false)
		beam(root,Vector3(x,2.8,-13.1),Vector3(x-signf(x)*1.1,3.9,-13.1),.2)
	box(root,Vector3(0,3.9,-13.1),Vector3(9,.25,.35),"wood",false)
	roof(root,5,5,3.95,6.6,Vector3(0,0,-11.3))
	box(root,Vector3(0,3,-9.4),Vector3(3.1,.7,.18),"wood",false);placard(root,Vector3(0,3,-9.51),"ADVENTURERS' GUILD",25)
	for x in [-2.3,2.3]:lantern(root,Vector3(x,2.65,-9.6))
	# Gable crest: crossed steel and a weathered bronze shield, visible from the road.
	var crest=Node3D.new();root.add_child(crest);crest.position=Vector3(0,8,-9.3)
	var shield=P.cone(crest,Vector3.ZERO,1.12,.14,"#877349",.85);shield.rotation.x=PI/2
	for side in [-1,1]:
		beam(crest,Vector3(-side*.8,-.9,-.15),Vector3(side*.8,.9,-.15),.12,"#bac1bd")
		beam(crest,Vector3(-side*.78,-.7,-.2),Vector3(-side*.35,-1.08,-.2),.1,"#d2ad64")
	# Interior exposed trusses, warm pools of light and a long central runner.
	for z in [-6,0,6]:
		beam(root,Vector3(-10.8,4.7,z),Vector3(10.8,4.7,z),.3)
		for side in [-1,1]:
			beam(root,Vector3(side*10.8,4.7,z),Vector3(0,11,z),.25)
			beam(root,Vector3(side*7,4.7,z),Vector3(0,9,z),.18)
		beam(root,Vector3(0,4.7,z),Vector3(0,11,z),.2)
	for z in [-5,2,7]:
		lantern(root,Vector3(0,3.6,z))
	box(root,Vector3(2,.035,1),Vector3(2,.035,13),"#745044",false)
	for x in [1.08,2.92]:box(root,Vector3(x,.058,1),Vector3(.08,.02,13),"#b49561",false)
	# Joinery on the reception counter, records, quill and a brass service bell.
	box(root,Vector3(0,.6,-4.3),Vector3(5,1.2,1.1),"wood")
	box(root,Vector3(0,1.22,-4.3),Vector3(5.3,.13,1.35),"floor",false)
	for x in [-2,-1,0,1,2]:box(root,Vector3(x,.62,-4.88),Vector3(.08,.9,.06),"#b79762",false)
	placard(root,Vector3(0,.8,-4.91),"GUILD RECEPTION",22)
	for i in range(3):box(root,Vector3(-1.5,1.33+i*.06,-4.3),Vector3(.5,.055,.7),["#57645b","#805b43","#bdac83"][i],false)
	P.cone(root,Vector3(1.6,1.42,-4.3),.14,.2,"#bd9e58",.06)
	# Notice boards are physical furnishings rather than floating labels.
	for x in [-9,9]:
		box(root,Vector3(x,2.2,8.7),Vector3(3,.05,1),"wood",false).rotation.x=PI/2
		for i in range(5):box(root,Vector3(x-.95+(i%3)*.8,2.05+(i/3)*.45,8.64),Vector3(.57,.66,.02),"#d4c59c",false)
	# Anvil, forge, stock racks and finished hides mark the working armorer's bay.
	box(root,Vector3(-6,.45,3.6),Vector3(1.6,.9,1.1),"wood")
	box(root,Vector3(-6,1.03,3.6),Vector3(1.5,.28,.55),"iron",false)
	P.cone(root,Vector3(-5.04,1.03,3.6),.26,.75,"#343b3e",.03).rotation.z=-PI/2
	box(root,Vector3(-8.7,1.1,6.8),Vector3(2.3,2.2,2),"stone")
	box(root,Vector3(-8.7,1.2,5.75),Vector3(1.5,.8,.1),"#281d16",false)
	for i in range(6):P.cone(root,Vector3(-9.2+i*.2,.95,5.6),.15,.14,"#ef913b",.1)
	lantern(root,Vector3(-7,3.3,4.7))
	box(root,Vector3(-8.7,4.8,7.2),Vector3(1.1,7,1.1),"stone",false)
	for x in [-9.4,-8.7,-8]:
		box(root,Vector3(x,2.5,8.45),Vector3(.55,1.4,.12),"#76513a",false)
		beam(root,Vector3(x-.33,3.1,8.3),Vector3(x+.33,3.1,8.3),.06,"iron")
	placard(root,Vector3(-6,2.6,7.7),"ARMORER",22)
	box(root,Vector3(7,.55,1.8),Vector3(4,1.1,1.4),"wood")
	box(root,Vector3(7,1.16,1.8),Vector3(4.2,.13,1.6),"floor",false)
	for x in [5.5,6.7,7.9]:
		var steel=box(root,Vector3(x,1.27,1.8),Vector3(.14,.05,1.05),"#b6bfbd",false);steel.rotation.y=.25
		box(root,Vector3(x,1.28,2.35),Vector3(.5,.06,.06),"iron",false);box(root,Vector3(x,1.28,2.6),Vector3(.08,.06,.45),"wood",false)
	for x in [6,7,8]:
		beam(root,Vector3(x,.6,8.55),Vector3(x,3.2,8.55),.09,"#aeb7b4")
		beam(root,Vector3(x-.3,1.05,8.4),Vector3(x+.3,1.05,8.4),.1,"iron")
	placard(root,Vector3(7,3.45,8.4),"SWORDS & EQUIPMENT",22)
	for x in [-7,-3]:
		box(root,Vector3(x,.84,-.5),Vector3(2.3,.16,1.4),"floor")
		for dx in [-.85,.85]:
			for dz in [-.45,.45]:box(root,Vector3(x+dx,.4,-.5+dz),Vector3(.15,.8,.15),"wood",false)
		for dz in [-1.5,1.5]:box(root,Vector3(x,.35,-.5+dz),Vector3(2,.7,.5),"wood")
		for dz in [-.35,.35]:P.cone(root,Vector3(x+.4,.92,-.5+dz),.1,.2,"#b5966b",.1)
	var hearth=Node3D.new();root.add_child(hearth);hearth.position=Vector3(3.5,0,8.1);preload("res://scripts/home_props.gd").furnish(hearth,"hearth")
	var fire=hearth.find_child("HearthFlame",true,false);var fire_mat=ShaderMaterial.new();fire_mat.shader=load("res://shaders/hearth_fire.gdshader");fire.material_override=fire_mat
	lantern(root,Vector3(4,3.5,6))
	# Keep a modest amount of static draw work despite the richer joinery.
	P.batch_kit(root,"rise_guild_lodge_v2")
