extends RefCounted
func run(test:RefCounted) -> void:
	var actor=test.game.player;var hero=actor.get_node("BetaHero")
	actor.set_physics_process(false);hero.set_process(false)
	actor.set_sword_drawn(false);hero.synchronize()
	var pad=actor.back_harness.get_node("CompactLeatherBackPad")
	var meshes=actor.back_harness.find_children("*","MeshInstance3D",true,false)
	test.check(actor.back_harness.get_meta("compact_beta_anchor",false) and meshes.all(func(mesh):return not mesh.mesh is BoxMesh) and pad.mesh.get_aabb().size.x<.20 and pad.mesh.get_aabb().size.y<.25,"Beta carry uses one compact rounded pad and no crossed box straps")
	var stable=true;var moves=false;var first=Vector3.ZERO
	var spine=hero.rig.find_bone("spine")
	var reference_pad=Transform3D.IDENTITY;var reference_sword=Transform3D.IDENTITY
	for running in [false,true]:
		actor.set_sword_drawn(false);actor.sprinting=running;actor.play_clip("walk_loop",0)
		for index in range(9):
			actor.animator.seek(actor.animator.get_animation(actor.clips.walk_loop).length*index/8.0,true);hero.synchronize()
			var bone_world=hero.rig.global_transform*hero.rig.get_bone_global_pose(spine)
			var local_pad=bone_world.affine_inverse()*pad.global_transform
			var local_sword=bone_world.affine_inverse()*actor.equipment.global_transform
			if index==0 and not running:
				reference_pad=local_pad;reference_sword=local_sword;first=pad.global_position
			stable=stable and local_pad.is_equal_approx(reference_pad) and local_sword.is_equal_approx(reference_sword)
			moves=moves or pad.global_position.distance_to(first)>.035
	test.check(stable and moves,"Pad and sheathed steel follow the actual Beta spine through walking and running without floating")
	# Starting the real draw from a moving gait preserves the mounted pose.
	var before=actor.equipment.global_transform
	actor.toggle_sword();actor._pose_sword("draw",0);hero.synchronize()
	test.check(before.origin.distance_to(actor.equipment.global_position)<.002 and before.basis.x.distance_to(actor.equipment.global_basis.x)<.002,"Drawing from a running pose begins continuously at the live back anchor")
	actor.animator.seek(actor.animator.get_animation(actor.clips.draw_sword).length*.60,true)
	actor._pose_sword("draw",.60);hero.synchronize()
	test.check(actor.sword_holders.all(func(holder):return not holder.visible) and hero.harness.visible and pad.visible,"Drawing clears both compact clips while the fixed back pad remains visible")
	actor.set_sword_drawn(false);hero.synchronize()
	test.check(actor.sword_holders.all(func(holder):return holder.visible) and hero.harness.visible,"Sheathing restores the compact clips and matching back pad")
	actor.set_sword_equipped(false);hero.synchronize()
	test.check(not hero.harness.visible and not hero.sword.visible,"Unequipping removes the complete back anchor and steel")
	actor.set_sword_equipped(true);actor.sprinting=false;hero.synchronize()
	actor.set_physics_process(true);hero.set_process(true)
