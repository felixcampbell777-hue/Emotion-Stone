extends CharacterBody3D
const BODY = preload("res://assets/characters/humanoid-v1.glb")
const SWORD = preload("res://assets/characters/greatsword-v1.glb")
const BETA_SWORD = preload("res://assets/characters/greatsword-beta.glb")
const BetaSwordMotion = preload("res://scripts/beta_sword_motion.gd")
signal health_changed(current: int, maximum: int)
signal damaged(amount: int)
signal dodge_rejected(reason: String)
signal defeated
signal ground_slam(at: Vector3, heavy: bool)
signal thrust_stopped(at: Vector3, direction: Vector3)
signal attack_contact(kind: String, direction: Vector3, hit_ids: Dictionary)
signal stamina_denied
signal stamina_changed(current: float, maximum: float)
signal parry_succeeded(enemy: Node3D)
signal water_cast(origin: Vector3, direction: Vector3)
signal vertical_water_cast(origin:Vector3,direction:Vector3)
signal lance_fired(origin: Vector3, direction: Vector3)
const WaterLanceCharge=preload("res://scripts/water_lance_charge.gd")
var visual: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
var definition: Dictionary
var water_unlocked=false
var lance_unlocked=false
var thrust_unlocked=false
var roll_unlocked=false
var dash_unlocked=false
var jump_unlocked=true
var dash_equipped=false
var jump_equipped=true
var thrust_charge_rate=1.0
var lance_stability=0.0
var dash_distance=0.0
var dash_distance_multiplier=1.0
var dash_attack_queued=false
var dash_attack_blend=0.0
var dash_water_unlocked=false
var dash_uppercut=false
var dash_water_pending=false
const DASH_ATTACK_PHASE=.28
const DASH_ATTACK_BLEND=.16
var dash_release_queued=false
var jump_active=false
var jump_velocity=0.0
var heavy_style="overhead"
var shift_pending=false
var shift_clock=0.0
var roll_restore_drawn=false
var roll_attack_queued=false
var controllable = false
var camera_relative=false
var movement_camera_yaw=0.0
var input_enabled = true
var walk_speed = 2.4
var last_axis = 0
var current_clip = ""
var clips: Dictionary = {}
var equipment: Node3D
var beta_hand_drop=0.0
var first_person_driver:RefCounted
var first_person_sword=preload("res://scripts/first_person_sword.gd").new()
var presentation_clock=0.0
var back_harness: Node3D
var harness_material: StandardMaterial3D
var holder_material: StandardMaterial3D
var sword_holders: Array[Node3D]=[]
var holder_rest: Array[Transform3D]=[]
var holder_anchors: Array[Vector3]=[]
var back_socket: BoneAttachment3D
var combat: Dictionary
var magic_gear:RefCounted
var motion: Dictionary
var health = 100
var max_health = 100
var sword_equipped=true
var dash_stamina_multiplier=1.0
var jump_stamina_multiplier=1.0
var sword_drawn = false
var state = "free"
var state_time = 0.0
var state_duration = 0.0
var attack_direction = Vector3.FORWARD
var hit_ids: Dictionary = {}
var slam_emitted=false
var slam_contact_started=false
var invulnerability = 0.0
var knockback = Vector3.ZERO
var arm_wrapped = true
var scrape_time = 0.0
var scrape_nodes: Array = []
var scrape_cursor = 0
var stamina=100.0
var max_stamina=100.0
var stamina_delay=0.0
var sprint_denial_latched=false
var sprinting=false
var sprint_exhausted=false
var parry_resolved=false
var parried_threats:Dictionary={}
var parry_flash=0.0
var blade_sweep_previous:Array=[]
var combo_stage=0
var combo_remaining=0.0
var combo_queued=false
var attack_yaw=0.0
var rush_clock=0.0
var rush_credit=0.0
var charge_rush=false
var attack_rushing=false
var compressed_windup=0.0
var chain_speed=0.0
var chain_blend=0.0
var chain_blend_duration=.12
var chain_bones: Array=[]
var chain_weapon=Transform3D.IDENTITY
var water_released=false
var counter_unlocked=false
var counter_equipped=false
var counter_target:WeakRef
var counter_remaining=0.0
var counter_active=false
var counter_step=Vector3.ZERO
var counter_damage=0.0
var measured_bonus=0.0
var measured_remaining=0.0
var measured_triggered=false
var undertow_unlocked=false
var undertow_cast=false
var dragon_unlocked=false
var dragon_pose=preload("res://scripts/dragon_caster_pose.gd").new()
var lance_charge_fx: Node3D
var movement_direction=Vector3.ZERO
var slow_sources:Dictionary={}
var ground_world:Node3D
var sword_material_backup: Array=[]
var sword_energy_materials: Array[ShaderMaterial]=[]
var sword_energy_front: float=-.15
var stagger_start_phase: float=0.0
var stagger_motion="lance"
var thrust_charging=false
var thrust_charge_seconds=0.0
var thrust_distance=0.0
var thrust_launch_seconds=0.0
var thrust_hold_seconds=0.0
var thrust_windup_seconds=0.0
var thrust_start_phase=0.0
var thrust_gust_emitted=false
var thrust_wind_fx:Node3D
const LANCE_HOLD_PHASE=.70
var action_transition_bones: Array=[]
var action_transition_remaining=0.0
var action_transition_duration=.16

func _init() -> void:
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	combat = JSON.parse_string(FileAccess.get_file_as_string("res://content/combat.json"))
	motion = JSON.parse_string(FileAccess.get_file_as_string("res://content/sword_motion.json"))
	max_health = int(combat.max_health)
	health = max_health
	max_stamina=float(combat.max_stamina)
	stamina=max_stamina
	var collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = .23
	shape.height = 1.12
	collision.shape = shape
	collision.position.y = .56
	add_child(collision)
	visual = BODY.instantiate()
	add_child(visual)
	_find_rig(visual)
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip in animator.get_animation_list():
		for key in ["idle_loop","walk_loop","interact","drag_idle_loop","drag_walk_loop","attack_light","attack_light2","attack_light3","attack_heavy","attack_water","attack_lance","parry_guard","draw_sword","sheathe_sword","attack_thrust","dodge_roll","stand_up","dodge_roll_sheathed","stand_up_sheathed"]:
			if String(clip)==key or String(clip)==key.trim_suffix("_loop") or String(clip).ends_with("/"+key.trim_suffix("_loop")):
				clips[key] = clip
				if key.ends_with("loop"):
					animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	var shadow_mesh = CylinderMesh.new()
	shadow_mesh.top_radius = .31
	shadow_mesh.bottom_radius = .31
	shadow_mesh.height = .004
	shadow_mesh.radial_segments = 12
	var shadow = MeshInstance3D.new()
	shadow.name = "Shadow"
	shadow.mesh = shadow_mesh
	shadow.position.y = .012
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("#52694e")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = material
	add_child(shadow)
	back_socket = BoneAttachment3D.new()
	back_socket.bone_name = "spine"
	skeleton.add_child(back_socket)
	equipment = SWORD.instantiate()
	back_socket.add_child(equipment)
	_place_on_back()
	_build_back_harness()

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
	sword_equipped = data.modules.equipment == "greatsword"
	equipment.visible = sword_equipped
	back_harness.visible=sword_equipped
	harness_material.albedo_color=Color(data.palette.leather)
	holder_material.albedo_color=Color(data.palette.leather)
	_apply_palette(visual)
	_apply_palette(equipment)
	visual.scale = Vector3(.92,.92,.92) * (Vector3(1.1,1.03,1.07) if data.modules.outfit=="workdress" else Vector3.ONE)
	play_clip("idle_loop")

func _apply_modules(node: Node) -> void:
	if node is MeshInstance3D:
		var node_name = String(node.name)
		if node_name.begins_with("hair_"):
			node.visible = node_name=="hair_"+definition.modules.hair
		elif node_name.begins_with("outfit_"):
			node.visible = node_name=="outfit_"+definition.modules.outfit
		elif node_name.begins_with("footwear_"):
			node.visible = node_name=="footwear_"+definition.modules.get("footwear","boots")
		elif node_name=="left_arm_human":
			node.visible = definition.modules.get("left_arm","human")=="human"
		elif node_name=="arm_prototype":
			node.visible = definition.modules.get("left_arm","human")=="prototype"
		elif node_name=="arm_wrapped":
			node.visible = definition.modules.get("left_arm","human")=="prototype" and arm_wrapped
	for child in node.get_children():
		_apply_modules(child)

func set_arm_wrapped(value: bool) -> void:
	arm_wrapped = value
	_apply_modules(visual)

func set_sword_art(profile:String) -> void:
	if equipment==null or not sword_material_backup.is_empty(): return
	var meshes:Array=[]; _collect_sword_meshes(equipment,meshes)
	for mesh in meshes:
		if not mesh.has_meta("original_steel_surfaces"):
			var saved:Array=[]
			for index in range(mesh.mesh.get_surface_count()): saved.append(mesh.get_surface_override_material(index))
			mesh.set_meta("original_steel_surfaces",saved)
		for index in range(mesh.mesh.get_surface_count()):
			var original=mesh.get_meta("original_steel_surfaces")[index]
			if profile=="original": mesh.set_surface_override_material(index,original); continue
			var source=original if original!=null else mesh.mesh.surface_get_material(index)
			if not source is StandardMaterial3D: continue
			var material=source.duplicate()
			if String(source.resource_name).begins_with("metal"): material.metallic=.75; material.roughness=.28
			elif String(source.resource_name).begins_with("gem"): material.roughness=.1; material.metallic=.2
			mesh.set_surface_override_material(index,material)

func set_beta_sword(enabled:bool) -> bool:
	# Swap the actual actor-owned steel; the personal body mirrors this same weapon.
	# Map/mode changes already reset action state. Stop effects before retiring gear.
	if bool(equipment.get_meta("beta_sword",false))==enabled: return false
	clear_lance_charge()
	set_sword_glow(false)
	var old=equipment; var parent=old.get_parent(); var pose=old.transform
	parent.remove_child(old)
	equipment=(BETA_SWORD if enabled else SWORD).instantiate()
	equipment.set_meta("beta_sword",enabled)
	parent.add_child(equipment); equipment.transform=pose; equipment.visible=sword_equipped
	if not enabled: _apply_palette(equipment)
	old.queue_free()
	beta_hand_drop=0.0
	back_socket.remove_child(back_harness); back_harness.queue_free()
	sword_holders.clear(); holder_rest.clear(); holder_anchors.clear()
	_build_back_harness()
	if not sword_drawn: _place_on_back()
	blade_sweep_previous.clear()
	return true

func set_sword_glow(enabled: bool, strength: float=3.0) -> void:
	if enabled:
		if not sword_material_backup.is_empty():
			return
		var meshes=[]
		_collect_sword_meshes(equipment,meshes)
		for mesh_instance in meshes:
			var overrides=[]
			for surface in range(mesh_instance.mesh.get_surface_count()):
				var source=mesh_instance.get_surface_override_material(surface)
				if source==null:
					source=mesh_instance.mesh.surface_get_material(surface)
				overrides.append(mesh_instance.get_surface_override_material(surface))
				if source is StandardMaterial3D:
					if String(mesh_instance.name) in ["SwordBlade","SwordTip"]:
						var energy=ShaderMaterial.new()
						energy.shader=preload("res://shaders/sword_energy.gdshader")
						energy.set_shader_parameter("base_color",source.albedo_color)
						energy.set_shader_parameter("steel_roughness",source.roughness)
						energy.set_shader_parameter("steel_metallic",source.metallic)
						energy.set_shader_parameter("mesh_to_sword",equipment.global_transform.affine_inverse()*mesh_instance.global_transform)
						energy.set_shader_parameter("blade_base",-BetaSwordMotion.BLADE_BASE if equipment.get_meta("beta_sword",false) else .045)
						energy.set_shader_parameter("blade_length",BetaSwordMotion.BLADE_BASE-BetaSwordMotion.TIP if equipment.get_meta("beta_sword",false) else 1.125)
						energy.set_shader_parameter("energy_front",-.15)
						energy.set_shader_parameter("energy_strength",strength)
						sword_energy_materials.append(energy)
						mesh_instance.set_surface_override_material(surface,energy)
						continue
					var glowing=source.duplicate() as StandardMaterial3D
					var is_gem=String(source.resource_name).begins_with("gem")
					if not is_gem:
						continue
					glowing.albedo_color=glowing.albedo_color.lerp(Color("#398dff" if is_gem else "#276fd2"),.78)
					glowing.emission_enabled=true
					glowing.emission=Color("#398dff") if is_gem else Color("#235ec9")
					glowing.emission_energy_multiplier=strength if is_gem else strength*.48
					mesh_instance.set_surface_override_material(surface,glowing)
			sword_material_backup.append({"mesh":mesh_instance,"materials":overrides})
	else:
		for entry in sword_material_backup:
			var mesh_instance=entry.get("mesh")
			if not is_instance_valid(mesh_instance):
				continue
			var materials:Array=entry.get("materials",[])
			for surface in range(materials.size()):
				mesh_instance.set_surface_override_material(surface,materials[surface])
		sword_material_backup.clear()
		sword_energy_materials.clear()
		sword_energy_front=-.15

func update_sword_energy(progress: float) -> void:
	# Aura accumulates first, then feeds a luminous front from guard to tip.
	sword_energy_front=lerpf(-.15,1.15,smoothstep(.76,1.0,progress))
	for material in sword_energy_materials:
		material.set_shader_parameter("energy_front",sword_energy_front)

func _collect_sword_meshes(node: Node, out: Array) -> void:
	if node is WaterLanceCharge:
		return
	if node is MeshInstance3D and node.mesh!=null:
		out.append(node)
	for child in node.get_children():
		_collect_sword_meshes(child,out)

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
				var current=node.get_surface_override_material(i)
				if current is ShaderMaterial and current.shader.resource_path in ["res://shaders/hero_surface.gdshader","res://shaders/hero_preview.gdshader","res://shaders/character_surface.gdshader"]:
					var detailed=current.duplicate()
					if current.shader.resource_path.get_file() in ["hero_surface.gdshader","hero_preview.gdshader"] and segments[0]=="dress": color=Color(definition.palette.dress)
					detailed.set_shader_parameter("tint",color)
					node.set_surface_override_material(i,detailed)
					continue
				node.set_surface_override_material(i,material)
	for child in node.get_children():
		_apply_palette(child)

func play_clip(key: String, blend: float=.12) -> void:
	if not clips.has(key):
		push_error("Required animation missing: "+key)
		return
	if current_clip!=key:
		# Manually sampled actions use our explicit body-pose transition. A
		# mixer crossfade needs advance(), and otherwise freezes the outgoing pose.
		if key.begins_with("attack_") or key in ["parry_guard","draw_sword","sheathe_sword","attack_thrust","dodge_roll","stand_up","dodge_roll_sheathed","stand_up_sheathed"]:
			blend=0.0
		animator.play(clips[key],blend)
		current_clip=key

func begin_action_transition(seconds: float=.16) -> void:
	action_transition_bones.clear()
	for index in range(skeleton.get_bone_count()):
		action_transition_bones.append(skeleton.get_bone_pose(index))
	action_transition_duration=maxf(.01,seconds)
	action_transition_remaining=action_transition_duration

func blend_action_transition(delta: float) -> void:
	if action_transition_remaining<=0 or action_transition_bones.size()!=skeleton.get_bone_count():
		return
	var weight=smoothstep(0,1,1-action_transition_remaining/action_transition_duration)
	for index in range(action_transition_bones.size()):
		skeleton.set_bone_pose(index,action_transition_bones[index].interpolate_with(skeleton.get_bone_pose(index),weight))
	action_transition_remaining=maxf(0,action_transition_remaining-delta)
	if action_transition_remaining<=0:
		action_transition_bones.clear()

func facing() -> Vector3:
	return Vector3(sin(visual.rotation.y),0,cos(visual.rotation.y))

func _input(event: InputEvent) -> void:
	if not controllable or (event is InputEventKey and event.echo): return
	if event.is_action_pressed("dash"): begin_dash_charge()
	elif event.is_action_released("dash"): release_dash()
	if event.is_action_pressed("jump"): begin_jump()
	var shift_key=event is InputEventKey and (event.physical_keycode==KEY_SHIFT or event.keycode==KEY_SHIFT)
	if shift_key and event.pressed:
		shift_pending=input_enabled and state=="free"
		shift_clock=0.0
	elif shift_key and not event.pressed:
		if shift_pending and shift_clock<=float(combat.dodge.tap_seconds): request_dodge()
		shift_pending=false
	if event.is_action_pressed("dodge"):
		shift_pending=false
		request_dodge()
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		last_axis=0
	elif event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		last_axis=1

func back_mount_pose(canonical:bool=false) -> Transform3D:
	var up=Vector3(-.82,.55,.10).normalized()
	if not canonical and equipment.get_meta("beta_sword",false):
		up=Vector3(-.60,.79,.06).normalized()
		var beta_right=(Vector3.RIGHT-up*up.x).normalized()
		return Transform3D(Basis(beta_right,up,beta_right.cross(up)),Vector3(-.43,1.59,-.12)-up*(BetaSwordMotion.GRIP*float(combat.sword_scale)))
	var right=(Vector3.RIGHT-up*up.x).normalized()
	return Transform3D(Basis(right,up,right.cross(up)),Vector3(-.88,1.62,-.20)-up*.256)

func back_mount_relative() -> Transform3D:
	return skeleton.get_bone_global_rest(skeleton.find_bone("spine")).affine_inverse()*back_mount_pose()

func _harness_link(a:Vector3,b:Vector3,width:float,depth:float,parent:Node3D=null) -> void:
	var mesh=MeshInstance3D.new()
	var box=BoxMesh.new()
	box.size=Vector3(width,a.distance_to(b),depth)
	mesh.mesh=box
	mesh.material_override=harness_material if parent==null else holder_material
	var up=(b-a).normalized()
	var right=(Vector3.RIGHT-up*up.x).normalized()
	mesh.transform=Transform3D(Basis(right,up,right.cross(up)),(a+b)*.5)
	if parent==null: back_harness.add_child(mesh)
	else:
		mesh.position-=parent.position
		parent.add_child(mesh)

func _build_back_harness() -> void:
	back_harness=Node3D.new()
	back_harness.name="BackCarryHarness"
	back_socket.add_child(back_harness)
	back_harness.transform=skeleton.get_bone_global_rest(skeleton.find_bone("spine")).affine_inverse()
	harness_material=StandardMaterial3D.new()
	harness_material.albedo_color=Color("#725136")
	harness_material.roughness=1
	holder_material=harness_material.duplicate()
	holder_material.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
	if equipment.get_meta("beta_sword",false):
		preload("res://scripts/beta_back_anchor.gd").build(self)
		return
	# Leather straps sit on the back; the two open saddles hold the blade.
	_harness_link(Vector3(-.18,1.40,-.16),Vector3(.16,1.09,-.17),.065,.032)
	_harness_link(Vector3(.18,1.40,-.16),Vector3(-.16,1.09,-.17),.055,.032)
	var mount=back_mount_pose()
	var beta=bool(equipment.get_meta("beta_sword",false))
	for distance in ([.48,.94] if beta else [.55,1.03]):
		var pivot=(BetaSwordMotion.GRIP*float(combat.sword_scale)) if equipment.get_meta("beta_sword",false) else .256
		var center=mount*Vector3(0,pivot-distance,0)
		var holder=Node3D.new()
		holder.position=center
		back_harness.add_child(holder)
		sword_holders.append(holder)
		holder_rest.append(holder.transform)
		var anchor=Vector3(clampf(center.x,-.18,.18),maxf(center.y,1.09),-.16)
		holder_anchors.append(anchor)
		# A leather attachment pad conceals the fully retracted holder.
		_harness_link(anchor+Vector3(0,-.055,.008),anchor+Vector3(0,.055,.008),.095,.025)
		_harness_link(anchor,center+Vector3(0,0,-.048),.025 if beta else .06,.020 if beta else .045,holder)
		var right=mount.basis.x
		var rear=center+Vector3(0,0,-.052)
		var half_width=.065 if beta else .15
		_harness_link(rear-right*half_width,rear+right*half_width,.032 if beta else .075,.020 if beta else .038,holder)
		for sign in [-1,1]:
			var edge=center+right*(half_width*sign)
			_harness_link(edge+Vector3(0,0,-.065),edge+Vector3(0,0,.02),.016 if beta else .035,.020 if beta else .06,holder)

func _update_sword_holders(draw_phase:float) -> void:
	var droop=smoothstep(.10,.25,draw_phase)
	var retract=smoothstep(.20,.46,draw_phase)
	for index in range(sword_holders.size()):
		var holder=sword_holders[index]
		holder.visible=retract<.999
		if equipment.get_meta("beta_sword",false):
			holder.position=holder_rest[index].origin.lerp(holder_anchors[index],retract)
			holder.basis=(Basis(back_mount_pose().basis.y,.18*droop)*holder_rest[index].basis).scaled(Vector3.ONE*maxf(.001,1-retract))
			continue
		var backing=holder_anchors[index]+Vector3(0,0,.008)
		holder.position=holder_rest[index].origin.lerp(backing,retract)+Vector3(0,-.09*droop*(1-retract),-.018*droop*(1-retract))
		var tilt=Basis(Vector3.FORWARD,(-.65 if index==0 else .65)*droop)
		holder.basis=(tilt*holder_rest[index].basis).scaled(Vector3.ONE*maxf(.001,1-retract))

func _place_on_back() -> void:
	if equipment.get_parent()!=back_socket:
		equipment.reparent(back_socket,false)
	equipment.transform=back_mount_relative()
	equipment.basis*=float(combat.sword_scale)

func sync_beta_back_carry(hero:Node3D) -> void:
	var frame=hero.carry_delta()*visual.global_transform
	back_harness.global_transform=frame
	if not sword_drawn and state not in ["draw","sheathe"]:
		equipment.global_transform=frame*back_mount_pose()
		equipment.basis*=float(combat.sword_scale)

func set_sword_equipped(value: bool) -> void:
	sword_equipped=value and definition.modules.equipment=="greatsword"
	set_sword_drawn(false)
	equipment.visible=sword_equipped
	back_harness.visible=sword_equipped

func set_weapon_visual(id:String) -> void:
	if equipment==null:return
	for mesh in equipment.find_children("*","MeshInstance3D",true,false):
		if id=="standard_greatsword" and "gem" in String(mesh.name).to_lower():mesh.visible=false;continue
		for surface in range(mesh.mesh.get_surface_count()):
			var base=mesh.mesh.surface_get_material(surface)
			if base==null:continue
			var name=String(base.resource_name).to_lower();var copy=base.duplicate()
			if id=="wolfs_bane_greatsword" and ("blade" in name or "steel" in name):copy.albedo_color=Color("#030406")
			elif id=="improved_standard_greatsword" and ("pommel" in name or "hilt" in name):copy.albedo_color=Color("#c17c32")
			mesh.set_surface_override_material(surface,copy)

func set_sword_drawn(value: bool) -> void:
	blade_sweep_previous.clear()
	clear_lance_charge()
	value=value and sword_equipped
	sprinting=false
	charge_rush=false
	thrust_charging=false
	if is_instance_valid(thrust_wind_fx): thrust_wind_fx.visible=false
	thrust_charge_seconds=0
	rush_clock=0
	rush_credit=0
	chain_blend=0
	roll_attack_queued=false
	dash_attack_queued=false
	dash_attack_blend=0.0
	dash_uppercut=false
	dash_water_pending=false
	dash_release_queued=false
	chain_speed=0
	movement_direction=Vector3.ZERO
	sword_drawn=value
	_update_sword_holders(1.0 if value else 0.0)
	state="free"
	state_time=0
	if value:
		if equipment.get_parent()!=visual:
			equipment.reparent(visual,false)
		equipment.scale=Vector3.ONE*float(combat.sword_scale)
		_pose_sword("drag",0)
	else:
		_place_on_back()
	current_clip=""
	play_clip("drag_idle_loop" if value else "idle_loop",0.0)
	animator.advance(0)

func clear_lance_charge() -> void:
	if is_instance_valid(lance_charge_fx):
		lance_charge_fx.stop()
		lance_charge_fx.queue_free()
	lance_charge_fx=null
	set_sword_glow(false)

# Both the authored body and rendered steel receive this same pose clock.
func sword_action_phase(progress:float,stowing:bool=false) -> float:
	var curve:Array=combat.get("sheathe_timing" if stowing else "draw_timing",[])
	var t=clampf(progress,0,1)
	if curve.size()<2: return t
	for index in range(curve.size()-1):
		var a=curve[index]
		var b=curve[index+1]
		if t<=float(b.time):
			var dt=float(b.time)-float(a.time)
			var f=clampf((t-float(a.time))/dt,0,1)
			return clampf(float(a.pose)*(2*f*f*f-3*f*f+1)+_sword_clock_slope(curve,index)*dt*(f*f*f-2*f*f+f)+float(b.pose)*(-2*f*f*f+3*f*f)+_sword_clock_slope(curve,index+1)*dt*(f*f*f-f*f),0,1)
	return 1.0

func _sword_clock_slope(curve:Array,index:int) -> float:
	if index==0 or index==curve.size()-1: return 0.0
	var before=(float(curve[index].pose)-float(curve[index-1].pose))/(float(curve[index].time)-float(curve[index-1].time))
	var after=(float(curve[index+1].pose)-float(curve[index].pose))/(float(curve[index+1].time)-float(curve[index].time))
	if before<=0 or after<=0: return 0.0
	# Harmonic slopes keep the clock monotone with continuous velocity at keys.
	return 2.0/(1.0/before+1.0/after)

func toggle_sword() -> bool:
	if not input_enabled or state!="free" or not sword_equipped:
		return false
	combo_stage=0
	combo_remaining=0
	combo_queued=false
	state="sheathe" if sword_drawn else "draw"
	state_time=0
	state_duration=float(combat.sheathe_seconds if sword_drawn else combat.draw_seconds)
	if not sword_drawn:
		equipment.reparent(visual,true)
		equipment.scale=Vector3.ONE*float(combat.sword_scale)
	begin_action_transition(.12)
	play_clip("sheathe_sword" if sword_drawn else "draw_sword",0.0)
	return true

func attack_tuning() -> Dictionary:
	if counter_active and state=="light":
		var counter=combat.combo[0].duplicate(true);counter.damage=roundi(counter.damage*(1+counter_damage));return counter
	if state=="thrust":
		var tuning=combat.thrust.duplicate()
		tuning.damage=roundi(float(tuning.damage)*(1+float(combat.thrust_charge.damage_per_second)*thrust_charge_seconds))
		return tuning
	return combat.combo[combo_stage-2] if state=="light" and combo_stage>1 else combat[state] if state in ["light","heavy","thrust"] else combat.light

func thrust_extension_hold(charged:float) -> float:
	var tuning=combat.thrust_charge
	return float(tuning.hold_base_seconds)/(1+log(1+maxf(0,charged))/log(1+float(tuning.hold_reference_charge)))

func thrust_prepare_phase() -> float:
	return float(combat.thrust_charge.ready_phase)*smoothstep(0,float(combat.thrust_charge.prepare_seconds),state_time)

func thrust_travel_speed() -> float:
	var t=clampf((state_time-thrust_windup_seconds)/thrust_launch_seconds,0,1)
	if state_time<thrust_windup_seconds or t>=1: return 0.0
	# Smooth acceleration (.18) and long braking (.48), integral = .67.
	return thrust_distance/thrust_launch_seconds/.67*smoothstep(0,.18,t)*(1-smoothstep(.52,1,t))

func attack_phase() -> float:
	if state=="thrust":
		if state_time<thrust_windup_seconds:
			return lerpf(thrust_start_phase,.24,state_time/thrust_windup_seconds)
		var elapsed=state_time-thrust_windup_seconds
		if elapsed<thrust_launch_seconds: return lerpf(.24,.64,elapsed/thrust_launch_seconds)
		elapsed-=thrust_launch_seconds
		if elapsed<thrust_hold_seconds: return .64
		return lerpf(.64,1,clampf((elapsed-thrust_hold_seconds)/float(combat.thrust_charge.recovery_seconds),0,1))
	if not attack_rushing or state not in ["light","heavy","thrust"]:
		return clampf(state_time/state_duration,0,1)
	var tuning=attack_tuning()
	var start=float(tuning.active_start)
	if state_time<compressed_windup:
		return start*state_time/compressed_windup
	return minf(1,start+(state_time-compressed_windup)/float(tuning.duration))

func begin_water(pull:bool=false) -> bool:
	if (not undertow_unlocked if pull else not water_unlocked) or not input_enabled or state!="free" or health<=0 or not sword_drawn:
		return false
	if not spend_stamina(28.0 if pull else float(combat.water.stamina_cost)):
		return false
	begin_action_transition(.18)
	state="water"
	undertow_cast=pull
	state_time=0
	state_duration=float(combat.water.duration)
	attack_direction=facing()
	water_released=false
	combo_remaining=0
	combo_stage=0
	charge_rush=false
	rush_credit=0
	chain_speed=0
	play_clip("attack_water",.08)
	return true

func sword_gem_position() -> Vector3:
	for mesh in equipment.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null: continue
		for surface in range(mesh.mesh.get_surface_count()):
			var material=mesh.mesh.surface_get_material(surface)
			if material==null or not "gem" in String(material.resource_name).to_lower(): continue
			var vertices=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			if vertices.is_empty(): continue
			var bounds=AABB(vertices[0],Vector3.ZERO)
			for vertex in vertices: bounds=bounds.expand(vertex)
			return mesh.global_transform*bounds.get_center()
	return equipment.global_transform*Vector3(0,.25 if equipment.get_meta("beta_sword",false) else .34,0)

func begin_dragon_channel() -> bool:
	if not dragon_unlocked or not input_enabled or state!="free" or health<=0 or not sword_drawn: return false
	if not spend_stamina(float(combat.sea_dragon.stamina_cost)): return false
	dragon_pose.start(self)
	begin_action_transition(.2)
	clear_dash_attack();clear_lance_charge()
	state="dragon_channel";state_time=0;state_duration=100000
	combo_queued=false;combo_remaining=0;combo_stage=0
	shift_pending=false;rush_clock=0;rush_credit=0;chain_speed=0
	velocity=Vector3.ZERO
	play_clip("attack_lance",0)
	set_sword_glow(true,2.2);update_sword_energy(0)
	return true

func begin_water_lance() -> bool:
	if not lance_unlocked or not input_enabled or state!="free" or health<=0 or not sword_drawn:
		return false
	if not spend_stamina(float(combat.lance.stamina_cost)):
		return false
	begin_action_transition(.20)
	state="lance_charge"
	state_time=0
	state_duration=float(combat.lance.charge_seconds)
	attack_direction=facing()
	combo_remaining=0
	combo_stage=0
	combo_queued=false
	charge_rush=false
	rush_clock=0
	rush_credit=0
	chain_speed=0
	lance_charge_fx=WaterLanceCharge.new()
	if first_person_driver!=null: add_child(lance_charge_fx)
	else: equipment.add_child(lance_charge_fx)
	lance_charge_fx.configure(self,state_duration)
	set_sword_glow(true,2.2)
	play_clip("attack_lance",.12)
	return true

func _link_combo() -> void:
	# Preserve the current body, blade and travel through the linked transition.
	var bones=[]
	for index in range(skeleton.get_bone_count()):
		bones.append(skeleton.get_bone_pose(index))
	var carry=velocity.length()
	var weapon_pose=equipment.transform
	state="free"
	combo_remaining=float(combat.combo_window)
	if not begin_attack("light"):
		set_sword_drawn(true)
		return
	chain_bones=bones
	chain_weapon=weapon_pose
	chain_blend=.12
	action_transition_remaining=0.0
	action_transition_bones.clear()
	chain_speed=minf(carry,float(attack_tuning().momentum))
	animator.seek(0,true)
	_pose_sword("light"+str(combo_stage),0)
	equipment.transform=chain_weapon

func queue_combo() -> bool:
	if not input_enabled or health<=0 or state!="light" or combo_stage>=3 or combo_queued or attack_phase()<.10:
		return false
	var next_tuning=combat.combo[combo_stage-1]
	if not can_afford(float(next_tuning.stamina_cost)):
		return false
	combo_queued=true
	return true

func begin_attack(kind: String, charged:float=0.0, prepared:bool=false) -> bool:
	if kind=="light" and state=="dash_charge": return queue_dash_attack()
	if kind=="light" and counter_ready(): return begin_counter()
	if kind=="light" and state in ["roll","stand"]:
		return queue_roll_light()
	if kind=="heavy" and heavy_style=="charge_thrust" and thrust_unlocked: kind="thrust"
	if kind=="light" and state=="light":
		return queue_combo()
	if not input_enabled or state!="free" or health<=0 or not sword_drawn or kind not in ["light","heavy","thrust"]:
		return false
	var next_stage=combo_stage+1 if kind=="light" and combo_remaining>0 and combo_stage<3 else 1
	var tuning=combat.combo[next_stage-2] if kind=="light" and next_stage>1 else combat[kind]
	if not spend_stamina(float(tuning.stamina_cost)):
		return false
	begin_action_transition(.16)
	counter_active=false;measured_triggered=false;dash_uppercut=false
	state=kind
	state_time=0
	state_duration=float(tuning.duration)
	attack_rushing=rush_credit>0 or charge_rush
	compressed_windup=float(tuning.duration)*float(tuning.active_start)
	if attack_rushing:
		var factor=float(combat.rush_heavy_windup if kind in ["heavy","thrust"] else combat.rush_light_windup)
		compressed_windup*=factor
		state_duration=compressed_windup+float(tuning.duration)*(1-float(tuning.active_start))
	if kind=="thrust":
		_ensure_thrust_wind()
		thrust_gust_emitted=false
		var charge=combat.thrust_charge
		thrust_charge_seconds=clampf(charged,0,float(charge.max_seconds))
		thrust_distance=float(charge.base_distance)+float(charge.distance_per_second)*thrust_charge_seconds
		thrust_launch_seconds=float(charge.launch_seconds)+float(charge.launch_seconds_per_charge)*thrust_charge_seconds
		thrust_hold_seconds=thrust_extension_hold(thrust_charge_seconds)
		thrust_start_phase=thrust_prepare_phase() if prepared else 0.0
		# state_time has just reset; use the supplied charge duration for preparation.
		if prepared: thrust_start_phase=float(charge.ready_phase)*smoothstep(0,float(charge.prepare_seconds),charged)
		thrust_windup_seconds=float(charge.release_windup_seconds if prepared else charge.unprepared_windup_seconds)
		if attack_rushing: thrust_windup_seconds*=float(combat.rush_heavy_windup)
		state_duration=thrust_windup_seconds+thrust_launch_seconds+thrust_hold_seconds+float(charge.recovery_seconds)
	thrust_charging=false
	charge_rush=false
	rush_credit=0
	rush_clock=0
	chain_speed=velocity.length()*.65 if attack_rushing else 0.0
	chain_blend=0
	chain_blend_duration=.12
	combo_stage=next_stage if kind=="light" else 0
	combo_remaining=0
	combo_queued=false
	if first_person_driver!=null: visual.rotation.y=wrapf(first_person_driver.yaw-PI,-PI,PI)
	attack_yaw=visual.rotation.y
	attack_direction=facing()
	slam_emitted=false
	slam_contact_started=false
	hit_ids.clear()
	blade_sweep_previous.clear()
	play_clip("attack_light"+str(combo_stage) if kind=="light" and combo_stage>1 else "attack_"+kind,0.0)
	return true

func queue_roll_light() -> bool:
	if not input_enabled or health<=0 or not sword_drawn or not roll_restore_drawn: return false
	if not can_afford(float(combat.light.stamina_cost)): return false
	roll_attack_queued=true
	return true

func _exit_roll_light() -> bool:
	var bones=[]
	for index in range(skeleton.get_bone_count()): bones.append(skeleton.get_bone_pose(index))
	var weapon_pose=equipment.transform
	state="free"
	combo_remaining=0
	combo_stage=0
	roll_attack_queued=false
	if not begin_attack("light"):
		state="stand"
		return false
	chain_bones=bones
	chain_weapon=weapon_pose
	chain_blend_duration=float(combat.dodge.attack_exit_blend)
	chain_blend=chain_blend_duration
	action_transition_remaining=0
	action_transition_bones.clear()
	animator.seek(0,true)
	_pose_sword("light",0)
	equipment.transform=chain_weapon
	for index in range(bones.size()): skeleton.set_bone_pose(index,bones[index])
	return true

func sprint_held() -> bool:
	return Input.is_action_pressed("sprint") and (not roll_unlocked or not shift_pending or shift_clock>float(combat.dodge.tap_seconds))

func begin_dash_charge() -> bool:
	if not input_enabled or state!="free" or not dash_unlocked or not dash_equipped:
		if input_enabled and not dash_equipped: dodge_rejected.emit("Learn and equip Dash in Skills.")
		return false
	if not can_afford(12*dash_stamina_multiplier): return false
	state="dash_charge";state_time=0;state_duration=1.5
	dash_release_queued=false
	dash_attack_queued=false;dash_attack_blend=0
	dash_water_pending=false
	combo_stage=0;combo_remaining=0;combo_queued=false
	rush_credit=0;charge_rush=false
	attack_direction=movement_vector(Vector2(0,-1)) if camera_relative else facing()
	play_clip("drag_idle_loop" if sword_drawn else "idle_loop")
	return true

func release_dash() -> bool:
	if state!="dash_charge": return false
	if not input_enabled: dash_release_queued=true;return false
	dash_release_queued=false
	var fraction=clampf(state_time/1.5,0,1)
	var cost=lerpf(12,24,fraction)*dash_stamina_multiplier
	if not spend_stamina(cost):
		state="free";dash_attack_queued=false;dash_attack_blend=0
		return false
	dash_distance=lerpf(2.5,7,fraction)*dash_distance_multiplier
	state="dash";state_time=0;state_duration=.32+dash_distance*.03
	return true

func queue_dash_attack() -> bool:
	if not input_enabled or health<=0 or state!="dash_charge" or not sword_drawn or dash_attack_queued: return false
	var dash_cost=lerpf(12,24,clampf(state_time/1.5,0,1))*dash_stamina_multiplier
	if not can_afford(dash_cost+float(combat.light.stamina_cost)): return false
	dash_attack_queued=true
	return true

func clear_dash_attack() -> void:
	dash_attack_queued=false
	if dash_water_pending:
		dash_water_pending=false
		set_sword_glow(false)

func _exit_dash_attack() -> bool:
	var weapon_pose=equipment.transform
	var bones=[]
	for index in range(skeleton.get_bone_count()): bones.append(skeleton.get_bone_pose(index))
	dash_attack_queued=false;dash_attack_blend=0
	# The intentionally queued dash strike wins over an earlier parry follow-up.
	counter_remaining=0;counter_target=null
	state="free";state_time=0;combo_stage=0;combo_remaining=0
	if not begin_attack("light"):
		set_sword_drawn(sword_drawn)
		return false
	dash_uppercut=true
	undertow_cast=false
	dash_water_pending=dash_water_unlocked and water_unlocked
	# The dash preloads this exact opener pose; never return to ready between them.
	state_time=float(combat.light.duration)*DASH_ATTACK_PHASE
	play_clip("attack_heavy",0)
	animator.seek(animator.get_animation(clips.attack_heavy).length*.68,true)
	chain_bones=bones;chain_weapon=weapon_pose
	chain_blend_duration=DASH_ATTACK_BLEND;chain_blend=chain_blend_duration
	action_transition_remaining=0;action_transition_bones.clear()
	equipment.transform=weapon_pose
	for index in range(bones.size()): skeleton.set_bone_pose(index,bones[index])
	return true

func _dash_water_followthrough(progress:float) -> void:
	if not dash_water_pending or state!="light" or combo_stage!=1: return
	if progress<.72:
		if progress>=.40:
			set_sword_glow(true,2.2)
			update_sword_energy(smoothstep(.40,.72,progress))
		return
	# Release after the melee cut, before its .74 combo join; one wave per dash attack.
	dash_water_pending=false
	set_sword_glow(false)
	if not dash_water_unlocked or not water_unlocked or not spend_stamina(float(combat.water.stamina_cost)): return
	var toward=attack_direction
	if first_person_driver!=null:
		var aim=-first_person_driver.sample_first_person(0,false).basis.z
		toward=Vector3(aim.x,0,aim.z).normalized()
	vertical_water_cast.emit(position+toward*.9,toward)

func begin_jump() -> bool:
	if not input_enabled or state!="free":
		return false
	if not spend_stamina(12*jump_stamina_multiplier): return false
	jump_active=true;jump_velocity=6.0
	state="jump";state_time=0;state_duration=2.0
	return true

func finish_jump() -> void:
	jump_active=false;jump_velocity=0;velocity.y=0
	if state=="jump": state="free";state_time=0

func request_dodge() -> bool:
	if not input_enabled: return false
	if not roll_unlocked:
		dodge_rejected.emit("Unlock Dodge in the Form skill tree [P].")
		return false
	if state!="free" or health<=0:
		dodge_rejected.emit("Finish the current action before dodging.")
		return false
	if stamina<float(combat.dodge.stamina_cost):
		stamina_denied.emit()
		return false
	return begin_roll()

func begin_roll() -> bool:
	if not roll_unlocked or not input_enabled or state!="free" or health<=0: return false
	if not spend_stamina(float(combat.dodge.stamina_cost)): return false
	roll_restore_drawn=sword_drawn
	roll_attack_queued=false
	# Keep the original equipment stance; a sheathed dodge never draws the blade.
	begin_action_transition(.10)
	state="roll"
	state_time=0.0
	state_duration=float(combat.dodge.duration)
	var axis=Input.get_vector("move_left","move_right","move_up","move_down")
	attack_direction=movement_vector(axis).normalized() if axis.length_squared()>.01 else facing()
	visual.rotation.y=atan2(attack_direction.x,attack_direction.z)
	combo_stage=0
	combo_remaining=0
	play_clip("dodge_roll" if roll_restore_drawn else "dodge_roll_sheathed",0)
	return true

func begin_charge() -> bool:
	if counter_ready():
		begin_counter();return false
	if state in ["roll","stand"]:
		return input_enabled and sword_drawn and roll_restore_drawn and can_afford(float(combat.light.stamina_cost))
	if state=="light":
		return input_enabled and combo_stage<3 and not combo_queued
	if not input_enabled or state!="free" or health<=0 or not sword_drawn:
		return false
	if not can_afford(float(combat.light.stamina_cost)): return false
	charge_rush=rush_credit>0 or sprinting
	begin_action_transition(.16)
	state="charge"
	state_time=0
	thrust_charging=heavy_style=="charge_thrust" and thrust_unlocked and stamina>=float(combat.thrust.stamina_cost)
	if thrust_charging: _ensure_thrust_wind()
	state_duration=float(combat.thrust_charge.max_seconds) if thrust_charging else float(combat.heavy_hold_seconds)
	attack_direction=facing()
	play_clip("drag_idle_loop")
	return true

func _ensure_thrust_wind() -> void:
	if is_instance_valid(thrust_wind_fx): return
	thrust_wind_fx=load("res://scripts/thrust_wind.gd").new()
	add_child(thrust_wind_fx)

func release_charge(kind: String) -> bool:
	if state in ["roll","stand"]:
		return queue_roll_light() if kind=="light" else false
	if state=="light":
		return queue_combo() if kind=="light" else false
	if state!="charge":
		return false
	var charged=state_time
	var held_thrust=thrust_charging
	var rushing=charge_rush
	var pose=equipment.transform
	var bones=[]
	for index in range(skeleton.get_bone_count()):
		bones.append(skeleton.get_bone_pose(index))
	state="free"
	if not begin_attack(kind,charged if held_thrust and kind=="heavy" else 0.0,held_thrust and kind=="heavy"):
		thrust_charging=false
		set_sword_drawn(true)
		return false
	if held_thrust or (rushing and state!="thrust"):
		if not held_thrust: state_time=minf(charged,compressed_windup)
		action_transition_remaining=0
		action_transition_bones.clear()
		chain_weapon=pose
		chain_bones=bones
		chain_blend=.12
	return true

func cancel_charge() -> void:
	charge_rush=false
	thrust_charging=false
	if is_instance_valid(thrust_wind_fx): thrust_wind_fx.visible=false
	if state=="charge":
		state="free"
		state_time=0

func begin_parry() -> bool:
	if not input_enabled or state!="free" or health<=0 or not sword_drawn:
		return false
	if not spend_stamina(float(combat.parry.stamina_cost)):
		return false
	begin_action_transition(.06)
	state="parry"
	combo_stage=0
	combo_remaining=0
	state_time=0
	state_duration=float(combat.parry.duration)
	parry_resolved=false
	parried_threats.clear()
	attack_direction=facing()
	play_clip("parry_guard",0)
	return true

func parry_pose_phase(progress:float) -> float:
	# Accelerate the existing outside-body entry; keep its path and recovery.
	var time=clampf(progress,0,1)*float(combat.parry.duration)
	var recovery=float(combat.parry.duration)*.68
	if time<=.06:return .30*smoothstep(0,.06,time)
	if time<recovery:return lerpf(.30,.68,(time-.06)/(recovery-.06))
	return clampf(progress,0,1)

func try_parry(enemy: Node3D,contact:Vector3=Vector3(INF,INF,INF)) -> bool:
	if not input_enabled or health<=0 or state!="parry" or not is_instance_valid(enemy) or parried_threats.has(enemy.get_instance_id()):
		return false
	if first_person_driver!=null: attack_direction=-Vector3(sin(first_person_driver.yaw),0,cos(first_person_driver.yaw))
	if state_time<float(combat.parry.active_start) or state_time>float(combat.parry.active_end):
		return false
	var threat=contact if is_finite(contact.x) else enemy.position
	var incoming=threat-position
	incoming.y=0
	if incoming.length()>float(combat.parry.contact_range):
		return false
	if incoming.normalized().dot(attack_direction)<float(combat.parry.cone_dot):
		return false
	var ray_end=Vector3(threat.x,position.y+.7,threat.z) if is_finite(contact.x) else enemy.position+Vector3(0,.7,0)
	var ray=PhysicsRayQueryParameters3D.create(position+Vector3(0,.7,0),ray_end,1)
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		return false
	parried_threats[enemy.get_instance_id()]=true
	parry_resolved=true
	parry_flash=.26
	parry_succeeded.emit(enemy)
	return true

func can_afford(amount:float) -> bool:
	if stamina+.0001<amount:
		stamina_denied.emit(); return false
	return true

func spend_stamina(amount: float) -> bool:
	if not can_afford(amount): return false
	stamina=maxf(0,stamina-amount)
	stamina_delay=float(combat.stamina_regen_delay)
	stamina_changed.emit(stamina,max_stamina)
	return true

func restore_stamina(value: float) -> void:
	stamina=clampf(value,0,max_stamina)
	stamina_delay=0
	sprint_exhausted=stamina<float(combat.sprint_resume_stamina)
	stamina_changed.emit(stamina,max_stamina)

func _recover_stamina(delta: float) -> void:
	stamina_delay=maxf(0,stamina_delay-delta)
	if state=="free" and not sprinting and stamina_delay<=0 and stamina<max_stamina:
		stamina=minf(max_stamina,stamina+float(combat.stamina_regen)*delta*(1+measured_bonus if measured_remaining>0 else 1))
		stamina_changed.emit(stamina,max_stamina)
	if stamina>=float(combat.sprint_resume_stamina):
		sprint_exhausted=false

func take_damage(amount: int, direction: Vector3) -> bool:
	if amount<=0 or health<=0 or invulnerability>0 or not input_enabled:
		return false
	counter_remaining=0;counter_target=null
	if magic_gear!=null: amount=magic_gear.incoming_damage(amount)
	if amount<=0:return false
	var previous_health=health
	health=maxi(0,health-amount)
	damaged.emit(previous_health-health)
	if dash_water_pending: clear_dash_attack()
	if state in ["dash_charge","dash"]: clear_dash_attack()
	invulnerability=float(combat.hurt_invulnerability)
	knockback=direction*2.4*(1-clampf(magic_gear.bonus("hurt_recoil_saving"),0,.65) if magic_gear!=null else 1.0)
	if state=="lance_charge" and health>0:
		stagger_motion="lance"
		stagger_start_phase=clampf(state_time/state_duration,0,1)*LANCE_HOLD_PHASE
		begin_action_transition(.12)
		clear_lance_charge()
		state="stagger"
		state_time=0
		state_duration=float(combat.lance.get("stagger_seconds",.8))
		combo_queued=false
		rush_credit=0
		velocity=Vector3.ZERO
	if health>0 and ((state=="charge" and thrust_charging) or state=="thrust"):
		stagger_start_phase=thrust_prepare_phase() if state=="charge" else attack_phase()
		stagger_motion="thrust"
		if is_instance_valid(thrust_wind_fx): thrust_wind_fx.visible=false
		begin_action_transition(.12)
		thrust_charging=false
		thrust_charge_seconds=0
		state="stagger"
		state_time=0
		state_duration=float(combat.thrust_charge.stagger_seconds)
		combo_queued=false
		hit_ids.clear()
		blade_sweep_previous.clear()
		velocity=Vector3.ZERO
	health_changed.emit(health,max_health)
	if health==0:
		clear_lance_charge()
		defeated.emit()
	return true

func restore_health(value: int) -> void:
	health=clampi(value,1,max_health)
	health_changed.emit(health,max_health)

func drown() -> void:
	if health<=0 or not input_enabled:return
	clear_lance_charge();health=0;health_changed.emit(health,max_health);defeated.emit()

func _draw_value(index:int,key:String) -> Vector3:
	var point=motion.draw[index]
	var grip=Vector3(point.grip[0],point.grip[1],point.grip[2])
	return grip if key=="grip" else (Vector3(point.tip[0],point.tip[1],point.tip[2])-grip).normalized()

func _draw_tangent(index:int,key:String) -> Vector3:
	if float(motion.draw[index].t)<=.10 or float(motion.draw[index].t)>=.82: return Vector3.ZERO
	return (_draw_value(index+1,key)-_draw_value(index-1,key))/(float(motion.draw[index+1].t)-float(motion.draw[index-1].t))

func _draw_curve(index:int,key:String,f:float,dt:float) -> Vector3:
	return _draw_value(index,key)*(2*f*f*f-3*f*f+1)+_draw_tangent(index,key)*dt*(f*f*f-2*f*f+f)+_draw_value(index+1,key)*(-2*f*f*f+3*f*f)+_draw_tangent(index+1,key)*dt*(f*f*f-f*f)

func sample_draw(t:float) -> Dictionary:
	for index in range(motion.draw.size()-1):
		var a=motion.draw[index]
		var b=motion.draw[index+1]
		if t<=float(b.t):
			var dt=float(b.t)-float(a.t)
			var f=clampf((t-float(a.t))/dt,0,1)
			var grip:Vector3
			var direction:Vector3
			if float(a.t)>=.10 and float(b.t)<=.82:
				grip=_draw_curve(index,"grip",f,dt)
				direction=_draw_curve(index,"direction",f,dt).normalized()
			else:
				f=f*f*(3-2*f)
				grip=_draw_value(index,"grip").lerp(_draw_value(index+1,"grip"),f)
				direction=_draw_value(index,"direction").slerp(_draw_value(index+1,"direction"),f)
			return {"grip":grip,"tip":grip+direction*2.128}
	var last=motion.draw.size()-1
	var grip=_draw_value(last,"grip")
	return {"grip":grip,"tip":grip+_draw_value(last,"direction")*2.128}

func motion_pose(key: String, t: float) -> Dictionary:
	if key=="draw": return sample_draw(t)
	var poses=motion[key]
	var a=poses[-1]
	var b=a
	var f=0.0
	for i in range(poses.size()-1):
		if t<=float(poses[i+1].t):
			a=poses[i]
			b=poses[i+1]
			f=smoothstep(float(a.t),float(b.t),t)
			break
	var result={}
	for key_name in ["grip","tip"]:
		result[key_name]=Vector3(a[key_name][0],a[key_name][1],a[key_name][2]).lerp(Vector3(b[key_name][0],b[key_name][1],b[key_name][2]),f)
	if key in ["roll","stand"]:
		var transform=dodge_transform(key,t)
		result.grip=transform*result.grip
		result.tip=transform*result.tip
	return result

func dodge_transform(key: String,t: float) -> Transform3D:
	var tuck=smoothstep(.02,.18,t) if key=="roll" else 1-smoothstep(.04,.90,t)
	var turn=TAU*smoothstep(.16,.88,t) if key=="roll" else TAU
	var rotation=Basis(Vector3.RIGHT,turn)
	var pivot=Vector3(0,.95,0)
	var height=.95-.31*tuck+.04*sin(turn*.5) if key=="roll" else .95-.31*tuck
	var center=Vector3(0,height,0)
	return Transform3D(rotation,center-rotation*pivot)

func _pose_sword(key: String, t: float) -> void:
	var draw_action=state in ["draw","sheathe"]
	var f=t if state!="sheathe" else 1-t
	_update_sword_holders(f if draw_action else 1.0)
	var pose=motion_pose("draw" if draw_action else key,f if draw_action else t)
	var mount=Transform3D.IDENTITY
	if draw_action:
		mount=skeleton.transform*skeleton.get_bone_global_pose(skeleton.find_bone("spine"))*back_mount_relative()
		if equipment.get_meta("beta_sword",false) and has_node("BetaHero"):
			var hero=get_node("BetaHero");hero.synchronize()
			mount=visual.global_transform.affine_inverse()*hero.carry_delta()*visual.global_transform*back_mount_pose()
		var weight=smoothstep(.10,.31,f)
		var mount_delta=mount*back_mount_pose(true).affine_inverse()
		var direction:Vector3=(pose.tip-pose.grip).normalized()
		pose.grip=(mount_delta*pose.grip).lerp(pose.grip,weight)
		if equipment.get_meta("beta_sword",false): pose.grip+=mount.basis.y*(BetaSwordMotion.GRIP*float(combat.sword_scale)-.256)*(1-weight)
		direction=(mount_delta.basis*direction).normalized().slerp(direction,weight)
		pose.tip=pose.grip+direction*2.128
	beta_hand_drop=0.0
	if equipment.get_meta("beta_sword",false):
		var previous_y=float(pose.grip.y)
		var carry_basis=dodge_transform(key,t).basis if key in ["roll","stand"] else Basis.IDENTITY
		pose=BetaSwordMotion.adapt(pose,"draw" if draw_action else key,f if draw_action else t,float(combat.sword_scale),carry_basis)
		beta_hand_drop=(float(pose.grip.y)-previous_y)*.92
	var up:Vector3=(pose.grip-pose.tip).normalized()
	var right=sword_right(up,key,t)
	if draw_action:
		var hint=mount.basis.x.lerp(Vector3.RIGHT,smoothstep(.10,.31,f))
		var transverse=hint-up*hint.dot(up)
		if transverse.length_squared()>.00001: right=transverse.normalized()
	var basis=Basis(right,up,right.cross(up))
	equipment.basis=basis*float(combat.sword_scale)
	var grip=BetaSwordMotion.GRIP if equipment.get_meta("beta_sword",false) else .16
	equipment.position=pose.grip-basis*Vector3(0,grip*float(combat.sword_scale),0)
	if first_person_driver!=null: first_person_sword.apply(self,"draw" if draw_action else key,f if draw_action else t)

func sword_right(up:Vector3,key:String,t:float) -> Vector3:
	var rotation=dodge_transform(key,t).basis if key in ["roll","stand"] else Basis.IDENTITY
	var local_up=rotation.inverse()*up
	var weight=smoothstep(.02,.16,t) if key=="roll" else 1-smoothstep(.72,1,t) if key=="stand" else 0.0
	var hint=Vector3.RIGHT.lerp(Vector3.DOWN,weight)
	var right=hint-local_up*hint.dot(local_up)
	if right.length_squared()<.00001:
		right=Vector3.UP-local_up*local_up.y
	return rotation*right.normalized()

func spin_rotation(phase:float) -> float:
	return TAU*smoothstep(.05,.36,phase)

func blade_segment() -> Array:
	var base=BetaSwordMotion.BLADE_BASE if equipment.get_meta("beta_sword",false) else -.05
	return [equipment.global_transform*Vector3(0,base,0),sword_tip()]

func blade_hits(enemy:Node3D) -> bool:
	var current=blade_segment()
	var previous=current if blade_sweep_previous.is_empty() else blade_sweep_previous
	var radius=float(enemy.definition.get("combat_radius",{"small":.25,"medium":.50,"large":.72,"giant":1.05}.get(enemy.size_class,.5)))
	var height=float(enemy.definition.get("combat_height",3.1 if enemy.definition.kind=="warden" else 1.0))
	var bottom=enemy.global_position+Vector3(0,minf(radius,height*.5),0)
	var top=enemy.global_position+Vector3(0,maxf(radius,height-radius),0)
	# Interpolate the previous/current steel rails, including movement and spin.
	for index in range(9):
		var fraction=index/8.0
		var base:Vector3=previous[0].lerp(current[0],fraction)
		var tip:Vector3=previous[1].lerp(current[1],fraction)
		var nearest=Geometry3D.get_closest_points_between_segments(base,tip,bottom,top)
		var steel_margin=BetaSwordMotion.WIDTH*.5 if equipment.get_meta("beta_sword",false) else .12
		if nearest[0].distance_to(nearest[1])<=radius+steel_margin: return true
	return false

func sword_tip() -> Vector3:
	var tip=BetaSwordMotion.TIP if equipment.get_meta("beta_sword",false) else -1.17
	return equipment.global_transform*Vector3(0,tip,0)

func _scrape(delta: float, moving: bool) -> void:
	for particle in scrape_nodes:
		particle.life-=delta
		particle.node.visible=particle.life>0
	if not moving:
		return
	if equipment.get_meta("beta_sword",false) and sword_tip().y-global_position.y>.10: return
	scrape_time-=delta
	if scrape_time>0:
		return
	scrape_time=.08
	if scrape_nodes.size()<12:
		var particle=MeshInstance3D.new()
		var mesh=BoxMesh.new()
		mesh.size=Vector3(.065,.035,.12)
		particle.mesh=mesh
		var material=StandardMaterial3D.new()
		material.albedo_color=Color("#d4c19a")
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		particle.material_override=material
		add_child(particle)
		particle.top_level=true
		scrape_nodes.append({"node":particle,"life":0.0})
	var item=scrape_nodes[scrape_cursor%scrape_nodes.size()]
	scrape_cursor+=1
	item.node.global_position=sword_tip()+Vector3(0,.035,0)
	item.node.rotation.y=visual.rotation.y
	item.life=.55

func movement_vector(axis:Vector2) -> Vector3:
	var direction=Vector3(axis.x,0,axis.y)
	return direction.rotated(Vector3.UP,movement_camera_yaw) if camera_relative else direction

func _physics_process(delta: float) -> void:
	if not controllable:
		animator.advance(delta)
		return
	invulnerability=maxf(0,invulnerability-delta)
	visual.visible=not has_meta("beta_hero") and (first_person_driver!=null or not has_meta("standalone_static")) and (first_person_driver!=null or invulnerability<=0 or fmod(invulnerability,.16)<.1)
	parry_flash=maxf(0,parry_flash-delta)
	sprinting=false
	if not input_enabled:
		shift_pending=false
		velocity=Vector3.ZERO
		return
	counter_remaining=maxf(0,counter_remaining-delta)
	measured_remaining=maxf(0,measured_remaining-delta)
	if state!="light": counter_active=false
	if magic_gear!=null: magic_gear.tick(delta)
	presentation_clock+=delta
	if dash_release_queued: release_dash()
	for key in slow_sources.keys():
		slow_sources[key].remaining-=delta
		if slow_sources[key].remaining<=0: slow_sources.erase(key)
	if shift_pending: shift_clock+=delta
	combo_remaining=maxf(0,combo_remaining-delta)
	var movement=Input.get_vector("move_left","move_right","move_up","move_down")
	if state=="free":
		sprinting=sprint_held() and movement.length_squared()>.01 and stamina>0 and not sprint_exhausted
		var denied_sprint=sprint_held() and movement.length_squared()>.01 and not sprinting
		if denied_sprint and not sprint_denial_latched: stamina_denied.emit()
		sprint_denial_latched=denied_sprint
		var resting_speed=float(combat.drawn_walk_speed) if sword_drawn else walk_speed
		var speed=float(combat.drawn_sprint_speed if sword_drawn else combat.sprint_speed) if sprinting else resting_speed
		if sprinting:
			var required=float(combat.drawn_sprint_drain if sword_drawn else combat.sprint_drain)*delta
			var ratio=minf(1,stamina/required)
			speed=lerpf(resting_speed,speed,ratio)
			spend_stamina(minf(required,stamina))
			if stamina<=.0001:
				sprint_exhausted=true
		var desired=movement_vector(movement)
		if desired.length_squared()>.01:
			movement_direction=desired if movement_direction.is_zero_approx() else movement_direction.lerp(desired,1-exp(-float(combat.turn_response)*delta)).normalized()
		else:
			movement_direction=Vector3.ZERO
		velocity=movement_direction*speed
		if sprinting and sword_drawn:
			rush_clock+=delta
			if rush_clock>=float(combat.rush_min_seconds):
				rush_credit=.2
		else:
			rush_clock=0
			rush_credit=maxf(0,rush_credit-delta)
		if movement.length_squared()>.01:
			visual.rotation.y=lerp_angle(visual.rotation.y,atan2(movement_direction.x,movement_direction.z),1-exp(-float(combat.turn_response)*delta))
			play_clip("drag_walk_loop" if sword_drawn else "walk_loop")
		elif current_clip!="interact" or not animator.is_playing():
			play_clip("drag_idle_loop" if sword_drawn else "idle_loop")
		animator.advance(delta*(1.65 if sprinting else 1.0))
		if sword_drawn:
			_pose_sword("drag",0)
	else:
		state_time=minf(state_duration,state_time+delta*(thrust_charge_rate if state=="charge" and thrust_charging else 1.0))
		var progress=attack_phase() if state in ["light","heavy","thrust"] else state_time/state_duration
		velocity=Vector3.ZERO
		if state in ["dash_charge","dash","jump"]:
			dash_attack_blend=move_toward(dash_attack_blend,1.0 if dash_attack_queued else 0.0,delta/DASH_ATTACK_BLEND)
			var desired=movement_vector(movement)
			if state=="dash": velocity=attack_direction*dash_distance/state_duration/.8*smoothstep(0,.1,progress)*(1-smoothstep(.7,1,progress))
			elif state=="jump": velocity=desired*(float(combat.drawn_walk_speed) if sword_drawn else walk_speed)
			animator.advance(delta)
			if sword_drawn: _pose_sword("drag",0)
			if state=="dash" and state_time>=state_duration:
				if dash_attack_queued: _exit_dash_attack()
				else: state="free";state_time=0;dash_attack_blend=0
		elif state in ["roll","stand"]:
			var clip=("dodge_roll" if state=="roll" else "stand_up")+("" if roll_restore_drawn else "_sheathed")
			var key="roll" if state=="roll" else "stand"
			animator.seek(progress*animator.get_animation(clips[clip]).length,true)
			blend_action_transition(delta)
			if sword_drawn: _pose_sword(key,progress)
			if state=="roll":
				velocity=attack_direction*float(combat.dodge.speed)*(1-smoothstep(.70,1,progress))
				if state_time>=state_duration:
					state="stand"
					state_time=0
					state_duration=float(combat.dodge.stand_seconds)
					play_clip("stand_up" if roll_restore_drawn else "stand_up_sheathed",0)
			elif roll_attack_queued and progress>=float(combat.dodge.attack_exit_phase):
				_exit_roll_light()
			elif state_time>=state_duration:
				set_sword_drawn(roll_restore_drawn)
				state_time=0
		elif state=="charge":
			var forward=Vector3(movement.x,0,movement.y).dot(attack_direction)
			var sprint_available=maxf(0,stamina-float(combat.thrust.stamina_cost)) if thrust_charging else stamina
			if sprint_held() and forward>.65 and sprint_available>0 and not sprint_exhausted:
				sprinting=true
				var sprint_cost=float(combat.drawn_sprint_drain)*delta
				velocity=attack_direction*float(combat.drawn_sprint_speed)*minf(1,sprint_available/sprint_cost)
				spend_stamina(minf(sprint_available,sprint_cost))
				rush_clock+=delta
				charge_rush=charge_rush or rush_clock>=float(combat.rush_min_seconds)
				if stamina<=.0001:
					sprint_exhausted=true
			if thrust_charging:
				# Retain the launch cost; exhaustion releases the charged move once.
				var reserve=float(combat.thrust.stamina_cost)
				var drain=minf(maxf(0,stamina-reserve),float(combat.thrust_charge.stamina_per_second)*delta)
				spend_stamina(drain)
				var phase=thrust_prepare_phase()
				play_clip("attack_thrust",0)
				animator.seek(phase*animator.get_animation(clips.attack_thrust).length,true)
				blend_action_transition(delta)
				_pose_sword("thrust",phase)
				if (stamina<=reserve+.0001 and state_time>=float(combat.heavy_hold_seconds)) or state_time>=state_duration:
					release_charge("heavy")
			else:
				play_clip("drag_walk_loop" if sprinting else "drag_idle_loop")
				animator.advance(delta*(1.65 if sprinting else 1.0))
				blend_action_transition(delta)
				_pose_sword("drag",0)
			if charge_rush and heavy_style!="charge_thrust":
				var anticipation=minf(.3,state_time/float(combat.heavy_hold_seconds)*.3)
				play_clip("attack_heavy",0)
				animator.seek(anticipation*animator.get_animation(clips.attack_heavy).length,true)
				_pose_sword("heavy",anticipation)
		elif state=="water":
			animator.seek(progress*animator.get_animation(clips.attack_water).length,true)
			blend_action_transition(delta)
			_pose_sword("water",progress)
			velocity=attack_direction*(2.5*smoothstep(.20,.42,progress)*(1-smoothstep(.62,.85,progress)))
			if not water_released and progress>=float(combat.water.release_phase):
				water_released=true
				var toward=attack_direction
				if first_person_driver!=null:
					var aim=-first_person_driver.sample_first_person(0,false).basis.z
					toward=Vector3(aim.x,0,aim.z).normalized()
				water_cast.emit(position,toward)
		elif state in ["dragon_channel","dragon_recover"]:
			play_clip("drag_idle_loop",0)
			animator.seek(0,true)
			dragon_pose.weapon(self)
			dragon_pose.apply_rig(skeleton,self,false)
		elif state=="lance_charge":
			update_sword_energy(progress)
			var lance_phase=progress*LANCE_HOLD_PHASE
			animator.seek(lance_phase*animator.get_animation(clips.attack_lance).length,true)
			blend_action_transition(delta)
			_pose_sword("lance",lance_phase)
			if is_instance_valid(lance_charge_fx):
				lance_charge_fx.set_progress(progress)
			if state_time>=state_duration:
				clear_lance_charge()
				state="lance_fire"
				state_time=0
				state_duration=float(combat.lance.recovery_seconds)
				animator.seek(animator.get_animation(clips.attack_lance).length*LANCE_HOLD_PHASE,true)
				_pose_sword("lance",LANCE_HOLD_PHASE)
				var toward=(sword_tip()-equipment.global_transform*Vector3(0,BetaSwordMotion.GRIP if equipment.get_meta("beta_sword",false) else .16,0)).normalized() if first_person_driver!=null else attack_direction
				lance_fired.emit(sword_tip(),toward)
		elif state=="stagger":
			# Recoil lowers the blade back along its already-cleared side path.
			var phase=stagger_start_phase*(1-smoothstep(0,1,progress))
			var clip="attack_"+stagger_motion
			play_clip(clip,0)
			animator.seek(animator.get_animation(clips[clip]).length*phase,true)
			blend_action_transition(delta)
			_pose_sword(stagger_motion,phase)
		elif state=="lance_fire":
			var lance_phase=lerpf(LANCE_HOLD_PHASE,1,progress)
			animator.seek(animator.get_animation(clips.attack_lance).length*lance_phase,true)
			_pose_sword("lance",lance_phase)
		elif state=="parry":
			var guard_phase=parry_pose_phase(progress)
			animator.seek(guard_phase*animator.get_animation(clips.parry_guard).length,true)
			blend_action_transition(delta)
			_pose_sword("parry",guard_phase)
		elif state in ["light","heavy","thrust"]:
			if dash_uppercut and state=="light" and combo_stage==1:
				var lift=smoothstep(.28,.74,progress)
				var body_phase=lerpf(.68,.42,lift) if progress<=.74 else lerpf(.42,0,smoothstep(.74,1,progress))
				animator.seek(body_phase*animator.get_animation(clips.attack_heavy).length,true)
			else: animator.seek(progress*animator.get_animation(clips[current_clip]).length,true)
			blend_action_transition(delta)
			if state=="light" and combo_stage==3:
				visual.rotation.y=attack_yaw+spin_rotation(progress)
			_pose_sword("light"+str(combo_stage) if state=="light" and combo_stage>1 else state,progress)
			var tuning=attack_tuning()
			var force=smoothstep(float(tuning.active_start)-.10,float(tuning.active_start)+.03,progress)*(1-smoothstep(float(tuning.active_end),.91,progress))
			if state=="light" and combo_stage==1:
				force=smoothstep(.34,.47,progress)*(1-smoothstep(.59,.72,progress))+.42*smoothstep(.56,.66,progress)*(1-smoothstep(.78,.92,progress))
			if state=="light" and combo_stage==3:
				force=smoothstep(.04,.12,progress)*(1-smoothstep(.32,.40,progress))
			if state=="thrust":
				force=smoothstep(.14,.26,progress)*(1-smoothstep(.58,.94,progress))
			velocity=attack_direction*(thrust_travel_speed() if state=="thrust" else maxf(float(tuning.momentum)*force,chain_speed*exp(-6*state_time)))
			if counter_active: velocity+=counter_step*3.6*smoothstep(.02,.10,progress)*(1-smoothstep(.32,.44,progress))
			if state=="light" and combo_stage==3:
				var forward=maxf(0,movement_vector(movement).dot(attack_direction))
				velocity+=attack_direction*float(combat.drawn_walk_speed)*forward*force
			if chain_blend>0:
				chain_blend=maxf(0,chain_blend-delta)
				var blend=1-chain_blend/chain_blend_duration
				equipment.transform=chain_weapon.interpolate_with(equipment.transform,blend)
				for index in range(skeleton.get_bone_count()):
					var pose=chain_bones[index].interpolate_with(skeleton.get_bone_pose(index),blend)
					skeleton.set_bone_pose(index,pose)
			var spin_slam=state=="light" and combo_stage==3
			if spin_slam and progress>=.60 and not slam_contact_started:
				slam_contact_started=true
				hit_ids.clear()
				blade_sweep_previous.clear()
			if (state=="heavy" or spin_slam) and progress>=.68 and not slam_emitted:
				slam_emitted=true
				ground_slam.emit(sword_tip(),state=="heavy")
			var contact=progress>=float(tuning.active_start) and progress<=float(tuning.active_end)
			if spin_slam: contact=contact and (progress<=.36 or progress>=.60)
			if state=="thrust": contact=contact and state_time<thrust_windup_seconds+thrust_launch_seconds
			if state=="thrust" and not thrust_gust_emitted and state_time>=thrust_windup_seconds+thrust_launch_seconds:
				thrust_gust_emitted=true
				thrust_stopped.emit(position+attack_direction*.9,attack_direction)
			if contact:
				attack_contact.emit(state,attack_direction,hit_ids)
				blade_sweep_previous=blade_segment()
			else:
				blade_sweep_previous.clear()
			_dash_water_followthrough(progress)

		else:
			var sword_phase=sword_action_phase(progress,state=="sheathe") if state in ["draw","sheathe"] else progress
			animator.seek(sword_phase*animator.get_animation(clips[current_clip]).length,true)
			blend_action_transition(delta)
			_pose_sword("drag",sword_phase)
		if state=="light" and combo_queued and combo_stage<3 and progress>=float(combat.combo_link_phase):
			_link_combo()
		elif state_time>=state_duration and state not in ["charge","roll","stand","free","dash_charge","jump"]:
			var chain=state=="light"
			var queued=combo_queued
			set_sword_drawn(state!="sheathe")
			combo_remaining=float(combat.combo_window) if chain and combo_stage<3 else 0.0
			combo_queued=false
			if queued and chain:
				begin_attack("light")
	_recover_stamina(delta)
	velocity*=terrain_speed_scale()
	velocity+=knockback
	knockback=knockback.move_toward(Vector3.ZERO,delta*9)
	var previous_position=position
	if jump_active:
		jump_velocity-=18*delta
		velocity.y=jump_velocity
	if is_instance_valid(ground_world): ground_world.move_grounded(self,delta)
	else:
		move_and_slide()
		if not jump_active: position.y=0
		elif position.y<=0 and jump_velocity<=0: position.y=0;finish_jump()
	if has_node("BetaHero"):
		var travel=position-previous_position;travel.y=0
		get_node("BetaHero").gait.advance_distance(self,travel.length(),delta)
	_scrape(delta,first_person_driver==null and sword_drawn and state=="free" and velocity.length_squared()>.05)
	if is_instance_valid(thrust_wind_fx):
		thrust_wind_fx.update_wind(self,delta)

func terrain_speed_scale() -> float:
	var scale=1.0
	for source in slow_sources.values(): scale=minf(scale,float(source.factor))
	return lerpf(scale,1,clampf(magic_gear.bonus("slow_resist"),0,1)) if magic_gear!=null else scale

func counter_ready() -> bool:
	return counter_unlocked and counter_equipped and input_enabled and health>0 and sword_drawn and state in ["parry","free"] and counter_remaining>0 and counter_target!=null and is_instance_valid(counter_target.get_ref()) and counter_target.get_ref().health>0 and global_position.distance_to(counter_target.get_ref().global_position)<=4.5
func begin_counter() -> bool:
	if not counter_ready() or not can_afford(float(combat.combo[0].stamina_cost)): return false
	var toward=counter_target.get_ref().global_position-global_position;toward.y=0
	var incoming=equipment.transform;var bones=[]
	for index in range(skeleton.get_bone_count()): bones.append(skeleton.get_bone_pose(index))
	var old=state
	counter_remaining=0;state="free";combo_stage=1;combo_remaining=float(combat.combo_window)
	if not begin_attack("light"): state=old;return false
	counter_active=true;state_duration=.85
	chain_weapon=incoming;chain_bones=bones;chain_blend=.16;chain_blend_duration=.16
	action_transition_remaining=0;action_transition_bones.clear()
	counter_step=toward.normalized()*.9+toward.normalized().cross(Vector3.UP)*.8
	return true
