extends RefCounted
## Shared art adapter. Gameplay geometry and original constructors stay authoritative.
const Props=preload("res://scripts/props.gd")
const ROOT="res://assets/environment/polyhaven_cc0/"
const VILLAGE="res://assets/environment/quaternius_medieval_village_cc0/"
static var materials:Dictionary={}
static var models:Dictionary={}
static var smoothed:Dictionary={}
static var canopies:Dictionary={}
static var stone_parts:Array=[]
static var detailed_character:Dictionary={}
static var detailed_hero:Dictionary={}
static var hero_rests:Array[Transform3D]=[]
static var hero_animations:Dictionary={}
static var trunk_meshes:Dictionary={}

static func character_meshes(hero:bool=false) -> Dictionary:
	if hero:
		if detailed_hero.is_empty():
			var model_only=OS.get_cmdline_user_args().has("--model-only")
			var scene=load("res://assets/characters/humanoid-hero-preview.glb" if model_only else "res://assets/characters/humanoid-hero-v1.glb").instantiate()
			for mesh in scene.find_children("*","MeshInstance3D",true,false): detailed_hero[String(mesh.name)]={"mesh":mesh.mesh,"skin":mesh.skin}
			var rig=scene.find_children("*","Skeleton3D",true,false)[0]
			for index in range(rig.get_bone_count()): hero_rests.append(rig.get_bone_rest(index))
			var players=scene.find_children("*","AnimationPlayer",true,false)
			if not players.is_empty():
				for key in players[0].get_animation_library_list(): hero_animations[key]=players[0].get_animation_library(key)
			elif model_only:
				# Empty preview clock satisfies actor startup without animating the unapproved model.
				var library=AnimationLibrary.new();var still=Animation.new();still.length=.001
				library.add_animation("idle",still);hero_animations[""]=library
			scene.free()
		return detailed_hero
	if detailed_character.is_empty():
		var scene=load("res://assets/characters/humanoid-advanced-v1.glb").instantiate()
		for mesh in scene.find_children("*","MeshInstance3D",true,false): detailed_character[String(mesh.name)]={"mesh":mesh.mesh,"skin":mesh.skin}
		scene.free()
	return detailed_character

static func add_canopy(parent:Node3D,height:float,variant:int) -> void:
	if not canopies.has(variant):
		var rng=RandomNumberGenerator.new(); rng.seed=variant+203
		var surface=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var patches=[Rect2(.19,.015,.43,.31),Rect2(.64,.02,.35,.37),Rect2(.28,.38,.37,.4),Rect2(.65,.43,.33,.4)]
		for tier in range(12):
			var y=.25+tier*.058; var radius=(1-y)*.39
			for spoke in range(10):
				var angle=spoke*TAU/10+tier*.83+rng.randf()*.25
				var outward=Vector3(cos(angle),0,sin(angle)); var across=Vector3(-sin(angle),0,cos(angle))
				for leaf in range(2):
					var tilt=.2 if leaf==0 else 1.05
					var side=(across*cos(tilt)+Vector3.UP*sin(tilt))*radius*.54
					var near=Vector3(0,y,0)+outward*.035; var far=near+outward*radius-Vector3.UP*radius*.12
					var points=[near-side,near+side,far+side,far-side]; var uv=patches[(spoke+tier+leaf)%patches.size()]
					var coords=[Vector2(uv.position.x,uv.end.y),uv.end,Vector2(uv.end.x,uv.position.y),uv.position]
					var normal=side.cross(far-near).normalized()
					for index in [0,1,2,0,2,3]: surface.set_normal(normal); surface.set_uv(coords[index]); surface.add_vertex(points[index])
		var mat=ShaderMaterial.new(); mat.shader=load("res://shaders/scanned_foliage.gdshader")
		mat.set_shader_parameter("needles",load(ROOT+"foliage/albedo.jpg")); mat.set_shader_parameter("cutout",load(ROOT+"foliage/alpha.png"))
		var mesh=surface.commit(); mesh.surface_set_material(0,mat); canopies[variant]=mesh
	var canopy=MeshInstance3D.new(); canopy.name="NeedleCanopy"; canopy.mesh=canopies[variant]; canopy.scale=Vector3.ONE*height
	canopy.visibility_range_end=90; canopy.visibility_range_end_margin=10; parent.add_child(canopy)

static func texture_material(id:String,scale:float=1.0,tint:Color=Color.WHITE) -> StandardMaterial3D:
	var key=id+str(scale)+str(tint)
	if materials.has(key): return materials[key]
	var material=StandardMaterial3D.new()
	material.albedo_texture=load(ROOT+id+"/albedo.jpg")
	material.normal_enabled=true; material.normal_texture=load(ROOT+id+"/normal.jpg"); material.normal_scale=.75
	material.roughness_texture=load(ROOT+id+"/roughness.jpg")
	material.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.albedo_color=tint; material.uv1_triplanar=true; material.uv1_world_triplanar=true
	material.uv1_scale=Vector3.ONE*scale
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	materials[key]=material
	return material

static func village_material(prefix:String,scale:float=1.0) -> StandardMaterial3D:
	var key="village/"+prefix+str(scale)
	if materials.has(key): return materials[key]
	var mat=StandardMaterial3D.new()
	mat.albedo_texture=load(VILLAGE+"Textures/T_"+prefix+"_BaseColor.png")
	mat.normal_enabled=true; mat.normal_texture=load(VILLAGE+"Textures/T_"+prefix+"_Normal.png")
	mat.roughness=.88; mat.albedo_color=Color("#bab7ae")
	mat.uv1_triplanar=true; mat.uv1_world_triplanar=true; mat.uv1_scale=Vector3.ONE*scale
	mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	materials[key]=mat
	return mat

static func _bounds(node:Node3D,transform:Transform3D=Transform3D.IDENTITY) -> AABB:
	var result=AABB(); var started=false; var local=transform*node.transform
	if node is MeshInstance3D: result=local*node.get_aabb(); started=true
	for child in node.get_children():
		if not child is Node3D: continue
		var box=_bounds(child,local)
		if box.size.length_squared()<.00001: continue
		result=result.merge(box) if started else box; started=true
	return result

static func model(path:String,size:Vector3,uniform:bool=true) -> Node3D:
	if not models.has(path): models[path]=load(path)
	var container=Node3D.new()
	if not models[path] is PackedScene: push_error("Missing environment asset "+path); return container
	var scene=models[path].instantiate(); container.add_child(scene)
	var box=_bounds(scene); var factor=size/box.size.max(Vector3.ONE*.001)
	if uniform: factor=Vector3.ONE*factor.y
	scene.scale=factor; scene.position=-Vector3(box.get_center().x,box.position.y,box.get_center().z)*factor
	for mesh in scene.find_children("*","MeshInstance3D",true,false):
		if path.get_file() in ["fir_a.glb","fir_b.glb","fir_c.glb"]:
			var key=mesh.mesh.get_instance_id()
			if not trunk_meshes.has(key):
				var trunk=ArrayMesh.new()
				for surface in range(mesh.mesh.get_surface_count()):
					var material=mesh.get_active_material(surface)
					if material!=null and "twig" in String(material.resource_name).to_lower(): continue
					trunk.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.mesh.surface_get_arrays(surface)); trunk.surface_set_material(trunk.get_surface_count()-1,material)
				trunk_meshes[key]=trunk
			mesh.mesh=trunk_meshes[key]
		mesh.visibility_range_end=100; mesh.visibility_range_end_margin=12
		mesh.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	container.set_meta("environment_asset",path)
	return container

static func _erase_meshes(node:Node3D) -> void:
	for child in node.get_children():
		if child is MeshInstance3D or child is MultiMeshInstance3D: node.remove_child(child); child.free()
		elif child is Node3D and not child is CollisionObject3D: _erase_meshes(child)

static func dress_prop(node:Node3D,data:Dictionary) -> void:
	if data.kind in ["castle_wall","castle_tower","castle_gate","castle_keep","market_stall"]: return
	var kind=String(data.kind); var code=String(data.get("catalog_code","")); var number=absi(String(data.id).hash())
	var asset=""; var size=Vector3.ONE
	if kind=="tree" or code.ends_with("A"):
		asset=ROOT+"models/fir_"+["a","b","c"][number%3]+".glb"; size=Vector3(3,7.5+(number%4)*.4,3)
		if code in ["3A","4A","5A"]:
			asset=ROOT+"models/fir_sapling_"+["a","b","c"][number%3]+".glb"; size.y=4.0 if code=="3A" else 5.7
		if String(data.id).begins_with("meadow_sapling"):
			asset=ROOT+"models/fir_sapling_"+["a","b","c"][number%3]+".glb"; size.y=4.0
	elif kind=="rock" or code.ends_with("B"):
		asset=ROOT+"models/rock_moss_set_01_"+["a","b","c","d","e","f"][number%6]+".glb"; size=Vector3(1.15,.8,1.05)
		if code=="2B": size=Vector3(.9,1.9,.8)
		elif code=="3B": size=Vector3(2,1.4,1.8)
		elif code=="1B": size=Vector3(1.2,.18,1)
	elif kind=="flowers" or code in ["3C","6C","7C","9C"]: asset=ROOT+"models/fern_02.glb"; size=Vector3(1.2,.48,1.2)
	elif code=="2C": asset=ROOT+"models/tree_stump_01.glb"; size=Vector3(1,.65,1)
	if not asset.is_empty():
		_erase_meshes(node)
		var art=model(asset,size,kind=="tree" or code.ends_with("A")); art.name="ScannedArt"; node.add_child(art)
		if kind=="tree" or code.ends_with("A"):
			if not "sapling" in asset: add_canopy(art,size.y,number%3)
			for body in node.find_children("CameraOccluder","StaticBody3D",true,false):
				body.position.y=size.y*.65; body.get_child(0).shape=body.get_child(0).shape.duplicate(); body.get_child(0).shape.size=Vector3(2.7,size.y*.5,2.7)
		return
	if kind=="house":
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			var color=mesh.material_override.albedo_color.to_html(false) if mesh.material_override is StandardMaterial3D else ""
			if color in ["a26854","6b7f7d","ae735a","788b85"]: mesh.visible=false
		var roof=model(VILLAGE+"glTF/Roof_RoundTiles_4x4.gltf",Vector3(3.75,1.3,3.1),false)
		roof.position.y=2.82+(1.35 if data.get("floors",1)==2 else 0.0); node.add_child(roof)
		for mesh in roof.find_children("*","MeshInstance3D",true,false):
			for index in range(mesh.mesh.get_surface_count()):
				var mat=mesh.get_active_material(index)
				if mat is StandardMaterial3D: mat=mat.duplicate(); mat.albedo_color=Color("#87928e"); mesh.set_surface_override_material(index,mat)
		var lamp=Props.cone(node,Vector3(.67,1.75,1.35),.10,.22,"#deb980",.08)
		var glow=StandardMaterial3D.new(); glow.albedo_color=Color("#bda375"); glow.emission_enabled=true; glow.emission=Color("#e7ba74"); glow.emission_energy_multiplier=1.8; lamp.material_override=glow
		var light=OmniLight3D.new(); light.position=lamp.position; light.light_color=Color("#e4b875"); light.light_energy=.35; light.omni_range=2.5; node.add_child(light)
	elif kind=="well":
		_erase_meshes(node)
		for level in range(3):
			for i in range(12):
				var a=(i+.5*(level%2))*TAU/12
				var stone=Props.box(node,Vector3(sin(a)*.64,.14+level*.24,cos(a)*.64),Vector3(.34,.22,.25),"#9a9c8a"); stone.rotation.y=a
		for x in [-.67,.67]: Props.box(node,Vector3(x,1.35,0),Vector3(.12,1.6,.14),"#745a40")
		var roof=model(VILLAGE+"glTF/Roof_RoundTiles_4x4.gltf",Vector3(1.9,.55,1.6),false); roof.position.y=2.02; node.add_child(roof)
		var water=Props.cone(node,Vector3(0,.15,0),.48,.02,"#26484a",.48); water.material_override=load("res://shaders/realistic_water.tres")
		Props.box(node,Vector3(0,1.32,0),Vector3(1.45,.08,.08),"#70523f")
		Props.box(node,Vector3(0,.98,0),Vector3(.022,.63,.022),"#b0a082")
	_retexture(node)

static func _retexture(node:Node3D) -> void:
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		if not mesh.material_override is StandardMaterial3D: continue
		var mat:StandardMaterial3D=mesh.material_override
		if mat.emission_enabled or mat.albedo_texture!=null: continue
		var color=mat.albedo_color
		if color.b>color.r*1.12 and color.g>color.r*1.10:
			var glass=mat.duplicate(); glass.roughness=.17; glass.metallic=.2; glass.albedo_color=Color("#495e63"); mesh.material_override=glass
		elif color.g>color.r*1.06 and color.g>color.b*1.02: mesh.material_override=texture_material("forest_leaves_02",.65,Color("#adbda1"))
		elif color.r>color.g*1.12 and color.r>color.b*1.3: mesh.material_override=texture_material("brown_planks_05",.8,Color("#9e8d78"))
		elif color.r>.67 and color.g>.60 and color.b<color.r*.91: mesh.material_override=village_material("Plaster",.6)
		else: mesh.material_override=village_material("UnevenBrick",.7)

static func cave_faces(world:Node3D) -> void:
	scanned_stone_parts(world)
	for mesh in world.find_children("CaveWall*","MeshInstance3D",true,false):
		if not mesh.mesh is BoxMesh: continue
		var size:Vector3=mesh.mesh.size; var along_x=size.x>size.z; var count=ceili(maxf(size.x,size.z)/1.3)
		for i in range(count):
			var rock=MeshInstance3D.new(); rock.name="ScannedCaveFace"; rock.mesh=stone_parts[i%stone_parts.size()]
			rock.position=mesh.position+(Vector3.RIGHT if along_x else Vector3.BACK)*((i+.5)/count-.5)*(size.x if along_x else size.z)
			rock.scale=Vector3(size.x/count*1.06,size.y,size.z*1.08) if along_x else Vector3(size.x*1.08,size.y,size.z/count*1.06)
			world.add_child(rock)
		mesh.material_override=texture_material("rocky_trail",.6,Color("#485350"))

static func ground_material(world:Node3D) -> ShaderMaterial:
	var mat=ShaderMaterial.new(); mat.shader=load("res://shaders/realistic_ground.gdshader")
	var soil="leafy_grass" if world.definition.id in ["village_green","coastal_path","lark_farm","beta_meadow","a2_haven","a2_crossroads"] else "forest_leaves_02"
	for pair in [["soil",soil],["trail","rocky_trail"],["stone","cobblestone_floor_08"]]:
		for map in ["albedo","normal","roughness"]: mat.set_shader_parameter(pair[0]+"_"+map,load(ROOT+pair[1]+"/"+map+".jpg"))
	var image=Image.create(int(world.bounds.size.x),int(world.bounds.size.y),false,Image.FORMAT_RGB8)
	for x in range(image.get_width()):
		for z in range(image.get_height()):
			var kind=world.terrain_at(int(world.bounds.position.x)+x,int(world.bounds.position.y)+z)
			image.set_pixel(x,z,Color(1 if kind=="path" else 0,1 if kind=="sand" else 0,1 if kind=="cobble" else 0))
	mat.set_shader_parameter("terrain_mask",ImageTexture.create_from_image(image)); mat.set_shader_parameter("map_origin",world.bounds.position); mat.set_shader_parameter("map_size",world.bounds.size)
	mat.set_shader_parameter("cave",world.definition.get("cave",false))
	return mat

static func apply(world:Node3D) -> void:
	var root=Node3D.new(); root.name="DarkwoodEnvironment"; world.add_child(root); world.set_meta("art_revision",1)
	var ground=ground_material(world); var grid=world.get_node_or_null("Terrain")
	if grid!=null:
		for index in grid.mesh_library.get_item_list(): grid.mesh_library.get_item_mesh(index).material=ground
	for node in world.get_children():
		if node is MeshInstance3D:
			if world.definition.has("interior"): continue
			if node.mesh is BoxMesh and node.mesh.size.y>.05 and node.mesh.size.x>world.bounds.size.x: node.material_override=load("res://shaders/realistic_water.tres") if world.definition.sea else ground
			elif node.mesh is ArrayMesh or (node.mesh is BoxMesh and node.mesh.size.y<=.25): node.material_override=ground
		elif node is MultiMeshInstance3D: node.visible=false
	if world.has_node("OldCobbledTrail"): world.get_node("OldCobbledTrail").visible=false
	if world.definition.has("interior") or world.definition.get("cave",false): _retexture(world)
	var flame=world.find_child("HearthFlame",true,false)
	if flame!=null:
		var fire=ShaderMaterial.new(); fire.shader=load("res://shaders/hearth_fire.gdshader"); flame.material_override=fire
	if world.definition.get("cave",false): cave_faces(world)
	for data in world.definition.props+world.definition.interactions:
		var node=world.get_node_or_null(NodePath(data.id))
		if node!=null: dress_prop(node,data)
	if not world.definition.has("interior") and not world.definition.get("cave",false) and world.definition.get("biome","") not in ["beach","highlands"]:
		if not String(world.definition.id).begins_with("a2_"):_scatter(root,world)
		_backdrop(root,world)
	# Generic dressing must not replace the region's slope-aware material.
	if String(world.definition.id).begins_with("a2_") and not world.definition.get("cave",false):load("res://scripts/alpha2_scenery.gd").ground(world)
	if world.definition.id=="herb_glade":
		for i in range(5):
			var wall=model(VILLAGE+"glTF/Wall_UnevenBrick_Straight.gltf",Vector3(3.2,2+(i%2)*.8,.5),false)
			wall.position=Vector3(-8.5 if i%2==0 else 8.5,0,7+i*3.0); wall.rotation.y=.4*i; root.add_child(wall)
			Props.camera_occluder(wall,Vector3(0,1,0),Vector3(3.2,2,.5))

static func _scatter(parent:Node3D,world:Node3D) -> void:
	_scatter_kind(parent,world,"fern_02",Vector3(1,.46,1),.14,180,1049)
	_scatter_kind(parent,world,"grass_medium_01",Vector3(.7,.35,.7),.9,800,1097)

static func _scatter_kind(parent:Node3D,world:Node3D,asset:String,size:Vector3,density:float,limit:int,seed_offset:int) -> void:
	var rng=RandomNumberGenerator.new(); rng.seed=int(world.definition.seed)+seed_offset
	var template=model(ROOT+"models/"+asset+".glb",size,false)
	# Add offscreen briefly so inherited transforms are valid while batching.
	parent.add_child(template); template.visible=false
	var placements:Array[Transform3D]=[]; var count=mini(limit,int(world.bounds.get_area()*density))
	for i in range(count*3):
		if placements.size()>=count: break
		var at=Vector3(rng.randf_range(world.bounds.position.x+.6,world.bounds.end.x-.6),0,rng.randf_range(world.bounds.position.y+.6,world.bounds.end.y-.6))
		if world.terrain_at(int(floor(at.x)),int(floor(at.z)))!="grass" or not world.safe_position(at): continue
		at.y=world.ground_height(at); placements.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(.7,1.5)),at))
	for mesh in template.find_children("*","MeshInstance3D",true,false):
		var batch=MultiMesh.new(); batch.transform_format=MultiMesh.TRANSFORM_3D; batch.mesh=mesh.mesh; batch.instance_count=placements.size()
		var local=template.global_transform.affine_inverse()*mesh.global_transform
		for index in range(placements.size()): batch.set_instance_transform(index,placements[index]*local)
		var instance=MultiMeshInstance3D.new(); instance.multimesh=batch; parent.add_child(instance); instance.visibility_range_end=45; instance.visibility_range_end_margin=8
	parent.remove_child(template); template.free()

static func _backdrop(parent:Node3D,world:Node3D) -> void:
	var rng=RandomNumberGenerator.new(); rng.seed=int(world.definition.seed)+503
	for i in range(48):
		var edge=i%4
		var at=Vector3(rng.randf_range(world.bounds.position.x-12,world.bounds.end.x+12),0,rng.randf_range(world.bounds.position.y-12,world.bounds.end.y+12))
		if edge==0: at.x=world.bounds.position.x-5-rng.randf()*7
		elif edge==1: at.x=world.bounds.end.x+5+rng.randf()*7
		elif edge==2: at.z=world.bounds.position.y-5-rng.randf()*7
		else: at.z=world.bounds.end.y+5+rng.randf()*7
		if world.definition.sea and (at.x>7 or at.z>7): continue
		var height=rng.randf_range(8,12)
		var tree=model(ROOT+"models/fir_"+["a","b","c"][i%3]+".glb",Vector3(3,height,3)); tree.position=at; tree.rotation.y=rng.randf()*TAU; parent.add_child(tree); add_canopy(tree,height,i%3)
	var floor=Props.box(parent,Vector3(world.bounds.get_center().x,-.28,world.bounds.get_center().y),Vector3(world.bounds.size.x+60,.15,world.bounds.size.y+60),"#474b3c")
	floor.material_override=ground_material(world)
	if world.definition.sea:
		floor.mesh=BoxMesh.new(); floor.mesh.size=Vector3(60,.15,60); floor.position=Vector3(-21,-.13,-21)
	if not world.definition.sea:
		for edge in range(4):
			var hill=SphereMesh.new(); hill.radial_segments=48; hill.rings=24; hill.radius=1; hill.height=2
			var at=Vector3(world.bounds.get_center().x,-4,world.bounds.get_center().y)
			if edge<2: at.x=world.bounds.position.x-25 if edge==0 else world.bounds.end.x+25
			else: at.z=world.bounds.position.y-25 if edge==2 else world.bounds.end.y+25
			var node=Props.mesh_node(parent,hill,at,"#607256"); node.scale=Vector3(21,9,24); node.material_override=texture_material("forest_leaves_02",.28,Color("#8c9e7f"))

static func configure_lighting(game:Control,data:Dictionary) -> void:
	var env:Environment=game.environment_settings; var sun:DirectionalLight3D=game.world_root.get_node("WorldSun")
	configure_scene(env,sun,data,game.environment_profile)
	if game.environment_profile=="original": env.fog_enabled=game.camera_mode!="overhead"; env.fog_density=.035; env.fog_light_color=env.background_color

static func configure_scene(env:Environment,sun:DirectionalLight3D,data:Dictionary,profile:String) -> void:
	env.fog_sky_affect=1.0
	var advanced=profile=="darkwood"; var forward=RenderingServer.get_current_rendering_method()=="forward_plus"
	env.ssao_enabled=advanced and forward; env.ssil_enabled=false; env.glow_enabled=advanced and forward; env.glow_intensity=.45
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC if advanced else Environment.TONE_MAPPER_LINEAR; env.tonemap_exposure=.9 if advanced else 1.0; env.tonemap_white=6.0 if advanced else 1.0
	env.adjustment_enabled=advanced; env.adjustment_saturation=.83; env.adjustment_contrast=1.08; env.adjustment_brightness=1.05
	env.fog_enabled=advanced and not data.has("interior"); env.fog_density=.013 if advanced else .01; env.fog_height=.8; env.fog_height_density=.04
	env.volumetric_fog_enabled=advanced and forward and not data.has("interior"); env.volumetric_fog_density=.012 if data.get("cave",false) else .007
	env.volumetric_fog_albedo=Color("#849c96"); env.volumetric_fog_length=65; env.fog_light_color=Color("#60736e")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color("#afc0cc" if advanced else "#d8e0c8")
	env.ambient_light_energy=(.22 if data.get("cave",false) else .4) if advanced else (.16 if data.get("cave",false) else .32)
	env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY if advanced else Environment.REFLECTION_SOURCE_DISABLED
	env.background_mode=Environment.BG_SKY if advanced and not data.has("interior") and not data.get("cave",false) else Environment.BG_COLOR
	if advanced:
		var sky=Sky.new(); var sky_mat=ProceduralSkyMaterial.new()
		sky_mat.sky_top_color=Color("#293c50"); sky_mat.sky_horizon_color=Color("#87958f"); sky_mat.ground_bottom_color=Color("#182321"); sky_mat.ground_horizon_color=Color("#87958f")
		sky_mat.sky_energy_multiplier=.55; sky.sky_material=sky_mat; env.sky=sky; env.ssao_radius=1.3; env.ssao_intensity=1.6
	sun.light_energy=.7 if advanced and data.get("cave",false) else 1.25 if advanced else .55
	sun.light_color=Color("#f2d5ac" if advanced else "#fff9ef"); sun.rotation_degrees=Vector3(-42,-32,0) if advanced else Vector3(-58,-28,0); sun.directional_shadow_max_distance=40 if advanced else 45

static func smooth_mesh(mesh:Mesh) -> Mesh:
	var key=mesh.get_instance_id()
	if smoothed.has(key): return smoothed[key]
	var output=ArrayMesh.new()
	var sums:Dictionary={}
	for surface in range(mesh.get_surface_count()):
		var arrays=mesh.surface_get_arrays(surface); var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]; var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		for index in range(normals.size()):
			var point=vertices[index].snapped(Vector3.ONE*.0001); sums[point]=sums.get(point,Vector3.ZERO)+normals[index]
	for surface in range(mesh.get_surface_count()):
		var arrays=mesh.surface_get_arrays(surface); var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]; var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		if normals.is_empty(): output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); continue
		for index in range(vertices.size()): normals[index]=sums[vertices[index].snapped(Vector3.ONE*.0001)].normalized()
		arrays[Mesh.ARRAY_NORMAL]=normals; output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); output.surface_set_material(surface,mesh.surface_get_material(surface))
	smoothed[key]=output
	return output

static func fit_hero_rig(actor:Node3D,advanced:bool) -> void:
	if not actor.has_meta("original_rests"):
		var rests:Array[Transform3D]=[]; var libraries:Dictionary={}
		for index in range(actor.skeleton.get_bone_count()): rests.append(actor.skeleton.get_bone_rest(index))
		for key in actor.animator.get_animation_library_list(): libraries[key]=actor.animator.get_animation_library(key)
		actor.set_meta("original_rests",rests); actor.set_meta("original_animations",libraries)
	if actor.get_meta("fitted_hero_rig",false)==advanced: return
	var clip=actor.animator.current_animation
	if clip.is_empty() and actor.clips.has(actor.current_clip): clip=actor.clips[actor.current_clip]
	var position=actor.animator.current_animation_position if not actor.animator.current_animation.is_empty() else 0.0
	actor.animator.stop()
	var rests=hero_rests if advanced else actor.get_meta("original_rests")
	for index in range(rests.size()): actor.skeleton.set_bone_rest(index,rests[index])
	actor.skeleton.reset_bone_poses()
	for key in actor.animator.get_animation_library_list(): actor.animator.remove_animation_library(key)
	var libraries=hero_animations if advanced else actor.get_meta("original_animations")
	for key in libraries: actor.animator.add_animation_library(key,libraries[key])
	actor.animator.clear_caches()
	if actor.animator.has_animation(clip): actor.animator.play(clip); actor.animator.seek(position,true)
	actor.set_meta("fitted_hero_rig",advanced)
	actor._place_on_back()

static func actor_quality(actor:Node3D,profile:String) -> void:
	if not actor.get("visual") is Node3D: return
	var advanced=profile=="darkwood"
	actor.set_sword_art(profile)
	if actor.has_node("Shadow"): actor.get_node("Shadow").visible=not advanced
	var hero=String(actor.definition.id)=="hero"
	var details=character_meshes(hero) if advanced else {}
	if hero: fit_hero_rig(actor,advanced)
	actor._apply_modules(actor.visual)
	if advanced and hero:
		var spare_arm=actor.visual.find_child("left_arm_human",true,false)
		if spare_arm!=null: spare_arm.visible=false
	for mesh in actor.visual.find_children("*","MeshInstance3D",true,false):
		if mesh.has_meta("first_person_arms"): continue
		if String(mesh.name).begins_with("Sword") or (actor.equipment!=null and actor.equipment.is_ancestor_of(mesh)): continue
		if not mesh.has_meta("original_mesh"):
			mesh.set_meta("original_mesh",mesh.mesh); mesh.set_meta("original_material",mesh.material_override); mesh.set_meta("original_skin",mesh.skin)
			var overrides:Array=[]
			for index in range(mesh.mesh.get_surface_count()): overrides.append(mesh.get_surface_override_material(index))
			mesh.set_meta("original_surfaces",overrides)
		mesh.mesh=smooth_mesh(mesh.get_meta("original_mesh")) if advanced else mesh.get_meta("original_mesh"); mesh.material_override=mesh.get_meta("original_material")
		mesh.skin=mesh.get_meta("original_skin")
		if advanced and details.has(String(mesh.name)): mesh.mesh=details[String(mesh.name)].mesh; mesh.skin=details[String(mesh.name)].skin
		for index in range(mesh.mesh.get_surface_count()):
			var original=mesh.get_meta("original_surfaces")[index] if index<mesh.get_meta("original_surfaces").size() else null
			if not advanced: mesh.set_surface_override_material(index,original); continue
			original=mesh.mesh.surface_get_material(index)
			if not original is StandardMaterial3D: continue
			var mat=ShaderMaterial.new(); mat.shader=load("res://shaders/hero_surface.gdshader" if hero else "res://shaders/character_surface.gdshader")
			if hero and actor.has_meta("equipment_preview"): mat.shader=load("res://shaders/hero_preview.gdshader")
			var slot=String(original.resource_name).get_slice("_",0)
			if hero and String(original.resource_name).begins_with("hair_card"):
				mat.shader=load("res://shaders/hero_hair.gdshader")
			var tint=Color(actor.definition.palette[slot]) if actor.definition.palette.has(slot) else original.albedo_color
			if hero:
				var kind=1.0 if slot=="skin" else 2.0 if slot=="hair" else 3.0 if slot=="leather" else 4.0 if slot=="eyewhite" else 5.0 if slot=="iris" else 6.0 if slot=="lips" else 7.0 if slot=="metal" else 8.0 if slot in ["buttons","freckles","eyebrows"] else 0.0
				mat.set_shader_parameter("surface_kind",kind)
				mat.set_shader_parameter("atlas",load("res://assets/characters/textures/hero-surface-atlas.png"))
				mat.set_shader_parameter("fabric_normal",load("res://assets/characters/textures/fabric_pattern_07/normal.jpg"))
				mat.set_shader_parameter("fabric_roughness",load("res://assets/characters/textures/fabric_pattern_07/roughness.jpg"))
				mat.set_shader_parameter("leather_normal",load("res://assets/characters/textures/leather_white/normal.jpg"))
				mat.set_shader_parameter("leather_roughness",load("res://assets/characters/textures/leather_white/roughness.jpg"))
				if slot!="dress":
					if String(original.resource_name).ends_with("_dark"): tint=tint.darkened(.12)
					elif String(original.resource_name).ends_with("_light"): tint=tint.lightened(.10)
				if slot=="hair": tint=tint.darkened(.12)
			mat.set_shader_parameter("tint",tint)
			mat.set_shader_parameter("fabric",1.0 if slot in ["dress","socks","leather"] else 0.0)
			mat.set_shader_parameter("skin",1.0 if slot=="skin" else 0.0)
			mesh.set_surface_override_material(index,mat)

static func scanned_stone_parts(enemy:Node3D) -> void:
	if not stone_parts.is_empty(): return
	for variant in ["a","c","d"]:
		var template=model(ROOT+"models/rock_moss_set_01_"+variant+".glb",Vector3.ONE,false)
		enemy.add_child(template); template.visible=false
		var surface=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES); var material:Material
		for mesh in template.find_children("*","MeshInstance3D",true,false):
			var local=mesh.transform; var ancestor=mesh.get_parent()
			while ancestor!=template: local=ancestor.transform*local; ancestor=ancestor.get_parent()
			local=Transform3D(Basis.IDENTITY,Vector3(0,-.5,0))*local
			for index in range(mesh.mesh.get_surface_count()): surface.append_from(mesh.mesh,index,local); material=mesh.get_active_material(index)
		var part=surface.commit(); part.surface_set_material(0,material); stone_parts.append(part)
		enemy.remove_child(template); template.free()

static func creature_quality(enemy:Node3D,profile:String) -> void:
	if enemy.has_meta("library_creature"):return
	if profile!="darkwood": return
	var slime=String(enemy.definition.kind)=="slime" or str(enemy.get("style")).ends_with("slime")
	var warden=String(enemy.definition.kind) in ["warden","bellkeeper"]
	if warden: scanned_stone_parts(enemy)
	if enemy.has_node("Shadow"): enemy.get_node("Shadow").visible=false
	var part_index=0
	for mesh in enemy.visual.find_children("*","MeshInstance3D",true,false):
		if warden and mesh.mesh is ArrayMesh and mesh.material_override is StandardMaterial3D and not mesh.material_override.emission_enabled:
			mesh.mesh=stone_parts[part_index%stone_parts.size()]; part_index+=1; mesh.material_override=null; continue
		if mesh.mesh is SphereMesh: mesh.mesh=mesh.mesh.duplicate(); mesh.mesh.radial_segments=48; mesh.mesh.rings=24
		elif mesh.mesh is ArrayMesh: mesh.mesh=smooth_mesh(mesh.mesh)
		elif mesh.mesh is BoxMesh and mesh.mesh.size.length()<2 and (mesh==enemy.body or mesh.mesh.size[mesh.mesh.size.min_axis_index()]>.06):
			var size:Vector3=mesh.mesh.size; var sphere=SphereMesh.new(); sphere.radius=.5; sphere.height=1.0; sphere.radial_segments=24; sphere.rings=12; mesh.mesh=sphere; mesh.scale*=size
		if not mesh.material_override is StandardMaterial3D: continue
		var mat:StandardMaterial3D=mesh.material_override.duplicate()
		if mat.emission_enabled: mesh.material_override=mat; continue
		if slime:
			if mesh==enemy.body:
				var gel=ShaderMaterial.new(); gel.shader=load("res://shaders/slime_surface.gdshader"); gel.set_shader_parameter("tint",mat.albedo_color); mesh.material_override=gel; continue
			mat.roughness=.23; mat.metallic=.1
		else: mat.roughness=.75; mat.normal_enabled=true; mat.normal_texture=load(ROOT+"pine_bark/normal.jpg"); mat.normal_scale=.2; mat.uv1_scale=Vector3.ONE*5
		mesh.material_override=mat
	if String(enemy.definition.kind)=="boar" or str(enemy.get("style"))=="piglet":
		for x in [-.25,.25]:
			var ear=Props.cone(enemy.visual,Vector3(x,.91,.45),.12,.30,"#4d3e34",.015); ear.rotation.z=x*-.65
			for segment in range(4):
				var tusk=Props.cone(enemy.visual,Vector3(x,.48+segment*.08,.77+segment*.015),.045-segment*.008,.10,"#d3c5a0",.035-segment*.008); tusk.rotation.z=-x*.9
		for i in range(9):
			var bristle=Props.cone(enemy.visual,Vector3(0,.91,-.45+i*.1),.095,.30,"#3e372e",.012); bristle.rotation.x=-.4
	enemy.set_meta("advanced_art",true); enemy.set_meta("advanced_body_material",enemy.body.material_override)
	if slime:
		var core=SphereMesh.new(); core.radius=.13 if str(enemy.get("style"))!="queen_slime" else .32; core.height=core.radius*2; core.radial_segments=24; core.rings=12
		var gem=Props.mesh_node(enemy.visual,core,Vector3(0,.62,.48),"#a9d9bc")
		var mat=StandardMaterial3D.new(); mat.albedo_color=Color("#bcd3aa"); mat.emission_enabled=true; mat.emission=Color("#527c6f"); mat.emission_energy_multiplier=.55; mat.roughness=.15; gem.material_override=mat

