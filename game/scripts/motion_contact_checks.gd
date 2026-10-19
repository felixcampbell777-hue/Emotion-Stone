extends RefCounted
func skin_clearance(hands:RefCounted,rails:Array,width:Vector3) -> float:
	var minimum=INF
	for part in hands.rig.get_children():
		if not part is MeshInstance3D or part.skin==null:continue
		var transforms=[];var wrist_binds=[]
		for bind in range(part.skin.get_bind_count()):
			var bone=part.skin.get_bind_bone(bind)
			if bone<0:bone=hands.rig.find_bone(part.skin.get_bind_name(bind))
			transforms.append(hands.rig.get_bone_global_pose(bone)*part.skin.get_bind_pose(bind))
			wrist_binds.append(String(hands.rig.get_bone_name(bone)).begins_with("view_hand"))
		for surface in range(part.mesh.get_surface_count()):
			var arrays=part.mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var shapes=[]
			if part.mesh.has_meta("closed_shapes"):
				for closed in part.mesh.get_meta("closed_shapes"):shapes.append(closed.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
			var posed=PackedVector3Array();posed.resize(vertices.size());var palm=PackedByteArray();palm.resize(vertices.size())
			for index in range(vertices.size()):
				var point=vertices[index]
				for shape in range(shapes.size()):point+=(shapes[shape][index]-vertices[index])*part.get_blend_shape_value(shape)
				var world=Vector3.ZERO;var hand_weight=0.0
				for influence in range(4):
					var weight=arrays[Mesh.ARRAY_WEIGHTS][index*4+influence]
					if weight<=0:continue
					var bind=arrays[Mesh.ARRAY_BONES][index*4+influence]
					world+=(transforms[bind]*point)*weight
					if wrist_binds[bind]:hand_weight+=weight
				posed[index]=hands.rig.global_transform*world;palm[index]=1 if hand_weight>.1 else 0
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			for index in range(0,indices.size(),3):
				var a=indices[index];var b=indices[index+1];var c=indices[index+2]
				# The parry deliberately puts the palm against the steel; inspect the
				# actual remaining forearm/upper-arm triangles rather than a capsule
				# ending partway through that intentionally braced hand.
				if palm[a] or palm[b] or palm[c]:continue
				for offset in [Vector3.ZERO,width,-width]:
					if Geometry3D.segment_intersects_triangle(rails[0]+offset,rails[1]+offset,posed[a],posed[b],posed[c])!=null:return 0.0
					for edge in [[posed[a],posed[b]],[posed[b],posed[c]],[posed[c],posed[a]]]:
						var near=Geometry3D.get_closest_points_between_segments(rails[0]+offset,rails[1]+offset,edge[0],edge[1])
						minimum=minf(minimum,near[0].distance_to(near[1]))
	return minimum
func run(test:RefCounted) -> void:
	var g=test.game;var actor=g.player;var driver=g.camera_driver;var hands=driver.visuals
	actor.set_physics_process(false);actor.set_sword_drawn(true);actor.state="free"
	driver.yaw=PI;driver.first_pitch=0
	var minimum=INF;var cut_minimum=INF;var tip_error=0.0;var clear=true;var closest={};var parry_skin=INF;var parry_samples=0
	for key in ["light","light2","light3","heavy","parry"]:
		actor.state="light" if key.begins_with("light") else key
		actor.combo_stage=3 if key=="light3" else 2 if key=="light2" else 1
		actor.state_duration=3.0
		var clip="parry_guard" if key=="parry" else "attack_"+key
		actor.play_clip(clip,0)
		for index in range(121):
			var phase=index/120.0;actor.state_time=actor.state_duration*phase
			actor.animator.seek(actor.animator.get_animation(actor.clips[clip]).length*phase,true)
			actor.visual.rotation.y=actor.spin_rotation(phase) if key=="light3" else 0
			actor._pose_sword(key,phase);driver.update_first_person(0)
			var rails=actor.blade_segment()
			var parry_warning=false
			var sampled=actor.first_person_sword.sample(key,phase)
			var frame=driver.sample_first_person(0,false)
			var floor_y=actor.ground_world.ground_height(frame*sampled.grip) if is_instance_valid(actor.ground_world) else actor.position.y
			var reach=(actor.BetaSwordMotion.GRIP-actor.BetaSwordMotion.TIP)*float(actor.combat.sword_scale)
			var pure=actor.first_person_sword.contact_pose(frame,sampled,key,phase,reach,floor_y)
			tip_error=maxf(tip_error,pure.tip.distance_to(actor.sword_tip()))
			for side in ["L","R"]:
				var shoulder=hands.rig.global_transform*hands.rig.get_bone_global_pose(hands.bone("upper_arm",side)).origin
				var elbow=hands.rig.global_transform*hands.rig.get_bone_global_pose(hands.bone("forearm",side)).origin
				var wrist:Vector3=hands.hand_targets[side]
				if key=="light" and index==66 and side=="R":test.check(g.camera.unproject_position(elbow).y>g.world_view.size.y*.95,"Cross-body opener keeps the right elbow near the lower view edge instead of exposing a folded upper arm")
				var end=elbow.lerp(wrist,.65) if key=="parry" and side=="L" else wrist
				for segment in [[shoulder,elbow],[elbow,end]]:
					for offset in [Vector3.ZERO,actor.equipment.global_basis.x.normalized()*.05,-actor.equipment.global_basis.x.normalized()*.05]:
						var nearest=Geometry3D.get_closest_points_between_segments(rails[0]+offset,rails[1]+offset,segment[0],segment[1])
						var distance=nearest[0].distance_to(nearest[1])
						if distance<minimum:minimum=distance;closest={"key":key,"phase":phase,"side":side,"segment":segment}
						if key!="parry":cut_minimum=minf(cut_minimum,distance);clear=clear and distance>.035
						elif distance<=.035:parry_warning=true
			if parry_warning:
				parry_skin=minf(parry_skin,skin_clearance(hands,rails,actor.equipment.global_basis.x.normalized()*.05));parry_samples+=1
	print("MOTION_CONTACT closest=",closest," minimum=",minimum," parry_skin=",parry_skin," parry_samples=",parry_samples," sampler_error=",tip_error)
	test.check(clear,"Repaired cuts and retained heavy keep steel outside fitted limbs across 484 subframes (minimum %.4fm)"%cut_minimum)
	test.check(parry_samples==0 or parry_skin>.003,"Every conservative parry-brace warning clears actual skinned arm triangles (%.4fm across %d phases)"%[parry_skin,parry_samples])
	test.check(tip_error<.0001,"Pure accepted-frame contact sampler matches actual rendered steel tip across 605 subframes (%.7fm)"%tip_error)
	actor.state="free";actor.combo_stage=0;actor.set_sword_drawn(true);actor.play_clip("drag_idle_loop",0);actor.set_physics_process(true)
