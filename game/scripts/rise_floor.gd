extends "res://scripts/world.gd"
const Shape=preload("res://scripts/rise_shape.gd")
const Art=preload("res://scripts/environment_art.gd")
var decoration:Dictionary={}
var pending:Array=[]
var loaded_chunks:Dictionary={}
var grass_material:ShaderMaterial
var grass_template:Node3D
var proxies:Dictionary={}
func build(data:Dictionary) -> void:
	definition=data;bounds=Rect2(-240,-240,480,480);npc_definitions=[]
	grass_material=ShaderMaterial.new();grass_material.shader=preload("res://shaders/rise_ground.gdshader");grass_material.set_shader_parameter("grass",load(Art.ROOT+"leafy_grass/albedo.jpg"));grass_material.set_shader_parameter("stone",load("res://assets/alpha2/rock_face/albedo.jpg"))
	for cx in range(-4,4):
		for cz in range(-4,4):terrain_chunk(cx,cz)
	var backdrop=preload("res://assets/environment/world_rise_backdrop/ring.tscn").instantiate();add_child(backdrop)
	arrival()
	for cx in range(-8,8):
		for cz in range(-8,8):
			if Vector2(cx*32+16,cz*32+16).length()<261:decoration[Vector2i(cx,cz)]=[]
	grass_template=Art.model(Art.ROOT+"models/grass_medium_01.glb",Vector3(.8,.45,.8),false);add_child(grass_template);grass_template.visible=false
	for t in Shape.spec.trees:
		var key=Vector2i(floori(t[0]/32),floori(t[1]/32))
		if not decoration.has(key):decoration[key]=[]
		decoration[key].append(t)
		# Physical trunks stay present even when distant leaf detail is unloaded.
		var trunk=StaticBody3D.new();trunk.collision_layer=1;trunk.collision_mask=0;var c=CollisionShape3D.new();var shape=CylinderShape3D.new();shape.radius=t[3];shape.height=5;c.shape=shape;trunk.add_child(c);add_child(trunk);trunk.position=Vector3(t[0],ground_height(Vector3(t[0],0,t[1]))+2.5,t[1])
		var proxy=Node3D.new();add_child(proxy);proxy.position=Vector3(t[0],ground_height(Vector3(t[0],0,t[1])),t[1]);Art.add_canopy(proxy,t[2],int(absf(t[0]))%3)
		var crown=proxy.get_child(0);crown.visibility_range_end=0;crown.visibility_range_begin=0;crown.visibility_range_begin_margin=12;crown.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not proxies.has(key):proxies[key]=[]
		proxies[key].append(crown)
func clipped(poly:Array) -> Array:
	var out=[]
	for i in range(poly.size()):
		var a:Vector3=poly[i];var b:Vector3=poly[(i+1)%poly.size()];var ai=Vector2(a.x,a.z).length_squared()<=57600;var bi=Vector2(b.x,b.z).length_squared()<=57600
		if ai:out.append(a)
		if ai!=bi:
			var av=Vector2(a.x,a.z);var dv=Vector2(b.x-a.x,b.z-a.z);var roots=Vector2(-av.dot(dv),sqrt(maxf(0,pow(av.dot(dv),2)-dv.length_squared()*(av.length_squared()-57600))))/dv.length_squared()
			var t=roots.x+roots.y if ai else roots.x-roots.y;var q=a.lerp(b,clampf(t,0,1));q.y=Shape.raw(q.x,q.z);out.append(q)
	return out
func terrain_chunk(cx:int,cz:int) -> void:
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);var count=0
	for x in range(cx*64,(cx+1)*64,4):
		for z in range(cz*64,(cz+1)*64,4):
			var v=[Vector3(x,Shape.raw(x,z),z),Vector3(x+4,Shape.raw(x+4,z),z),Vector3(x,Shape.raw(x,z+4),z+4),Vector3(x+4,Shape.raw(x+4,z+4),z+4)]
			for ids in [[0,2,1],[1,2,3]]:
				var poly=clipped([v[ids[0]],v[ids[1]],v[ids[2]]])
				for i in range(1,poly.size()-1):
					for p in [poly[0],poly[i],poly[i+1]]:st.set_normal(Shape.normal(p.x,p.z));st.set_uv(Vector2(p.x,p.z));st.add_vertex(p);count+=1
				for i in range(poly.size()):
					var a:Vector3=poly[i];var b:Vector3=poly[(i+1)%poly.size()]
					if Vector2(a.x,a.z).length()>239.99 and Vector2(b.x,b.z).length()>239.99:
						for p in [a,b,Vector3(a.x,-45,a.z),b,Vector3(b.x,-45,b.z),Vector3(a.x,-45,a.z)]:st.set_normal(Vector3(a.x,0,a.z).normalized());st.set_uv(Vector2(p.x,p.z));st.add_vertex(p);count+=1
	if count==0:return
	var mesh=st.commit();var node=MeshInstance3D.new();node.name="TerrainChunk_%d_%d"%[cx,cz];node.mesh=mesh;node.material_override=grass_material;add_child(node)
	var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;var shape=CollisionShape3D.new();shape.shape=mesh.create_trimesh_shape();shape.shape.backface_collision=true;body.add_child(shape);add_child(body)
func arrival() -> void:
	for radius in [6,15,17.5]:
		var mesh=TorusMesh.new();mesh.inner_radius=radius-.06;mesh.outer_radius=radius+.06;mesh.rings=96;mesh.ring_segments=4
		var ring=Props.mesh_node(self,mesh,Vector3(0,26.04,0),"#c8c99d");ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(4):
		var at=Vector3(sin(i*PI/2)*14,26,cos(i*PI/2)*14);Props.box(self,at+Vector3.UP*1.1,Vector3(.6,2.2,.6),"#adb7b2")
		var crystal=Props.cone(self,at+Vector3.UP*2.6,.25,.8,"#69c2d1",.08);var mat=Props.mat("#69c2d1");mat.emission_enabled=true;mat.emission=Color("#69c2d1");crystal.material_override=mat
	var label=Label3D.new();label.text="WORLD RISE\nFLOOR 1 · THE VERDANT REACH";label.font_size=48;label.pixel_size=.012;label.position=Vector3(0,29,-12);add_child(label)
func update_details(at:Vector3) -> void:
	for key in decoration:
		var distance=Vector2(at.x-key.x*32-16,at.z-key.y*32-16).length()
		if distance<110 and not loaded_chunks.has(key) and key not in pending:pending.append(key)
		if distance>145 and loaded_chunks.has(key):
			loaded_chunks[key].queue_free();loaded_chunks.erase(key)
			for crown in proxies.get(key,[]):crown.visibility_range_begin=0
	if pending.is_empty():return
	pending.sort_custom(func(a,b):return Vector2(at.x-a.x*32-16,at.z-a.y*32-16).length_squared()<Vector2(at.x-b.x*32-16,at.z-b.y*32-16).length_squared())
	var key:Vector2i=pending.pop_front();var root=Node3D.new();root.name="LandscapeDetail";add_child(root);loaded_chunks[key]=root
	for crown in proxies.get(key,[]):crown.visibility_range_begin=85
	for t in decoration[key]:
		var tree=Art.model(Art.ROOT+"models/fir_a.glb",Vector3(7,t[2],7),false);root.add_child(tree);tree.position=Vector3(t[0],ground_height(Vector3(t[0],0,t[1])),t[1]);tree.rotation.y=t[0]*.2
		Art.add_canopy(tree,t[2],int(absf(t[0]))%3)
		for mesh in tree.find_children("*","MeshInstance3D",true,false):mesh.visibility_range_end=110;mesh.visibility_range_end_margin=15;mesh.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	var rng=RandomNumberGenerator.new();rng.seed=abs(key.x*73856093+key.y*19349663)+613
	var placements:Array[Transform3D]=[]
	for i in range(180):
		var pos=Vector3(key.x*32+rng.randf()*32,0,key.y*32+rng.randf()*32);var radius=Vector2(pos.x,pos.z).length()
		if radius<20 or radius>225 or Shape.normal(pos.x,pos.z).y<.68:continue
		pos.y=ground_height(pos);placements.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(.7,1.6)),pos))
	for mesh in grass_template.find_children("*","MeshInstance3D",true,false):
		var batch=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.mesh=mesh.mesh;batch.instance_count=placements.size()
		var local=grass_template.global_transform.affine_inverse()*mesh.global_transform
		for index in range(placements.size()):batch.set_instance_transform(index,placements[index]*local)
		var instance=MultiMeshInstance3D.new();instance.multimesh=batch;root.add_child(instance);instance.visibility_range_end=65;instance.visibility_range_end_margin=12;instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Sparse low outcrops emphasize hill shoulders without blocking the open valleys.
	if Vector2(key.x*32+16,key.y*32+16).length()>45:
		var pos=Vector3(key.x*32+12,0,key.y*32+10)
		if Vector2(pos.x,pos.z).length()<220:
			pos.y=ground_height(pos)-.9;var rock=Art.model(Art.ROOT+"models/rock_moss_set_01_a.glb",Vector3(3.5,1.3,2.8),false)
			if rock!=null:root.add_child(rock);rock.position=pos;rock.rotation.y=rng.randf()*TAU
func ground_height(at:Vector3) -> float:return Shape.height(at)
func safe_position(at:Vector3) -> bool:return Shape.safe(at)
func move_grounded(body:CharacterBody3D,delta:float) -> void:
	var outside=Vector2(body.position.x,body.position.z).length()>240.15
	if outside or body.has_meta("rise_fall"):
		var fall=float(body.get_meta("rise_fall",body.velocity.y));fall-=18*delta;body.set_meta("rise_fall",fall);body.velocity.y=fall;body.move_and_slide()
		if not outside and body.is_on_floor():body.remove_meta("rise_fall");body.position.y=ground_height(body.position);if_jump_finish(body)
		if body.position.y< -65 and body.has_method("take_damage"):
			if body.get("controllable")==true:body.invulnerability=0
			body.take_damage(999999,Vector3.ZERO)
		return
	super.move_grounded(body,delta)
func if_jump_finish(body:Node) -> void:
	if body.has_method("finish_jump") and body.jump_active:body.finish_jump()
