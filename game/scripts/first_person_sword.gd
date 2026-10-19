extends RefCounted
## Camera-space grip paths own the real steel, not a decorative weapon overlay.
var definition=JSON.parse_string(FileAccess.get_file_as_string("res://content/first_person_motion.json"))
var gait_phase=0.0
var gait_clock=-1.0
var gait_actor_id=0
var gait_rate=7.0
func reset_gait(actor:Node3D) -> void:
	gait_actor_id=actor.get_instance_id();gait_clock=float(actor.presentation_clock);gait_phase=0.0
	gait_rate=10.5 if actor.sprinting else 7.0
func update_gait(actor:Node3D) -> void:
	var clock=float(actor.presentation_clock)
	var rate=10.5 if actor.sprinting else 7.0
	if gait_actor_id!=actor.get_instance_id() or clock<gait_clock:
		reset_gait(actor)
	var delta=clampf(clock-gait_clock,0,.1)
	gait_phase=fposmod(gait_phase+delta*(gait_rate+rate)*.5,TAU)
	gait_clock=clock;gait_rate=rate
func vector(value:Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])
func path_vector(frame:Dictionary,field:String) -> Vector3:
	var value=vector(frame[field])
	return value.normalized() if field=="direction" else value
func path_slope(frames:Array,index:int,field:String) -> Vector3:
	# Keep deliberate ready/catch endpoints still, including both combo joins.
	if index==0 or index==frames.size()-1 or is_equal_approx(float(frames[index].t),.74):return Vector3.ZERO
	var a=path_vector(frames[index-1],field);var b=path_vector(frames[index],field);var c=path_vector(frames[index+1],field)
	var before=(b-a)/(float(frames[index].t)-float(frames[index-1].t))
	var after=(c-b)/(float(frames[index+1].t)-float(frames[index].t))
	var slope=Vector3.ZERO
	for axis in range(3):
		if before[axis]*after[axis]>0:slope[axis]=2*before[axis]*after[axis]/(before[axis]+after[axis])
	return slope
func continuous_vector(frames:Array,index:int,field:String,t:float) -> Vector3:
	var a=frames[index];var b=frames[index+1];var duration=float(b.t)-float(a.t)
	var f=clampf((t-float(a.t))/duration,0,1)
	# Monotone component tangents stay inside the authored interval envelope.
	# Interior passing keys no longer force the steel to stop during a cut.
	return path_vector(a,field)*(2*f*f*f-3*f*f+1)+path_slope(frames,index,field)*duration*(f*f*f-2*f*f+f)+path_vector(b,field)*(-2*f*f*f+3*f*f)+path_slope(frames,index+1,field)*duration*(f*f*f-f*f)
func sample(key:String,t:float) -> Dictionary:
	var ready=definition.ready
	if not definition.paths.has(key): return {"grip":vector(ready.grip),"direction":vector(ready.direction).normalized()}
	var frames=definition.paths[key]
	for index in range(frames.size()-1):
		var a=frames[index];var b=frames[index+1]
		if t<=float(b.t):
			if key in ["light","light2"]:
				return {"grip":continuous_vector(frames,index,"grip",t),"direction":continuous_vector(frames,index,"direction",t).normalized()}
			var f=smoothstep(float(a.t),float(b.t),t)
			return {"grip":vector(a.grip).lerp(vector(b.grip),f),"direction":vector(a.direction).normalized().slerp(vector(b.direction).normalized(),f)}
	return {"grip":vector(frames[-1].grip),"direction":vector(frames[-1].direction).normalized()}
func apply(actor:Node3D,key:String,t:float) -> void:
	update_gait(actor)
	var frame:Transform3D=actor.first_person_driver.sample_first_person(0,not actor.is_physics_processing() and not actor.get_meta("canonical_manual_step",false))
	if key=="light" and actor.dash_uppercut: key="dash_uppercut"
	actor.set_meta("view_sword_sample",{"key":key,"phase":t})
	var pose=sample(key,t)
	if key=="drag":
		if actor.dash_attack_blend>0:
			var loaded=sample("dash_uppercut",actor.DASH_ATTACK_PHASE)
			var weight=smoothstep(0,1,actor.dash_attack_blend)
			pose.grip=pose.grip.lerp(loaded.grip,weight)
			pose.direction=pose.direction.slerp(loaded.direction,weight)
		var moving=actor.velocity.length_squared()>.05
		pose.grip+=Vector3(sin(gait_phase)*.008,sin(gait_phase*2)*(.015 if moving else .004),cos(gait_phase)*(.015 if moving else .003))*(1-actor.dash_attack_blend)
	var reach=(actor.BetaSwordMotion.GRIP-actor.BetaSwordMotion.TIP)*float(actor.combat.sword_scale) if actor.equipment.get_meta("beta_sword",false) else 2.128
	var floor_y=float(actor.position.y)
	if key in ["heavy","light3","dash_uppercut"] or (key=="drag" and actor.dash_attack_blend>0):
		if is_instance_valid(actor.ground_world):floor_y=actor.ground_world.ground_height(frame*pose.grip)
	var world=contact_pose(frame,pose,key,t,reach,floor_y,key=="drag" and actor.dash_attack_blend>0)
	var hilt=actor.BetaSwordMotion.GRIP if actor.equipment.get_meta("beta_sword",false) else .16
	var desired=Transform3D(world.basis*float(actor.combat.sword_scale),world.grip-world.basis*Vector3(0,hilt*float(actor.combat.sword_scale),0))
	var weight=1.0
	if key=="roll": weight=1-smoothstep(0,.10,t)
	elif key=="stand": weight=smoothstep(.72,1,t)
	actor.equipment.global_transform=actor.equipment.global_transform.interpolate_with(desired,weight)

## Pure shared steel placement. Callers supply the accepted view frame, including
## authored head/root offsets and collision correction; eye/yaw/pitch alone is
## not equivalent to that frame. No camera, skeleton or mutable gait is read here.
func contact_pose(frame:Transform3D,pose:Dictionary,key:String,t:float,reach:float,floor_y:float,loaded_uppercut:bool=false) -> Dictionary:
	var grip:Vector3=frame*pose.grip
	var direction:Vector3=(frame.basis*pose.direction).normalized()
	if (key=="dash_uppercut" or loaded_uppercut) and direction.y<0:
		var down=clampf((floor_y+.035-grip.y)/reach,-.98,.98)
		if direction.y<down: direction=Vector3(direction.x,0,direction.z).normalized()*sqrt(1-down*down)+Vector3.UP*down
	if key in ["heavy","light3"]:
		var weight=smoothstep(.58,.68,t)*(1-smoothstep(.82,.92,t))
		var down=clampf((floor_y+.03-grip.y)/reach,-.98,.98)
		var forward=Vector3(direction.x,0,direction.z).normalized()
		var ground_direction=forward*sqrt(1-down*down)+Vector3.UP*down
		direction=direction.slerp(ground_direction,weight)
	var up=-direction
	var right=frame.basis.x-up*frame.basis.x.dot(up)
	if right.length_squared()<.00001: right=frame.basis.y-up*frame.basis.y.dot(up)
	right=right.normalized()
	var basis=Basis(right,up,right.cross(up))
	return {"grip":grip,"direction":direction,"basis":basis,"tip":grip+direction*reach}
