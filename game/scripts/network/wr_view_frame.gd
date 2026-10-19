extends RefCounted
## Shared first-person world frame. The authority supplies its real accepted Actor;
## client camera nodes and client-supplied bone transforms are never required.
## This deliberately does not approximate the animated head with an eye height.

## A headless Actor can use this object as first_person_driver. Only the
## authority writes yaw/pitch; all body/head/action state remains Actor-owned.
var accepted_actor:Node3D
var tuning:Dictionary={}
var yaw=PI
var first_pitch=0.0
var locomotion_camera_blend=0.0
var shape_query:PhysicsShapeQueryParameters3D
var eye_height=1.52

func bind(actor:Node3D,settings:Dictionary) -> void:
	accepted_actor=actor;tuning=settings;shape_query=collision_query()
	eye_height=float(settings.get("first_person_eye_height",1.52))
	actor.first_person_driver=self

func sample_first_person(delta:float=0.0,advance_gait:bool=true) -> Transform3D:
	assert(is_instance_valid(accepted_actor),"A headless view driver requires its accepted Actor")
	accepted_actor.camera_relative=true
	accepted_actor.movement_camera_yaw=yaw
	if accepted_actor.input_enabled and accepted_actor.state=="free":
		accepted_actor.visual.rotation.y=wrapf(yaw-PI,-PI,PI)
	locomotion_camera_blend=locomotion_blend(accepted_actor,locomotion_camera_blend,delta,advance_gait)
	return from_actor(accepted_actor,tuning,yaw,first_pitch,locomotion_camera_blend,accepted_actor.get_world_3d().direct_space_state,shape_query,eye_height)

static func actor_rig(actor:Node3D) -> Skeleton3D:
	var rig:Skeleton3D=actor.skeleton
	if actor.has_node("BetaHero"):
		var hero=actor.get_node("BetaHero")
		hero.synchronize()
		rig=hero.rig
	rig.force_update_all_bone_transforms()
	return rig

## Called once by Actor physics before any action pose is sampled. Render passes
## only read this envelope, so 30/60/120 FPS cannot alter contact geometry.
static func advance_actor(actor:Node3D,delta:float) -> void:
	var previous=float(actor.get_meta("canonical_view_blend",0.0))
	var next=previous
	if actor.state!="free":next=0.0
	elif actor.input_enabled:
		var walking=actor.current_clip in ["walk_loop","drag_walk_loop"]
		next=move_toward(previous,1.0 if walking else 0.0,delta/.16)
	actor.set_meta("canonical_view_blend",next)

static func locomotion_blend(actor:Node3D,previous:float,delta:float,advance:bool) -> float:
	if actor.has_meta("canonical_view_blend") and (actor.is_physics_processing() or actor.get_meta("canonical_manual_step",false)):return float(actor.get_meta("canonical_view_blend"))
	if actor.state!="free":return 0.0
	if not actor.input_enabled or not advance:return previous
	var walking=actor.current_clip in ["walk_loop","drag_walk_loop"]
	var target=1.0 if walking else 0.0
	return move_toward(previous,target,delta/.16) if delta>0 else target

static func lance_charge_offset(progress:float,stability:float,tuning:Dictionary) -> Vector2:
	var seconds=progress*3.0
	var motion=Vector2(sin(seconds*8.3+sin(seconds*3.1))*.23,sin(seconds*11.9+.8)*.20)
	var impulses=[Vector2(-1,.5),Vector2(.85,-.8),Vector2(-.6,-1),Vector2(1,.65),Vector2(-.95,.4),Vector2(.7,-.9),Vector2(-.85,-.7)]
	var times=[.18,.34,.51,.65,.80,.93,.985]
	for index in range(times.size()):
		var elapsed=(progress-times[index])*3.0
		if elapsed>0:motion+=impulses[index]*smoothstep(0,.035,elapsed)*exp(-elapsed*11)
	motion.x=clampf(motion.x,-1,1);motion.y=clampf(motion.y,-1,1)
	var buildup=smoothstep(0,.12,progress)*lerpf(.35,1,progress)
	var control=1-clampf(stability,0,.75)
	return motion*Vector2(deg_to_rad(float(tuning.get("first_person_lance_yaw_degrees",6))),deg_to_rad(float(tuning.get("first_person_lance_pitch_degrees",4))))*buildup*control

static func lance_offset(actor:Node3D,tuning:Dictionary) -> Vector2:
	if actor.state=="lance_charge":
		return lance_charge_offset(clampf(actor.state_time/actor.state_duration,0,1),actor.lance_stability,tuning)
	if actor.state=="lance_fire":
		return lance_charge_offset(1,actor.lance_stability,tuning)*(1-smoothstep(0,.38,actor.state_time/actor.state_duration))
	return Vector2.ZERO

static func from_actor(actor:Node3D,tuning:Dictionary,yaw:float,pitch:float,locomotion:float,space:PhysicsDirectSpaceState3D,query:PhysicsShapeQueryParameters3D,eye:float=1.52) -> Transform3D:
	return from_rig(actor,actor_rig(actor),tuning,yaw,pitch,locomotion,space,query,eye)

static func from_rig(actor:Node3D,rig:Skeleton3D,tuning:Dictionary,yaw:float,pitch:float,locomotion:float,space:PhysicsDirectSpaceState3D,query:PhysicsShapeQueryParameters3D,eye:float=1.52) -> Transform3D:
	var head=rig.find_bone("head")
	assert(head>=0,"Authoritative first-person frame requires the accepted animated head")
	var rest=rig.get_bone_global_rest(head)
	var pose=rig.get_bone_global_pose(head)
	var eye_bind=rig.global_transform.affine_inverse()*(actor.global_position+Vector3(0,eye,0))
	var eye_local=rest.affine_inverse()*eye_bind
	var head_world=rig.global_transform*pose
	var spinning=actor.state=="light" and actor.combo_stage==3
	var base_facing=actor.attack_yaw if spinning else actor.visual.rotation.y
	var mouse_offset=wrapf(yaw-base_facing-PI,-PI,PI)
	var orientation=(rig.global_basis*pose.basis*rest.basis.inverse()*Basis(Vector3.UP,PI+mouse_offset)*Basis(Vector3.RIGHT,-pitch)).orthonormalized()
	var chest=actor.position+Vector3(0,.65,0)
	var forward=-orientation.z
	var desired_eye=head_world*eye_local+forward*.18
	var motion_scale=lerpf(1.0,float(tuning.get("first_person_movement_motion",.5)),locomotion)
	if motion_scale<1.0:
		var look_basis=Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,-pitch)
		var neutral_eye=actor.global_position+Vector3(0,eye,0)-look_basis.z*.18
		var view_pose=Transform3D(look_basis,neutral_eye).interpolate_with(Transform3D(orientation,desired_eye),motion_scale)
		orientation=view_pose.basis;desired_eye=view_pose.origin;forward=-orientation.z
	if actor.state=="parry":
		var phase=actor.parry_pose_phase(actor.state_time/actor.state_duration)
		var guard=smoothstep(0,.12,phase)*(1-smoothstep(.82,1,phase))
		var parry_scale=lerpf(1.0,float(tuning.get("first_person_parry_motion",.2)),guard)
		var look_basis=Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,-pitch)
		orientation=Basis(look_basis.get_rotation_quaternion().slerp(orientation.get_rotation_quaternion(),parry_scale))
		forward=-orientation.z
		desired_eye=head_world*eye_local+forward*.18
	var kick=lance_offset(actor,tuning)
	if not kick.is_zero_approx():
		orientation=(orientation*Basis(Vector3.UP,kick.x)*Basis(Vector3.RIGHT,kick.y)).orthonormalized()
		forward=-orientation.z;desired_eye=head_world*eye_local+forward*.18
	query.transform=Transform3D(Basis.IDENTITY,chest)
	query.motion=desired_eye-chest
	var fractions=space.cast_motion(query)
	return Transform3D(orientation,chest+query.motion*fractions[0])

static func collision_query() -> PhysicsShapeQueryParameters3D:
	var query=PhysicsShapeQueryParameters3D.new()
	var sphere=SphereShape3D.new();sphere.radius=.18
	query.shape=sphere;query.collision_mask=1|8
	return query
