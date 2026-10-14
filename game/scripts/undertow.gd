extends Node3D
## Low outward surge catches targets, then draws them back along collision-aware ground motion.
var game:Control
var direction=Vector3.FORWARD
var clock=0.0
var reach=6.0
var strength=1.0
var caught:Dictionary={}
var mesh=ImmediateMesh.new()
var front=MeshInstance3D.new()
var material=ShaderMaterial.new()
func configure(owner_game:Control,at:Vector3,toward:Vector3) -> void:
	game=owner_game;position=at;direction=Vector3(toward.x,0,toward.z).normalized();rotation.y=atan2(direction.x,direction.z)
	var rank=game.progression.rank("undertow")
	reach=6.0+.75*(rank-1);strength=1+.2*(rank-1)
	front.mesh=mesh;front.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material.shader=load("res://shaders/mana_water.gdshader");material.set_shader_parameter("tint",Color(.035,.34,.54,.62))
	front.material_override=material;add_child(front);draw_wave(0)
func _physics_process(delta:float) -> void:
	if game.player.input_enabled: advance(delta)
func advance(delta:float) -> void:
	clock+=delta
	var radius=reach*clampf(clock/.5,0,1) if clock<=.5 else reach*(1-clampf((clock-.5)/.85,0,1))
	var space=get_world_3d().direct_space_state
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.health<=0: continue
		var toward=enemy.global_position-global_position;toward.y=0
		if clock<=.5 and toward.length()<=radius+.5 and toward.normalized().dot(direction)>.45:
			var ray=PhysicsRayQueryParameters3D.create(global_position+Vector3(0,.5,0),enemy.global_position+Vector3(0,.5,0),1)
			if space.intersect_ray(ray).is_empty(): caught[enemy.get_instance_id()]=weakref(enemy)
		if not caught.has(enemy.get_instance_id()) or clock<.5 or toward.length()<1.25: continue
		var ray=PhysicsRayQueryParameters3D.create(global_position+Vector3(0,.5,0),enemy.global_position+Vector3(0,.5,0),1)
		if space.intersect_ray(ray).is_empty(): enemy.take_undertow(-toward.normalized(),strength)
	draw_wave(radius)
	if clock>=1.35: queue_free()
func draw_wave(radius:float) -> void:
	mesh.clear_surfaces();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(32):
		var a=lerpf(-1.08,1.08,i/32.0);var b=lerpf(-1.08,1.08,(i+1)/32.0)
		var inner=maxf(.08,radius-.55)
		var points=[Vector3(sin(a)*inner,.055,cos(a)*inner),Vector3(sin(a)*radius,.18+sin(clock*14+i)*.06,cos(a)*radius),Vector3(sin(b)*radius,.18+sin(clock*14+i+1)*.06,cos(b)*radius),Vector3(sin(b)*inner,.055,cos(b)*inner)]
		for index in [0,1,2,0,2,3]:
			var point=points[index];var world=global_transform*point
			point.y+=game.current_world.ground_height(world)-global_position.y
			mesh.surface_set_normal(Vector3.UP);mesh.surface_set_uv(Vector2(world.x,world.z)*.08)
			mesh.surface_add_vertex(point)
	mesh.surface_end();material.set_shader_parameter("clock",clock);material.set_shader_parameter("dissolve",clampf((1.35-clock)/.3,0,1))
