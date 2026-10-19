extends RefCounted
## Asset-independent transition regression; the actor clock is the only time source.
class MotionActor extends Node3D:
	var presentation_clock=0.0
	var velocity=Vector3.ZERO
	var walk_speed=2.4
	var sprinting=false

func run(test) -> void:
	var largest_step=0.0
	var largest_phase_step=0.0
	var repeat_error=0.0
	var session_error=0.0
	for fps in [30,60,120]:
		var reference=[]
		for elapsed in [0.0,60.0,600.0]:
			var actor=MotionActor.new();actor.presentation_clock=elapsed;actor.velocity=Vector3(0,0,2.4)
			var hands=load("res://scripts/unarmed_hands.gd").new()
			var sword=load("res://scripts/first_person_sword.gd").new()
			hands.targets(actor,Transform3D.IDENTITY);sword.update_gait(actor)
			for i in range(fps*2):
				actor.presentation_clock+=1.0/fps;hands.targets(actor,Transform3D.IDENTITY);sword.update_gait(actor)
			var previous=hands.targets(actor,Transform3D.IDENTITY).R
			for i in range(fps*3):
				actor.sprinting=i<fps
				actor.velocity=Vector3(0,0,4.6 if actor.sprinting else 2.4) if i<fps*2 else Vector3.ZERO
				var old_phase=hands.gait_phase
				actor.presentation_clock+=1.0/fps
				var point=hands.targets(actor,Transform3D.IDENTITY).R
				sword.update_gait(actor)
				largest_step=maxf(largest_step,point.distance_to(previous)*fps)
				largest_phase_step=maxf(largest_phase_step,fposmod(hands.gait_phase-old_phase,TAU)*fps)
				var phase=sword.gait_phase
				for repeat in range(3):
					repeat_error=maxf(repeat_error,hands.targets(actor,Transform3D.IDENTITY).R.distance_to(point))
					sword.update_gait(actor);repeat_error=maxf(repeat_error,absf(sword.gait_phase-phase))
				if elapsed==0:reference.append(point)
				else:session_error=maxf(session_error,Vector2(point.x,point.z).distance_to(Vector2(reference[i].x,reference[i].z)))
				previous=point
			hands.reset(actor);sword.reset_gait(actor)
			test.check(hands.gait_phase==0 and sword.gait_phase==0 and hands.moving==0 and hands.previous_clock==actor.presentation_clock,"New-game/teleport presentation reset clears motion without changing the actor clock")
			actor.presentation_clock=0;hands.targets(actor,Transform3D.IDENTITY);sword.update_gait(actor)
			test.check(hands.gait_phase==0 and sword.gait_phase==0 and hands.moving==0,"Clock reset clears locomotion envelopes and phases at %d FPS / %.0fs"%[fps,elapsed])
			actor.free()
	test.check(largest_phase_step<=10.501,"Sprint phase speed stays within authored frequency at 30/60/120 FPS and long session clocks")
	test.check(largest_step<3.0,"Walk/sprint/stop hand speed stays bounded below 3m/s rather than jumping across view (%.3f)"%largest_step)
	test.check(repeat_error<.000001,"Repeated camera/IK samples and a frozen actor clock never advance gait")
	test.check(session_error<.00001,"Locomotion transitions are independent of elapsed session time (%.8f)"%session_error)
