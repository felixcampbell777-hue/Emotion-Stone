extends Node3D

var shield: MeshInstance3D
var glow: StandardMaterial3D
var pulse := 0.0

func build(parent: Node3D, at: Vector3, width: float = 3.35) -> void:
	position = at
	parent.add_child(self)
	var body := StaticBody3D.new()
	body.name = "EnemyOnlyGuildBarrier"
	body.collision_layer = 8
	body.collision_mask = 0
	var solid := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 2.8, .16)
	solid.shape = shape
	solid.position.y = 1.4
	body.add_child(solid)
	add_child(body)

	glow = StandardMaterial3D.new()
	glow.albedo_color = Color("#ffd85a")
	glow.emission_enabled = true
	glow.emission = Color("#ffb51f")
	glow.emission_energy_multiplier = 3.2
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color.a = 0.0
	shield = MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width, 2.8)
	shield.mesh = mesh
	shield.material_override = glow
	shield.position = Vector3(0, 1.4, -.10)
	shield.visible = false
	add_child(shield)

	var area := Area3D.new()
	area.name = "EnemyBarrierContact"
	area.collision_layer = 0
	area.collision_mask = 4
	var trigger := CollisionShape3D.new()
	var trigger_shape := BoxShape3D.new()
	trigger_shape.size = Vector3(width + .45, 2.9, 1.0)
	trigger.shape = trigger_shape
	trigger.position.y = 1.4
	area.add_child(trigger)
	area.body_entered.connect(_on_enemy_contact)
	add_child(area)

func _on_enemy_contact(body: Node3D) -> void:
	if body == null or body.collision_layer & 4 == 0:
		return
	pulse = .55
	shield.visible = true
	glow.albedo_color.a = .82

func _process(delta: float) -> void:
	if pulse <= 0.0:
		return
	pulse = maxf(0.0, pulse - delta)
	var phase := 1.0 - pulse / .55
	glow.albedo_color.a = lerpf(.82, 0.0, phase)
	glow.emission_energy_multiplier = lerpf(4.5, 1.2, phase)
	shield.scale.x = 1.0 + sin(phase * PI) * .035
	if pulse <= 0.0:
		shield.visible = false
