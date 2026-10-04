extends CharacterBody3D
const BODY = preload("res://assets/characters/humanoid-v1.glb")
const SWORD = preload("res://assets/characters/greatsword-v1.glb")
var visual: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
var definition: Dictionary
var controllable = false
var input_enabled = true
var walk_speed = 2.4
var last_axis = 0
var current_clip = ""
var clips: Dictionary = {}
var equipment: Node3D

func _init() -> void:
	collision_layer = 2
	collision_mask = 1 | 2
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = .23
	shape.height = 1.2
	collision.shape = shape
	collision.position.y = .6
	add_child(collision)
	visual = BODY.instantiate()
	add_child(visual)
	_find_rig(visual)
	for clip in animator.get_animation_list():
		for key in ["idle_loop","walk_loop","interact"]:
			if key in String(clip) or String(clip)==key.trim_suffix("_loop"):
				clips[key] = clip
				if key.ends_with("loop"):
					animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	var shadow_mesh = CylinderMesh.new()
	shadow_mesh.top_radius = .31
	shadow_mesh.bottom_radius = .31
	shadow_mesh.height = .004
	shadow_mesh.radial_segments = 12
	var shadow = MeshInstance3D.new()
	shadow.mesh = shadow_mesh
	shadow.position.y = .012
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("#52694e")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = material
	add_child(shadow)
	var socket = BoneAttachment3D.new()
	socket.bone_name = "spine"
	skeleton.add_child(socket)
	equipment = SWORD.instantiate()
	equipment.position = Vector3(.18,.23,-.21)
	equipment.rotation.z = -.28
	equipment.rotation.y = PI
	socket.add_child(equipment)

func _find_rig(node: Node) -> void:
	if node is Skeleton3D:
		skeleton = node
	if node is AnimationPlayer:
		animator = node
	for child in node.get_children():
		_find_rig(child)

func configure(data: Dictionary) -> void:
	definition = data.duplicate(true)
	_apply_modules(visual)
	equipment.visible = data.modules.equipment == "greatsword"
	_apply_palette(visual)
	_apply_palette(equipment)
	play_clip("idle_loop")

func _apply_modules(node: Node) -> void:
	if node is MeshInstance3D:
		if String(node.name).begins_with("hair_"):
			node.visible = String(node.name)=="hair_"+definition.modules.hair
		elif String(node.name).begins_with("outfit_"):
			node.visible = String(node.name)=="outfit_"+definition.modules.outfit
	for child in node.get_children():
		_apply_modules(child)

func _apply_palette(node: Node) -> void:
	if node is MeshInstance3D:
		for i in range(node.mesh.get_surface_count()):
			var source = node.mesh.surface_get_material(i)
			if source is StandardMaterial3D:
				var segments = String(source.resource_name).split("_")
				if segments.size()<2 or not definition.palette.has(segments[0]):
					continue
				var material = source.duplicate() as StandardMaterial3D
				var color = Color(definition.palette[segments[0]])
				if segments[1]=="dark":
					color = color.darkened(.28)
				elif segments[1]=="light":
					color = color.lightened(.22)
				material.albedo_color = color
				material.roughness = 1.0
				node.set_surface_override_material(i,material)
	for child in node.get_children():
		_apply_palette(child)

func play_clip(key: String) -> void:
	if not clips.has(key):
		push_error("Required animation missing: "+key)
		return
	if current_clip!=key:
		animator.play(clips[key],.12)
		current_clip=key

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		last_axis=0
	elif event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		last_axis=1

func _physics_process(_delta: float) -> void:
	if not controllable:
		return
	var movement = Vector2.ZERO
	if input_enabled:
		movement=Input.get_vector("move_left","move_right","move_up","move_down")
		if movement.x!=0 and movement.y!=0:
			movement = Vector2(sign(movement.x),0) if last_axis==0 else Vector2(0,sign(movement.y))
	velocity=Vector3(movement.x,0,movement.y)*walk_speed
	move_and_slide()
	position.y=0
	if movement.length_squared()>.01:
		visual.rotation.y=atan2(movement.x,movement.y)
		play_clip("walk_loop")
	else:
		if current_clip!="interact" or not animator.is_playing():
			play_clip("idle_loop")
