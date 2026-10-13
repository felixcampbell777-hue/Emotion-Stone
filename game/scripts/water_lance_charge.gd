extends Node3D
## Blue water gathers at the greatsword pommel, tightening into the crystal.
var actor: Node
var elapsed=0.0
var duration=3.0
var progress=0.0
var active=true
var follows_world_sword=false
var hilt_anchor=Vector3.ZERO
var glow: MeshInstance3D
var droplets: Array=[]
var rings: Array=[]
var glow_material: StandardMaterial3D
var droplet_material: StandardMaterial3D

func configure(owner: Node, seconds: float) -> void:
	actor=owner
	duration=seconds
	position=Vector3(0,owner.BetaSwordMotion.POMMEL if owner.equipment.get_meta("beta_sword",false) else .36,0)
	hilt_anchor=position
	follows_world_sword=owner.first_person_driver!=null
	glow=MeshInstance3D.new()
	var core_mesh=SphereMesh.new()
	core_mesh.radius=.14
	core_mesh.height=.28
	core_mesh.radial_segments=10
	core_mesh.rings=5
	glow.mesh=core_mesh
	glow_material=StandardMaterial3D.new()
	glow_material.albedo_color=Color("#58d8ff",.78)
	glow_material.emission_enabled=true
	glow_material.emission=Color("#2abaff")
	glow_material.emission_energy_multiplier=2.0
	glow_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	if follows_world_sword: glow_material.albedo_color.a=.28
	glow.material_override=glow_material
	add_child(glow)
	droplet_material=StandardMaterial3D.new()
	droplet_material.albedo_color=Color("#a4f5ff",.92)
	droplet_material.emission_enabled=true
	droplet_material.emission=Color("#47caff")
	droplet_material.emission_energy_multiplier=1.2
	droplet_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	droplet_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	for index in range(10):
		var node=MeshInstance3D.new()
		var mesh=SphereMesh.new()
		mesh.radius=.045
		mesh.height=.09
		mesh.radial_segments=6
		mesh.rings=3
		node.mesh=mesh
		node.material_override=droplet_material
		add_child(node)
		droplets.append(node)
	for index in range(2):
		var node=MeshInstance3D.new()
		var mesh=SphereMesh.new()
		mesh.radius=.18
		mesh.height=.36
		mesh.radial_segments=10
		mesh.rings=5
		node.mesh=mesh
		var material=droplet_material.duplicate() as StandardMaterial3D
		material.albedo_color=Color("#58d8ff",.24)
		material.emission_energy_multiplier=.65
		node.material_override=material
		add_child(node)
		rings.append(node)
	_update_form()

func set_progress(value: float) -> void:
	if not active:
		return
	progress=clampf(value,0,1)
	_update_form()

func stop() -> void:
	# Deferred deletion must not let this effect reapply a restored material.
	active=false
	set_physics_process(false)
	visible=false

func _physics_process(delta: float) -> void:
	if active and is_instance_valid(actor) and actor.input_enabled:
		elapsed+=delta
		_update_form()

func _update_form() -> void:
	if follows_world_sword and is_instance_valid(actor): global_transform=actor.equipment.global_transform*Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.20),hilt_anchor)
	var tightening=smoothstep(.04,.97,progress)
	glow.scale=Vector3.ONE*(.60+.78*tightening)
	glow_material.emission_energy_multiplier=1.15+2.8*tightening
	var radius=lerpf(.36,.16,tightening)
	for index in range(droplets.size()):
		var angle=elapsed*(2.7+index*.07)+TAU*index/droplets.size()
		var spiral=Vector3(cos(angle)*radius,sin(angle*1.3)*.12,sin(angle)*radius)
		var inward=Vector3(cos(angle+.8),sin(angle+.8)*.45,sin(angle+.8)).normalized()
		droplets[index].position=spiral.lerp(inward*.11,progress*.28)
		droplets[index].scale=Vector3.ONE*(.75+.35*sin(angle*2))
	for index in range(rings.size()):
		rings[index].scale=Vector3(.70+tightening*.45,.12,.70+tightening*.45)
		rings[index].rotation=Vector3(elapsed*(.8+index*.4),elapsed*(1.1+index*.3),elapsed*.5+index*1.2)
