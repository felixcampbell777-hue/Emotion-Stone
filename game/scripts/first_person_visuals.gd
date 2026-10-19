extends RefCounted
## Separate camera layers keep the player's head out of view and retain her arms.
const BODY_LAYER=1<<19
const ARMS_LAYER=1<<18
var rig_id=0
var appearance_revision=""
var weapon_grip=false
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
var wrist_solve_pole=Vector3.ZERO
var view_frame=Transform3D.IDENTITY
var grip_frames={}
var grip_motion=preload("res://scripts/first_person_sword.gd").new()
var grip_sample={"key":"drag","phase":0.0}
const PALM=Vector3(-.017,-.30,.012)

func prepare(actor:Node3D) -> void:
	# The static review body stays hidden; its existing gameplay rig supplies
	# the active first-person arms and steel without animating the fixed model.
	if actor.has_meta("standalone_static"): actor.visual.visible=true
	var skeleton:Skeleton3D=actor.get_node("BetaHero").rig if actor.has_node("BetaHero") else actor.skeleton
	var identity=skeleton.get_instance_id()
	var revision=String(actor.get_meta("appearance_revision",""))
	if identity==rig_id and revision==appearance_revision and resting.size()==skeleton.get_bone_count(): return
	rig_id=identity
	appearance_revision=revision
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
	if personal_skin:
		for side in ["L","R"]:
			if rig.find_bone("view_hand."+side)>=0:continue
			var wrist=rig.get_bone_count();rig.add_bone("view_hand."+side);rig.set_bone_parent(wrist,bone("forearm",side));rig.set_bone_rest(wrist,Transform3D(Basis.IDENTITY,Vector3(0,-.26,0)))
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
		var runtime=actor.get("weapon_runtime")
		if runtime!=null and is_instance_valid(runtime.model) and (source==runtime.model or runtime.model.is_ancestor_of(source)):continue
		if actor.has_node("BetaHero") and actor.get_node("BetaHero").sword.is_ancestor_of(source): continue
		source.layers=BODY_LAYER
		if not source is MeshInstance3D or source.skin==null or source.mesh==null: continue
		var source_rig=source.get_node_or_null(source.skeleton)
		if source_rig!=skeleton: continue
		var label=String(source.name).to_lower()
		if ["hair","crown","eyebrow","eyelash","teeth","tongue","high-poly","denim"].any(func(word): return word in label): continue
		# Body wrists preserve the immutable pre-grip surface/skin. Extract the
		# accepted first-person arms from those originals, never a gripped mesh.
		var extraction=source
		if source.has_meta("body_grip_original_mesh"):
			extraction=source.duplicate()
			extraction.mesh=source.get_meta("body_grip_original_mesh") if source.mesh==source.get_meta("body_grip_mesh") or source.mesh.get_blend_shape_count()>0 else source.mesh
			extraction.skin=source.get_meta("body_grip_original_skin")
		var filtered=arms_mesh(extraction,skeleton)
		if filtered.get_surface_count()>0:
			var arms=source.duplicate(); arms.name=String(source.name)+"FirstPersonArms"
			var view_skin=wrist_skin(extraction.skin) if personal_skin else extraction.skin
			arms.mesh=grip_blends(filtered,extraction.skin,skeleton,view_skin) if personal_skin else filtered; arms.skin=view_skin; arms.layers=ARMS_LAYER; arms.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			arms.set_meta("first_person_arms",true);rig.add_child(arms)
			arms.transform=skeleton.global_transform.affine_inverse()*source.global_transform
			arms.skeleton=NodePath("..");arms.visible=true
		if extraction!=source:extraction.free()
	if actor.has_meta("appearance_profile"):
		load("res://scripts/character_appearance.gd").apply(actor,actor.get_meta("appearance_profile"))

func update(actor:Node3D,frame:Transform3D) -> void:
	if not is_instance_valid(root) or not is_instance_valid(source_rig) or appearance_revision!=String(actor.get_meta("appearance_revision","")) or resting.size()!=source_rig.get_bone_count(): prepare(actor)
	view_frame=frame
	grip_sample=actor.get_meta("view_sword_sample",{"key":"drag","phase":0.0})
	if actor.get("weapon_runtime")!=null and actor.weapon_runtime.enabled():grip_sample={"key":"weapon","phase":0.0}
	var holding=actor.sword_equipped and actor.sword_drawn
	var draw=actor.state in ["draw","sheathe"]
	var arm_frame=frame
	var basis=arm_frame.basis*Basis(Vector3.UP,PI)*rig_basis
	# Lower the view-only shoulder anchor so a cross-body grip does not bring
	# the extracted proximal arm edge into the bottom of the first-person frame.
	root.global_transform=Transform3D(basis,arm_frame.origin-basis*bind_eye-arm_frame.basis.z*.18-arm_frame.basis.y*(.06*support_elbow_weight()))
	for index in range(source_rig.get_bone_count()):
		# The view arms get their own stable shoulders, preserving the real skin.
		rig.set_bone_pose(index,source_rig.get_bone_pose(index) if not holding and not draw else resting[index])
	for side in ["L","R"]:
		var wrist=rig.find_bone("view_hand."+side)
		if wrist>=0:rig.set_bone_pose(wrist,rig.get_bone_rest(wrist))
	rig.force_update_all_bone_transforms()
	var clock=float(actor.presentation_clock)
	var sway=Vector3(sin(clock*7)*.009,sin(clock*14)*.008,0) if actor.velocity.length_squared()>.05 else Vector3(0,sin(clock*2)*.004,0)
	var right=frame*(Vector3(.24,-.14,-.50)+sway)
	var left=frame*(Vector3(-.24,-.16,-.48)-sway)
	if not holding or draw:
		var relaxed=unarmed.targets(actor,arm_frame);right=relaxed.R;left=relaxed.L
	var phase=float(actor.animator.current_animation_position)/actor.animator.get_animation(actor.clips[actor.current_clip]).length if draw else 1.0
	if draw and actor.state=="sheathe": phase=1-phase
	var right_weight=smoothstep(.10,.40,phase) if draw else 1.0 if holding else 0.0
	var left_weight=0.0;var brace_weight=0.0
	var grip=.065 if actor.equipment.get_meta("beta_sword",false) else .16
	var runtime=actor.get("weapon_runtime")
	var weapon_targets:Dictionary=runtime.hand_targets() if runtime!=null and runtime.enabled() and (holding or draw) else {}
	weapon_grip=not weapon_targets.is_empty()
	if weapon_grip:
		right=weapon_targets.R;left=weapon_targets.L
		right_weight=float(weapon_targets.get("R_grasp",1.0));left_weight=float(weapon_targets.get("L_grasp",1.0))
	elif holding or draw:
		var right_grip=actor.equipment.global_transform*Vector3(0,grip,0)
		right=right.lerp(right_grip,smoothstep(.0,.35,phase)) if draw else right_grip
		var two_hand=actor.state not in ["water","draw","sheathe","roll","stand"]
		var action_phase=actor.state_time/actor.state_duration if actor.state!="free" and actor.state_duration>0 else 1.0
		left_weight=1.0 if two_hand else 0.0
		if actor.state=="water": left_weight=maxf(1-smoothstep(0,.14,action_phase),smoothstep(.80,1,action_phase))
		if draw: left_weight=smoothstep(.35,.75,phase)
		var left_grip=actor.equipment.global_transform*Vector3(0,.20 if actor.equipment.get_meta("beta_sword",false) else .08,0)
		left=left.lerp(left_grip,left_weight)
		if actor.state=="parry":
			var guard_phase=actor.parry_pose_phase(actor.state_time/actor.state_duration)
			var brace=smoothstep(.10,.30,guard_phase)*(1-smoothstep(.65,.90,guard_phase))
			brace_weight=brace
			left=left.lerp(actor.equipment.global_transform*Vector3(0,-.34,.045),brace)
			left_weight*=1-brace
	var right_axis=weapon_targets.R_axis if weapon_grip else -actor.equipment.global_basis.y if holding or draw else Vector3.ZERO
	fit("R",right,right_axis,right_weight,1.0 if weapon_grip else smoothstep(.10,.50,phase) if draw else 1.0)
	var left_axis=weapon_targets.L_axis if weapon_grip else (-actor.equipment.global_basis.y.normalized()).slerp(actor.equipment.global_basis.x.normalized(),brace_weight)
	if weapon_grip and left_weight<=.001:left_axis=Vector3.ZERO
	fit("L",left,left_axis if holding or draw else Vector3.ZERO,left_weight,1.0 if weapon_grip else smoothstep(.35,.75,phase) if draw else 1.0)
	for mesh in rig.get_children():
		if mesh is MeshInstance3D and mesh.mesh.get_blend_shape_count()==2:
			mesh.set_blend_shape_value(0,right_weight);mesh.set_blend_shape_value(1,left_weight)
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
	rig.set_bone_pose_rotation(index,basis.orthonormalized().get_rotation_quaternion());rig.force_update_all_bone_transforms()

func support_elbow_weight() -> float:
	var phase=float(grip_sample.phase)
	if String(grip_sample.key)=="light":return smoothstep(0,.12,phase)*(1-smoothstep(.74,1,phase))
	if String(grip_sample.key)=="light2":return 1-smoothstep(0,.20,phase)
	return 0.0

func fit(side:String,world_target:Vector3,world_axis:Vector3=Vector3.ZERO,grasp:float=1.0,twist:float=1.0) -> void:
	if personal_skin and not world_axis.is_zero_approx():
		fit_wrist(side,world_target,world_axis,grasp,twist);return
	var upper=bone("upper_arm",side);var lower=bone("forearm",side)
	var shoulder=rig.get_bone_global_pose(upper).origin
	var target=rig.global_transform.affine_inverse()*world_target
	var palm:Vector3=palms[side]
	if not world_axis.is_zero_approx():
		# Imported palms lie in local Y/Z; X points through the palm.
		if personal_skin:
			palm+=Vector3(.009 if side=="R" else -.009,-.018,.012)*grasp
		else: palm.z-=.026
	var a=global_rests[upper].origin.distance_to(global_rests[lower].origin);var b=palm.length()
	var direction=(target-shoulder).normalized();var distance=clampf(shoulder.distance_to(target),.02,a+b-.001)
	var along=(a*a-b*b+distance*distance)/(2*distance)
	var pole=Vector3(-.65 if side=="R" else .65,-.7,.2)
	var support=support_elbow_weight() if personal_skin else 0.0
	if support>0:
		# The support elbow remains below/outside its wrist in view space.
		# A shoulder-seeking pole rolls it over when the hilt crosses the chest.
		pole=pole.lerp(rig.global_basis.inverse()*view_frame.basis*Vector3(-.55 if side=="L" else .35,-1.0,.15),support)
	pole-=direction*pole.dot(direction)
	if pole.length_squared()<.00001: pole=Vector3.DOWN
	pole=pole.normalized()
	var radius=sqrt(maxf(0,a*a-along*along))
	if personal_skin and not wrist_solve_pole.is_zero_approx():
		var preferred=wrist_solve_pole-direction*wrist_solve_pole.dot(direction)
		if preferred.length_squared()>.00001:
			var turn=pole.signed_angle_to(preferred.normalized(),direction)
			pole=Basis(direction, .55*sin(turn)*(1-support))*pole

	var elbow=shoulder+direction*along+pole*radius
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

func wrist_skin(source:Skin) -> Skin:
	var skin:Skin=source.duplicate();var binds={}
	for side in ["R","L"]:
		for i in range(source.get_bind_count()):
			var bone_index=source.get_bind_bone(i);var name=String(rig.get_bone_name(bone_index)) if bone_index>=0 else String(source.get_bind_name(i))
			if name not in ["forearm."+side,"forearm_"+side]:continue
			binds[side]=skin.get_bind_count();skin.add_bind(rig.find_bone("view_hand."+side),Transform3D(Basis.IDENTITY,Vector3(0,.26,0))*source.get_bind_pose(i));break
	skin.set_meta("hand_binds",binds);return skin

func wrist_weights(arrays:Array,source:Skin,skin:Skin) -> void:
	var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES].duplicate();var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS].duplicate();var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	for v in range(vertices.size()):
		for j in range(4):
			var index=v*4+j;var bind=bones[index]
			if weights[index]<.01:continue
			var bone_index=source.get_bind_bone(bind);var name=String(rig.get_bone_name(bone_index)) if bone_index>=0 else String(source.get_bind_name(bind))
			if not name.begins_with("forearm"):continue
			# Blend on the forearm side of the wrist, keeping the complete thumb
			# and palm on the same joint so a wrist turn cannot tear their web.
			var local=source.get_bind_pose(bind)*vertices[v];var amount=1-smoothstep(-.25,-.21,local.y)
			if amount<=0:continue
			var hand_bind=int(skin.get_meta("hand_binds")["R" if name.ends_with("R") else "L"])
			if amount>.999:bones[index]=hand_bind
			else:
				for k in range(4):
					if weights[v*4+k]>.00001:continue
					bones[v*4+k]=hand_bind;weights[v*4+k]=weights[index]*amount;weights[index]*=1-amount;break
			break
	arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights

func grip_track(key:String,side:String) -> Array:
	var cache_key=key+side
	if grip_frames.has(cache_key):return grip_frames[cache_key]
	var ready=grip_motion.sample("drag",0)
	var z:Vector3=ready.direction
	var shoulder=Vector3(.17625 if side=="R" else -.17625,-.24265,-.20165)
	var y=(shoulder-ready.grip);y=(y-z*y.dot(z)).normalized()
	if key in ["light2","light3"]:
		var previous=grip_track("light" if key=="light2" else "light2",side)
		var join:Basis=previous[roundi(.74*240)]
		y=join.y;z=join.z
	var frames=[]
	for i in range(241):
		var pose=grip_motion.sample(key,i/240.0)
		var next:Vector3=pose.direction
		y=Basis(Quaternion(z,next))*y;z=next
		var phase=i/240.0
		var shoulder_drop=smoothstep(0,.12,phase)*(1-smoothstep(.74,1,phase)) if key=="light" else 1-smoothstep(0,.20,phase) if key=="light2" else 0.0
		var toward:Vector3=shoulder+Vector3.DOWN*.06*shoulder_drop-pose.grip
		if side=="L" and key=="light":
			var support=smoothstep(.0,.18,phase)*(1-smoothstep(.74,1,phase))
			toward=toward.lerp(Vector3(-.45,-.85,.35),support)
		toward-=z*toward.dot(z)
		if toward.length_squared()>.00001:
			# Parallel transport retains roll through axial alignments. A bounded
			# shoulder preference adds natural pronation without a wrist flip.
			var turn=y.signed_angle_to(toward.normalized(),z)
			y=Basis(z,clampf(turn,-.08,.08))*y
		y=(y-z*y.dot(z)).normalized()
		frames.append(Basis(y.cross(z).normalized(),y,z))
	grip_frames[cache_key]=frames
	return frames

func transported_grip(side:String,axis:Vector3) -> Basis:
	var key=String(grip_sample.key)
	var frames=grip_track(key,side)
	var at=clampf(float(grip_sample.phase),0,1)*240
	var a:Basis=frames[floori(at)];var b:Basis=frames[mini(240,floori(at)+1)]
	var basis=Basis(a.get_rotation_quaternion().slerp(b.get_rotation_quaternion(),at-floor(at)))
	basis=rig.global_basis.inverse()*view_frame.basis*basis
	basis=Basis(Quaternion(basis.z.normalized(),axis))*basis
	return basis.orthonormalized()

func fit_wrist(side:String,world_target:Vector3,world_axis:Vector3,grasp:float,twist:float) -> void:
	var upper=bone("upper_arm",side);var lower=bone("forearm",side);var wrist=rig.find_bone("view_hand."+side)
	var target=rig.global_transform.affine_inverse()*world_target;var axis=(rig.global_basis.inverse()*world_axis).normalized()
	var center:Vector3=palms[side]+Vector3(.009 if side=="R" else -.009,-.018,.012)*grasp
	var wrist_local=Vector3(0,-.26,0)
	var old:Vector3=palms[side]
	var desired:Basis
	var shoulder=rig.get_bone_global_pose(upper).origin
	if weapon_grip:
		# New weapon sockets specify their own thumb axis. Do not borrow a cached
		# greatsword roll track for the bow's pull hand or a one-handed rapier.
		var toward=shoulder-target;toward-=axis*toward.dot(axis)
		if toward.length_squared()<.00001:
			toward=rig.global_basis.inverse()*view_frame.basis.y;toward-=axis*toward.dot(axis)
		if toward.length_squared()<.00001:
			toward=rig.global_basis.inverse()*view_frame.basis.x;toward-=axis*toward.dot(axis)
		var hand_y=toward.normalized()
		desired=Basis(hand_y.cross(axis).normalized(),hand_y,axis)
	else:desired=transported_grip(side,axis)
	var existing=rig.get_bone_global_pose(lower).basis.orthonormalized()
	desired=Basis(existing.get_rotation_quaternion().slerp(desired.get_rotation_quaternion(),twist))
	palms[side]=wrist_local
	var wrist_target=target-desired*(center-wrist_local)
	var arm_length=global_rests[upper].origin.distance_to(global_rests[lower].origin)+wrist_local.length()
	var reach=wrist_target-shoulder
	var advance=maxf(0,reach.length()+.035-arm_length)
	if advance>0:
		var parent=rig.get_bone_parent(upper)
		var origin=shoulder+reach.normalized()*minf(advance,.24)
		rig.set_bone_pose_position(upper,rig.get_bone_global_pose(parent).affine_inverse()*origin)
		rig.force_update_all_bone_transforms()
	wrist_solve_pole=desired.y
	fit(side,rig.global_transform*wrist_target,Vector3.ZERO)
	var action_phase=float(grip_sample.phase)
	var action_bend=0.0 if String(grip_sample.key) in ["drag","draw"] else smoothstep(0,.15,action_phase)*(1-smoothstep(.85,1,action_phase))
	if String(grip_sample.key) in ["light2","light3"]:action_bend=1-smoothstep(.85,1,action_phase)
	var wrist_limit=lerpf(16,36,action_bend)
	if weapon_grip:wrist_limit=36
	for iteration in range(14):
		var incoming=rig.get_bone_global_pose(lower).basis.y.normalized()
		var bend=desired.y.angle_to(incoming)
		if bend<deg_to_rad(wrist_limit):break
		var correction=Quaternion(desired.y,incoming)
		var amount=(bend-deg_to_rad(wrist_limit-2))/maxf(bend,.0001)
		desired=Basis(Quaternion.IDENTITY.slerp(correction,amount*.65))*desired
		wrist_solve_pole=desired.y
		wrist_target=target-desired*(center-wrist_local)
		fit(side,rig.global_transform*wrist_target,Vector3.ZERO)
	palms[side]=old;wrist_solve_pole=Vector3.ZERO
	var forearm=rig.get_bone_global_pose(lower).basis.orthonormalized()
	var forearm_axis=forearm.y.normalized()
	var roll_goal=desired.z-forearm_axis*desired.z.dot(forearm_axis)
	if roll_goal.length_squared()>.00001:
		set_basis(lower,Basis(forearm_axis,forearm.z.signed_angle_to(roll_goal.normalized(),forearm_axis))*forearm)

	var lower_basis=rig.get_bone_global_pose(lower).basis
	var upper_basis=rig.get_bone_global_pose(upper).basis.orthonormalized()
	var upper_axis=(rig.get_bone_global_pose(lower).origin-rig.get_bone_global_pose(upper).origin).normalized()
	var forearm_direction=-lower_basis.y.normalized()
	var hinge=upper_axis.cross(forearm_direction)
	if hinge.length_squared()>.00001:
		hinge=hinge.normalized()
		if hinge.dot(upper_basis.x)<0:hinge=-hinge
		var turn=upper_basis.x.signed_angle_to(hinge,upper_axis)
		set_basis(upper,Basis(upper_axis,.35*sin(turn))*upper_basis)
		set_basis(lower,lower_basis)

	set_basis(wrist,desired)

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
				# Four fingers curl around the oval handle in the palm's X/Y plane.
				# Thumb vertices occupy the separate high-Z web above the knuckles;
				# never drag the index finger into that web.
				var extension=clampf(-original.y-.318,0,.12)
				if extension>0:
					var angle=minf(3.1,extension/.025)
					local.y=-.318-.022*sin(angle)
					local.x+=side*.022*(1-cos(angle))
				var thumb=smoothstep(.055,.082,original.z)*(1-smoothstep(.310,.332,-original.y))*smoothstep(-.006,.014,side*original.x)
				var thumb_base=Vector3(side*.005,-.265,.052)
				var tucked=thumb_base+Basis(Vector3.RIGHT,.65)*(original-thumb_base)
				tucked.x-=side*.008
				local=local.lerp(tucked,thumb)
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

func grip_blends(source:ArrayMesh,skin:Skin,skeleton:Skeleton3D,view_skin:Skin) -> ArrayMesh:
	var right=grip_mesh(source,skin,skeleton,"R",false);var left=grip_mesh(source,skin,skeleton,"L",false)
	var result=ArrayMesh.new();result.blend_shape_mode=Mesh.BLEND_SHAPE_MODE_RELATIVE;result.add_blend_shape("GripR");result.add_blend_shape("GripL")
	for surface in range(source.get_surface_count()):
		var base=source.surface_get_arrays(surface);var shapes=[]
		for closed in [right,left]:
			var full=closed.surface_get_arrays(surface);var shape=[];shape.resize(Mesh.ARRAY_MAX)
			var delta:PackedVector3Array=full[Mesh.ARRAY_VERTEX].duplicate()
			for i in range(delta.size()):delta[i]-=base[Mesh.ARRAY_VERTEX][i]
			shape[Mesh.ARRAY_VERTEX]=delta
			var normals=PackedVector3Array();normals.resize(full[Mesh.ARRAY_VERTEX].size())
			var vertices:PackedVector3Array=full[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=full[Mesh.ARRAY_INDEX]
			for i in range(0,indices.size(),3):
				var a=indices[i];var b=indices[i+1];var c=indices[i+2];var normal=(vertices[c]-vertices[a]).cross(vertices[b]-vertices[a])
				normals[a]+=normal;normals[b]+=normal;normals[c]+=normal
			for i in range(normals.size()):normals[i]=normals[i].normalized() if normals[i].length_squared()>.0000001 else base[Mesh.ARRAY_NORMAL][i]
			for i in range(normals.size()):
				if delta[i].length_squared()<.0000000001:normals[i]=Vector3.ZERO;continue
				if normals[i].dot(base[Mesh.ARRAY_NORMAL][i])<0:normals[i]=-normals[i]
				normals[i]-=base[Mesh.ARRAY_NORMAL][i]
			shape[Mesh.ARRAY_NORMAL]=normals
			if base[Mesh.ARRAY_TANGENT]!=null:
				var tangents=PackedFloat32Array();tangents.resize(base[Mesh.ARRAY_TANGENT].size());shape[Mesh.ARRAY_TANGENT]=tangents
			shapes.append(shape)
		wrist_weights(base,skin,view_skin)
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,base,shapes);result.surface_set_material(surface,source.surface_get_material(surface))
	result.set_meta("closed_shapes",[right,left]);result.set_meta("source_mesh",source);result.set_meta("source_skin",skin)
	return result

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
				if name.begins_with("upper_arm") or name.begins_with("forearm"):
					var local=source.skin.get_bind_pose(bones[v*influences+i])*vertices[v]
					if personal_skin and name.begins_with("upper_arm") and local.y>-.065:continue
					arm_weight+=weights[v*influences+i]
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
