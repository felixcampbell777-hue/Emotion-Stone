extends SceneTree
const Profiles=preload("res://scripts/weapon_profiles.gd")
const Motion=preload("res://scripts/weapon_motion.gd")
const Ballistics=preload("res://scripts/arrow_ballistics.gd")
const Models=preload("res://scripts/weapon_models.gd")
const Runtime=preload("res://scripts/weapon_runtime.gd")
class Growth extends RefCounted:
 func rank(_id:String) -> int:return 0
class Gear extends RefCounted:
 var owned=["wooden_arrows","hunting_bow"]
 var quantities={"wooden_arrows":3}
 func bonus(_id:String) -> float:return 0.0
class GameFixture extends Node:
 var progression=Growth.new()
 var magic_items=Gear.new()
 var game_mode="world_rise"
 var current_world:Node3D
 var enemies=[]
 func notify(_message:String) -> void:pass
class TargetFixture extends Node3D:
 var definition={"combat_radius":.5,"combat_height":1.0}
class AnimatorFixture extends RefCounted:
 func get_animation(_key:String) -> Dictionary:return {"length":1.0}
 func seek(_time:float,_update:bool) -> void:pass
class DriverFixture extends RefCounted:
 var runtime:RefCounted
 var rig:Skeleton3D
 var samples=0
 func sample_first_person(_delta:float,_present:bool) -> Transform3D:
  samples+=1
  if samples==1:runtime.apply_rig(rig,false)
  return Transform3D(Basis.IDENTITY,Vector3(8,1.5,0))
class ActorFixture extends CharacterBody3D:
 var clips={"attack_thrust":"thrust","drag_idle_loop":"idle","idle_loop":"idle"}
 var presentation_clock=0.0
 var animator=AnimatorFixture.new()
 var skeleton:Skeleton3D
 var state="free"
 var state_time=0.0
 var state_duration=1.0
 var input_enabled=true
 var simulation_enabled=false
 var sword_drawn=true
 var sword_equipped=true
 var health=100
 var stamina=100.0
 var action_sequence=0
 var attack_direction=Vector3.FORWARD
 var attack_yaw=0.0
 var first_person_driver=null
 var movement_camera_yaw=0.0
 var visual=Node3D.new()
 var equipment=Node3D.new()
 func _init() -> void:add_child(visual);add_child(equipment)
 func can_afford(cost:float) -> bool:return stamina>=cost
 func spend_stamina(cost:float) -> bool:
  if not can_afford(cost):return false
  stamina-=cost;return true
 func facing() -> Vector3:return Vector3.FORWARD
 func play_clip(_key:String,_blend:float) -> void:pass
 func action_context() -> Dictionary:return {"actor_id":"fixture","action_id":"fixture:"+str(action_sequence)}
var failures:Array[String]=[]
func check(condition:bool,label:String) -> void:
 if not condition:failures.append(label);push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 for id in ["standard_greatsword","improved_standard_greatsword","wolfs_bane_greatsword"]:
  check(Profiles.kind(id)=="greatsword" and Profiles.profile(id).legacy,"Greatsword compatibility identity")
 var spear=Profiles.profile("field_spear");var rapier=Profiles.profile("duelist_rapier");var bow=Profiles.profile("hunting_bow")
 check(spear.length>rapier.length,"Spear longest authored melee reach")
 check(rapier.duration<spear.duration,"Rapier thrust quicker than spear")
 check(bow.recovery_seconds<bow.arrow_recovery_seconds,"Bow action/recoverable arrow lifetimes independent")
 for profile in [spear,rapier]:
  var previous=Vector3.ZERO
  for i in range(121):
   var t=float(i)/120;var sample=Motion.sample(profile.kind,"attack",t)
   var transform=Motion.weapon_transform(Transform3D.IDENTITY,sample)
   var segment=Motion.contact_segments(transform,profile)
   check(absf(segment[0].distance_to(segment[1])-profile.damaging_length)<.0001,"Real damaging segment length")
   if i>0:check(sample.grip.distance_to(previous)<.10,"Continuous authored grip path")
   previous=sample.grip
 var origin=Vector3(0,1.5,0);var initial=Ballistics.velocity(Vector3.FORWARD,.75,bow)
 var step=float(bow.step_seconds);var at=origin;var speed=initial
 for i in range(120):
  var next=Ballistics.advance(at,speed,step,bow.gravity);at=next.position;speed=next.velocity
 var exact=Ballistics.advance(origin,initial,120*step,bow.gravity)
 check(at.distance_to(exact.position)<.0001,"Ballistic fixed steps match analytic flight")
 # Actual physics wall: preview and live integration stop on the same first segment.
 var world=Node3D.new();root.add_child(world)
 var wall=StaticBody3D.new();wall.collision_layer=1;world.add_child(wall);wall.position=Vector3(0,1,-3)
 var collider=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(4,4,.2);collider.shape=box;wall.add_child(collider)
 await physics_frame;await physics_frame
 var state=world.get_world_3d().direct_space_state
 # Query-only player anatomy includes the head above the unchanged locomotion capsule.
 var combat_actor=ActorFixture.new();world.add_child(combat_actor);combat_actor.position=Vector3(0,0,-1.5)
 combat_actor.skeleton=Skeleton3D.new();combat_actor.add_child(combat_actor.skeleton)
 var anchors={"pelvis":Vector3(0,.82,0),"head":Vector3(0,1.50,0),"upper_arm.L":Vector3(-.17,1.28,0),"upper_arm.R":Vector3(.17,1.28,0)}
 for anchor in anchors:
  combat_actor.skeleton.add_bone(anchor)
  combat_actor.skeleton.set_bone_rest(combat_actor.skeleton.find_bone(anchor),Transform3D(Basis.IDENTITY,anchors[anchor]))
 combat_actor.skeleton.reset_bone_poses();combat_actor.skeleton.force_update_all_bone_transforms()
 var eye=Vector3(0,1.55,0);var behind=Vector3(0,1.55,-5)
 var head_hit=Ballistics.sweep(state,eye,behind,[],[combat_actor])
 check(head_hit.get("collider")==combat_actor and head_hit.get("player_region")=="head","Combined bow query hits visible player head above movement capsule")
 check(head_hit.get("normal",Vector3.ZERO).is_normalized(),"Player impact supplies a surface normal for preview circle")
 var self_ignored=Ballistics.sweep(state,eye,behind,[combat_actor.get_rid()],[combat_actor])
 check(self_ignored.get("collider")==wall,"Bow excludes its owner anatomy and still finds scenery")
 var blocked_player=Ballistics.launch(state,eye,Vector3(0,1.55,-2.2),Vector3.FORWARD,bow,[],[combat_actor])
 check(not blocked_player.valid and blocked_player.hit.collider==combat_actor,"Eye-to-muzzle cannot bypass close player anatomy")
 wall.position.z=-.6;await physics_frame;await physics_frame
 var blocked_head=Ballistics.sweep(state,eye,behind,[],[combat_actor])
 check(blocked_head.get("collider")==wall,"Nearer scenery blocks an otherwise valid head hit")
 wall.position.z=-3;await physics_frame;await physics_frame
 var preview_head=Ballistics.predict(state,eye,Ballistics.velocity(Vector3.FORWARD,1,bow),bow,[],[combat_actor])
 check(preview_head.hit.get("collider")==combat_actor,"Ballistic preview uses the same visible player anatomy")
 var head_position=eye;var head_velocity=Ballistics.velocity(Vector3.FORWARD,1,bow);var head_live={}
 for i in range(300):
  var next=Ballistics.advance(head_position,head_velocity,step,bow.gravity)
  head_live=Ballistics.sweep(state,head_position,next.position,[],[combat_actor])
  if not head_live.is_empty():break
  head_position=next.position;head_velocity=next.velocity
 check(head_live.get("collider")==combat_actor and head_live.position.distance_to(preview_head.hit.position)<.0001,"Cached-pose preview and live arrow hit identical player surface")
 combat_actor.queue_free();await physics_frame
 var prediction=Ballistics.predict(state,origin,initial,bow)
 check(not prediction.hit.is_empty(),"Preview finds colliding wall")
 at=origin;speed=initial;var live_hit={}
 for i in range(300):
  var next=Ballistics.advance(at,speed,step,bow.gravity);live_hit=Ballistics.sweep(state,at,next.position)
  if not live_hit.is_empty():break
  at=next.position;speed=next.velocity
 check(not live_hit.is_empty() and live_hit.position.distance_to(prediction.hit.position)<.0001,"Preview and live first impact agree")
 var floor_body=StaticBody3D.new();floor_body.collision_layer=1;world.add_child(floor_body);floor_body.position=Vector3(0,-.1,-80)
 var floor_collision=CollisionShape3D.new();var floor_box=BoxShape3D.new();floor_box.size=Vector3(20,.2,200);floor_collision.shape=floor_box;floor_body.add_child(floor_collision)
 await physics_frame;await physics_frame
 for pitch in [-.65,.65]:
  var aimed=Basis(Vector3.RIGHT,pitch)*Vector3.FORWARD
  var aimed_velocity=Ballistics.velocity(aimed,1,bow)
  var aimed_preview=Ballistics.predict(state,origin,aimed_velocity,bow)
  var live_position=origin;var live_velocity=aimed_velocity;var pitched_hit={}
  for i in range(ceili(float(bow.lifetime)/step)):
   var next=Ballistics.advance(live_position,live_velocity,step,bow.gravity)
   pitched_hit=Ballistics.sweep(state,live_position,next.position)
   if not pitched_hit.is_empty():break
   live_position=next.position;live_velocity=next.velocity
  check(not pitched_hit.is_empty() and not aimed_preview.hit.is_empty() and pitched_hit.position.distance_to(aimed_preview.hit.position)<.0001,"Steep pitch preview matches live wall/ground impact")
 var denied=Ballistics.launch(state,origin,Vector3(0,1,-4),Vector3.FORWARD,bow)
 check(not denied.valid,"Muzzle cannot spawn behind a wall")
 var game=GameFixture.new();root.add_child(game);game.current_world=world
 var actor=ActorFixture.new();world.add_child(actor);actor.position=Vector3(8,0,0)
 var runtime=Runtime.new();runtime.configure(game,actor);runtime.equip("hunting_bow")
 check(runtime.begin_primary(),"Bow first draw accepted")
 check(runtime.action_context().attacker_id=="fixture" and runtime.action_context().action_id==actor.action_context().action_id,"Weapon attribution uses canonical Actor identity and action sequence")
 actor.state_time=.8;runtime.tick(.8)
 check(runtime.release_primary(),"Bow first release accepted")
 check(game.magic_items.quantities.wooden_arrows==2,"Bow consumes exactly one arrow on release")
 actor.state_time=.5;runtime.tick(.5)
 check(actor.state=="free","Bow recovery finishes after half a second")
 check(runtime.begin_primary(),"Bow can draw again after recovery")
 actor.state_time=.8;runtime.tick(.8)
 check(runtime.release_primary(),"Bow repeat release accepted")
 check(game.magic_items.quantities.wooden_arrows==1,"Bow second shot consumes one more arrow")
 runtime.cancel();check(actor.state=="free","Equipment cancellation clears custom action")
 check(runtime.begin_primary(),"Draw can restart after cancellation")
 runtime.cancel();check(game.magic_items.quantities.wooden_arrows==1,"Canceled bow draw does not consume arrow")
 runtime.cancel()
 actor.sword_drawn=false;runtime.pose("ready",0)
 var carry=runtime.model.global_transform
 actor.state="draw";actor.state_time=0;runtime.pose("drag",0)
 check(runtime.model.global_transform.is_equal_approx(carry),"New weapon draw begins at the actual carry transform")
 runtime.pose("drag",1);var ready=runtime.model.global_transform
 actor.state="sheathe";runtime.pose("drag",0)
 check(runtime.model.global_transform.is_equal_approx(ready),"Sheathe begins at forward ready without snapping")
 runtime.pose("drag",1)
 check(runtime.model.global_transform.is_equal_approx(carry),"Sheathe returns exactly to actual carry")
 actor.sword_equipped=false;runtime.pose("ready",0)
 check(not runtime.model.visible,"Unequipped new weapon is invisible")
 actor.sword_equipped=true;actor.sword_drawn=true
 for weapon_id in ["field_spear","duelist_rapier"]:
  runtime.equip(weapon_id);actor.state="weapon_attack";actor.state_duration=float(runtime.settings.duration);actor.state_time=actor.state_duration*.4;runtime.pose("attack",.4)
  var steel=runtime.contact_segments();var steel_center:Vector3=steel[1]
  var target=TargetFixture.new();world.add_child(target);target.global_position=Vector3(steel_center.x,0,steel_center.z)
  check(runtime.hits(target,steel),"Level aim connects real "+weapon_id+" steel with ordinary low enemy")
  target.queue_free()
 # Camera sampling may synchronize the observer rig: rig fitting must never resample it.
 var rig=Skeleton3D.new();world.add_child(rig)
 rig.add_bone("upper_arm.R");rig.add_bone("forearm.R");rig.set_bone_parent(1,0)
 rig.set_bone_rest(0,Transform3D(Basis.IDENTITY,Vector3(8.2,1.3,0)))
 rig.set_bone_rest(1,Transform3D(Basis.IDENTITY,Vector3(0,.3,0)))
 rig.reset_bone_poses();rig.force_update_all_bone_transforms()
 var driver=DriverFixture.new();driver.runtime=runtime;driver.rig=rig;actor.first_person_driver=driver
 actor.state="free";actor.sword_drawn=true;runtime.pose("ready",0)
 check(driver.samples==1,"Observer rig fit does not recursively sample the camera")
 actor.first_person_driver=null;driver.runtime=null;rig.queue_free()
 runtime=null;game.queue_free()
 for profile in [spear,rapier,bow]:
  var model=Models.create(profile.kind,profile);world.add_child(model)
  check(model.get_child_count()>0,"Weapon visual contains authored geometry")
 print("WEAPON_CHECKS "+("PASS" if failures.is_empty() else "FAIL "+str(failures)))
 world.queue_free();quit(0 if failures.is_empty() else 1)
