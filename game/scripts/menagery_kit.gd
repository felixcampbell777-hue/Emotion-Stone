extends RefCounted
const Props=preload("res://scripts/props.gd")
static func create(definition:Dictionary) -> Node3D:
	var node=Node3D.new()
	node.name=definition.id
	node.position=Vector3(definition.at[0],0,definition.at[1])
	node.rotation.y=deg_to_rad(float(definition.get("rotation",0)))
	node.scale=Vector3.ONE*float(definition.get("scale",1))
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://content/menagery.json"))
	var entry=catalog.features.filter(func(item): return item.code==definition.catalog_code)[0]
	var style=entry.style
	if style=="inaccessible_bluff":
		load("res://scripts/dreadmore.gd").bluff(node,[-4,-3,8,6,16])
	elif entry.code.ends_with("F"):
		load("res://scripts/terrain_kit.gd").create(node,entry.code)
	elif entry.code.ends_with("G"):
		load("res://scripts/cave_kit.gd").feature(node,style)
	elif style=="jungle_tree":
		Props.cone(node,Vector3(0,1.7,0),.30,3.4,"#63513b",.17)
		Props.collider(node,Vector3(0,1.5,0),Vector3(.6,3,.6))
		for i in range(7):
			var a=i*TAU/7
			var root=Props.box(node,Vector3(sin(a)*.45,.2,cos(a)*.45),Vector3(.22,.22,1.4),"#69543a"); root.rotation.y=a
			ball(node,Vector3(sin(a)*1.1,3.3+sin(i)*.25,cos(a)*1.1),1.1,"#386f4e" if i%2 else "#508754")
			var vine=Props.cone(node,Vector3(sin(a)*1.5,2.05,cos(a)*1.5),.045,2.2,"#648752",.025); vine.rotation.z=sin(a)*.1
		ball(node,Vector3(0,3.9,0),1.2,"#6b9a54")
		Props.camera_occluder(node,Vector3(0,3.5,0),Vector3(4,2,4))
	elif style=="jungle_growth":
		for i in range(10):
			var a=i*TAU/10
			var leaf=Props.box(node,Vector3(sin(a)*.45,.35+(i%3)*.16,cos(a)*.45),Vector3(.32,.045,1.15),"#438255" if i%2 else "#739847"); leaf.rotation=Vector3(-.35,a,.1)
		for i in range(3): Props.cone(node,Vector3(sin(i*2)*.6,.65,cos(i*2)*.6),.11,.25,"#c27856",0)
	elif style=="vine_arch":
		for sign in [-1,1]:
			Props.cone(node,Vector3(sign*1.7,1.6,0),.22,3.2,"#66543c",.13)
			Props.collider(node,Vector3(sign*1.7,1.5,0),Vector3(.45,3,.55))
		Props.box(node,Vector3(0,3.15,0),Vector3(3.5,.24,.3),"#685b3e")
		for i in range(9):
			var x=-1.6+i*.4
			ball(node,Vector3(x,3.3,0),.38,"#4e8151")
			Props.cone(node,Vector3(x,2.65,0),.025,.7+(i%3)*.2,"#79954f",.015)
		Props.camera_occluder(node,Vector3(0,3.2,0),Vector3(3.8,.8,1))
	elif style=="jungle_path":
		for i in range(6):
			var stone=Props.cone(node,Vector3(-1.2+i*.48,.045,sin(i*2)*.23),.30,.08,"#8d9474",.27)
			stone.rotation.y=i
			Props.box(node,Vector3(-1.2+i*.48,.09,sin(i*2)*.23),Vector3(.22,.014,.1),"#527746")
	elif style in ["fir","oak","birch","willow"]:
		Props.cone(node,Vector3(0,1.1,0),.19,2.2,"#dddfcd" if style=="birch" else "#73563f",.13)
		Props.collider(node,Vector3(0,1,0),Vector3(.4,2,.4))
		if style=="fir":
			for tier in range(4): Props.cone(node,Vector3(0,1.2+tier*.55,0),1.25-tier*.24,1.35,"#426a50" if tier%2==0 else "#608563",.05)
		elif style=="oak":
			for i in range(6):
				var a=i*TAU/6
				var branch=Props.box(node,Vector3(cos(a)*.46,1.85,sin(a)*.46),Vector3(.15,1.2,.15),"#73563f")
				branch.rotation.z=cos(a)*.7
				branch.rotation.x=sin(a)*.7
				ball(node,Vector3(cos(a)*.72,2.4+sin(a)*.13,sin(a)*.72),.9,"#66814f")
			ball(node,Vector3(0,2.9,0),.9,"#7f975e")
		elif style=="birch":
			for i in range(8): Props.box(node,Vector3(0,.3+i*.23,.145),Vector3(.26,.045,.05),"#686c65")
			for i in range(4): ball(node,Vector3(sin(i*2)*.42,2.1+i*.2,cos(i*2)*.42),.75,"#a7bd70")
		else:
			ball(node,Vector3(0,2.6,0),1.25,"#779567")
			for i in range(16):
				var a=i*TAU/16
				var frond=Props.box(node,Vector3(cos(a)*1.15,1.65,sin(a)*1.15),Vector3(.18,1.8,.23),"#91aa6e" if i%2==0 else "#668959")
				frond.rotation.z=cos(a)*.16
		Props.camera_occluder(node,Vector3(0,2.4,0),Vector3(2.4,2,2.4))
	elif style in ["pebbles","shard","boulder","moss_rock","rock_pile"]:
		var count=6 if style in ["pebbles","rock_pile"] else 1
		for i in range(count):
			var radius=.28 if style=="pebbles" else .53 if style=="rock_pile" else 1.0 if style=="boulder" else .65
			var at=Vector3(sin(i*2.4)*.5,.18+(.2 if style=="rock_pile" and i>3 else 0),cos(i*2.4)*.4) if count>1 else Vector3.ZERO
			if style=="shard":
				var mesh=PrismMesh.new(); mesh.size=Vector3(.85,1.85,.6)
				Props.mesh_node(node,mesh,Vector3(0,.85,0),"#7c8790").rotation.z=.25
			else:
				var mesh=SphereMesh.new(); mesh.radius=radius; mesh.height=radius*1.3; mesh.radial_segments=7; mesh.rings=3
				Props.mesh_node(node,mesh,at+Vector3(0,radius*.4,0),"#949e94")
			if style=="moss_rock": Props.cone(node,Vector3(0,.58,0),.55,.10,"#73924e",.43)
		Props.collider(node,Vector3(0,.4,0),Vector3(1.5,.8,1.2) if style=="boulder" else Vector3(1,.8,1))
	elif style in ["log","bridge"]:
		for i in range(1 if style=="log" else 5):
			var log=Props.cone(node,Vector3(0,.22,i*.26-.52 if style=="bridge" else 0),.22,2.5,"#7a5b3e",.22)
			log.rotation.z=PI/2
			for x in [-1.25,1.25]:
				var end=Props.cone(node,Vector3(x,.22,i*.26-.52 if style=="bridge" else 0),.17,.02,"#c4a376",.17)
				end.rotation.z=PI/2
		if style=="log": Props.collider(node,Vector3(0,.22,0),Vector3(2.5,.44,.5))
		else:
			for z in [-.82,.82]:
				Props.box(node,Vector3(0,.75,z),Vector3(2.8,.12,.12),"#8a6b49")
				for x in [-1.15,1.15]: Props.box(node,Vector3(x,.45,z),Vector3(.14,.9,.14),"#785337")
	elif style=="stump":
		Props.cone(node,Vector3(0,.3,0),.55,.6,"#7c5b3c",.43)
		Props.cone(node,Vector3(0,.61,0),.42,.015,"#c4a172",.42)
		Props.cone(node,Vector3(0,.625,0),.26,.008,"#99754d",.26)
		Props.collider(node,Vector3(0,.3,0),Vector3(.8,.6,.8))
	elif style=="ferns":
		for i in range(12):
			var a=i*TAU/12
			var leaf=Props.box(node,Vector3(cos(a)*.4,.25,sin(a)*.4),Vector3(.15,.07,.85),"#699851")
			leaf.rotation=Vector3(.3,-a+PI/2,0)
	elif style=="mushrooms":
		for i in range(7):
			var at=Vector3(sin(i*2.4)*.65,.18,cos(i*2.4)*.55)
			Props.cone(node,at,.045,.36,"#d9c6a2",.035)
			Props.cone(node,at+Vector3.UP*.18,.20,.18,"#ab7970" if i%2 else "#d5ac6c",.04)
	elif style=="deadwood":
		Props.cone(node,Vector3(0,.6,0),.13,1.2,"#93846b",.08)
		for i in range(5):
			var branch=Props.box(node,Vector3(sin(i)*.3,.6+i*.12,cos(i)*.2),Vector3(.06,.8,.06),"#93846b")
			branch.rotation.z=(i%2*2-1)*.7
	elif style=="shrub":
		for i in range(6):
			var at=Vector3(sin(i*2.4)*.45,.45,cos(i*2.4)*.4)
			ball(node,at,.45,"#65834e")
			Props.box(node,at+Vector3(0,.28,.15),Vector3(.09,.09,.09),"#aa625c")
	elif style=="reeds":
		for i in range(14):
			var at=Vector3(sin(i*2.4)*.65,.4,cos(i*2.4)*.5)
			Props.box(node,at,Vector3(.035,.8+.03*i,.035),"#899d59")
			Props.box(node,at+Vector3.UP*.4,Vector3(.075,.22,.075),"#795b3c")
	elif style=="pool":
		Props.cone(node,Vector3(0,.016,0),1.25,.02,"#749e9c",1.25)
		for i in range(12): ball(node,Vector3(sin(i*TAU/12)*1.2,.08,cos(i*TAU/12)*1.2),.16,"#9da79a")
	else:
		if style in ["dirt","fork"]:
			Props.box(node,Vector3(0,.016,0),Vector3(.95,.02,2.8),"#aa9670")
			if style=="fork":
				for sign in [-1,1]: Props.box(node,Vector3(sign*.5,.016,-.55),Vector3(.8,.02,1.5),"#aa9670").rotation.y=sign*.65
		else:
			for i in range(24 if style=="cobbles" else (18 if style=="gravel" else 4)):
				var at=Vector3((i%3-1)*.32 if style=="cobbles" else sin(i*2.4)*.32,.028,-1.1+(i/3)*.28 if style=="cobbles" else -1.1+i*(.14 if style=="gravel" else .72))
				Props.cone(node,at,.12 if style=="gravel" else (.20 if style=="cobbles" else .33),.055,"#b4b5a2" if style=="gravel" else "#8e9a88",.1 if style=="gravel" else (.18 if style=="cobbles" else .30))
	Props.batch_kit(node,"menagery/"+entry.code)
	var label=Label3D.new()
	label.text=entry.code+"  "+entry.name
	label.position=Vector3(0,1.1+(load("res://scripts/terrain_kit.gd").height(entry.code,Vector2.ZERO) if entry.code.ends_with("F") else 0),1.35)
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size=32
	label.pixel_size=.008
	label.no_depth_test=true
	label.outline_size=5
	label.visibility_range_end=30
	label.visible=bool(definition.get("show_label",true))
	node.add_child(label)
	return node

static func ball(node:Node3D,at:Vector3,radius:float,color:String) -> MeshInstance3D:
	var mesh=SphereMesh.new(); mesh.radius=radius; mesh.height=radius*1.8; mesh.radial_segments=8; mesh.rings=4
	return Props.mesh_node(node,mesh,at,color)
