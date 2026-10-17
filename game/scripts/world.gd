extends Node3D
const Props = preload("res://scripts/props.gd")
var definition: Dictionary
var interactions: Array = []
var npc_definitions: Array = []
var bounds: Rect2
var shoreline: Array=[]
var coast_time=0.0
const Sculpt=preload("res://scripts/sculpt_terrain.gd")
const Wading=preload("res://scripts/wading.gd")
const Terrain=preload("res://scripts/terrain_kit.gd")
var terrain_features:Array=[]
var environment_profile="original"

func terrain_at(x: int, z: int) -> String:
	var kind = "grass"
	for region in definition.terrain_regions:
		var r = region.rect
		if Rect2(r[0],r[1],r[2],r[3]).has_point(Vector2(x,z)):
			kind = region.kind
	return kind

func build(data: Dictionary) -> void:
	definition = data
	terrain_features=data.props.filter(func(prop): return prop.get("catalog_code","").ends_with("F"))
	var b = data.bounds
	bounds = Rect2(b[0],b[1],b[2]-b[0],b[3]-b[1])
	if data.get("cave",false): load("res://scripts/cave_kit.gd").room(self)
	if data.has("interior"):
		load("res://scripts/home_props.gd").room(self)
	var rng = RandomNumberGenerator.new()
	rng.seed = int(data.seed)
	var tiles = MeshLibrary.new()
	var colors = ["#789267","#799369","#779166","#596765" if data.get("cave",false) else "#b0a485","#bfaf90","#596765" if data.get("cave",false) else "#707d60"]
	if data.get("biome","")=="jungle": colors=["#4b7354","#507858","#547b52","#817756","#b0a27b","#46664a"]
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
				if not Wading.enabled(self):Props.collider(self,Vector3(x+.5,.75,z+.5),Vector3(1,1.5,1))
				continue
			var tile = rng.randi_range(0,2) if kind=="grass" else 3 if kind=="path" else 5 if kind=="cobble" else 4
			if not data.has("interior") and data.get("sculpted_terrain",[]).is_empty(): grid.set_cell_item(Vector3i(x,0,z),tile)
			if data.sea and (terrain_at(x+1,z)=="water" or terrain_at(x,z+1)=="water"):
				Props.box(self,Vector3(x+.5,-.66,z+.5),Vector3(1.01,1.3,1.01),"#8c9484")
	if not data.get("sculpted_terrain",[]).is_empty(): Sculpt.build_ground(self)
	_build_cobbles(rng)
	if data.sea:
		var ocean = Props.box(self,Vector3(bounds.get_center().x,-.18,bounds.get_center().y),Vector3(bounds.size.x+60,.08,bounds.size.y+60),"#719da4")
		ocean.name="LegacyOcean"
		var shader = Shader.new()
		shader.code = "shader_type spatial; varying vec3 water_position; void vertex(){ water_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; } render_mode unshaded; void fragment(){ float stripe=step(0.94,sin((water_position.x+water_position.z)*4.0+TIME*0.8)); ALBEDO=mix(vec3(0.39,0.57,0.61),vec3(0.60,0.73,0.72),stripe*0.27); }"
		var water = ShaderMaterial.new()
		water.shader = shader
		ocean.material_override = water
		if data.id=="coastal_path":
			for i in range(18):
				var foam=Props.box(self,Vector3(9.12,.025,-8+i*.85),Vector3(.09,.015,.65),"#d2e4d8")
				shoreline.append(foam)
	elif not data.has("interior") and data.get("sculpted_terrain",[]).is_empty():
		Props.box(self,Vector3(bounds.get_center().x,-.2,bounds.get_center().y),Vector3(bounds.size.x,.1,bounds.size.y),"#69815c")
	Props.collider(self,Vector3(b[0]-.1,1,bounds.get_center().y),Vector3(.2,2,bounds.size.y+4))
	Props.collider(self,Vector3(b[2]+.1,1,bounds.get_center().y),Vector3(.2,2,bounds.size.y+4))
	Props.collider(self,Vector3(bounds.get_center().x,1,b[1]-.1),Vector3(bounds.size.x+4,2,.2))
	Props.collider(self,Vector3(bounds.get_center().x,1,b[3]+.1),Vector3(bounds.size.x+4,2,.2))
	for prop in data.props:
		if prop.get("catalog_code","").ends_with("F") and not data.get("sculpted_terrain",[]).is_empty(): continue
		var kit=Props.create(prop)
		if not prop.get("catalog_code","").ends_with("F"): kit.position.y=ground_height(kit.position)
		add_child(kit)
	for item in data.interactions:
		var sign=Props.create(item); sign.position.y=ground_height(sign.position); add_child(sign)
		interactions.append({"id":item.id,"title":item.title,"lines":item.lines,"position":sign.position,"actor":null})
	for exit in data.exits:
		if exit.get("interact",false):
			var r=exit.rect
			interactions.append({"id":exit.id,"title":exit.label,"lines":[],"position":Vector3(r[0]+r[2]/2,0,r[1]+r[3]/2),"actor":null,"travel":exit})
		npc_definitions = data.npcs
	# Seeded grass tufts: one batched draw, no bespoke assets per map.
	var grass_mesh = BoxMesh.new()
	grass_mesh.size = Vector3(.045,.12,.08)
	grass_mesh.material = Props.mat("#a0b986")
	var multi = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = grass_mesh
	multi.instance_count = 400
	for i in range(400):
		var x = rng.randf_range(b[0]+1,b[2]-1)
		var z = rng.randf_range(b[1]+1,b[3]-1)
		var location = Vector3(x,ground_height(Vector3(x,0,z))+.08,z) if terrain_at(int(floor(x)),int(floor(z)))=="grass" else Vector3(0,-4,0)
		multi.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf()*TAU),location))
	var tufts = MultiMeshInstance3D.new()
	tufts.multimesh = multi
	add_child(tufts)
	# Batched irregular ground flecks break up the grid without extra draw calls.
	var fleck_mesh=PrismMesh.new()
	fleck_mesh.size=Vector3(.14,.005,.21)
	fleck_mesh.material=Props.mat("#879c70")
	var flecks=MultiMesh.new()
	flecks.transform_format=MultiMesh.TRANSFORM_3D
	flecks.mesh=fleck_mesh
	flecks.instance_count=600
	for i in range(600):
		var x=rng.randf_range(b[0],b[2])
		var z=rng.randf_range(b[1],b[3])
		var location=Vector3(x,ground_height(Vector3(x,0,z))+.009,z) if terrain_at(int(floor(x)),int(floor(z)))=="grass" else Vector3(0,-4,0)
		flecks.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(.5,1.8)),location))
	var ground_detail=MultiMeshInstance3D.new()
	ground_detail.multimesh=flecks
	add_child(ground_detail)
	if environment_profile=="darkwood":
		load("res://scripts/environment_art.gd").apply(self)

func _build_cobbles(rng: RandomNumberGenerator) -> void:
	var stones=[]
	for x in range(int(bounds.position.x),int(bounds.end.x)):
		for z in range(int(bounds.position.y),int(bounds.end.y)):
			if terrain_at(x,z)!="cobble":
				continue
			for column in range(3):
				for row in range(3):
					if rng.randf()<.16:
						continue
					var at=Vector3(x+(column+.5)/3.0+rng.randf_range(-.025,.025),.025,z+(row+.5)/3.0+rng.randf_range(-.035,.035))
					stones.append(Transform3D(Basis(Vector3.UP,rng.randf_range(-.18,.18)).scaled(Vector3(rng.randf_range(.78,1.1),1,rng.randf_range(.78,1.08))),at))
	if stones.is_empty():
		return
	var mesh=CylinderMesh.new()
	mesh.radial_segments=6
	mesh.top_radius=.15
	mesh.bottom_radius=.165
	mesh.height=.045
	mesh.material=Props.mat("#939b89")
	var multi=MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.use_colors=true
	multi.mesh=mesh
	multi.instance_count=stones.size()
	for index in range(stones.size()):
		multi.set_instance_transform(index,stones[index])
		multi.set_instance_color(index,Color.WHITE.lerp(Color("#718167"),rng.randf_range(0,.4)))
	# Instance colors weather the pavers; missing stones expose mossy ground.
	mesh.material.vertex_color_use_as_albedo=true
	var batch=MultiMeshInstance3D.new()
	batch.name="OldCobbledTrail"
	batch.multimesh=multi
	add_child(batch)

func safe_position(at: Vector3) -> bool:
	if definition.get("id","")=="wr_floor_01":return preload("res://scripts/rise_shape.gd").safe(at)
	if load("res://scripts/dreadmore.gd").blocked(String(definition.id),at):return false
	if not bounds.grow(-.30).has_point(Vector2(at.x,at.z)):
		return false
	for offset in [Vector2(.23,0),Vector2(-.23,0),Vector2(0,.23),Vector2(0,-.23)]:
		if terrain_at(int(floor(at.x+offset.x)),int(floor(at.z+offset.y)))=="water" and (not Wading.enabled(self) or Wading.depth(self,at)>Wading.SHOULDER):
			return false
	if definition.has("interior"):
		if absf(at.x)>4.54 or at.z< -4.54 or (at.z>4.54 and (definition.interior=="bedroom" or absf(at.x)>.55)): return false
		if Rect2(1.8,1.85,2.4,3.2).has_point(Vector2(at.x,at.z)): return false
	if definition.get("cave",false):
		if absf(at.x)>7.15 or at.z< -8.15 or at.z>7.15: return false
		if Rect2(-7.6,1.7,6.4,1.8).has_point(Vector2(at.x,at.z)) or Rect2(1.3,-1.6,6.5,1.8).has_point(Vector2(at.x,at.z)): return false
	for offset in [Vector3(.24,0,0),Vector3(-.24,0,0),Vector3(0,0,.24),Vector3(0,0,-.24)]:
		if absf(ground_height(at)-ground_height(at+offset))>.45: return false
	for prop in definition.props+definition.interactions:
		if prop.get("catalog_code","")=="1H":
			var scale=float(prop.get("scale",1))
			var local=Basis(Vector3.UP,deg_to_rad(float(prop.get("rotation",0)))).inverse()*(at-Vector3(prop.at[0],0,prop.at[1]))/scale
			if absf(local.x)<4+.25/scale and absf(local.z)<3+.25/scale:return false
		if prop.kind in ["castle_wall","castle_tower","castle_gate","castle_keep","market_stall"]:
			var point=(Vector2(at.x,at.z)-Vector2(prop.at[0],prop.at[1])).rotated(deg_to_rad(float(prop.get("rotation",0))))/float(prop.get("scale",1))
			for rect in load("res://scripts/castle_kit.gd").solid_rects(prop):
				if rect.grow(.23/float(prop.get("scale",1))).has_point(point): return false
			continue
		var dimensions={"house":Vector2(3.15,2.45),"tree":Vector2(.35,.35),"rock":Vector2(.8,.7),"bench":Vector2(1.35,.48),"well":Vector2(1.35,1.35),"sign":Vector2(.2,.2),"wall":Vector2(prop.get("length",3),.4)}
		dimensions.merge(load("res://scripts/home_props.gd").SIZES)
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

func _process(delta: float) -> void:
	coast_time+=delta
	var flame=find_child("HearthFlame",true,false)
	if flame!=null:
		flame.scale=Vector3(1+.07*sin(coast_time*7),1+.12*sin(coast_time*9),1)
		if environment_profile=="darkwood" and flame.material_override is ShaderMaterial: flame.material_override.set_shader_parameter("clock",coast_time)
	for i in range(shoreline.size()):
		var wave=shoreline[i]
		var phase=coast_time*1.2+i*.45
		wave.position.x=9.22+.22*sin(phase)
		wave.scale.x=.65+.35*sin(phase)
		wave.scale.z=.8+.2*cos(phase)

func update_interior_walls(camera_at:Vector3,hero_at:Vector3,mode:String) -> void:
	if not definition.has("interior"): return
	var leaf=find_child("InteriorDoorLeaf",true,false)
	if leaf!=null: leaf.visible=mode!="overhead"
	var toward=(camera_at-hero_at)*Vector3(1,0,1)
	for node in get_children():
		if node.has_meta("outward"):
			node.visible=mode!="overhead" or toward.normalized().dot(node.get_meta("outward"))<.25

func base_height(at:Vector3) -> float:
	var result=0.0
	var features=terrain_features if not terrain_features.is_empty() else definition.get("props",[]).filter(func(prop): return prop.get("catalog_code","").ends_with("F"))
	for prop in features:
		var scale=float(prop.get("scale",1))
		var local=(Vector2(at.x,at.z)-Vector2(prop.at[0],prop.at[1])).rotated(deg_to_rad(float(prop.get("rotation",0))))/scale
		result=maxf(result,Terrain.height(prop.catalog_code,local)*scale)
	return result

func raw_sculpt_height(at:Vector3) -> float:
	return Sculpt.apply(definition.get("sculpted_terrain",[]).filter(func(p): return p.profile!="overhang"),at,base_height(at))

func ground_height(at:Vector3) -> float:
	if definition.get("id","")=="wr_floor_01":return preload("res://scripts/rise_shape.gd").height(at)
	if Wading.enabled(self) and terrain_at(floori(at.x),floori(at.z))=="water":return Wading.level(self)-Wading.depth(self,at)
	if definition.get("sculpted_terrain",[]).is_empty(): return base_height(at)
	var cell=Vector2(at.x,at.z).snapped(Vector2(.5,.5))
	cell=(Vector2(at.x,at.z)/.5).floor()*.5
	var uv=(Vector2(at.x,at.z)-cell)/.5
	var a=raw_sculpt_height(Vector3(cell.x,0,cell.y)); var b=raw_sculpt_height(Vector3(cell.x+.5,0,cell.y)); var c=raw_sculpt_height(Vector3(cell.x,0,cell.y+.5)); var d=raw_sculpt_height(Vector3(cell.x+.5,0,cell.y+.5))
	var result=a+(b-a)*uv.x+(c-a)*uv.y if uv.x+uv.y<=1 else d+(c-d)*(1-uv.x)+(b-d)*(1-uv.y)
	return Sculpt.apply(definition.get("sculpted_terrain",[]).filter(func(p): return p.profile=="overhang"),at,result)

func ground_step_allowed(at:Vector3,to:Vector3) -> bool:
	var horizontal=Vector2(to.x-at.x,to.z-at.z).length()
	var rise=absf(ground_height(to)-ground_height(at))
	return rise<=.02 or (rise<=.45 and rise<=horizontal*1.1)

func safe_landing(at:Vector3) -> Vector3:
	var inset=bounds.grow(-.8)
	var result=Vector3(clampf(at.x,inset.position.x,inset.end.x),0,clampf(at.z,inset.position.y,inset.end.y))
	if not safe_position(result):
		for i in range(16):
			var candidate=result+Vector3(sin(i*TAU/16)*1.8,0,cos(i*TAU/16)*1.8)
			if inset.has_point(Vector2(candidate.x,candidate.z)) and safe_position(candidate): result=candidate; break
	result.y=ground_height(result)
	return result

func move_grounded(body:CharacterBody3D,delta:float) -> void:
	if body.get("controllable")==true:body.velocity*=Wading.speed(self,body.position)
	if body.has_method("finish_jump") and body.jump_active:
		# Jump uses the real actor capsule; walls and ceilings remain physical.
		body.move_and_slide()
		if body.is_on_ceiling() and body.jump_velocity>0: body.jump_velocity=0
		var floor_y=ground_height(body.position)
		if body.jump_velocity<=0 and (body.position.y<=floor_y+.001 or body.is_on_floor()):
			body.position.y=floor_y;body.finish_jump()
		return
	body.position.y=ground_height(body.position)
	var goal=body.position+body.velocity*delta
	if not ground_step_allowed(body.position,goal):
		var x_goal=body.position+Vector3(body.velocity.x*delta,0,0)
		var z_goal=body.position+Vector3(0,0,body.velocity.z*delta)
		if not ground_step_allowed(body.position,x_goal): body.velocity.x=0
		if not ground_step_allowed(body.position,z_goal): body.velocity.z=0
		goal=body.position+body.velocity*delta
		if not ground_step_allowed(body.position,goal): body.velocity=Vector3.ZERO
	body.velocity.y=(ground_height(body.position+body.velocity*delta)-body.position.y)/maxf(delta,.001)
	body.move_and_slide()
	body.position.y=ground_height(body.position)
	body.velocity.y=0
