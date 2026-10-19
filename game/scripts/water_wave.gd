extends Node3D
## One expanding water front; swept radial contact prevents tunneling at low frame rates.
var game: Node
var tuning: Dictionary
var direction=Vector3.FORWARD
var radius=0.0
var hit_ids: Dictionary={}
var front: MeshInstance3D
var crest: MeshInstance3D
var front_mesh=ImmediateMesh.new()
var crest_mesh=ImmediateMesh.new()
var droplets: Array=[]
var blocked: Array=[]
const SEGMENTS=24

func configure(target: Node, origin: Vector3, toward: Vector3, settings: Dictionary) -> void:
	game=target
	tuning=settings
	position=origin
	direction=toward.normalized()
	rotation.y=atan2(direction.x,direction.z)
	for color in [Color("#43bde5"),Color("#c5f7f4")]:
		var node=MeshInstance3D.new()
		var material=StandardMaterial3D.new()
		material.albedo_color=color
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
		node.material_override=material
		add_child(node)
		if front==null:
			front=node
			front.mesh=front_mesh
		else:
			crest=node
			crest.mesh=crest_mesh
	for i in range(12):
		var drop=MeshInstance3D.new()
		var mesh=SphereMesh.new()
		mesh.radius=.035
		mesh.height=.07
		mesh.radial_segments=6
		mesh.rings=2
		drop.mesh=mesh
		drop.material_override=crest.material_override
		add_child(drop)
		droplets.append(drop)
	for i in range(SEGMENTS):
		blocked.append(float(tuning.range)+1)
	_draw_front()

func damage_at(distance: float) -> int:
	return maxi(0,roundi(float(tuning.damage)*clampf(1-distance/float(tuning.range),0,1)))

func _physics_process(delta: float) -> void:
	if game.simulation_active() and not game.gallery_mode:
		advance(delta)

func advance(delta: float) -> void:
	var previous=radius
	radius=minf(float(tuning.range),radius+float(tuning.speed)*delta)
	var space=get_world_3d().direct_space_state
	for i in range(SEGMENTS):
		if blocked[i]<=radius:
			continue
		var angle=lerpf(-float(tuning.half_angle),float(tuning.half_angle),(i+.5)/SEGMENTS)
		var local_ray=Vector3(sin(angle),0,cos(angle))
		var endpoint=global_transform*(local_ray*radius)
		var query=PhysicsRayQueryParameters3D.create(position+Vector3(0,.65,0),endpoint+Vector3(0,.65,0),1)
		var wall=space.intersect_ray(query)
		if not wall.is_empty():
			blocked[i]=position.distance_to(wall.position-Vector3(0,.65,0))
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.health<=0 or hit_ids.has(enemy.get_instance_id()):
			continue
		var toward=enemy.position-position
		toward.y=0
		var distance=toward.length()
		if distance>radius+.46 or distance<previous-float(tuning.thickness)-.46 or toward.normalized().dot(direction)<cos(float(tuning.half_angle)):
			continue
		var query=PhysicsRayQueryParameters3D.create(position+Vector3(0,.65,0),enemy.position+Vector3(0,.65,0),1)
		if not space.intersect_ray(query).is_empty():
			continue
		hit_ids[enemy.get_instance_id()]=true
		var damage=damage_at(distance)
		if damage>0:
			enemy.take_damage(damage,toward.normalized())
	_draw_front()
	if radius>=float(tuning.range):
		queue_free()

func _draw_front() -> void:
	var fade=clampf(1-radius/float(tuning.range),0,1)
	front.material_override.albedo_color.a=fade*.7
	crest.material_override.albedo_color.a=fade*.95
	front_mesh.clear_surfaces()
	crest_mesh.clear_surfaces()
	front_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	crest_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(SEGMENTS):
		if radius>blocked[i]:
			continue
		var a=lerpf(-float(tuning.half_angle),float(tuning.half_angle),float(i)/SEGMENTS)
		var b=lerpf(-float(tuning.half_angle),float(tuning.half_angle),float(i+1)/SEGMENTS)
		var inner=maxf(0,radius-float(tuning.thickness))
		var height=.28+.20*sin(i*.65+radius*4)
		var outer_a=Vector3(sin(a)*radius,height,cos(a)*radius)
		var outer_b=Vector3(sin(b)*radius,height,cos(b)*radius)
		var inner_a=Vector3(sin(a)*inner,.08,cos(a)*inner)
		var inner_b=Vector3(sin(b)*inner,.08,cos(b)*inner)
		for vertex in [outer_a,outer_b,inner_a,inner_a,outer_b,inner_b]:
			front_mesh.surface_add_vertex(vertex)
		for vertex in [outer_a,outer_b,outer_a+Vector3(0,.045,-.065),outer_a+Vector3(0,.045,-.065),outer_b,outer_b+Vector3(0,.045,-.065)]:
			crest_mesh.surface_add_vertex(vertex)
	front_mesh.surface_end()
	crest_mesh.surface_end()
	for i in range(droplets.size()):
		var angle=lerpf(-float(tuning.half_angle),float(tuning.half_angle),(i+.5)/droplets.size())
		var bin=mini(SEGMENTS-1,int((i+.5)/droplets.size()*SEGMENTS))
		droplets[i].visible=radius<=blocked[bin]
		droplets[i].position=Vector3(sin(angle)*radius,.45+.25*sin(radius*6+i*1.7),cos(angle)*radius)
		droplets[i].scale=Vector3.ONE*(.4+fade*.8)
