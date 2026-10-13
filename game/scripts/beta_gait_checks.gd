extends RefCounted
func run(test:RefCounted) -> void:
	var actor=test.game.player; var hero=actor.get_node("BetaHero")
	actor.set_physics_process(false); hero.set_process(false)
	var width_ok=true; var grounded=true; var lengths_ok=true; var bend_ok=true; var loop_ok=true
	for clip in ["walk_loop","drag_walk_loop"]:
		actor.set_sword_drawn(clip=="drag_walk_loop"); actor.state="free"; actor.play_clip(clip,0)
		var first=[]
		for sample in range(241):
			actor.animator.seek(actor.animator.get_animation(actor.clips[clip]).length*sample/240.0,true)
			hero.synchronize()
			var feet=[]
			for side in ["L","R"]:
				var thigh=hero.gait.bone(hero,"thigh",side); var shin=hero.gait.bone(hero,"shin",side); var foot=hero.gait.bone(hero,"foot",side)
				var hip=hero.rig.get_bone_global_pose(thigh).origin; var knee=hero.rig.get_bone_global_pose(shin).origin; var ankle=hero.rig.get_bone_global_pose(foot).origin
				feet.append(ankle)
				grounded=grounded and ankle.y>=hero.global_rests[foot].origin.y-.002 and ankle.y<=hero.global_rests[foot].origin.y+.036
				lengths_ok=lengths_ok and absf(hip.distance_to(knee)-hero.global_rests[thigh].origin.distance_to(hero.global_rests[shin].origin))<.002 and absf(knee.distance_to(ankle)-hero.global_rests[shin].origin.distance_to(hero.global_rests[foot].origin))<.002
				bend_ok=bend_ok and knee.z>lerpf(hip.z,ankle.z,.4)-.01
			width_ok=width_ok and absf(feet[0].x-feet[1].x-.21)<.002
			grounded=grounded and minf(feet[0].y,feet[1].y)<hero.global_rests[hero.gait.bone(hero,"foot","L")].origin.y+.012
			if sample==0: first=feet
			if sample==240: loop_ok=loop_ok and feet[0].distance_to(first[0])<.002 and feet[1].distance_to(first[1])<.002
	test.check(width_ok,"Both Beta walks retain a narrow 21cm foot track throughout the cycle")
	test.check(grounded,"Both preset walks keep boot lift below 3.6cm and a support boot near the floor")
	test.check(lengths_ok and bend_ok,"Beta knees bend forward without changing leg segment lengths")
	test.check(loop_ok,"Both Beta walks join continuously at the cycle boundary")
	var walking_pose=hero.rig.get_bone_pose_rotation(hero.gait.bone(hero,"thigh","L"))
	var flight=false;var heel_recovery=false;var running_lengths=true
	for drawn in [false,true]:
		actor.set_sword_drawn(drawn);actor.sprinting=true;actor.play_clip("drag_walk_loop" if drawn else "walk_loop",0)
		for frame in range(121):
			actor.animator.seek(frame/120.0*actor.animator.get_animation(actor.clips[actor.current_clip]).length,true);hero.synchronize()
			var feet=[]
			for side in ["L","R"]:
				var thigh=hero.gait.bone(hero,"thigh",side);var shin=hero.gait.bone(hero,"shin",side);var foot=hero.gait.bone(hero,"foot",side)
				var hip=hero.rig.get_bone_global_pose(thigh).origin;var knee=hero.rig.get_bone_global_pose(shin).origin;var ankle=hero.rig.get_bone_global_pose(foot).origin
				feet.append(ankle)
				running_lengths=running_lengths and absf(hip.distance_to(knee)-hero.global_rests[thigh].origin.distance_to(hero.global_rests[shin].origin))<.002 and absf(knee.distance_to(ankle)-hero.global_rests[shin].origin.distance_to(hero.global_rests[foot].origin))<.002
				heel_recovery=heel_recovery or (ankle.y>.25 and ankle.z<hip.z-.15)
			flight=flight or (not drawn and minf(feet[0].y,feet[1].y)>.13)
	test.check(flight and heel_recovery and running_lengths and not walking_pose.is_equal_approx(hero.rig.get_bone_pose_rotation(hero.gait.bone(hero,"thigh","L"))),"Sprint uses distinct preset running with flight, backward heel recovery and unstretched legs")
	actor.sprinting=false
	hero.gait.run_blend=0.0
	var phase=hero.gait.phase;hero.gait.advance_distance(actor,.67,.1)
	test.check(absf(fposmod(hero.gait.phase-phase,1.0)-.5)<.001,"Walk cadence advances by travelled distance rather than rendering time")
	var frozen_phase=hero.gait.phase
	actor.input_enabled=false;actor._physics_process(.1);actor.input_enabled=true
	test.check(hero.gait.phase==frozen_phase,"An overlay blocks locomotion cadence along with actor movement")
	actor.state="attack"; actor.play_clip("attack_light",0); hero.synchronize()
	test.check(hero.gait.blend==0 and hero.gait.body_drop==0,"Walk correction releases completely during sword attacks")
	actor.state="free"; actor.set_sword_drawn(false); actor.play_clip("idle_loop",0)
	actor.set_physics_process(true); hero.set_process(true)
