extends RefCounted
## Relaxed body-aligned arms, with opposite arm swings driven by the actor clock.
var tuning=JSON.parse_string(FileAccess.get_file_as_string("res://content/unarmed_hands.json"))
var moving=0.0
var running=0.0
var previous_clock=-1.0
func vector(value:Array) -> Vector3: return Vector3(value[0],value[1],value[2])
func targets(actor:Node3D,frame:Transform3D) -> Dictionary:
	var clock=float(actor.presentation_clock)
	var delta=clampf(clock-previous_clock,0,.1) if previous_clock>=0 else 0.0
	previous_clock=clock
	var speed=Vector2(actor.velocity.x,actor.velocity.z).length()
	var weight=1-exp(-delta/float(tuning.blend_seconds))
	moving=lerpf(moving,clampf(speed/maxf(.1,actor.walk_speed),0,1),weight)
	running=lerpf(running,1.0 if actor.sprinting and speed>.3 else 0.0,weight)
	var base=vector(tuning.idle).lerp(vector(tuning.walk).lerp(vector(tuning.sprint),running),moving)
	var rate=lerpf(float(tuning.walk_rate),float(tuning.sprint_rate),running)
	var forward=lerpf(float(tuning.walk_forward),float(tuning.sprint_forward),running)*moving
	var lift=lerpf(float(tuning.walk_lift),float(tuning.sprint_lift),running)*moving
	var result={}
	for side in ["R","L"]:
		var sign=1.0 if side=="R" else -1.0
		var swing=sin(clock*rate)*sign
		var local=Vector3(base.x*sign,base.y+lift*maxf(0,swing)+sin(clock*2)*.003*(1-moving),base.z-forward*swing)
		local.x+=sign*.015*moving*cos(clock*rate)
		result[side]=frame*local
	return result
