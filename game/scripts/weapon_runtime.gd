extends RefCounted
## Actor-owned clocks and resources; all authored/contact samples are renderer-independent.
const Profiles=preload("res://scripts/weapon_profiles.gd")
const Motion=preload("res://scripts/weapon_motion.gd")
const Models=preload("res://scripts/weapon_models.gd")
const Ballistics=preload("res://scripts/arrow_ballistics.gd")
const Arrow=preload("res://scripts/physical_arrow.gd")
const Preview=preload("res://scripts/bow_preview.gd")
var game:Node
var actor:Node3D
var item_id="standard_greatsword"
var settings:Dictionary={"kind":"greatsword","legacy":true}
var model:Node3D
var preview:Node3D
var previous_segment:Array=[]
var struck:Dictionary={}
var sequence=0
var action_id=""
var targets:Dictionary={}
var last_charge=0.0
var sampled_frame=Transform3D.IDENTITY
var rig_fit=preload("res://scripts/dragon_caster_pose.gd").new()
func configure(owner_game:Node,owner_actor:Node3D) -> void:
 game=owner_game;actor=owner_actor
func enabled() -> bool:return not bool(settings.get("legacy",true))
func active() -> bool:return enabled() and actor.state in ["weapon_attack","bow_draw","weapon_recovery"]
func equip(id:String) -> void:
 cancel();item_id=id;settings=Profiles.profile(id)
 if is_instance_valid(model):model.queue_free()
 model=null
 apply_stats()
 if enabled():
  model=Models.create(settings.kind,settings);actor.add_child(model)
  model.visible=actor.sword_equipped
  actor.equipment.visible=false
 else:actor.equipment.visible=actor.sword_equipped
func online() -> bool:
 return is_instance_valid(game) and game.has_method("online_session_active") and game.online_session_active()
func request_network(action:String,data:Dictionary={}) -> void:
 var session=game.get("network_session")
 if is_instance_valid(session) and session.has_method("request_action"):session.request_action(action,data)
func movement_multiplier() -> float:return float(settings.get("movement_multiplier",1.0))
func next_action() -> void:
 sequence+=1
 action_id=String(actor.action_context().action_id) if actor.has_method("action_context") else "%s:%d"%[actor.name,sequence]
 struck.clear();previous_segment.clear()
func begin_primary() -> bool:
 if not enabled() or not actor.input_enabled or actor.health<=0 or not actor.sword_drawn or actor.state!="free":return false
 if settings.kind=="bow":
  if int(game.magic_items.quantities.get(settings.ammo_id,0))<=0:game.notify("No arrows. Buy Wooden Arrows from the guild.");return false
  if not actor.can_afford(float(settings.stamina)):return false
  actor.state="bow_draw";actor.state_time=0;actor.state_duration=3600.0;last_charge=0
 else:
  if not actor.spend_stamina(float(settings.stamina)):return false
  actor.state="weapon_attack";actor.state_time=0;actor.state_duration=float(settings.duration)
 next_action()
 if online():request_network("primary_down",{})
 actor.attack_direction=actor.facing();actor.attack_yaw=actor.visual.rotation.y
 # Retained rig animation is sampled conservatively; no rejected source regeneration.
 actor.play_clip("idle_loop",.1)
 if actor.has_method("emit_presentation"):actor.emit_presentation("weapon.bow.draw" if settings.kind=="bow" else "weapon."+String(settings.kind)+".thrust",action_context())
 return true
func release_primary() -> bool:
 if not enabled():return false
 if settings.kind!="bow":return active()
 if actor.state!="bow_draw":return false
 last_charge=clampf(actor.state_time/float(settings.draw_max_seconds),0,1)
 var shot=launch_spec()
 if not shot.valid:
  cancel();game.notify("The bow is blocked by nearby scenery.");return false
 if online():
  request_network("primary_up",{})
  actor.state="weapon_recovery";actor.state_time=0;actor.state_duration=float(settings.recovery_seconds)
  if is_instance_valid(preview):preview.visible=false
  return true
 var count=int(game.magic_items.quantities.get(settings.ammo_id,0))
 if count<=0 or not actor.spend_stamina(float(settings.stamina)):cancel();return false
 game.magic_items.quantities[settings.ammo_id]=count-1
 if count==1:game.magic_items.quantities.erase(settings.ammo_id);game.magic_items.owned.erase(settings.ammo_id)
 var arrow=Arrow.new();game.current_world.add_child(arrow)
 var context=action_context();context["damage"]=roundi(float(settings.damage)*lerpf(.55,1.0,last_charge))
 arrow.configure(game,actor,shot.origin,Ballistics.velocity(shot.direction,last_charge,settings),settings,context)
 if actor.has_method("emit_presentation"):actor.emit_presentation("weapon.bow.release",context)
 actor.state="weapon_recovery";actor.state_time=0;actor.state_duration=float(settings.recovery_seconds)
 if is_instance_valid(preview):preview.visible=false
 return true
func cancel() -> void:
 if is_instance_valid(actor) and actor.state=="bow_draw" and online():request_network("cancel_primary")
 if is_instance_valid(preview):preview.visible=false
 previous_segment.clear();struck.clear();last_charge=0
 if is_instance_valid(actor) and actor.state in ["weapon_attack","bow_draw","weapon_recovery"]:actor.state="free";actor.state_time=0
func apply_stats() -> void:
 settings=Profiles.profile(item_id)
 if not enabled() or not is_instance_valid(game):return
 var growth=game.progression;var gear=game.magic_items
 var universal=maxf(.01,1-.02*growth.rank("iron_body")) if game.game_mode=="world_rise" else 1.0
 var damage=1+.02*growth.rank("iron_body") if game.game_mode=="world_rise" else 1.0
 if settings.kind!="bow":damage*=1+gear.bonus("melee")
 settings.damage=roundi(float(settings.damage)*damage*(1+gear.bonus("all_damage")))
 settings.stamina*=universal*maxf(.01,1-.15*growth.rank("honed_arms")) if game.game_mode=="world_rise" else 1.0
func action_context() -> Dictionary:
 var result=actor.action_context().duplicate(true) if actor.has_method("action_context") else {}
 result.merge({"attacker_id":String(result.get("actor_id",actor.get_meta("player_id",actor.name))),"weapon_id":item_id,"weapon_type":settings.get("kind","greatsword"),"action_id":action_id,"strike_index":0,"damage_kind":"projectile" if settings.get("kind","")=="bow" else "melee"},true)
 return result
func view_frame() -> Transform3D:
 if actor.first_person_driver!=null:return actor.first_person_driver.sample_first_person(0,false)
 var yaw=float(actor.get("movement_camera_yaw"))
 return Transform3D(Basis(Vector3.UP,yaw),actor.global_position+Vector3.UP*1.5)
func carry_transform() -> Transform3D:
 var basis=Basis(Vector3.RIGHT,2.7) if settings.kind=="spear" else Basis(Vector3.FORWARD,.25)
 return actor.global_transform*Transform3D(basis,Vector3(-.25,1.3,.18))
func pose(key:String,t:float) -> void:
 if not enabled() or not is_instance_valid(model):return
 var holding=actor.sword_equipped and (actor.sword_drawn or actor.state in ["draw","sheathe"])
 model.visible=actor.sword_equipped
 actor.equipment.visible=false
 if not holding:
  model.global_transform=carry_transform();targets.clear();return
 if actor.state in ["draw","sheathe"]:
  key="draw";t=t if actor.state=="draw" else 1.0-t
 if actor.state=="bow_draw":key="ready";t=0;last_charge=clampf(actor.state_time/float(settings.draw_max_seconds),0,1)
 elif actor.state in ["weapon_attack","weapon_recovery"]:key="attack";t=actor.state_time/actor.state_duration
 if actor.state=="weapon_attack" and settings.kind in ["spear","rapier"]:
  # Greatsword's retained thrust dives into a deep crouch and pitches the head.
  # New lighter weapons use their own restrained body drive and real hand IK.
  actor.play_clip("idle_loop",.08)
  actor.animator.seek(fmod(actor.presentation_clock,actor.animator.get_animation(actor.clips.idle_loop).length),true)
  var pulse=smoothstep(.12,.36,t)*(1-smoothstep(.58,.92,t))
  if actor.get("skeleton")!=null:
   var spine=actor.skeleton.find_bone("spine")
   if spine>=0:
    var rest=actor.skeleton.get_bone_pose_rotation(spine)
    actor.skeleton.set_bone_pose_rotation(spine,rest*Quaternion(Vector3.UP,(.06 if settings.kind=="spear" else -.08)*pulse))
    actor.skeleton.force_update_all_bone_transforms()
 var sampled=Motion.sample(settings.kind,key,t,last_charge)
 var frame=view_frame();sampled_frame=frame;var authored=Motion.weapon_transform(frame,sampled)
 model.global_transform=carry_transform().interpolate_with(authored,smoothstep(0,.25,t)) if key=="draw" else authored
 actor.equipment.global_transform=model.global_transform
 var hand_delta=model.global_transform*authored.affine_inverse()
 targets={"R":hand_delta*(frame*sampled.right_hand),"L":hand_delta*(frame*sampled.left_hand),"R_axis":hand_delta.basis*frame.basis*sampled.right_axis,"L_axis":hand_delta.basis*frame.basis*sampled.left_axis,"R_grasp":sampled.grasp_right,"L_grasp":sampled.grasp_left}
 if actor.get("skeleton")!=null:apply_rig(actor.skeleton,false)
 if settings.kind=="bow":
  Models.update_string(model,last_charge if actor.state=="bow_draw" else 0.0)
  var nocked=model.get_node_or_null("NockedArrow")
  if nocked!=null:nocked.visible=actor.state=="bow_draw"
func apply_rig(rig:Skeleton3D,personal:bool=false) -> void:
 if not enabled() or targets.is_empty() or not actor.sword_drawn:return
 var to_rig=rig.global_transform.affine_inverse()
 for side in ["L","R"]:
  var upper=rig.find_bone("upper_arm."+side);var lower=rig.find_bone("forearm."+side)
  if upper<0 or lower<0:continue
  var palm=Vector3(-.017 if side=="R" else .017,-.30,.012) if personal else Vector3(0,.31,0)
  var target:Vector3=targets[side]
  # Scapula protraction extends the shoulder toward the grip without scaling arm bones.
  # Bound total local displacement, including movement mirrored from the canonical rig.
  var local_target=to_rig*target
  var shoulder=rig.get_bone_global_pose(upper).origin
  var reach=rig.get_bone_global_rest(upper).origin.distance_to(rig.get_bone_global_rest(lower).origin)+palm.length()
  var excess=maxf(0,shoulder.distance_to(local_target)-reach+.003)
  if excess>0:
   var parent=rig.get_bone_parent(upper);var shoulder_pose=rig.get_bone_pose(upper)
   var parent_basis=rig.get_bone_global_pose(parent).basis if parent>=0 else Basis.IDENTITY
   var rest_origin=rig.get_bone_rest(upper).origin
   var shifted=shoulder_pose.origin-rest_origin+parent_basis.inverse()*(local_target-shoulder).normalized()*excess
   shoulder_pose.origin=rest_origin+shifted.limit_length(float(settings.get("shoulder_reach",.18)))
   rig.set_bone_pose(upper,shoulder_pose);rig.force_update_all_bone_transforms()
  var pole=to_rig.basis*sampled_frame.basis*Vector3(-.8 if side=="L" else .8,-.6,.3)
  rig_fit.chain(rig,upper,lower,palm,to_rig*target,pole)
func hand_targets() -> Dictionary:return targets
func contact_segments() -> Array:
 return Motion.contact_segments(model.global_transform,settings) if is_instance_valid(model) else []
func combat_player_targets() -> Array:
 return game.combat_player_targets(actor) if game.has_method("combat_player_targets") else []
func combat_exclusions() -> Array[RID]:
 var result:Array[RID]=[actor.get_rid()]
 if game.has_method("combat_player_exclusions"):
  for rid in game.combat_player_exclusions(actor):
   if rid not in result:result.append(rid)
 return result
func launch_spec() -> Dictionary:
 var frame=view_frame();var muzzle=frame*(Models.bow_grip()+Models.arrow_tip_socket(last_charge))
 return Ballistics.launch(actor.get_world_3d().direct_space_state,frame.origin,muzzle,-frame.basis.z,settings,combat_exclusions(),combat_player_targets())
func update_preview() -> void:
 if not enabled() or actor.state!="bow_draw":
  if is_instance_valid(preview):preview.visible=false
  return
 if game.get("prediction_mode")==true:return
 var launch=launch_spec()
 if not launch.valid:
  if is_instance_valid(preview):preview.visible=false
  return
 if not is_instance_valid(preview):preview=Preview.new();game.current_world.add_child(preview)
 preview.display(Ballistics.predict(actor.get_world_3d().direct_space_state,launch.origin,Ballistics.velocity(launch.direction,last_charge,settings),settings,combat_exclusions(),combat_player_targets()))
func tick(_delta:float) -> void:
 if not active():
  if is_instance_valid(preview):preview.visible=false
  return
 if actor.health<=0:cancel();return
 pose("attack",actor.state_time/actor.state_duration)
 if actor.state=="bow_draw":update_preview()
 elif actor.state=="weapon_attack":
  var phase=actor.state_time/actor.state_duration
  var current=contact_segments()
  if phase>=float(settings.active_start) and phase<=float(settings.active_end):
   if online():
    if game.has_method("capture_weapon_contact"):game.capture_weapon_contact(action_context(),current,previous_segment,settings,struck)
   else:
    for enemy in game.enemies:
     if not is_instance_valid(enemy) or enemy.health<=0 or struck.has(enemy.get_instance_id()):continue
     if hits(enemy,current):
      struck[enemy.get_instance_id()]=true
      var away=(enemy.global_position-actor.global_position).normalized()
      if game.has_method("resolve_weapon_contact"):game.resolve_weapon_contact(action_context(),enemy,int(settings.damage),away,bool(settings.strong))
  previous_segment=current
 if actor.state!="bow_draw" and actor.state_time>=actor.state_duration:actor.state="free";actor.state_time=0;previous_segment.clear()
func hits(enemy:Node3D,current:Array) -> bool:
 var radius=float(enemy.definition.get("combat_radius",.5));var height=float(enemy.definition.get("combat_height",1.0))
 var eye=view_frame().origin
 var clearance=func(point:Vector3) -> bool:
  return actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,point,1,[actor.get_rid()])).is_empty()
 return bool(preload("res://scripts/steel_contact.gd").capsule(current,previous_segment,enemy.global_position,radius,height,float(settings.radius),clearance).hit)
