extends RefCounted
func run(test:RefCounted) -> void:
	var g=test.game;var actor=g.player;var driver=g.camera_driver;var h=driver.visuals
	actor.set_physics_process(false);actor.set_sword_drawn(true);actor.state="free";actor.play_clip("drag_idle_loop",0);actor._pose_sword("drag",0);driver.update_first_person(0)
	var meshes=h.rig.get_children().filter(func(n):return n is MeshInstance3D)
	test.check(not meshes.is_empty() and meshes.all(func(m):return m.mesh.get_blend_shape_count()==2 and m.mesh.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_RELATIVE),"Visible hands have independent additive grip shapes without multiplying their skin positions")
	test.check(meshes.all(func(m):return m.get_blend_shape_value(0)>.99 and m.get_blend_shape_value(1)>.99),"Both hands close around the actual ready hilt")
	var fitting=0.0;var alignment=1.0
	for side in ["R","L"]:
		var pose=h.rig.get_bone_global_pose(h.rig.find_bone("view_hand."+side));var center=h.palms[side]+Vector3(.009 if side=="R" else -.009,-.018,.012)
		fitting=maxf(fitting,(h.rig.global_transform*(pose*(center-Vector3(0,-.26,0)))).distance_to(h.hand_targets[side]))
		alignment=minf(alignment,absf((h.rig.global_basis*pose.basis.z).normalized().dot(actor.equipment.global_basis.y.normalized())))
	test.check(fitting<.003 and alignment>.999,"Actual skinned wrist centers meet the hilt and the fingers align along its axis instead of twisting the whole forearm")
	var separation=true;var curled=0;var finite=true
	for m in meshes:
		for surface in range(m.mesh.get_surface_count()):
			var base=m.mesh.get_meta("source_mesh").surface_get_arrays(surface);var source_skin:Skin=m.mesh.get_meta("source_skin");var shapes=m.mesh.get_meta("closed_shapes").map(func(shape):return shape.surface_get_arrays(surface))
			for i in range(base[Mesh.ARRAY_VERTEX].size()):
				for j in range(4):
					var bind=base[Mesh.ARRAY_BONES][i*4+j];var bone=source_skin.get_bind_bone(bind);var name=String(h.rig.get_bone_name(bone)) if bone>=0 else String(source_skin.get_bind_name(bind))
					if not name.begins_with("forearm") or base[Mesh.ARRAY_WEIGHTS][i*4+j]<.85:continue
					var original=source_skin.get_bind_pose(bind)*base[Mesh.ARRAY_VERTEX][i];var closed=source_skin.get_bind_pose(bind)*shapes[0 if name.ends_with("R") else 1][Mesh.ARRAY_VERTEX][i]
					finite=finite and closed.is_finite()
					if original.y<-.345:
						separation=separation and absf(closed.z-original.z)<.0001
						if closed.y>original.y+.01:curled+=1
					break
	test.check(finite and separation and curled>100,"Fingers curl back around the handle while keeping their separation; index fingertips are not pulled into the thumb")
	for fixture in [["water","attack_water",.45,0.0],["parry","parry_guard",.4,0.0],["lance_charge","attack_lance",.4,1.0]]:
		actor.state=fixture[0];actor.state_duration=3;actor.state_time=3*fixture[2];actor.play_clip(fixture[1],0)
		actor._pose_sword("water" if fixture[0]=="water" else "parry" if fixture[0]=="parry" else "lance",fixture[2]);driver.update_first_person(0)
		test.check(meshes.all(func(m):return m.get_blend_shape_value(0)>.99 and absf(m.get_blend_shape_value(1)-fixture[3])<.01),fixture[0]+": gripping hand stays closed while the supporting or bracing palm uses its own pose")
	actor.state="draw";actor.state_duration=1;actor.play_clip("draw_sword",0);actor.animator.seek(actor.animator.get_animation(actor.clips.draw_sword).length*.25,true);driver.update_first_person(0)
	test.check(meshes.all(func(m):return m.get_blend_shape_value(0)>0 and m.get_blend_shape_value(0)<1),"Drawing blends finger closure instead of swapping instantly between open and closed meshes")
	var shoulder=h.rig.get_bone_global_pose(h.bone("upper_arm","R")).origin
	h.fit_wrist("R",h.rig.global_transform*(shoulder+Vector3.DOWN*.4),h.rig.global_basis*Vector3.DOWN,1,1)
	test.check(h.rig.get_bone_global_pose(h.rig.find_bone("view_hand.R")).basis.is_finite(),"Vertical sword alignment keeps a finite wrist orientation instead of collapsing its twist axis")
	actor.state="free";actor.set_sword_drawn(false);actor.set_physics_process(true)
