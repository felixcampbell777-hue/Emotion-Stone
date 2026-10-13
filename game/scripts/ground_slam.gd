extends Node3D
## Ground-only crater, cracked rim and thrown earth; no gameplay collision.
var game:Node
var age=0.0
var rubble:Array=[]
var surfaces:Array=[]
var radius=1.0
var wave:MeshInstance3D
var wave_tuning:Dictionary
var wave_hits:Dictionary={}
var wave_radius=0.0

func configure(owner:Node, at:Vector3, heavy:bool) -> void:
	game=owner
	add_to_group("ground_slam")
	position=at
	radius=1.15 if heavy else .90
	wave_tuning=game.player.combat.slam_shockwave
	wave=MeshInstance3D.new()
	var ring=TorusMesh.new()
	ring.inner_radius=.92
	ring.outer_radius=1.0
	ring.rings=32
	ring.ring_segments=6
	wave.mesh=ring
	wave.position.y=.045
	add_child(wave)
	paint(wave,Color("#e1cf9a"))
	wave.material_override.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	wave.scale=Vector3(.06,.24,.06)
	var disk=MeshInstance3D.new()
	var mesh=CylinderMesh.new()
	mesh.top_radius=radius*.82
	mesh.bottom_radius=radius*.82
	mesh.height=.025
	mesh.radial_segments=16
	disk.mesh=mesh
	add_child(disk)
	paint(disk,Color("#342f2a"))
	for i in range(16):
		var a=i*TAU/16
		var direction=Vector3(cos(a),0,sin(a))
		var rim=MeshInstance3D.new()
		var stone=BoxMesh.new()
		stone.size=Vector3(.34,.10,.18)*radius
		rim.mesh=stone
		rim.position=direction*radius*.84+Vector3(0,.04,0)
		rim.rotation.y=-a
		add_child(rim)
		paint(rim,Color("#716351"))
		var crack=MeshInstance3D.new()
		var slit=BoxMesh.new()
		slit.size=Vector3(.045,.015,.42)*radius
		crack.mesh=slit
		crack.position=direction*radius*1.02
		crack.rotation.y=PI/2-a
		add_child(crack)
		paint(crack,Color("#292820"))
		var fragment=MeshInstance3D.new()
		var chip=BoxMesh.new()
		chip.size=Vector3(.11,.10,.14)*(1+i%3*.25)
		fragment.mesh=chip
		fragment.position=direction*.3
		add_child(fragment)
		paint(fragment,Color("#998873"))
		rubble.append({"node":fragment,"start":fragment.position,"velocity":direction*(1.4+i%4*.35)+Vector3.UP*(2.0+i%3*.35)})

func paint(node:MeshInstance3D, color:Color) -> void:
	var material=StandardMaterial3D.new()
	material.albedo_color=color
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness=1.0
	node.material_override=material
	surfaces.append(node)

func _physics_process(delta:float) -> void:
	if game==null or not game.player.input_enabled or game.gallery_mode: return
	age+=delta
	if age<=float(wave_tuning.seconds)+delta:
		var progress=clampf(age/float(wave_tuning.seconds),0,1)
		wave_radius=float(wave_tuning.radius)*progress
		wave.scale=Vector3(maxf(.06,wave_radius),.24,maxf(.06,wave_radius))
		wave.visible=progress<1
		for enemy in game.enemies:
			if not is_instance_valid(enemy) or enemy.health<=0 or wave_hits.has(enemy.get_instance_id()): continue
			var away=enemy.global_position-global_position
			away.y=0
			var distance=away.length()
			if distance>wave_radius: continue
			wave_hits[enemy.get_instance_id()]=true
			var query=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.45,enemy.global_position+Vector3.UP*.45,1)
			if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
			if away.is_zero_approx(): away=game.player.facing()
			var strength=float(wave_tuning.force_factor)*lerpf(1.0,.65,distance/float(wave_tuning.radius))
			enemy.take_slam_shockwave(away,strength,float(wave_tuning.stun_seconds))
	for piece in rubble:
		var t=minf(age,.70)
		piece.node.position=piece.start+piece.velocity*t+Vector3(0,-4.8*t*t,0)
		piece.node.position.y=maxf(.04,piece.node.position.y)
		piece.node.rotation=Vector3(t*3,t*2,t)
	for surface in surfaces:
		surface.material_override.albedo_color.a=(1-clampf(age/float(wave_tuning.seconds),0,1)) if surface==wave else 1-smoothstep(2.2,3.2,age)
	if age>=3.2: queue_free()
