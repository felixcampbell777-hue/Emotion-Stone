extends RefCounted
## Separate camera layers keep the player's head out of view and retain her arms.
const BODY_LAYER=1<<19
const ARMS_LAYER=1<<18
var rig_id=0
var root:Node3D
var rig:Skeleton3D
var source_rig:Skeleton3D
var rig_basis=Basis.IDENTITY
var bind_eye=Vector3.ZERO
var hand_targets:Dictionary={}
var resting:Array[Transform3D]=[]
var global_rests:Array[Transform3D]=[]
var palms:Dictionary={}
var personal_skin=false
var unarmed=preload("res://scripts/unarmed_hands.gd").new()
const PALM=Vector3(-.017,-.30,.012)

func prepare(actor:Node3D) -> void:
	# The static review body stays hidden; its existing gameplay rig supplies
	# the active first-person arms and steel without animating the fixed model.
	if actor.has_meta("standalone_static"): actor.visual.visible=true
	var skeleton:Skeleton3D=actor.get_node("BetaHero").rig if actor.has_node("BetaHero") else actor.skeleton
	var identity=skeleton.get_instance_id()
	if identity==rig_id: return
	rig_id=identity
	if is_instance_valid(root): root.free()
	source_rig=skeleton
	personal_skin=actor.has_node("BetaHero")
	root=Node3D.new();root.name="FirstPersonHands";actor.add_child(root)
	rig=Skeleton3D.new();rig.name="ViewRig";root.add_child(rig)
	resting.clear();global_rests.clear()
	for index in range(skeleton.get_bone_count()):
		rig.add_bone(skeleton.get_bone_name(index));rig.set_bone_rest(index,skeleton.get_bone_rest(index))
		rig.set_bone_parent(index,skeleton.get_bone_parent(index));resting.append(skeleton.get_bone_rest(index))
		global_rests.append(skeleton.get_bone_global_rest(index))
	var relative=Basis(Vector3.UP,actor.visual.global_rotation.y).inverse()*skeleton.global_basis
	rig_basis=relative
	var eye=1.52 if actor.has_node("BetaHero") else 1.65
	bind_eye=skeleton.global_transform.affine_inverse()*(actor.global_position+Vector3(0,eye,0))
	for side in ["L","R"]:
		var palm=PALM;palm.x*=1 if side=="R" else -1
		if not actor.has_node("BetaHero"): palm=skeleton.get_bone_global_rest(bone("forearm",side)).affine_inverse()*Vector3(-.385 if side=="R" else .385,.88,.015)
		palms[side]=palm
	for old in actor.find_children("*","MeshInstance3D",true,false):
		if old.has_meta("first_person_arms"): old.free()
	for source in actor.find_children("*","GeometryInstance3D",true,false):
		if root.is_ancestor_of(source): continue
		if actor.equipment.is_ancestor_of(source) or source==actor.equipment: continue
		if actor.has_node("BetaHero") and actor.get_node("BetaHero").sword.is_ancestor_of(source): continue
		source.layers=BODY_LAYER
		if not source is MeshInstance3D or source.skin==null or source.mesh==null: continue
		var source_rig=source.get_node_or_null(source.skeleton)
		if source_rig!=skeleton: continue
		var label=String(source.name).to_lower()
		if ["hair","crown","eyebrow","eyelash","teeth","tongue","high-poly"].any(func(word): return word in label): continue
		var filtered=arms_mesh(source,skeleton)
		if filtered.get_surface_count()>0:
			var arms=source.duplicate(); arms.name=String(source.name)+"FirstPersonArms"
			arms.mesh=filtered; arms.layers=ARMS_LAYER; arms.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			arms.set_meta("relaxed_mesh",filtered)
			arms.set_meta("gripped_mesh",grip_mesh(filtered,source.skin,skeleton) if actor.has_node("BetaHero") else filtered)
			arms.set_meta("first_person_arms",true);rig.add_child(arms)
			arms.transform=skeleton.global_transform.affine_inverse()*source.global_transform
			arms.skeleton=NodePath("..");arms.visible=true

func update(actor:Node3D,frame:Transform3D) -> void:
	if not is_instance_valid(root) or not is_instance_valid(source_rig): prepare(actor)
	var holding=actor.sword_equipped and actor.sword_drawn
	var draw=actor.state in ["draw","sheathe"]
	var arm_frame=frame
	var basis=arm_frame.basis*Basis(Vector3.UP,PI)*rig_basis
	root.global_transform=Transform3D(basis,arm_frame.origin-basis*bind_eye-arm_frame.basis.z*.18)
	for index in range(rig.get_bone_count()):
		# The view arms get their own stable shoulders, preserving the real skin.
		rig.set_bone_pose(index,source_rig.get_bone_pose(index) if not holding and not draw else resting[index])
	rig.force_update_all_bone_transforms()
	var clock=float(actor.presentation_clock)
	var sway=Vector3(sin(clock*7)*.009,sin(clock*14)*.008,0) if actor.velocity.length_squared()>.05 else Vector3(0,sin(clock*2)*.004,0)
	var right=frame*(Vector3(.24,-.14,-.50)+sway)
	var left=frame*(Vector3(-.24,-.16,-.48)-sway)
	if not holding and not draw:
		var relaxed=unarmed.targets(actor,arm_frame);right=relaxed.R;left=relaxed.L
	var phase=float(actor.animator.current_animation_position)/actor.animator.get_animation(actor.clips[actor.current_clip]).length if draw else 1.0
	if draw and actor.state=="sheathe": phase=1-phase
	var grip=.065 if actor.equipment.get_meta("beta_sword",false) else .16
	if holding or (draw and phase>.10):
		var right_grip=actor.equipment.global_transform*Vector3(0,grip,0)
		right=right.lerp(right_grip,smoothstep(.08,.44,phase)) if draw else right_grip
		var two_hand=actor.state not in ["water","draw","sheathe","roll","stand"]
		var action_phase=actor.state_time/actor.state_duration if actor.state!="free" and actor.state_duration>0 else 1.0
		var left_weight=1.0 if two_hand else 0.0
		if actor.state=="water": left_weight=maxf(1-smoothstep(0,.14,action_phase),smoothstep(.80,1,action_phase))
		if draw: left_weight=smoothstep(.35,.75,phase)
		var left_grip=actor.equipment.global_transform*Vector3(0,.20 if actor.equipment.get_meta("beta_sword",false) else .08,0)
		left=left.lerp(left_grip,left_weight)
		if actor.state=="parry":
			var brace=smoothstep(.10,.30,actor.state_time/actor.state_duration)*(1-smoothstep(.65,.90,actor.state_time/actor.state_duration))
			left=left.lerp(actor.equipment.global_transform*Vector3(0,-.24,.03),brace)
	fit("R",right,actor.equipment.global_basis.y if holding else Vector3.ZERO)
	fit("L",left,-actor.equipment.global_basis.y if holding else Vector3.ZERO)
	for mesh in rig.get_children():
		if mesh is MeshInstance3D: mesh.mesh=mesh.get_meta("gripped_mesh" if holding else "relaxed_mesh")
	hand_targets={"R":right,"L":left}
	# During the remote-to-body return, reaching for the planted hilt would put
	# the separate view arms through the camera. Restore them once standing.
	root.visible=actor.first_person_driver!=null and actor.state!="dragon_recover" and (holding or actor.state not in ["roll","stand"])

func bone(key:String,side:String) -> int:
	var index=rig.find_bone(key+"_"+side)
	return index if index>=0 else rig.find_bone(key+"."+side)

func set_basis(index:int,basis:Basis) -> void:
	var parent=rig.get_bone_parent(index)
	if parent>=0: basis=rig.get_bone_global_pose(parent).basis.inverse()*basis
	rig.set_bone_pose_rotation(index,basis.get_rotation_quaternion());rig.force_update_all_bone_transforms()

func fit(side:String,world_target:Vector3,world_axis:Vector3=Vector3.ZERO) -> void:
	var upper=bone("upper_arm",side);var lower=bone("forearm",side)
	var shoulder=rig.get_bone_global_pose(upper).origin
	var target=rig.global_transform.affine_inverse()*world_target
	var palm:Vector3=palms[side]
	if not world_axis.is_zero_approx():
		# Imported palms lie in local Y/Z; X points through the palm.
		if personal_skin:
			palm.x+=.026 if side=="R" else -.026
			palm.y-=.012;palm.z+=.012
		else: palm.z-=.026
	var a=global_rests[upper].origin.distance_to(global_rests[lower].origin);var b=palm.length()
	var direction=(target-shoulder).normalized();var distance=clampf(shoulder.distance_to(target),.02,a+b-.001)
	var along=(a*a-b*b+distance*distance)/(2*distance)
	var pole=Vector3(-.65 if side=="R" else .65,-.7,.2)
	pole-=direction*pole.dot(direction)
	if pole.length_squared()<.00001: pole=Vector3.DOWN
	var elbow=shoulder+direction*along+pole.normalized()*sqrt(maxf(0,a*a-along*along))
	var old=rig.get_bone_global_pose(lower).origin-shoulder
	set_basis(upper,Basis(Quaternion(old.normalized(),(elbow-shoulder).normalized()))*rig.get_bone_global_pose(upper).basis)
	var pose=rig.get_bone_global_pose(lower)
	set_basis(lower,Basis(Quaternion((pose.basis*palm).normalized(),(shoulder+direction*distance-elbow).normalized()))*pose.basis)
	if not world_axis.is_zero_approx():
		pose=rig.get_bone_global_pose(lower)
		var along_palm=(pose.basis*palm).normalized()
		var goal=(rig.global_basis.inverse()*world_axis).normalized()
		goal-=along_palm*goal.dot(along_palm)
		var across=pose.basis.z if personal_skin else pose.basis.x
		var current=across-along_palm*across.dot(along_palm)
		if goal.length_squared()>.00001 and current.length_squared()>.00001:
			set_basis(lower,Basis(along_palm,current.normalized().signed_angle_to(goal.normalized(),along_palm))*pose.basis)

func grip_mesh(source:ArrayMesh,skin:Skin,skeleton:Skeleton3D,only_side:String="",rebuild_normals:bool=true) -> ArrayMesh:
	var result=ArrayMesh.new()
	for surface in range(source.get_surface_count()):
		var arrays=source.surface_get_arrays(surface)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
		var influences=bones.size()/vertices.size()
		for index in range(vertices.size()):
			for influence in range(influences):
				var bind=bones[index*influences+influence]
				var bone_index=skin.get_bind_bone(bind)
				var name=String(skeleton.get_bone_name(bone_index)) if bone_index>=0 else String(skin.get_bind_name(bind))
				if not name.begins_with("forearm") or weights[index*influences+influence]<.85: continue
				if not only_side.is_empty() and not name.ends_with(only_side): continue
				var local=skin.get_bind_pose(bind)*vertices[index]
				var original=local
				var side=1.0 if name.ends_with("R") else -1.0
				# Preserve the four fingers' spread along Z, folding each finger
				# into the palm along X/Y rather than collapsing their separation.
				var extension=clampf(-local.y-.315,0,.12)
				if extension>0:
					var angle=minf(3.25,extension/.025)
					local.y=-.315-.025*sin(angle)
					local.x+=side*.025*(1-cos(angle))
				if original.y<-.245:
					var thumb=smoothstep(.025,.085,original.z)*smoothstep(-.018,.012,side*original.x)
					local=local.lerp(Vector3(side*.028,-.305,.028+original.z*.25),thumb)
				vertices[index]=skin.get_bind_pose(bind).affine_inverse()*local
				break
		arrays[Mesh.ARRAY_VERTEX]=vertices
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		result.surface_set_material(result.get_surface_count()-1,source.surface_get_material(surface))
	if not rebuild_normals: return result
	var shaded=ArrayMesh.new()
	for surface in range(result.get_surface_count()):
		var builder=SurfaceTool.new();builder.create_from(result,surface)
		builder.generate_normals();builder.generate_tangents();builder.commit(shaded)
		shaded.surface_set_material(shaded.get_surface_count()-1,result.surface_get_material(surface))
	return shaded

func arms_mesh(source:MeshInstance3D,rig:Skeleton3D) -> ArrayMesh:
	var mesh=ArrayMesh.new()
	for surface in range(source.mesh.get_surface_count()):
		var arrays=source.mesh.surface_get_arrays(surface)
		if arrays.is_empty() or arrays[Mesh.ARRAY_BONES]==null or arrays[Mesh.ARRAY_INDEX]==null: continue
		var vertices=arrays[Mesh.ARRAY_VERTEX]; var bones=arrays[Mesh.ARRAY_BONES]; var weights=arrays[Mesh.ARRAY_WEIGHTS]
		var influences=bones.size()/vertices.size(); var selected=PackedByteArray(); selected.resize(vertices.size())
		for v in range(vertices.size()):
			var arm_weight=0.0
			for i in range(influences):
				var bone_index=source.skin.get_bind_bone(bones[v*influences+i])
				var name=String(rig.get_bone_name(bone_index)) if bone_index>=0 else String(source.skin.get_bind_name(bones[v*influences+i]))
				if name.begins_with("upper_arm") or name.begins_with("forearm"): arm_weight+=weights[v*influences+i]
			selected[v]=1 if arm_weight>.55 else 0
		var indices=PackedInt32Array(); var original=arrays[Mesh.ARRAY_INDEX]
		for t in range(0,original.size(),3):
			if selected[original[t]] and selected[original[t+1]] and selected[original[t+2]]:
				indices.append_array(PackedInt32Array([original[t],original[t+1],original[t+2]]))
		if indices.is_empty(): continue
		arrays[Mesh.ARRAY_INDEX]=indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var material=source.get_surface_override_material(surface)
		mesh.surface_set_material(mesh.get_surface_count()-1,material if material!=null else source.mesh.surface_get_material(surface))
	return mesh
