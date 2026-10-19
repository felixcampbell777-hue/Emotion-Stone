extends RefCounted
## Server-authored presentation state; JSON-portable transforms use basis columns then origin.
static func encode_transform(value:Transform3D) -> Array:
 return [value.basis.x.x,value.basis.x.y,value.basis.x.z,value.basis.y.x,value.basis.y.y,value.basis.y.z,value.basis.z.x,value.basis.z.y,value.basis.z.z,value.origin.x,value.origin.y,value.origin.z]
static func snapshot(actor:Node3D) -> Dictionary:
 var result:Dictionary={}
 for key in ["slow_sources","swing_cue_action","action_event_index","shift_pending","shift_clock","stamina_delay","sprint_exhausted","sprint_denial_latched","parry_resolved","parry_flash","invulnerability","measured_remaining","measured_triggered","water_released","undertow_cast","dash_water_pending","attack_yaw","combo_stage","combo_remaining","combo_queued","dash_distance","dash_attack_queued","dash_attack_blend","dash_uppercut","dash_release_queued","roll_restore_drawn","roll_attack_queued","thrust_charging","thrust_charge_seconds","thrust_distance","thrust_launch_seconds","thrust_hold_seconds","thrust_windup_seconds","thrust_start_phase","thrust_gust_emitted","charge_rush","attack_rushing","compressed_windup","chain_speed","chain_blend","chain_blend_duration","action_transition_remaining","action_transition_duration","stagger_start_phase","stagger_motion","counter_active","counter_remaining","sprinting","jump_active","jump_velocity","current_clip","presentation_clock","slam_emitted","slam_contact_started","beta_hand_drop","rush_clock","rush_credit","heavy_style"]:
  var value=actor.get(key);result[key]=value.duplicate(true) if value is Dictionary or value is Array else value
 for key in ["attack_direction","movement_direction","counter_step","knockback"]:
  var vector:Vector3=actor.get(key);result[key]=[vector.x,vector.y,vector.z]
 result.visual_yaw=actor.visual.rotation.y
 result.equipment_transform=encode_transform(actor.equipment.transform)
 result.equipment_parent="visual" if actor.equipment.get_parent()==actor.visual else "back_socket"
 result.chain_weapon=encode_transform(actor.chain_weapon)
 for key in ["chain_bones","action_transition_bones"]:
  var bones:Array=[]
  for pose in actor.get(key):bones.append(encode_transform(pose))
  result[key]=bones
 result.animator_clip=actor.animator.current_animation
 result.animator_position=actor.animator.current_animation_position
 result.blade_sweep_previous=[]
 for vector in actor.blade_sweep_previous:result.blade_sweep_previous.append([vector.x,vector.y,vector.z])
 var native:Array=[]
 for index in range(actor.skeleton.get_bone_count()):
  var p=actor.skeleton.get_bone_pose_position(index);var q=actor.skeleton.get_bone_pose_rotation(index);var scale=actor.skeleton.get_bone_pose_scale(index)
  native.append([p.x,p.y,p.z,q.x,q.y,q.z,q.w,scale.x,scale.y,scale.z])
 result.native_bones=native
 if actor.weapon_runtime!=null:
  var weapon=actor.weapon_runtime;var targets:Dictionary={}
  for key in weapon.targets:
   var value=weapon.targets[key]
   targets[key]=[value.x,value.y,value.z] if value is Vector3 else value
  result.weapon_state={"model_transform":encode_transform(weapon.model.transform) if is_instance_valid(weapon.model) else [],"previous_segment":[],"last_charge":weapon.last_charge,"sequence":weapon.sequence,"action_id":weapon.action_id,"sampled_frame":encode_transform(weapon.sampled_frame),"targets":targets}
  for vector in weapon.previous_segment:result.weapon_state.previous_segment.append([vector.x,vector.y,vector.z])
 result.view_blend=actor.first_person_driver.locomotion_camera_blend if actor.first_person_driver!=null else 0.0
 if actor.has_node("BetaHero"):
  var hero=actor.get_node("BetaHero");var gait=hero.gait
  var carry:Array=[]
  if actor.state in ["draw","sheathe"]:
   for pose in hero.carry_transition:carry.append(encode_transform(pose))
  result.hero_state={"previous_state":hero.previous_state,"carry_transition":carry}
  result.gait={"phase":gait.phase,"blend":gait.blend,"run_blend":gait.run_blend,"body_drop":gait.body_drop}
 return result
static func decode_transform(value:Array) -> Transform3D:
 return Transform3D(Basis(Vector3(value[0],value[1],value[2]),Vector3(value[3],value[4],value[5]),Vector3(value[6],value[7],value[8])),Vector3(value[9],value[10],value[11]))
static func apply(actor:Node3D,state:Dictionary) -> void:
 # Derive the accepted field allowlist from the same serializer; no arbitrary
 # network property names are written to the actor.
 var allowed=snapshot(actor)
 var vectors=["attack_direction","movement_direction","counter_step","knockback"]
 var complex=["hero_state","equipment_parent","equipment_transform","chain_weapon","chain_bones","action_transition_bones","source_bones","native_bones","gait","view_blend","visual_yaw","weapon_state","animator_clip","animator_position","blade_sweep_previous"]
 for key in allowed:
  if not state.has(key) or key in complex:continue
  if key in vectors:
   var value=state[key]
   if value is Array and value.size()==3:actor.set(key,Vector3(value[0],value[1],value[2]))
  elif typeof(state[key])==typeof(allowed[key]) or (state[key] is float and allowed[key] is int):
   actor.set(key,state[key].duplicate(true) if state[key] is Dictionary or state[key] is Array else int(state[key]) if allowed[key] is int else state[key])
 if state.has("animator_clip") and actor.animator.has_animation(String(state.animator_clip)):
  actor.animator.play(String(state.animator_clip),0)
  actor.animator.seek(float(state.get("animator_position",0)),true)
 actor.blade_sweep_previous.clear()
 for value in state.get("blade_sweep_previous",[]):
  if value is Array and value.size()==3:actor.blade_sweep_previous.append(Vector3(value[0],value[1],value[2]))
 if state.has("visual_yaw"):actor.visual.rotation.y=float(state.visual_yaw)
 var parent=actor.visual if state.get("equipment_parent","")=="visual" else actor.back_socket if state.get("equipment_parent","")=="back_socket" else null
 if parent!=null and actor.equipment.get_parent()!=parent:actor.equipment.reparent(parent,false)
 if state.get("equipment_transform",[]).size()==12:actor.equipment.transform=decode_transform(state.equipment_transform)
 if state.get("chain_weapon",[]).size()==12:actor.chain_weapon=decode_transform(state.chain_weapon)
 for key in ["chain_bones","action_transition_bones"]:
  if not state.has(key):continue
  var poses:Array=[]
  for value in state[key]:
   if value is Array and value.size()==12:poses.append(decode_transform(value))
  actor.set(key,poses)
 var native=state.get("native_bones",[])
 if native.size()==actor.skeleton.get_bone_count():
  for index in range(native.size()):
   var value=native[index]
   if value is Array and value.size()==10:
    actor.skeleton.set_bone_pose_position(index,Vector3(value[0],value[1],value[2]))
    actor.skeleton.set_bone_pose_rotation(index,Quaternion(value[3],value[4],value[5],value[6]))
    actor.skeleton.set_bone_pose_scale(index,Vector3(value[7],value[8],value[9]))
 var bones=state.get("source_bones",[])
 if native.is_empty() and bones.size()==actor.skeleton.get_bone_count():
  for index in range(bones.size()):
   if bones[index] is Array and bones[index].size()==12:actor.skeleton.set_bone_pose(index,decode_transform(bones[index]))
 actor.skeleton.force_update_all_bone_transforms()
 if actor.weapon_runtime!=null and state.get("weapon_state",{}) is Dictionary:
  var weapon=actor.weapon_runtime;var accepted=state.weapon_state
  weapon.last_charge=float(accepted.get("last_charge",0));weapon.sequence=int(accepted.get("sequence",0));weapon.action_id=String(accepted.get("action_id",""))
  if accepted.get("sampled_frame",[]).size()==12:weapon.sampled_frame=decode_transform(accepted.sampled_frame)
  weapon.previous_segment.clear()
  for value in accepted.get("previous_segment",[]):
   if value is Array and value.size()==3:weapon.previous_segment.append(Vector3(value[0],value[1],value[2]))
  weapon.targets.clear()
  for key in accepted.get("targets",{}):
   var value=accepted.targets[key]
   weapon.targets[key]=Vector3(value[0],value[1],value[2]) if value is Array and value.size()==3 else value
  if is_instance_valid(weapon.model):
   if accepted.get("model_transform",[]).size()==12:weapon.model.transform=decode_transform(accepted.model_transform)
   else:weapon.model.global_transform=actor.equipment.global_transform
 if actor.has_node("BetaHero") and state.get("gait",{}) is Dictionary:
  var hero=actor.get_node("BetaHero")
  var accepted=state.get("hero_state",{})
  if accepted is Dictionary and accepted.has("previous_state"):
   hero.previous_state=String(accepted.previous_state);hero.carry_transition.clear()
   for value in accepted.get("carry_transition",[]):
    if value is Array and value.size()==12:hero.carry_transition.append(decode_transform(value))
  for key in ["phase","blend","run_blend","body_drop"]:
   if state.gait.has(key):hero.gait.set(key,float(state.gait[key]))
  hero.synchronize()
 if actor.first_person_driver!=null and state.has("view_blend"):
  actor.first_person_driver.locomotion_camera_blend=float(state.view_blend)
  actor.set_meta("canonical_view_blend",float(state.view_blend))
