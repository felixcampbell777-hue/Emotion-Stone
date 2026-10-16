extends RefCounted
## Camera-space grip paths own the real steel, not a decorative weapon overlay.
var definition=JSON.parse_string(FileAccess.get_file_as_string("res://content/first_person_motion.json"))
func vector(value:Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])
func sample(key:String,t:float) -> Dictionary:
	var ready=definition.ready
	if not definition.paths.has(key): return {"grip":vector(ready.grip),"direction":vector(ready.direction).normalized()}
	var frames=definition.paths[key]
	for index in range(frames.size()-1):
		var a=frames[index];var b=frames[index+1]
		if t<=float(b.t):
			var f=smoothstep(float(a.t),float(b.t),t)
			return {"grip":vector(a.grip).lerp(vector(b.grip),f),"direction":vector(a.direction).normalized().slerp(vector(b.direction).normalized(),f)}
	return {"grip":vector(frames[-1].grip),"direction":vector(frames[-1].direction).normalized()}
func apply(actor:Node3D,key:String,t:float) -> void:
	var frame:Transform3D=actor.first_person_driver.sample_first_person(0,not actor.is_physics_processing())
	if key=="light" and actor.dash_uppercut: key="dash_uppercut"
	actor.set_meta("view_sword_sample",{"key":key,"phase":t})
	var pose=sample(key,t)
	if key=="drag":
		if actor.dash_attack_blend>0:
			var loaded=sample("dash_uppercut",actor.DASH_ATTACK_PHASE)
			var weight=smoothstep(0,1,actor.dash_attack_blend)
			pose.grip=pose.grip.lerp(loaded.grip,weight)
			pose.direction=pose.direction.slerp(loaded.direction,weight)
		var clock=actor.presentation_clock
		var moving=actor.velocity.length_squared()>.05
		var rate=10.5 if actor.sprinting else 7.0
		pose.grip+=Vector3(sin(clock*rate)*.008,sin(clock*rate*2)*(.015 if moving else .004),cos(clock*rate)*(.015 if moving else .003))*(1-actor.dash_attack_blend)
	var grip:Vector3=frame*pose.grip
	var direction:Vector3=(frame.basis*pose.direction).normalized()
	var reach=(actor.BetaSwordMotion.GRIP-actor.BetaSwordMotion.TIP)*float(actor.combat.sword_scale) if actor.equipment.get_meta("beta_sword",false) else 2.128
	if (key=="dash_uppercut" or (key=="drag" and actor.dash_attack_blend>0)) and direction.y<0:
		var floor_y=actor.ground_world.ground_height(grip) if is_instance_valid(actor.ground_world) else actor.position.y
		var down=clampf((floor_y+.035-grip.y)/reach,-.98,.98)
		if direction.y<down: direction=Vector3(direction.x,0,direction.z).normalized()*sqrt(1-down*down)+Vector3.UP*down
	if key in ["heavy","light3"]:
		var weight=smoothstep(.58,.68,t)*(1-smoothstep(.82,.92,t))
		var floor_y=actor.ground_world.ground_height(grip) if is_instance_valid(actor.ground_world) else actor.position.y
		var down=clampf((floor_y+.03-grip.y)/reach,-.98,.98)
		var forward=Vector3(direction.x,0,direction.z).normalized()
		var ground_direction=forward*sqrt(1-down*down)+Vector3.UP*down
		direction=direction.slerp(ground_direction,weight)
	var up=-direction
	var right=frame.basis.x-up*frame.basis.x.dot(up)
	if right.length_squared()<.00001: right=frame.basis.y-up*frame.basis.y.dot(up)
	right=right.normalized()
	var basis=Basis(right,up,right.cross(up))
	var hilt=actor.BetaSwordMotion.GRIP if actor.equipment.get_meta("beta_sword",false) else .16
	var desired=Transform3D(basis*float(actor.combat.sword_scale),grip-basis*Vector3(0,hilt*float(actor.combat.sword_scale),0))
	var weight=1.0
	if key=="draw": weight=smoothstep(.48,.80,t)
	elif key=="roll": weight=1-smoothstep(0,.10,t)
	elif key=="stand": weight=smoothstep(.72,1,t)
	actor.equipment.global_transform=actor.equipment.global_transform.interpolate_with(desired,weight)
