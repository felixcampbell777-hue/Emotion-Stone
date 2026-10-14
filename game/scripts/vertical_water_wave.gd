extends "res://scripts/water_wave.gd"
## Upright, narrow water crest; damage volume follows its straight swept path.
const HEIGHT=2.8
const HALF_WIDTH=.32
var water=ShaderMaterial.new()
var foam=ShaderMaterial.new()
var blocked_at=INF
func configure(target:Node,origin:Vector3,toward:Vector3,settings:Dictionary) -> void:
	water.shader=load("res://shaders/mana_water.gdshader");water.set_shader_parameter("tint",Color(.03,.34,.62,.78))
	foam.shader=water.shader;foam.set_shader_parameter("tint",Color(.45,.9,1,.85))
	super.configure(target,origin,Vector3(toward.x,0,toward.z).normalized(),settings)
	front.material_override=water;crest.material_override=foam
	front.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;crest.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_draw_front()
func advance(delta:float) -> void:
	var previous=radius
	radius=minf(float(tuning.range),radius+float(tuning.speed)*delta)
	var space=get_world_3d().direct_space_state
	var box=BoxShape3D.new();box.size=Vector3(HALF_WIDTH*2,HEIGHT,.65)
	var query=PhysicsShapeQueryParameters3D.new();query.shape=box;query.collision_mask=1
	var start=global_transform*Vector3(0,0,previous+.135)
	start.y=game.current_world.ground_height(start)+HEIGHT*.5+.06
	query.transform=Transform3D(global_basis,start);query.motion=direction*(radius-previous)
	var obstruction=space.cast_motion(query)
	if not space.intersect_shape(query,1).is_empty(): blocked_at=previous
	elif obstruction[0]<1: blocked_at=lerpf(previous,radius,obstruction[0])
	var stop=minf(radius,blocked_at)
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.health<=0 or hit_ids.has(enemy.get_instance_id()): continue
		var local=global_transform.affine_inverse()*enemy.global_position
		var extent=float(enemy.definition.get("combat_radius",.5))
		if absf(local.x)>HALF_WIDTH+extent or local.z<previous-float(tuning.thickness)-extent or local.z>stop+.45+extent: continue
		var surface=game.current_world.ground_height(enemy.global_position)
		var body_height=float(enemy.definition.get("combat_height",3.1 if enemy.definition.kind=="warden" else 1))
		if enemy.global_position.y>surface+HEIGHT or enemy.global_position.y+body_height<surface: continue
		var ray=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.8,enemy.global_position+Vector3.UP*.8,1)
		if not space.intersect_ray(ray).is_empty(): continue
		hit_ids[enemy.get_instance_id()]=true
		var damage=damage_at(maxf(0,local.z))
		if damage>0: enemy.take_damage(damage,direction)
	radius=stop;_draw_front()
	if blocked_at<INF or radius>=float(tuning.range): queue_free()
func _draw_front() -> void:
	if front==null: return
	var fade=clampf(1-radius/float(tuning.range),0,1)
	for material in [water,foam]: material.set_shader_parameter("clock",radius*.18);material.set_shader_parameter("dissolve",fade)
	var center=global_transform*Vector3(0,0,radius)
	var floor_offset=game.current_world.ground_height(center)-global_position.y
	for strip in [[front_mesh,false],[crest_mesh,true]]:
		var mesh:ImmediateMesh=strip[0];mesh.clear_surfaces();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(32):
			var a=i/32.0;var b=(i+1)/32.0
			var points=[]
			for sample in [a,b]:
				var bow=sin(sample*PI);var width=HALF_WIDTH*(.12+.88*bow)*(0.30 if strip[1] else 1.0)
				var z=radius+bow*.45-(0.0 if strip[1] else .18)
				points.append(Vector3(-width,.06+floor_offset+sample*HEIGHT,z));points.append(Vector3(width,.06+floor_offset+sample*HEIGHT,z))
			for index in [0,1,2,1,3,2]:
				mesh.surface_set_normal(Vector3.FORWARD);mesh.surface_set_uv(Vector2(.0 if index%2==0 else 1.0,a if index<2 else b));mesh.surface_add_vertex(points[index])
		mesh.surface_end()
	for i in range(droplets.size()):
		var t=(i+.5)/droplets.size();droplets[i].position=Vector3(sin(i*2+radius*4)*.13,.06+floor_offset+t*HEIGHT,radius+sin(t*PI)*.45)
		droplets[i].scale=Vector3.ONE*(.4+fade*.6)
