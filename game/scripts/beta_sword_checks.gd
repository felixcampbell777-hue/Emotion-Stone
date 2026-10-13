extends RefCounted
func run(test:RefCounted) -> void:
	var actor=test.game.player; var avatar=actor.get_node("BetaHero")
	var blade=actor.equipment.find_child("SwordBlade",true,false)
	test.check(actor.equipment.get_meta("beta_sword",false) and blade!=null,"Beta owns the separate CC0 broad war sword scene")
	var root_to_mesh=actor.equipment.global_transform.affine_inverse()*blade.global_transform
	var minimum=Vector3(INF,INF,INF); var maximum=-minimum; var actual_tip=Vector3.ZERO
	for vertex in blade.mesh.get_faces():
		var point=root_to_mesh*vertex
		minimum=minimum.min(point); maximum=maximum.max(point)
		if point.y<actual_tip.y: actual_tip=point
	test.check(absf(minimum.y-actor.BetaSwordMotion.TIP)<.0001 and absf((maximum.x-minimum.x)*1.472-.10)<.0002 and absf((maximum.z-minimum.z)*1.472-.012)<.0002,"Imported broad steel is 1.40m to the tip, 10cm wide and 12mm at the spine")
	actor.set_sword_drawn(true); actor.visual.rotation.y=0
	var endpoints_match=true
	for key in ["drag","light","light2","light3","heavy","parry","water","lance","roll","stand"]:
		for phase in [.0,.28,.55,.68,.74,1.0]:
			actor._pose_sword(key,phase)
			endpoints_match=endpoints_match and actor.sword_tip().distance_to(actor.equipment.global_transform*actual_tip)<.0002
	test.check(endpoints_match,"Damage/projectile endpoint follows the shorter rendered tip through combat and dodge poses")
	for key in ["heavy","light3"]:
		actor._pose_sword(key,.68)
		test.check(absf(actor.sword_tip().y-actor.global_position.y)<.05,"Shorter Beta blade reaches actual ground during "+key+" impact")
	actor._pose_sword("drag",0)
	var view=actor.first_person_driver
	test.check(view!=null and actor.sword_tip().y>actor.global_position.y+1.4,"First-person carry raises the broad sword ahead rather than dragging its tip")
	actor._scrape(.2,true)
	test.check(actor.scrape_nodes.is_empty() or actor.scrape_nodes.all(func(item): return item.life<=0),"Forward-ready carry has no obsolete ground-drag sparks")
	var rat=test.game.enemies.filter(func(enemy): return enemy.definition.kind=="beta_rat")[0]
	var home=rat.position
	actor._pose_sword("light",.44); actor.blade_sweep_previous.clear()
	var old_tip=actor.equipment.global_transform*Vector3(0,actor.BetaSwordMotion.TIP-.5,0)
	rat.global_position=old_tip-Vector3(0,.5,0)
	test.check(not actor.blade_hits(rat),"A target well beyond the enlarged visible steel still misses")
	rat.global_position=actor.sword_tip()-Vector3(0,.5,0)
	test.check(actor.blade_hits(rat),"A target intersecting the new visible tip is hittable")
	rat.position=home
	actor.set_sword_glow(true); actor.update_sword_energy(1.0)
	var energy=blade.get_surface_override_material(0)
	test.check(energy is ShaderMaterial and absf(float(energy.get_shader_parameter("blade_length"))-(actor.BetaSwordMotion.BLADE_BASE-actor.BetaSwordMotion.TIP))<.0001,"Lance energy fills the complete shorter blade")
	actor.set_sword_glow(false)
	var steel=blade.get_active_material(0)
	test.check(steel is StandardMaterial3D and steel.metallic>.9 and steel.roughness<.4,"Release restores the customized polished steel material")
	for sample in [["attack_heavy","heavy",.68],["attack_lance","lance",.70]]:
		actor.play_clip(sample[0],0)
		actor.animator.seek(actor.animator.get_animation(actor.clips[sample[0]]).length*sample[2],true)
		actor._pose_sword(sample[1],sample[2]); avatar.synchronize()
		var right=avatar.gait.bone(avatar,"forearm","R")
		view.update_first_person()
		var palm=view.visuals.rig.global_transform*(view.visuals.rig.get_bone_global_pose(right)*view.visuals.PALM)
		var grip=actor.equipment.global_transform*Vector3(0,actor.BetaSwordMotion.GRIP,0)
		test.check(palm.distance_to(grip)<.10,"First-person palm follows real sword grip during "+sample[1])
	var body=avatar.find_child("Static_Human_0",true,false)
	var local_samples=[]
	for surface in range(body.mesh.get_surface_count()):
		var arrays=body.mesh.surface_get_arrays(surface); var vertices=arrays[Mesh.ARRAY_VERTEX]; var bones=arrays[Mesh.ARRAY_BONES]; var weights=arrays[Mesh.ARRAY_WEIGHTS]
		var influences=bones.size()/vertices.size()
		for v in range(vertices.size()):
			for i in range(influences):
				var bind=bones[v*influences+i]
				if String(body.skin.get_bind_name(bind))!="forearm.R" or weights[v*influences+i]<.98: continue
				var point=body.skin.get_bind_pose(bind)*vertices[v]
				if point.y>-.32 and point.y<-.27 and absf(point.z)<.025: local_samples.append(point)
	var center=Vector3.ZERO
	for point in local_samples: center+=point
	if not local_samples.is_empty(): center/=local_samples.size()
	test.check(not local_samples.is_empty() and center.distance_to(avatar.hands.PALM)<.05,"Hand fitting anchor is measured inside actual imported palm skin, with the correct bone-local axis")
	actor.set_physics_process(false)
	actor.set_sword_drawn(false); actor.skeleton.force_update_all_bone_transforms()
	# BoneAttachment follows the newly sought idle spine on the next engine frame.
	await test.frames(2)
	await actor.get_tree().process_frame
	var mount=actor.equipment.global_transform
	actor.equipment.reparent(actor.visual,true); actor.state="draw"
	actor._pose_sword("draw",0)
	test.check(actor.equipment.global_transform.origin.distance_to(mount.origin)<.001 and actor.equipment.global_transform.basis.x.distance_to(mount.basis.x)<.001,"Shorter Beta sword starts drawing continuously from its actual back mount")
	actor.set_sword_drawn(false)
	actor.set_physics_process(true)
