extends RefCounted
## Reusable rustic furnishing kit. Ground footprints also validate saved positions.
const P=preload("res://scripts/props.gd")
const SIZES={"bed":Vector2(1.8,3),"table":Vector2(2.3,1.4),"chair":Vector2(.7,.7),"cupboard":Vector2(1.7,.75),"hearth":Vector2(2.5,1.5),"shelf":Vector2(2,.55)}

static func furnish(n:Node3D,kind:String) -> void:
	match kind:
		"bed":
			P.box(n,Vector3(0,.32,0),Vector3(1.8,.5,3),"#654633")
			P.box(n,Vector3(0,.67,0),Vector3(1.7,.3,2.8),"#e3d9b9")
			P.box(n,Vector3(0,.84,.4),Vector3(1.73,.12,1.9),"#597a85")
			for x in [-.6,0,.6]: P.box(n,Vector3(x,.91,.4),Vector3(.035,.015,1.9),"#9faf99")
			P.box(n,Vector3(0,.88,-.95),Vector3(1.2,.18,.55),"#f2e7cf")
			P.box(n,Vector3(0,.88,-1.48),Vector3(1.85,1.3,.12),"#77573b")
			for x in [-.83,.83]: P.cone(n,Vector3(x,.5,1.4),.085,1,"#77573b",.085)
		"table":
			P.box(n,Vector3(0,.82,0),Vector3(2.3,.14,1.4),"#a07d52")
			for x in [-.9,.9]:
				for z in [-.5,.5]: P.box(n,Vector3(x,.4,z),Vector3(.12,.8,.12),"#6d5037")
			P.box(n,Vector3(0,.90,0),Vector3(.65,.015,1.3),"#d5bd8c")
			P.cone(n,Vector3(.5,.98,0),.19,.12,"#d5c3a0",.23)
			P.cone(n,Vector3(-.4,1.06,.1),.12,.28,"#9b684c",.08)
			P.cone(n,Vector3(-.4,1.26,.1),.15,.18,"#638264")
		"chair":
			P.box(n,Vector3(0,.47,0),Vector3(.7,.1,.7),"#93704b")
			P.box(n,Vector3(0,.85,-.3),Vector3(.7,.65,.08),"#93704b")
			for x in [-.25,.25]:
				for z in [-.25,.25]: P.box(n,Vector3(x,.23,z),Vector3(.09,.46,.09),"#684b35")
		"cupboard":
			P.box(n,Vector3(0,.95,0),Vector3(1.7,1.9,.75),"#725139")
			for x in [-.42,.42]:
				P.box(n,Vector3(x,1,.39),Vector3(.77,1.7,.06),"#9d794c")
				P.cone(n,Vector3(x*.25,1,.44),.05,.07,"#d6b477")
			P.box(n,Vector3(0,1.98,0),Vector3(1.86,.12,.86),"#624630")
		"shelf":
			P.box(n,Vector3(0,1,-.22),Vector3(2,2,.12),"#6b4e37")
			for y in [.12,.72,1.32,1.95]:
				P.box(n,Vector3(0,y,0),Vector3(2.1,.09,.55),"#9a7950")
			for row in range(3):
				for i in range(6):
					P.box(n,Vector3(-.8+i*.31,.39+row*.6,0),Vector3(.17,.4,.28),["#6c8588","#9d674e","#bba678"][i%3])
		"rug":
			P.box(n,Vector3(0,.015,0),Vector3(3.8,.025,2.8),"#994f40")
			P.box(n,Vector3(0,.03,0),Vector3(3.5,.01,2.5),"#c09468")
			P.box(n,Vector3(0,.04,0),Vector3(3.15,.01,2.15),"#736e62")
			for x in [-1.45,-.75,0,.75,1.45]: P.box(n,Vector3(x,.05,0),Vector3(.07,.01,1.9),"#c9b38a")
		"stairs":
			pass # The floor-specific stairwell is built by room().
		"door":
			for x in [-.84,.84]: P.box(n,Vector3(x,1.3,0),Vector3(.16,2.6,.25),"#755137")
			P.box(n,Vector3(0,2.6,0),Vector3(1.85,.18,.25),"#755137")
			P.box(n,Vector3(0,.015,-.1),Vector3(1.6,.03,.48),"#b6ad92")
			var hinge=Node3D.new()
			hinge.name="InteriorDoorLeaf"
			hinge.position=Vector3(-.70,0,-.04)
			hinge.rotation.y=.38
			n.add_child(hinge)
			P.box(hinge,Vector3(.70,1.18,0),Vector3(1.4,2.36,.09),"#705039")
			for x in [.14,.42,.7,.98,1.26]: P.box(hinge,Vector3(x,1.18,-.056),Vector3(.018,2.16,.018),"#a8895d")
			for y in [.5,1.8]: P.box(hinge,Vector3(.7,y,-.07),Vector3(1.3,.08,.035),"#483a30")
			P.box(hinge,Vector3(1.19,1.12,-.105),Vector3(.07,.07,.09),"#d8b36c")
		"hearth":
			P.box(n,Vector3(0,.10,0),Vector3(2.6,.2,1.65),"#8e897a")
			for x in [-1,1]:
				for row in range(5): P.box(n,Vector3(x,.32+row*.32,0),Vector3(.5,.3,1.2),"#a6a18f" if row%2==0 else "#8b887b")
			P.box(n,Vector3(0,1.7,0),Vector3(2.5,.38,1.3),"#979080")
			P.box(n,Vector3(0,2.6,-.32),Vector3(1.3,1.6,.6),"#aba18a")
			P.box(n,Vector3(0,.75,-.42),Vector3(1.5,1.2,.15),"#352e28")
			P.box(n,Vector3(0,1.95,0),Vector3(2.7,.16,1.5),"#6e5037")
			for x in [-.3,.3]:
				var log=P.cone(n,Vector3(x,.3,.25),.12,.85,"#4e382a",.12)
				log.rotation.z=PI/2
			var flame=P.cone(n,Vector3(0,.64,.2),.40,.85,"#eea34f",.02)
			flame.name="HearthFlame"
			var glow=OmniLight3D.new()
			glow.position=Vector3(0,.85,.8)
			glow.light_color=Color("#ffbb77")
			glow.light_energy=2
			glow.omni_range=7
			n.add_child(glow)
	if SIZES.has(kind):
		var size:Vector2=SIZES[kind]
		P.collider(n,Vector3(0,.6,0),Vector3(size.x,1.2,size.y))

static func wall(n:Node3D,label:String,at:Vector3,size:Vector3,normal:Vector3) -> void:
	# Keep collision active when the foreground upper wall is cut away overhead.
	P.collider(n,at+Vector3(0,1.5,0),Vector3(size.x,3,size.z))
	P.box(n,at+Vector3(0,.20,0),Vector3(size.x,.4,size.z),"#a78f69")
	var upper=Node3D.new()
	upper.name="InteriorWall"+label
	upper.set_meta("outward",normal)
	n.add_child(upper)
	P.box(upper,at+Vector3(0,1.7,0),Vector3(size.x,2.6,size.z),"#d6c5a3")
	for y in [.48,2.85]: P.box(upper,at+Vector3(0,y,0),Vector3(size.x+.02,.13,size.z+.02),"#745239")
	for along in [-.45,0,.45]:
		P.box(upper,at+Vector3(size.x*along,1.7,size.z*along),Vector3(.12,2.9,.12),"#745239")

static func window(n:Node3D,at:Vector3,angle:float=0) -> void:
	var frame=Node3D.new()
	frame.position=at
	frame.rotation.y=angle
	n.add_child(frame)
	P.box(frame,Vector3.ZERO,Vector3(1.4,1.15,.10),"#71543e")
	P.box(frame,Vector3(0,0,.07),Vector3(1.2,.95,.10),"#9cc8c6")
	P.box(frame,Vector3(0,0,.14),Vector3(.06,.95,.04),"#e6d2ab")
	P.box(frame,Vector3(0,0,.14),Vector3(1.2,.06,.04),"#e6d2ab")
	for x in [-.82,.82]: P.box(frame,Vector3(x,0,.13),Vector3(.25,1.3,.08),"#71888a")

static func room(n:Node3D) -> void:
	var upstairs=n.definition.interior=="bedroom"
	P.box(n,Vector3(0,-2.15,0),Vector3(30,.1,30),"#332a24")
	for x in range(-5,5):
		for z in range(-5,5):
			if upstairs and x>=2 and x<4 and z>=2: continue
			P.box(n,Vector3(x+.5,-.045,z+.5),Vector3(.975,.08,.995),["#a88962","#b7986c","#967550"][(x+z+30)%3])
	wall(n,"North",Vector3(0,0,-4.88),Vector3(10,0,.24),Vector3(0,0,-1))
	wall(n,"West",Vector3(-4.88,0,0),Vector3(.24,0,10),Vector3(-1,0,0))
	wall(n,"East",Vector3(4.88,0,0),Vector3(.24,0,10),Vector3(1,0,0))
	if upstairs:
		wall(n,"South",Vector3(0,0,4.88),Vector3(10,0,.24),Vector3(0,0,1))
	else:
		wall(n,"SouthLeft",Vector3(-2.925,0,4.88),Vector3(4.15,0,.24),Vector3(0,0,1))
		wall(n,"SouthRight",Vector3(2.925,0,4.88),Vector3(4.15,0,.24),Vector3(0,0,1))
		P.box(n,Vector3(0,2.85,4.88),Vector3(1.7,.3,.24),"#d6c5a3")
	for x in [-3,2.6]: window(n,Vector3(x,1.8,-4.70))
	window(n,Vector3(-4.70,1.8,-1),PI/2)
	var stair=Node3D.new()
	stair.name="DescendingStairwell" if upstairs else "AscendingStaircase"
	stair.position=Vector3(3,0,2)
	n.add_child(stair)
	for i in range(9):
		var height=(i+1)*.19
		var y=-.10-i*.19 if upstairs else height/2
		P.box(stair,Vector3(0,y,.14+i*.28),Vector3(1.6,.12 if upstairs else height,.28),"#96704a")
		P.box(stair,Vector3(0,y+(.065 if upstairs else height/2),.14+i*.28),Vector3(1.65,.03,.29),"#b69363")
		if upstairs:
			P.box(stair,Vector3(0,y-.015,.28+i*.28),Vector3(1.6,.19,.035),"#60462f")
	if upstairs:
		for x in [-.88,.88]: P.box(stair,Vector3(x,-1.05,1.3),Vector3(.08,2,2.7),"#574333")
	for x in [-.92,.92]:
		for z in [.06,1.25,2.55]:
			var post_height=1.1 if upstairs else 1.1+z*.65
			P.box(stair,Vector3(x,post_height/2,z),Vector3(.10,post_height,.10),"#715037")
		var rail=P.box(stair,Vector3(x,1.1 if upstairs else 1.95,1.3),Vector3(.10,.10,2.7 if upstairs else 3.2),"#715037")
		if not upstairs: rail.rotation.x=-.58
	P.collider(stair,Vector3(0,.7,1.35),Vector3(1.8,1.4,2.7))
	if upstairs:
		for x in [-.97,.97]: P.box(stair,Vector3(x,-.015,1.3),Vector3(.14,.10,2.8),"#715037")
		for z in [-.04,2.65]: P.box(stair,Vector3(0,-.015,z),Vector3(2,.10,.14),"#715037")
		P.box(stair,Vector3(0,1.1,2.65),Vector3(1.9,.1,.1),"#715037")
		for x in [-.95,.95]: P.collider(stair,Vector3(x,.5,1.35),Vector3(.1,1,2.7))
