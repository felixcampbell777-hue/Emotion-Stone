extends "res://scripts/world.gd"
const Shape=preload("res://scripts/rise_shape.gd")
const Art=preload("res://scripts/environment_art.gd")
var decoration:Dictionary={}
var pending:Array=[]
var loaded_chunks:Dictionary={}
var grass_material:ShaderMaterial
var grass_template:Node3D
var proxies:Dictionary={}
var render_profile:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://content/render_budget.json")).profiles.balanced
func configure_render(profile:Dictionary) -> void:
	render_profile=profile
	for key in proxies:
		for crown in proxies[key]:crown.visibility_range_begin=render_profile.detail-12 if loaded_chunks.has(key) else 0
const West=preload("res://scripts/west_islands.gd")
func build(data:Dictionary) -> void:
	definition=data;bounds=Rect2(-500,-240,740,480);npc_definitions=[]
	grass_material=ShaderMaterial.new();grass_material.shader=preload("res://shaders/rise_ground.gdshader");grass_material.set_shader_parameter("grass",load(Art.ROOT+"leafy_grass/albedo.jpg"));grass_material.set_shader_parameter("stone",load("res://assets/alpha2/rock_face/albedo.jpg"))
	grass_material.set_shader_parameter("cobbles",load(Art.ROOT+"cobblestone_floor_08/albedo.jpg"))
	for cx in range(-4,4):
		for cz in range(-4,4):terrain_chunk(cx,cz)
	var backdrop=preload("res://assets/environment/world_rise_backdrop/ring.tscn").instantiate();add_child(backdrop)
	arrival()
	preload("res://scripts/rise_guild_house.gd").build(self)
	West.build(self,grass_material)
	for cx in range(-8,8):
		for cz in range(-8,8):
			if Vector2(cx*32+16,cz*32+16).length()<261:decoration[Vector2i(cx,cz)]=[]
	grass_template=Art.model(Art.ROOT+"models/grass_medium_01.glb",Vector3(.8,.45,.8),false);add_child(grass_template);grass_template.visible=false
	for t in Shape.spec.trees:
		if Vector2(t[0]+168,t[1]+125).length()<10:continue
		var key=Vector2i(floori(t[0]/32),floori(t[1]/32))
		if not decoration.has(key):decoration[key]=[]
		decoration[key].append(t)
		# Physical trunks stay present even when distant leaf detail is unloaded.
		var trunk=StaticBody3D.new();trunk.collision_layer=1;trunk.collision_mask=0;var c=CollisionShape3D.new();var shape=CylinderShape3D.new();shape.radius=t[3];shape.height=5;c.shape=shape;trunk.add_child(c);add_child(trunk);trunk.position=Vector3(t[0],ground_height(Vector3(t[0],0,t[1]))+2.5,t[1])
		var proxy=Node3D.new();add_child(proxy);proxy.position=Vector3(t[0],ground_height(Vector3(t[0],0,t[1])),t[1]);Art.add_canopy(proxy,t[2],int(absf(t[0]))%3)
		var crown=proxy.get_child(0);crown.visibility_range_end=0;crown.visibility_range_begin=0;crown.visibility_range_begin_margin=12;crown.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		crown.set_meta("budget_kind","skyline")
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
	for radius in [3,7.5,8.75]:
		var mesh=TorusMesh.new();mesh.inner_radius=radius-.06;mesh.outer_radius=radius+.06;mesh.rings=96;mesh.ring_segments=4
		var ring=Props.mesh_node(self,mesh,Vector3(0,26.04,0),"#c8c99d");ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var label=Label3D.new();label.text="WORLD RISE\nFLOOR 1 · THE VERDANT REACH";label.font_size=48;label.pixel_size=.012;label.position=Vector3(0,29,-6);add_child(label)
func update_details(at:Vector3) -> void:
	for key in decoration:
		var distance=Vector2(at.x-key.x*32-16,at.z-key.y*32-16).length()
		if distance<render_profile.load and not loaded_chunks.has(key) and key not in pending:pending.append(key)
		if distance>render_profile.unload and loaded_chunks.has(key):
			loaded_chunks[key].queue_free();loaded_chunks.erase(key)
			for crown in proxies.get(key,[]):crown.visibility_range_begin=0
	pending=pending.filter(func(key):return Vector2(at.x-key.x*32-16,at.z-key.y*32-16).length()<render_profile.load)
	if pending.is_empty():return
	pending.sort_custom(func(a,b):return Vector2(at.x-a.x*32-16,at.z-a.y*32-16).length_squared()<Vector2(at.x-b.x*32-16,at.z-b.y*32-16).length_squared())
	var key:Vector2i=pending.pop_front();var root=Node3D.new();root.name="LandscapeDetail";add_child(root);loaded_chunks[key]=root
	for crown in proxies.get(key,[]):crown.visibility_range_begin=render_profile.detail-12
	for t in decoration[key]:
		if Vector2(t[0]+168,t[1]+125).length()<10:continue
		var tree=Art.model(Art.ROOT+"models/fir_a.glb",Vector3(7,t[2],7),false);root.add_child(tree);tree.position=Vector3(t[0],ground_height(Vector3(t[0],0,t[1])),t[1]);tree.rotation.y=t[0]*.2
		Art.add_canopy(tree,t[2],int(absf(t[0]))%3)
		for mesh in tree.find_children("*","MeshInstance3D",true,false):mesh.visibility_range_end=110;mesh.visibility_range_end_margin=15;mesh.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	var rng=RandomNumberGenerator.new();rng.seed=abs(key.x*73856093+key.y*19349663)+613
	var placements:Array[Transform3D]=[]
	for i in range(180):
		var pos=Vector3(key.x*32+rng.randf()*32,0,key.y*32+rng.randf()*32);var radius=Vector2(pos.x,pos.z).length()
		if radius<10 or radius>225 or Shape.normal(pos.x,pos.z).y<.68 or Vector2(pos.x-146,pos.z-146).length()<18 or Shape.trail_distance(pos)<3.2:continue
		pos.y=ground_height(pos);placements.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(.7,1.6)),pos))
	for mesh in grass_template.find_children("*","MeshInstance3D",true,false):
		var batch=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.mesh=mesh.mesh;batch.instance_count=placements.size()
		var local=grass_template.global_transform.affine_inverse()*mesh.global_transform
		for index in range(placements.size()):batch.set_instance_transform(index,placements[index]*local)
		var instance=MultiMeshInstance3D.new();instance.multimesh=batch;root.add_child(instance);instance.visibility_range_end=65;instance.visibility_range_end_margin=12;instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.add_to_group("budget_scenery");instance.set_meta("budget_kind","grass")
	# Sparse low outcrops emphasize hill shoulders without blocking the open valleys.
	if Vector2(key.x*32+16,key.y*32+16).length()>45:
		var pos=Vector3(key.x*32+12,0,key.y*32+10)
		if Vector2(pos.x,pos.z).length()<220 and Vector2(pos.x-146,pos.z-146).length()>20:
			pos.y=ground_height(pos)-.9;var rock=Art.model(Art.ROOT+"models/rock_moss_set_01_a.glb",Vector3(3.5,1.3,2.8),false)
			if rock!=null:root.add_child(rock);rock.position=pos;rock.rotation.y=rng.randf()*TAU
func ground_height(at:Vector3) -> float:
	# Western bridges are the only surfaces that override the main terrain.
	if at.x> -230:return Shape.height(at)
	var island=island_height(at)
	return island if not is_nan(island) else Shape.height(at)
func island_height(at:Vector3) -> float:
	return West.support(at)
func island_walkable(at:Vector3) -> bool:return not is_nan(island_height(at))
func safe_position(at:Vector3) -> bool:return West.safe(at) or Shape.safe(at)
func support_height(body:CharacterBody3D,at:Vector3) -> float:
	# Root height must clear the bottom hemisphere against the slope, not bury
	# its uphill edge by placing its lowest point at the height of its center.
	var result=ground_height(at)
	for child in body.get_children():
		if not child is CollisionShape3D or child.disabled:continue
		var shape=child.shape
		if not (shape is CapsuleShape3D or shape is SphereShape3D):continue
		var radius=shape.radius*child.scale.x
		var half_height=shape.height*.5*child.scale.y if shape is CapsuleShape3D else radius
		var center=at+child.position
		var h=ground_height(center)
		# Optimize h(x,z)+sqrt(r²-offset²) on the local terrain planes.
		# Each candidate remains within the actual capsule footprint; nearby
		# planes cover triangle seams without eighty repeated height lookups.
		var support=h+radius
		var planes={}
		for i in range(9):
			var seed=center if i==0 else center+Vector3(sin(i*TAU/8),0,cos(i*TAU/8))*radius*.85
			support=maxf(support,ground_height(seed)+radius*(1.0 if i==0 else sqrt(1-.85*.85)))
			var slope:Vector2
			if center.x> -230:slope=Shape.gradient(seed)
			else:slope=Vector2((ground_height(seed+Vector3(.1,0,0))-ground_height(seed-Vector3(.1,0,0)))*5,(ground_height(seed+Vector3(0,0,.1))-ground_height(seed-Vector3(0,0,.1)))*5)
			if planes.has(slope):continue
			planes[slope]=true
			var offset=slope*radius/sqrt(1+slope.length_squared())
			var edge=ground_height(center+Vector3(offset.x,0,offset.y))+sqrt(maxf(0,radius*radius-offset.length_squared()))
			support=maxf(support,edge)
		result=maxf(result,support+(half_height-radius)-child.position.y+.008)
	return result
func ground_step_allowed(at:Vector3,to:Vector3) -> bool:
	var run=Vector2(to.x-at.x,to.z-at.z).length()
	return absf(ground_height(to)-ground_height(at))<=maxf(.02,run*1.8)
func move_grounded(body:CharacterBody3D,delta:float) -> void:
	var outside=Vector2(body.position.x,body.position.z).length()>240.15 and not island_walkable(body.position)
	if outside or body.has_meta("rise_fall"):
		var fall=float(body.get_meta("rise_fall",body.velocity.y));fall-=18*delta;body.set_meta("rise_fall",fall);body.velocity.y=fall;body.move_and_slide()
		if not outside and body.is_on_floor():body.remove_meta("rise_fall");body.position.y=ground_height(body.position);if_jump_finish(body)
		if body.position.y< -65 and body.has_method("take_damage"):
			if body.get("controllable")==true:body.invulnerability=0
			body.set_meta("pending_damage_context",{"damage_kind":"fall","source":body.get_meta("last_impulse_context",body.get_meta("last_damage_context",{}))})
			body.take_damage(999999,Vector3.ZERO)
		return
	body.motion_mode=CharacterBody3D.MOTION_MODE_GROUNDED
	body.floor_max_angle=deg_to_rad(62);body.floor_stop_on_slope=true;body.floor_constant_speed=true;body.floor_snap_length=.35
	if body.has_method("finish_jump") and body.jump_active:
		body.move_and_slide()
		if body.is_on_ceiling() and body.jump_velocity>0:body.jump_velocity=0
		var floor_y=support_height(body,body.position)
		if body.jump_velocity<=0 and (body.position.y<=floor_y+.001 or body.is_on_floor()):body.position.y=floor_y;body.finish_jump()
		return
	body.position.y=support_height(body,body.position)
	var goal=body.position+body.velocity*delta
	if not ground_step_allowed(body.position,goal):body.velocity=Vector3.ZERO
	body.velocity.y=(support_height(body,body.position+body.velocity*delta)-body.position.y)/maxf(delta,.001)
	body.move_and_slide()
	if not body.has_meta("rise_fall"):body.position.y=support_height(body,body.position)
	body.velocity.y=0
func if_jump_finish(body:Node) -> void:
	if body.has_method("finish_jump") and body.jump_active:body.finish_jump()
