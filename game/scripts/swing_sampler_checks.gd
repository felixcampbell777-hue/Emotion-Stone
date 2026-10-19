extends RefCounted
func run(test) -> void:
	var motion=load("res://scripts/first_person_sword.gd").new()
	var key_error=0.0;var direction_error=0.0;var max_join_velocity_error=0.0;var lowest_cut_speed=INF
	var finite=true;var bounded=true
	for key in ["light","light2"]:
		var frames=motion.definition.paths[key]
		for frame in frames:
			var pose=motion.sample(key,float(frame.t))
			key_error=maxf(key_error,pose.grip.distance_to(motion.vector(frame.grip)))
			direction_error=maxf(direction_error,pose.direction.distance_to(motion.vector(frame.direction).normalized()))
		for index in range(frames.size()-1):
			var a=motion.vector(frames[index].grip);var b=motion.vector(frames[index+1].grip)
			for step in range(31):
				var pose=motion.sample(key,lerpf(float(frames[index].t),float(frames[index+1].t),step/30.0))
				finite=finite and pose.grip.is_finite() and pose.direction.is_finite() and absf(pose.direction.length()-1)<.00001
				for axis in range(3):bounded=bounded and pose.grip[axis]>=minf(a[axis],b[axis])-.00001 and pose.grip[axis]<=maxf(a[axis],b[axis])+.00001
		for phase in ([.44,.54] if key=="light" else [.43]):
			var epsilon=.0001
			var before=motion.sample(key,phase-epsilon);var at=motion.sample(key,phase);var after=motion.sample(key,phase+epsilon)
			var previous_tip=before.grip+before.direction*2.128;var tip=at.grip+at.direction*2.128;var next_tip=after.grip+after.direction*2.128
			var incoming=(tip-previous_tip)/epsilon;var outgoing=(next_tip-tip)/epsilon
			lowest_cut_speed=minf(lowest_cut_speed,minf(incoming.length(),outgoing.length()))
			max_join_velocity_error=maxf(max_join_velocity_error,incoming.distance_to(outgoing))
	test.check(key_error<.00001 and direction_error<.00001,"Continuous cuts retain every authored grip and direction key, ready endpoints and .74 catches")
	test.check(finite and bounded,"Cut interpolation remains finite, normalized and inside authored grip envelopes")
	test.check(lowest_cut_speed>1.0,"Steel passes interior active-cut keys without artificial full stops (%.3fm/phase)"%lowest_cut_speed)
	test.check(max_join_velocity_error<.2,"Steel velocity remains continuous through passing keys (%.4f)"%max_join_velocity_error)
	for pair in [["light","light2"],["light2","light3"]]:
		var end=motion.sample(pair[0],.74);var next=motion.sample(pair[1],0)
		test.check(end.grip.distance_to(next.grip)<.000001 and end.direction.distance_to(next.direction)<.000001,"Combo join remains exact: "+pair[0]+" to "+pair[1])
