extends Node3D
## A fast, wall-limited water beam with a bright impact burst and splash damage.
var game: Node
var wielder: Node3D
var tuning: Dictionary
var direction=Vector3.FORWARD
var travel=0.0
var impact_time=0.0
var finished=false
var beam_outer: MeshInstance3D
var beam_core: MeshInstance3D
var outer_mesh: BoxMesh
var core_mesh: BoxMesh
var impact_core: MeshInstance3D
var shards: Array=[]
var hit_ids: Dictionary={}

func configure(owner: Node, from: Vector3, toward: Vector3, settings: Dictionary, source: Node3D) -> void:
	game=owner
	wielder=source
	tuning=settings.duplicate(true)
	direction=toward.normalized()
	position=from
	_create_beam()

func _create_beam() -> void:
	beam_outer=MeshInstance3D.new()
	outer_mesh=BoxMesh.new()
	outer_mesh.size=Vector3(.24,.24,1)
	beam_outer.mesh=outer_mesh
	beam_outer.material_override=_glow_material(Color("#299ef5",.42),Color("#278fff"),2.0)
	beam_outer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam_outer)
	beam_core=MeshInstance3D.new()
	core_mesh=BoxMesh.new()
	core_mesh.size=Vector3(.075,.075,1)
	beam_core.mesh=core_mesh
	beam_core.material_override=_glow_material(Color("#dbffff",.98),Color("#93edff"),3.5)
	beam_core.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam_core)
	impact_core=MeshInstance3D.new()
	var flash=SphereMesh.new()
	flash.radius=.19
	flash.height=.38
	flash.radial_segments=8
	flash.rings=4
	impact_core.mesh=flash
	impact_core.material_override=_glow_material(Color("#85e8ff",.85),Color("#36baff"),3.5)
	impact_core.visible=false
	add_child(impact_core)
	for index in range(12):
		var shard=MeshInstance3D.new()
		var mesh=SphereMesh.new()
		mesh.radius=.065
		mesh.height=.13
		mesh.radial_segments=6
		mesh.rings=3
		shard.mesh=mesh
		shard.material_override=_glow_material(Color("#91edff",.9),Color("#41c7ff"),2.4)
		shard.visible=false
		add_child(shard)
		shards.append(shard)
	_update_beam(0)

func _glow_material(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material=StandardMaterial3D.new()
	material.albedo_color=color
	material.emission_enabled=true
	material.emission=emission
	material.emission_energy_multiplier=energy
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _physics_process(delta: float) -> void:
	if finished:
		if not game.simulation_active() or game.gallery_mode:
			return
		impact_time+=delta
		_animate_impact(delta)
		if impact_time>.42:
			queue_free()
		return
	if not game.simulation_active() or game.gallery_mode:
		return
	var previous=travel
	var next=minf(float(tuning.range),travel+float(tuning.speed)*delta)
	var from=global_position+direction*previous
	var to=global_position+direction*next
	var segment=to-from
	var length_squared=maxf(segment.length_squared(),.0001)
	var space=get_world_3d().direct_space_state
	var query=PhysicsRayQueryParameters3D.create(from,to,1,[wielder.get_rid()])
	var wall=space.intersect_ray(query)
	var limit=1.0 if wall.is_empty() else clampf(from.distance_to(wall.position)/sqrt(length_squared),0,1)
	var first_enemy: Node3D=null
	var enemy_phase=limit+.001
	var enemy_point=Vector3.ZERO
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.health<=0:
			continue
		var target=enemy.position+Vector3(0,.62,0)
		var phase=clampf((target-from).dot(segment)/length_squared,0,1)
		var closest=from+segment*phase
		if phase<=limit and phase<enemy_phase and closest.distance_to(target)<=.78:
			first_enemy=enemy
			enemy_phase=phase
			enemy_point=closest
	if first_enemy!=null:
		travel=previous+segment.length()*enemy_phase
		_update_beam(travel)
		_explode(enemy_point,first_enemy)
		return
	if not wall.is_empty():
		travel=previous+from.distance_to(wall.position)
		_update_beam(travel)
		_explode(wall.position,wall.collider)
		return
	travel=next
	_update_beam(travel)
	if travel>=float(tuning.range):
		_explode(global_position+direction*travel,null)

func _update_beam(distance: float) -> void:
	var safe_length=maxf(.015,distance)
	beam_outer.position=direction*safe_length*.5
	beam_core.position=direction*safe_length*.5
	beam_outer.quaternion=Quaternion(Vector3.BACK,direction)
	beam_core.quaternion=Quaternion(Vector3.BACK,direction)
	outer_mesh.size.z=safe_length
	core_mesh.size.z=safe_length
	beam_outer.visible=not finished
	beam_core.visible=not finished

func _explode(at: Vector3, collider: Object) -> void:
	if finished:
		return
	finished=true
	impact_time=0
	beam_outer.visible=true
	beam_core.visible=true
	var space=get_world_3d().direct_space_state
	var direct_target: Node3D=collider as Node3D if collider is Node3D and collider in game.enemies else null
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.health<=0 or hit_ids.has(enemy.get_instance_id()):
			continue
		var flat=enemy.position-at
		flat.y=0
		var distance=flat.length()
		var direct=enemy==direct_target
		if not direct and distance>float(tuning.blast_radius):
			continue
		var blocked=false
		if not direct:
			var ray=PhysicsRayQueryParameters3D.create(at,enemy.position+Vector3(0,.55,0),1,[wielder.get_rid()])
			blocked=not space.intersect_ray(ray).is_empty()
		if blocked:
			continue
		hit_ids[enemy.get_instance_id()]=true
		enemy.take_lance_damage(int(tuning.damage if direct else tuning.splash_damage),direction)
	impact_core.position=to_local(at)
	impact_core.visible=true
	for index in range(shards.size()):
		var angle=TAU*index/shards.size()
		shards[index].position=to_local(at)
		shards[index].set_meta("burst_direction",Vector3(cos(angle),sin(angle*.7),sin(angle)))
		shards[index].visible=true
	for enemy in game.enemies:
		if enemy.health>0 and enemy.get_instance_id() in hit_ids:
			var bar=game.enemy_bars.filter(func(item): return item.enemy==enemy)
			if not bar.is_empty():
				bar[0].bar.value=enemy.health

func _animate_impact(delta: float) -> void:
	var fade=1.0-clampf(impact_time/.42,0,1)
	var swell=smoothstep(0,.13,impact_time)
	impact_core.scale=Vector3.ONE*(.45+2.0*swell)
	var material=impact_core.material_override as StandardMaterial3D
	material.albedo_color.a=.85*fade
	for shard in shards:
		var burst: Vector3=shard.get_meta("burst_direction")
		shard.position+=burst*delta*5.0
		shard.scale=Vector3.ONE*fade
		(shard.material_override as StandardMaterial3D).albedo_color.a=.9*fade
	beam_outer.scale.z=fade
	beam_core.scale.z=fade
