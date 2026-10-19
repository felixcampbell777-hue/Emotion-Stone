extends SceneTree
## Isolated mathematical regression for the shared head/root frame extraction.
## This does not certify network clock replication; that is a separate bridge test.
const Frame=preload("res://scripts/network/wr_view_frame.gd")
const Actor=preload("res://scripts/actor.gd")
const Sword=preload("res://scripts/first_person_sword.gd")
class Slope:
	extends Node3D
	func ground_height(at:Vector3) -> float:return .8+.15*at.x

var failures=0
var samples=0
var maximum=0.0
func check(ok:bool,message:String) -> void:
	if not ok:
		failures+=1
		if failures<4:push_error(message)
func _initialize() -> void:call_deferred("run")
func reference(actor:Node3D,rig:Skeleton3D,yaw:float,pitch:float,blend:float,tuning:Dictionary,query:PhysicsShapeQueryParameters3D) -> Transform3D:
	# Frozen pre-extraction client equation, evaluated independently of Frame.
	var h=rig.find_bone("head");var rest=rig.get_bone_global_rest(h);var pose=rig.get_bone_global_pose(h)
	var bind=rig.global_transform.affine_inverse()*(actor.global_position+Vector3.UP*1.52)
	var head_world=rig.global_transform*pose
	var facing=actor.attack_yaw if actor.state=="light" and actor.combo_stage==3 else actor.visual.rotation.y
	var orientation=(rig.global_basis*pose.basis*rest.basis.inverse()*Basis(Vector3.UP,PI+wrapf(yaw-facing-PI,-PI,PI))*Basis(Vector3.RIGHT,-pitch)).orthonormalized()
	var desired=head_world*(rest.affine_inverse()*bind)-orientation.z*.18
	var scale=lerpf(1.0,float(tuning.get("first_person_movement_motion",.5)),blend)
	if scale<1:
		var look=Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,-pitch)
		var reduced=Transform3D(look,actor.global_position+Vector3.UP*1.52-look.z*.18).interpolate_with(Transform3D(orientation,desired),scale)
		orientation=reduced.basis;desired=reduced.origin
	if actor.state=="parry":
		var phase=actor.parry_pose_phase(actor.state_time/actor.state_duration)
		var amount=lerpf(1,float(tuning.get("first_person_parry_motion",.2)),smoothstep(0,.12,phase)*(1-smoothstep(.82,1,phase)))
		var look=Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,-pitch)
		orientation=Basis(look.get_rotation_quaternion().slerp(orientation.get_rotation_quaternion(),amount))
		desired=head_world*(rest.affine_inverse()*bind)-orientation.z*.18
	var chest=actor.position+Vector3.UP*.65
	query.transform=Transform3D(Basis.IDENTITY,chest);query.motion=desired-chest
	return Transform3D(orientation,chest+query.motion*actor.get_world_3d().direct_space_state.cast_motion(query)[0])
func run() -> void:
	var world=Slope.new();root.add_child(world)
	var actor=Actor.new();world.add_child(actor);actor.set_physics_process(false);actor.set_process(false)
	actor.configure(JSON.parse_string(FileAccess.get_file_as_string("res://content/characters/hero.json")))
	actor.ground_world=world
	var driver=Frame.new();driver.bind(actor,{"first_person_movement_motion":.5,"first_person_parry_motion":.2})
	actor.set_sword_drawn(true)
	var query=Frame.collision_query();var other_query=Frame.collision_query()
	var sword=Sword.new();var tuning={"first_person_movement_motion":.5,"first_person_parry_motion":.2}
	await physics_frame
	for personal in [false,true]:
		preload("res://scripts/beta_hero.gd").apply(actor,personal)
		if actor.has_node("BetaHero"):actor.get_node("BetaHero").set_process(false)
		for clip in ["drag_idle_loop","drag_walk_loop","attack_light","attack_light2","attack_light3","attack_heavy","attack_thrust","parry_guard"]:
			actor.state="free" if clip.ends_with("loop") else "parry" if clip=="parry_guard" else "light" if clip.begins_with("attack_light") else "heavy"
			actor.combo_stage=3 if clip=="attack_light3" else 2 if clip=="attack_light2" else 1
			actor.state_duration=1.0;actor.play_clip(clip,0)
			for phase in [0.0,.08,.28,.34,.52,.60,.68,.74,.92,1.0]:
				actor.state_time=phase;actor.animator.seek(actor.animator.get_animation(actor.clips[clip]).length*phase,true)
				for pitch in [-1.15,0.0,1.15]:
					for yaw in [-2.3,.7]:
						actor.position=Vector3(2.4+phase*3,.8+phase*.45,-3.1+phase);actor.visual.rotation.y=yaw-PI+(actor.spin_rotation(phase) if clip=="attack_light3" else 0.0);actor.attack_yaw=yaw-PI
						var rig=Frame.actor_rig(actor)
						var blend=.7 if clip=="drag_walk_loop" else 0.0
						var actual=Frame.from_rig(actor,rig,tuning,yaw,pitch,blend,actor.get_world_3d().direct_space_state,query)
						var expected=reference(actor,rig,yaw,pitch,blend,tuning,other_query)
						var error=maxf(actual.origin.distance_to(expected.origin),maxf(actual.basis.x.distance_to(expected.basis.x),maxf(actual.basis.y.distance_to(expected.basis.y),actual.basis.z.distance_to(expected.basis.z))))
						maximum=maxf(maximum,error);samples+=1
						check(error<.00001,"Accepted animated head/root frame differs from original client equation")
						for path in ["light","light2","light3","heavy","dash_uppercut","thrust"]:
							var pose=sword.sample(path,phase);var reach=2.128
							var contact=sword.contact_pose(actual,pose,path,phase,reach,.8+.15*(actual*pose.grip).x)
							check(absf(contact.grip.distance_to(contact.tip)-reach)<.00001,"Slope-fitted steel keeps physical reach")
							check(absf(contact.basis.determinant()-1)<.00001,"Contact transverse basis keeps nonzero width")
							# Apply through the actual rendered equipment path, then independently
							# reconstruct its exact mesh endpoints from the headless world pose.
							driver.yaw=yaw;driver.first_pitch=pitch;driver.locomotion_camera_blend=blend
							actor.first_person_sword.apply(actor,path,phase)
							var live_frame=driver.sample_first_person(0,false)
							var beta=actor.equipment.get_meta("beta_sword",false)
							var shape=preload("res://scripts/beta_sword_motion.gd")
							var scale=float(actor.combat.sword_scale)
							var physical_reach=(shape.GRIP-shape.TIP)*scale if beta else 2.128
							var steel=sword.contact_pose(live_frame,pose,path,phase,physical_reach,world.ground_height(live_frame*pose.grip))
							var hilt=shape.GRIP if beta else .16
							var mesh=Transform3D(steel.basis*scale,steel.grip-steel.basis*Vector3(0,hilt*scale,0))
							var rails=actor.blade_segment()
							check(absf(actor.equipment.global_basis.x.length()-scale)<.00001,"Steel world width retains the accepted mesh scale")
							check(rails[0].distance_to(mesh*Vector3(0,shape.BLADE_BASE if beta else -.05,0))<.00001,"Headless contact base matches actual rendered steel")
							check(rails[1].distance_to(mesh*Vector3(0,shape.TIP if beta else -1.17,0))<.00001,"Headless contact tip matches actual rendered steel")
	# The sphere cast must constrain both owners against actual scenery, rather
	# than silently using an unconstrained head transform on a headless server.
	actor.state="free";actor.position=Vector3.ZERO;actor.visual.rotation.y=0
	actor.play_clip("drag_idle_loop",0);actor.animator.seek(0,true)
	var clear=Frame.from_actor(actor,tuning,PI,0,0,actor.get_world_3d().direct_space_state,query)
	var ceiling=StaticBody3D.new();ceiling.collision_layer=1;world.add_child(ceiling)
	var collider=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(4,.1,4);collider.shape=box;ceiling.add_child(collider);ceiling.position=Vector3(0,1.05,0)
	await physics_frame
	var constrained=Frame.from_actor(actor,tuning,PI,0,0,actor.get_world_3d().direct_space_state,query)
	check(constrained.origin.y<clear.origin.y-.25,"Headless frame respects the same physical camera obstruction")
	var independent=reference(actor,Frame.actor_rig(actor),PI,0,0,tuning,other_query)
	check(constrained.origin.distance_to(independent.origin)<.00001,"Obstructed headless and rendered frames agree")
	check(samples==960,"Both source and personal rigs cover every action/time/steep aim sample")
	print("View frame extraction: samples=",samples," max_error=",maximum," failures=",failures)
	world.queue_free();await process_frame
	quit(1 if failures else 0)
