extends MeshInstance3D
## One forward pressure fan at the sliding stop; scenery blocks its contacts.
var game:Node
var tuning:Dictionary
var direction=Vector3.FORWARD
var age=0.0
var hit_ids:Dictionary={}
var ribbons=ImmediateMesh.new()

func configure(owner:Node,at:Vector3,forward:Vector3) -> void:
	game=owner
	tuning=game.player.combat.thrust_charge
	global_position=at
	direction=Vector3(forward.x,0,forward.z).normalized()
	rotation.y=atan2(direction.x,direction.z)
	add_to_group("thrust_gust")
	mesh=ribbons
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo=true
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material_override=material
	redraw()

func _physics_process(delta:float) -> void:
	if game==null or not game.player.input_enabled or game.gallery_mode: return
	age+=delta
	var progress=clampf(age/float(tuning.gust_seconds),0,1)
	var reach=float(tuning.gust_distance)*progress
	var right=Vector3(direction.z,0,-direction.x)
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.health<=0 or hit_ids.has(enemy.get_instance_id()): continue
		var toward=enemy.global_position-global_position
		var forward=toward.dot(direction)
		if forward<-.3 or forward>reach+.3 or forward>float(tuning.gust_distance): continue
		var width=lerpf(.65,float(tuning.gust_half_width),clampf(forward/float(tuning.gust_distance),0,1))
		if absf(toward.dot(right))>width+.3 or absf(toward.y)>.95: continue
		hit_ids[enemy.get_instance_id()]=true
		var query=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.3,enemy.global_position+Vector3.UP*.65,1)
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		enemy.take_thrust_gust(direction,float(tuning.recoil_multiplier),float(tuning.gust_stun_seconds))
	redraw()
	if progress>=1: queue_free()

func redraw() -> void:
	var t=clampf(age/float(tuning.gust_seconds),0,1)
	var reach=float(tuning.gust_distance)*t
	var width=lerpf(.65,float(tuning.gust_half_width),t)
	ribbons.clear_surfaces()
	ribbons.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in range(5):
		for segment in range(22):
			var a=crest(segment/22.0,reach,width,layer)
			var b=crest((segment+1)/22.0,reach,width,layer)
			var strip=Vector3(0,.015, .055)*(1-layer*.1)
			for vertex in [a-strip,a+strip,b+strip,a-strip,b+strip,b-strip]:
				ribbons.surface_set_color(Color(.89,.99,.96,sqrt(1-t)*(.95-layer*.08)))
				ribbons.surface_add_vertex(vertex)
	ribbons.surface_end()

func crest(f:float,reach:float,width:float,layer:int) -> Vector3:
	var across=f*2-1
	return Vector3(across*width,.12+layer*.15+sin(f*PI)*.22,reach-absf(across)*.45-layer*.20)
