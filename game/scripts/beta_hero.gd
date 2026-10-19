extends Node3D
## Current personal heroine driven by the actor's established motion clocks.
var actor:Node3D
var rig:Skeleton3D
var rests:Array[Transform3D]=[]
var global_rests:Array[Transform3D]=[]
var source_rests:Array[Transform3D]=[]
var sword:Node3D
var harness:Node3D
var gear_parts:Array=[]
var previous_state=""
var source_weapon_id=0
var carry_transition:Array[Transform3D]=[]
var gait=preload("res://scripts/beta_gait.gd").new()
var hands=preload("res://scripts/beta_hands.gd").new()
var dragon_grips:Array=[]

static func apply(target:Node3D,enabled:bool,beta_weapon:bool=true) -> void:
	var weapon_changed=target.set_beta_sword(enabled and beta_weapon)
	var current=target.get_node_or_null("BetaHero")
	if current!=null and (weapon_changed or current.source_weapon_id!=target.equipment.get_instance_id()):
		target.remove_child(current); current.queue_free(); current=null
	if not enabled:
		target.remove_meta("beta_hero")
		if current!=null: target.remove_child(current); current.queue_free()
		return
	if current==null:
		current=load("res://scripts/beta_hero.gd").new(); current.name="BetaHero"; current.actor=target
		current.source_weapon_id=target.equipment.get_instance_id()
		var scene=load("res://assets/characters/heroine-beta.glb").instantiate()
		current.add_child(scene); target.add_child(current)
		current.rig=scene.find_children("*","Skeleton3D",true,false)[0]
		current.prepare_dragon_grip(scene)
		for i in range(current.rig.get_bone_count()): current.rests.append(current.rig.get_bone_rest(i))
		for i in range(current.rig.get_bone_count()):
			var rest=current.rests[i]; var parent=current.rig.get_bone_parent(i)
			current.global_rests.append(current.global_rests[parent]*rest if parent>=0 else rest)
		for mixer in scene.find_children("*","AnimationPlayer",true,false): mixer.active=false
		current.sword=target.equipment.duplicate(); current.add_child(current.sword)
		current.harness=target.back_harness.duplicate(); current.add_child(current.harness)
		for pair in [[target.equipment,current.sword],[target.back_harness,current.harness]]:
			current.cache_gear_parts(pair[0],pair[1])
	target.set_meta("beta_hero",true)
	current.source_rests.clear()
	for i in range(target.skeleton.get_bone_count()):
		var rest=target.skeleton.get_bone_rest(i); var parent=target.skeleton.get_bone_parent(i)
		current.source_rests.append(current.source_rests[parent]*rest if parent>=0 else rest)
	target.visual.visible=false
	if target.has_node("Shadow"): target.get_node("Shadow").visible=false
	current.synchronize()
	# Recreated presentation nodes (weapon/art changes) retain accepted cosmetics.
	if target.has_meta("appearance_profile"):
		preload("res://scripts/character_appearance.gd").apply(target,target.get_meta("appearance_profile"))

func cache_gear_parts(source:Node,copy:Node) -> void:
	# duplicate() preserves child order but renames automatically named nodes.
	for i in range(source.get_child_count()):
		var source_child=source.get_child(i); var copy_child=copy.get_child(i)
		if source_child is Node3D: gear_parts.append([source_child,copy_child])
		cache_gear_parts(source_child,copy_child)

func synchronize(delta:float=0.0) -> void:
	if actor.state in ["draw","sheathe"] and previous_state!=actor.state:
		carry_transition.clear()
		for i in range(rig.get_bone_count()):carry_transition.append(rig.get_bone_pose(i))
	previous_state=actor.state
	actor.skeleton.force_update_all_bone_transforms()
	actor.visual.visible=false
	visible=actor.first_person_driver!=null or actor.invulnerability<=0 or fmod(actor.invulnerability,.16)<.1
	rotation.y=actor.visual.rotation.y
	var desired_globals:Array[Basis]=[]
	for index in range(rig.get_bone_count()):
		var original=actor.skeleton.find_bone(rig.get_bone_name(index))
		if original<0:
			desired_globals.append(global_rests[index].basis)
			continue
		var movement=actor.skeleton.get_bone_pose_position(original)-actor.skeleton.get_bone_rest(original).origin
		rig.set_bone_pose_position(index,rests[index].origin+movement*.92)
		var relative=actor.skeleton.get_bone_global_pose(original).basis*source_rests[original].basis.inverse()
		if rig.get_bone_name(index)=="hair_sway":
			var head=actor.skeleton.find_bone("head")
			relative=actor.skeleton.get_bone_global_pose(head).basis*source_rests[head].basis.inverse()
		var desired=relative*global_rests[index].basis
		desired_globals.append(desired)
		var parent=rig.get_bone_parent(index)
		if parent>=0: desired=desired_globals[parent].inverse()*desired
		rig.set_bone_pose_rotation(index,desired.get_rotation_quaternion())
		rig.set_bone_pose_scale(index,actor.skeleton.get_bone_pose_scale(original))
	sword.transform=global_transform.affine_inverse()*actor.equipment.global_transform
	sword.visible=actor.sword_equipped
	harness.transform=global_transform.affine_inverse()*actor.back_harness.global_transform
	harness.visible=actor.sword_equipped
	# Actor owns transforms and materials, including draw holders and steel/glow swaps.
	for pair in gear_parts:
		pair[1].transform=pair[0].transform; pair[1].visible=pair[0].visible
		if pair[0] is MeshInstance3D:
			pair[1].material_override=pair[0].material_override
			for surface in range(pair[0].mesh.get_surface_count()):
				pair[1].set_surface_override_material(surface,pair[0].get_surface_override_material(surface))
	rig.force_update_all_bone_transforms()
	gait.apply(self,delta if actor.input_enabled else 0.0)
	if actor.state in ["draw","sheathe"] and not carry_transition.is_empty():
		var clock=actor.state_time
		if not actor.is_physics_processing() and not actor.get_meta("canonical_manual_step",false) and actor.current_clip in ["draw_sword","sheathe_sword"]:
			var length=actor.animator.get_animation(actor.clips[actor.current_clip]).length
			clock=actor.animator.current_animation_position/length*float(actor.combat.draw_seconds if actor.state=="draw" else actor.combat.sheathe_seconds)
		var weight=smoothstep(0,.12,clock)
		for i in range(rig.get_bone_count()):rig.set_bone_pose(i,carry_transition[i].interpolate_with(rig.get_bone_pose(i),weight))
		rig.force_update_all_bone_transforms()
	hands.apply(self)
	if actor.state in ["dragon_channel","dragon_recover"]: actor.dragon_pose.apply_rig(rig,actor,true)
	var grip_weight=smoothstep(0,1,actor.dragon_pose.phase(actor)) if actor.state in ["dragon_channel","dragon_recover"] else 0.0
	for item in dragon_grips:
		item[0].mesh=item[2] if grip_weight>0 else item[1]
		if grip_weight>0: item[0].set_blend_shape_value(0,grip_weight)
	actor.sync_beta_back_carry(self)
	sword.transform=global_transform.affine_inverse()*actor.equipment.global_transform
	harness.transform=global_transform.affine_inverse()*actor.back_harness.global_transform

	if actor.weapon_runtime!=null and actor.weapon_runtime.enabled():
		sword.visible=false;harness.visible=false
		actor.weapon_runtime.apply_rig(rig,true)

func carry_delta() -> Transform3D:
	var spine=rig.find_bone("spine")
	return rig.global_transform*rig.get_bone_global_pose(spine)*global_rests[spine].affine_inverse()*rig.global_transform.affine_inverse()

func prepare_dragon_grip(scene:Node) -> void:
	# A local morph closes only the supporting hand; saved meshes and other actions stay intact.
	var fitter=preload("res://scripts/first_person_visuals.gd").new()
	for part in scene.find_children("*","MeshInstance3D",true,false):
		if part.skin==null or not part.mesh is ArrayMesh or part.mesh.get_blend_shape_count()>0: continue
		var source=part.mesh;var closed=fitter.grip_mesh(source,part.skin,rig,"R",false);var morph=ArrayMesh.new()
		morph.blend_shape_mode=Mesh.BLEND_SHAPE_MODE_NORMALIZED
		morph.add_blend_shape("dragon_grip")
		for surface in range(source.get_surface_count()):
			var shape=[];shape.resize(Mesh.ARRAY_MAX);var target=closed.surface_get_arrays(surface)
			for field in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT]: shape[field]=target[field]
			morph.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,source.surface_get_arrays(surface),[shape])
			morph.surface_set_material(surface,source.surface_get_material(surface))
		dragon_grips.append([part,source,morph])

func _process(delta:float) -> void:
	if is_instance_valid(actor): synchronize(delta)
