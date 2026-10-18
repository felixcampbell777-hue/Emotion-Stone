extends "res://scripts/rise_floor.gd"
const Fen=preload("res://scripts/swamp_shape.gd")
var water_material:ShaderMaterial
var mist_material:ShaderMaterial
var deep_fog_material:ShaderMaterial
var nodes_by_chunk:Dictionary={}
var templates:Dictionary={}
var clock=0.0
func build(data:Dictionary) -> void:
	definition=data;bounds=Rect2(-240,-240,480,480);npc_definitions=[]
	grass_material=ShaderMaterial.new();grass_material.shader=preload("res://shaders/swamp_ground.gdshader")
	grass_material.set_shader_parameter("arrival_center",Fen.arrival())
	for pair in [["soil","forest_ground_04/albedo.jpg"],["litter","forest_leaves_02/albedo.jpg"],["cover","leafy_grass/albedo.jpg"],["soil_normal","forest_ground_04/normal.jpg"]]:grass_material.set_shader_parameter(pair[0],load(Art.ROOT+pair[1]))
	for x in range(-8,8):
		for z in range(-8,8):terrain_chunk(x,z)
	var water=PlaneMesh.new();water.size=Vector2(480,480);var surface=Props.mesh_node(self,water,Vector3.ZERO,"#61784a")
	water_material=ShaderMaterial.new();water_material.shader=preload("res://shaders/swamp_water.gdshader");water_material.set_shader_parameter("bed",load("res://assets/environment/swamp/depth-height.png"));surface.material_override=water_material;surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Hide water outside the circular island in the shader; no square ocean corners.
	var rim=TorusMesh.new();rim.inner_radius=239.2;rim.outer_radius=240.2;rim.rings=256;rim.ring_segments=4;Props.mesh_node(self,rim,Vector3(0,.3,0),"#7c9183")
	var skirt=SurfaceTool.new();skirt.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(256):
		var a=Vector3(sin(i*TAU/256)*240,-3.6,cos(i*TAU/256)*240);var b=Vector3(sin((i+1)*TAU/256)*240,-3.6,cos((i+1)*TAU/256)*240)
		for p in [a,b,a-Vector3.UP*40,b,b-Vector3.UP*40,a-Vector3.UP*40]:skirt.set_normal(Vector3(p.x,0,p.z).normalized());skirt.set_uv(Vector2(p.x,p.y));skirt.add_vertex(p)
	var wall=MeshInstance3D.new();wall.mesh=skirt.commit();wall.material_override=Art.texture_material("pine_bark",1,Color("#647266"));add_child(wall)
	var backdrop=preload("res://assets/environment/world_rise_backdrop/ring.tscn").instantiate();add_child(backdrop)
	for mesh in backdrop.find_children("*","MeshInstance3D",true,false):
		if mesh.material_override is ShaderMaterial:
			var mat=mesh.material_override.duplicate();var shader=Shader.new();shader.code=mat.shader.code.replace(", fog_disabled","");mat.shader=shader;mesh.material_override=mat
	var arrival=Node3D.new();arrival.name="SwampArrival";add_child(arrival);arrival.position=Vector3(Fen.arrival().x,.85,Fen.arrival().y)
	for radius in [1.925,3,7.5,8.75]:
		var ring=TorusMesh.new();ring.inner_radius=radius-.06;ring.outer_radius=radius+.06;ring.rings=96;ring.ring_segments=4;var seal=Props.mesh_node(arrival,ring,Vector3(0,.04,0),"#74d4db" if radius<2 else "#c8c99d");seal.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var crystals=Node3D.new();crystals.name="ArrivalCrystals";arrival.add_child(crystals)
	var crystal_material=Props.mat("#74d4db");crystal_material.emission_enabled=true;crystal_material.emission=Color("#74d4db");crystal_material.emission_energy_multiplier=1.4;crystal_material.metallic=.15;crystal_material.roughness=.24
	for i in range(4):
		var p=Vector3(sin(i*TAU/4+PI/4)*8,.3,cos(i*TAU/4+PI/4)*8);Props.box(crystals,p,Vector3(.65,.6,.65),"#697a72")
		var crystal=Props.cone(crystals,p+Vector3.UP*.8,.3,.9,"#74d4db",.06);crystal.material_override=crystal_material
	for site in Fen.spec.sites:
		if site.id=="arrival":continue
		var root=Node3D.new();add_child(root);root.position=Vector3(site.at[0],ground_height(Vector3(site.at[0],0,site.at[1])),site.at[1]);Props.box(root,Vector3(0,.25,0),Vector3(1,.5,1),"#667869")
		var crystal=Props.cone(root,Vector3(0,.85,0),.28,.8,"#83dbc5",.03);var mat=Props.mat("#83dbc5");mat.emission_enabled=true;mat.emission=Color("#83dbc5");crystal.material_override=mat
		interactions.append({"id":site.id,"wr_action":site,"title":"Rest · Fen Refuge","position":root.position,"actor":null,"lines":[]})
	load("res://scripts/swamp_raft.gd").build(self)
	for i in range(Fen.spec.nodes.size()):
		var n=Fen.spec.nodes[i];var key=Vector2i(floori(n.at[0]/32),floori(n.at[1]/32))
		if not nodes_by_chunk.has(key):nodes_by_chunk[key]=[]
		nodes_by_chunk[key].append(i)
	prepare_templates()
	# Real trunks persist through scenery streaming; clear island centres and landing approaches.
	for n in Fen.spec.nodes:
		if Vector2(n.at[0]-Fen.arrival().x,n.at[1]-Fen.arrival().y).length()<28:continue
		var at=Vector3(n.at[0]+n.radii[0]*.46,0,n.at[1]-n.radii[1]*.32);at.y=ground_height(at)
		if at.y>.15:Props.collider(self,at+Vector3.UP*2,Vector3(.5,4,.5))
	mist_material=ShaderMaterial.new();mist_material.shader=preload("res://shaders/swamp_mist.gdshader")
	for x in range(-3,4):
		for z in range(-3,4):
			if Vector2(x*65,z*65).length()>220:continue
			var patch=PlaneMesh.new();patch.size=Vector2(78,78);var veil=MeshInstance3D.new();veil.mesh=patch;veil.material_override=mist_material;veil.position=Vector3(x*65,.22,z*65);veil.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(veil)
	# A bounded depth-aware pass integrates only low fog above genuinely deep water.
	# It leaves the existing world mist untouched and avoids costly volumetric fog.
	deep_fog_material=ShaderMaterial.new();deep_fog_material.shader=preload("res://shaders/swamp_deep_fog.gdshader");deep_fog_material.set_shader_parameter("deep_mask",load("res://assets/environment/swamp/deep-mist-mask.png"));deep_fog_material.set_shader_parameter("density",.20);deep_fog_material.render_priority=126
	var quad=QuadMesh.new();quad.size=Vector2(2,2);var cloud=MeshInstance3D.new();cloud.name="DeepWaterMist";cloud.mesh=quad;cloud.material_override=deep_fog_material;cloud.extra_cull_margin=16384;cloud.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(cloud)
func terrain_chunk(cx:int,cz:int) -> void:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);var count=0
	for x in range(cx*32,(cx+1)*32,2):
		for z in range(cz*32,(cz+1)*32,2):
			if Vector2(x+1,z+1).length()>242:continue
			var points=[]
			for offset in [Vector2(0,0),Vector2(2,0),Vector2(0,2),Vector2(2,2)]:
				var flat=Vector2(x,z)+offset
				if flat.length()>240:flat=flat.normalized()*240
				points.append(Vector3(flat.x,Fen.terrain_height(Vector3(flat.x,0,flat.y)),flat.y))
			for triangle in [[0,2,1],[1,2,3]]:
				var a:Vector3=points[triangle[0]];var b:Vector3=points[triangle[1]];var c:Vector3=points[triangle[2]]
				if (b-a).cross(c-a).length_squared()<.000001:continue
				for p in [a,b,c]:
					var normal=Vector3(Fen.terrain_height(p-Vector3(1,0,0))-Fen.terrain_height(p+Vector3(1,0,0)),2,Fen.terrain_height(p-Vector3(0,0,1))-Fen.terrain_height(p+Vector3(0,0,1))).normalized()
					st.set_normal(normal);st.set_uv(Vector2(p.x,p.z));st.add_vertex(p);count+=1
	if count==0:return
	var mesh=st.commit();var node=MeshInstance3D.new();node.mesh=mesh;node.material_override=grass_material;add_child(node)
	var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;var shape=CollisionShape3D.new();shape.shape=mesh.create_trimesh_shape();shape.shape.backface_collision=true;body.add_child(shape);add_child(body)
func prepare_templates() -> void:
	for entry in [["tree","res://assets/environment/swamp/twisted-tree.glb",Vector3(5,8,5)],["dead","res://assets/environment/swamp/dead-tree.glb",Vector3(3,7,3)],["reeds","res://assets/environment/swamp/reeds.glb",Vector3(.8,1.15,.8)],["grass",Art.ROOT+"models/grass_medium_01.glb",Vector3(1.1,.4,1.1)],["fern",Art.ROOT+"models/fern_02.glb",Vector3(1.5,.85,1.5)],["rock",Art.ROOT+"models/rock_moss_set_01_b.glb",Vector3(2.5,1.1,2)],["stump",Art.ROOT+"models/tree_stump_01.glb",Vector3(2,1.1,2)]]:
		var model=Art.model(entry[1],entry[2],false);add_child(model);model.visible=false;templates[entry[0]]=model
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			for surface in range(mesh.mesh.get_surface_count()):
				var original=mesh.get_active_material(surface)
				if original==null:continue
				if entry[0] in ["tree","dead","reeds"] and original is StandardMaterial3D:
					if original.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED or "leav" in String(original.resource_name).to_lower() or entry[0]=="reeds":
						var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/swamp_foliage.gdshader");mat.set_shader_parameter("leaf",original.albedo_texture);mesh.set_surface_override_material(surface,mat)
					else:mesh.set_surface_override_material(surface,Art.texture_material("pine_bark",1,Color("#626952")))
func batch(root:Node3D,key:String,placements:Array) -> void:
	var template:Node3D=templates[key]
	for mesh in template.find_children("*","MeshInstance3D",true,false):
		var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=mesh.mesh;multi.instance_count=placements.size()
		var local=template.global_transform.affine_inverse()*mesh.global_transform
		for i in range(placements.size()):multi.set_instance_transform(i,placements[i]*local)
		var node=MultiMeshInstance3D.new();node.multimesh=multi;root.add_child(node)
		for surface in range(mesh.mesh.get_surface_count()):
			# MultiMesh uses the shared mesh's materials; keep per-surface overrides on a cached duplicate.
			if mesh.get_surface_override_material(surface)!=null:
				if multi.mesh==mesh.mesh:multi.mesh=mesh.mesh.duplicate()
				multi.mesh.surface_set_material(surface,mesh.get_active_material(surface))
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if key in ["reeds","fern","grass"] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
func update_details(at:Vector3) -> void:
	var limit=minf(float(render_profile.load),85)
	for key in nodes_by_chunk:
		var distance=Vector2(at.x-key.x*32-16,at.z-key.y*32-16).length()
		if distance<limit and not loaded_chunks.has(key) and key not in pending:pending.append(key)
		if distance>limit+24 and loaded_chunks.has(key):loaded_chunks[key].queue_free();loaded_chunks.erase(key)
	if pending.is_empty():return
	pending.sort_custom(func(a,b):return Vector2(at.x-a.x*32-16,at.z-a.y*32-16).length_squared()<Vector2(at.x-b.x*32-16,at.z-b.y*32-16).length_squared())
	var key:Vector2i=pending.pop_front();var root=Node3D.new();add_child(root);loaded_chunks[key]=root
	var rng=RandomNumberGenerator.new();rng.seed=abs(key.x*73856093+key.y*19349663)+902
	var groups={"tree":[],"dead":[],"reeds":[],"grass":[],"fern":[],"rock":[],"stump":[]}
	for index in nodes_by_chunk[key]:
		var n=Fen.spec.nodes[index];var centre=Vector3(n.at[0],0,n.at[1]);var arrival_distance=Vector2(centre.x-Fen.arrival().x,centre.z-Fen.arrival().y).length()
		if arrival_distance<25:continue
		var tree_at=centre+Vector3(n.radii[0]*.46,0,-n.radii[1]*.32);tree_at.y=ground_height(tree_at)
		if tree_at.y>.15:groups["dead" if index%3==0 else "tree"].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(.8,1.2)),tree_at))
		for i in range(75):
			var angle=rng.randf()*TAU;var radius=rng.randf_range(.42,1.12);var p=centre+Vector3(sin(angle)*n.radii[0]*radius,0,cos(angle)*n.radii[1]*radius);p.y=ground_height(p)
			if Fen.raft_surface(p) or p.y<-.45 or p.y>.86 or Vector2(p.x-centre.x,p.z-centre.z).length()<4:continue
			groups.reeds.append(Transform3D(Basis(Vector3.UP,angle).scaled(Vector3.ONE*rng.randf_range(.65,1.2)),p))
		for i in range(65):
			var p=centre+Vector3(rng.randf_range(-.8,.8)*n.radii[0],0,rng.randf_range(-.8,.8)*n.radii[1]);p.y=ground_height(p)
			if not Fen.raft_surface(p) and p.y>.08 and Vector2(p.x-centre.x,p.z-centre.z).length()>3.5:groups.grass.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(.6,1.2)),p))
		for i in range(14):
			var p=centre+Vector3(rng.randf_range(-.55,.55)*n.radii[0],0,rng.randf_range(-.55,.55)*n.radii[1]);p.y=ground_height(p)
			if not Fen.raft_surface(p) and p.y>.1:groups.fern.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU),p))
		if index%5==0:
			var p=centre+Vector3(-n.radii[0]*.4,0,0);p.y=ground_height(p)-.2;groups["stump" if index%2 else "rock"].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU),p))
	for name in groups:
		if not groups[name].is_empty():batch(root,name,groups[name])
func ground_height(at:Vector3) -> float:return Fen.height(at)
func safe_position(at:Vector3) -> bool:return Fen.safe(at)
func island_height(_at:Vector3) -> float:return NAN
func island_walkable(_at:Vector3) -> bool:return false
func support_height(body:CharacterBody3D,at:Vector3) -> float:
	var height=ground_height(at)
	if body.get("controllable")!=true:return maxf(height,-.04)
	for offset in [Vector3(.25,0,0),Vector3(-.25,0,0),Vector3(0,0,.25),Vector3(0,0,-.25)]:height=maxf(height,ground_height(at+offset)-.04)
	return height+.008
func move_grounded(body:CharacterBody3D,delta:float) -> void:
	if body.get("controllable")==true and body.position.y<.1:
		var factor=Fen.movement_factor(body.position);body.velocity.x*=factor;body.velocity.z*=factor
	elif body.get("controllable")!=true and not Fen.safe(body.position+body.velocity*delta):body.velocity=Vector3.ZERO
	super.move_grounded(body,delta)
func animate_water(delta:float) -> void:
	clock+=delta;water_material.set_shader_parameter("clock",clock);mist_material.set_shader_parameter("clock",clock);deep_fog_material.set_shader_parameter("clock",clock)
