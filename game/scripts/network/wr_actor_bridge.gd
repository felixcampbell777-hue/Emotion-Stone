extends Control
## Server command adapter around the playable Actor. Never reconstructs action clocks,
## locomotion, resources, rig poses or weapon contacts from a network dictionary.
const Actor=preload("res://scripts/actor.gd")
const Rock=preload("res://scripts/rock_projectile.gd")
const Shot=preload("res://scripts/menagery_projectile.gd")
const ViewFrame=preload("res://scripts/network/wr_view_frame.gd")
const Stats=preload("res://scripts/network/wr_actor_stats.gd")
const Profiles=preload("res://scripts/weapon_profiles.gd")
signal presentation(event:Dictionary)
signal contact(context:Dictionary,kind:String,direction:Vector3,hits:Dictionary)
var actor:CharacterBody3D
var player:CharacterBody3D
var runtime:Node
var current_world:Node3D
var progression=preload("res://scripts/progression.gd").new()
var magic_items=preload("res://scripts/magic_items.gd").new()
var driver=ViewFrame.new()
var game_mode="world_rise"
var map_id=""
var gallery_mode=false
var authoritative_simulation=true
var prediction_mode=false
# Opt-in benchmark instrumentation; production does no clock reads.
var profile_enabled=false
var profile_us:Dictionary={}
var combat_skills=preload("res://scripts/combat_skills.gd").new()
var effects:Array=[]
var selected_special_attack="water_sweep"
var network_session:Node
var wr_session:Node
var enemies:Array=[]
var contact_active=false
var previous_steel:Array=[]
var accepted_steel:Array=[]
var accepted_transform=Transform3D.IDENTITY
var accepted_origin=Vector3.ZERO
var accepted_frame=Transform3D.IDENTITY
var accepted_contact:Dictionary={}
var blocked=false
var last_jump=false
var primary_pending=false
var primary_clock=0.0
var profile_data:Dictionary={}
var id=""
func simulation_active() -> bool:return actor!=null and actor.simulation_active()
func online_session_active() -> bool:return true
func request_action(_kind:String,_payload:Dictionary={}) -> void:pass
func notify(_message:String) -> void:pass
func setup(floor_runtime:Node,profile:Dictionary,character_id:String) -> void:
 runtime=floor_runtime;current_world=runtime.current_world;id=character_id;map_id=String(runtime.map_id)
 profile_data=profile.duplicate(true);network_session=self;wr_session=self;combat_skills.game=self
 progression.restore(profile.get("progression",{}));magic_items.restore(profile.get("magic_items",{}));magic_items.game=self
 var config=JSON.parse_string(FileAccess.get_file_as_string("res://content/platform.json"))
 actor=Actor.new();player=actor;actor.name="Authority_"+id;actor.entity_id=id
 actor.set_meta("player_id",id);actor.set_meta("character_id",id);actor.set_meta("canonical_manual_step",true)
 actor.controllable=true;actor.input_enabled=true;actor.online_mode=true;actor.damage_authority=true
 actor.motion_mode=CharacterBody3D.MOTION_MODE_GROUNDED
 actor.configure(JSON.parse_string(FileAccess.get_file_as_string("res://content/characters/"+String(config.player_character)+".json")))
 runtime.world_root.add_child(actor);actor.set_process_input(false);actor.set_physics_process(false)
 actor.ground_world=current_world
 actor.weapon_runtime=preload("res://scripts/weapon_runtime.gd").new();actor.weapon_runtime.configure(self,actor)
 actor.set_weapon_visual(magic_items.weapon_id)
 preload("res://scripts/beta_hero.gd").apply(actor,true)
 actor.get_node("BetaHero").set_process(false)
 driver.bind(actor,config.follow_camera)
 apply_skill_stats()
 actor.health=actor.max_health;actor.stamina=actor.max_stamina
 actor.visible=false
 actor.presentation_event.connect(func(event):presentation.emit(event))
 actor.attack_contact.connect(func(kind,direction,hits):
  contact_active=true;accepted_origin=actor.position;accepted_frame=driver.sample_first_person(0,false);accepted_transform=actor.equipment.global_transform;accepted_steel=actor.blade_segment();previous_steel=actor.blade_sweep_previous.duplicate()
  accepted_contact={"damage":int(actor.attack_tuning().damage),"strong":actor.state in ["heavy","thrust"] or (actor.state=="light" and actor.combo_stage==3 and actor.attack_phase()>=.60),"recoil_multiplier":(float(actor.combat.thrust_charge.recoil_multiplier) if actor.state=="thrust" else 1.0)*(1+magic_items.bonus("sword_recoil")),"context":source_context(),"hits":hits}
  contact.emit(actor.action_context(),kind,direction,hits))
 actor.parry_succeeded.connect(parry_succeeded)
 actor.ground_slam.connect(ground_slam)
 actor.thrust_stopped.connect(thrust_stopped)
func apply_skill_stats() -> void:
 var stats=Stats.build({"progression":progression.snapshot(),"magic_items":magic_items.snapshot()})
 for key in ["combat","max_health","max_stamina","walk_speed","dash_distance_multiplier","dash_stamina_multiplier","jump_stamina_multiplier"]:actor.set(key,stats[key])
 actor.weapon_type=Profiles.kind(magic_items.weapon_id)
 actor.roll_unlocked=progression.has("belly_roll");actor.dash_unlocked=progression.has("dash")
 actor.thrust_unlocked=progression.has("charge_thrust") and actor.weapon_type=="greatsword"
 actor.thrust_charge_rate=2.0 if progression.has("fast_thrust") else 1.0
 actor.counter_unlocked=progression.has("flowing_counter")
 actor.counter_damage=progression.bonus("counter_damage");actor.measured_bonus=progression.bonus("measured_recovery")
 actor.magic_gear=magic_items;actor.weapon_runtime.apply_stats()
 var loadout=profile_data.get("skill_loadout",{})
 actor.dash_equipped=actor.dash_unlocked and bool(loadout.get("dash",false))
 actor.counter_equipped=actor.counter_unlocked and bool(loadout.get("flowing_counter",false))
 actor.heavy_style=String(profile_data.get("heavy_attack","overhead"))
 if actor.heavy_style=="charge_thrust" and not actor.thrust_unlocked:actor.heavy_style="overhead"
func refresh(profile:Dictionary) -> void:
 profile_data=profile.duplicate(true);progression.restore(profile.progression);magic_items.restore(profile.magic_items)
 if actor.weapon_runtime.item_id!=magic_items.weapon_id:actor.set_weapon_visual(magic_items.weapon_id)
 apply_skill_stats();actor.health=mini(actor.health,actor.max_health);actor.stamina=minf(actor.stamina,actor.max_stamina)
func set_pose(at:Vector3,yaw:float,pitch:float) -> void:
 actor.position=at;driver.yaw=yaw;driver.first_pitch=pitch;actor.movement_camera_yaw=yaw
 driver.sample_first_person(0,false)
func action(kind:String,payload:Dictionary={}) -> Dictionary:
 if actor==null:return {"ok":false,"error":"Actor unavailable"}
 if kind in ["cancel","cancel_primary","focus_lost"]:
  primary_pending=false;primary_clock=0
  actor.cancel_pending_input()
  if actor.state=="bow_draw":actor.weapon_runtime.cancel()
  return {"ok":true}
 if actor.health<=0 or blocked:return {"ok":false,"error":"Controls unavailable"}
 var accepted=false
 match kind:
  "draw":accepted=actor.toggle_sword()
  "jump":accepted=actor.begin_jump()
  "parry":
   actor.cancel_pending_input();accepted=actor.begin_parry()
  "dodge":actor.shift_pending=false;accepted=actor.request_dodge()
  "shift_down":actor.shift_pending=actor.input_enabled and actor.state=="free";actor.shift_clock=0;accepted=true
  "shift_up":
   if actor.shift_pending and actor.shift_clock<=float(actor.combat.dodge.tap_seconds):actor.request_dodge()
   actor.shift_pending=false;accepted=true
  "dash_charge":accepted=actor.begin_dash_charge()
  "dash_release":accepted=actor.release_dash()
  "dash_attack":accepted=actor.queue_dash_attack()
  "primary_down","bow_draw","charge":
   accepted=actor.begin_charge();primary_pending=accepted;primary_clock=0
  "primary_up","release","fire":
   if kind=="primary_up" and not primary_pending:return {"ok":true}
   primary_pending=false
   if actor.weapon_type=="bow":return release_bow()
   var style="heavy" if actor.thrust_charging and primary_clock>=float(actor.combat.heavy_hold_seconds) else "light"
   accepted=actor.release_charge(style)
  "attack":accepted=actor.begin_attack("light")
  "weapon_equipped":
   if not payload.get("enabled") is bool:return {"ok":false,"error":"Invalid equipment state"}
   actor.set_sword_equipped(payload.enabled);accepted=true
  "bow_cancel":actor.weapon_runtime.cancel();accepted=true
  _ :return {"ok":false,"error":"Unknown actor command"}
 return {"ok":accepted,"error":"" if accepted else "Action rejected by Actor"}
func release_bow() -> Dictionary:
 var weapon=actor.weapon_runtime
 if actor.state!="bow_draw":return {"ok":false,"error":"Bow is not drawn"}
 weapon.last_charge=clampf(actor.state_time/float(weapon.settings.draw_max_seconds),0,1)
 var shot=weapon.launch_spec()
 if not shot.valid:
  weapon.cancel();return {"ok":false,"error":"Bow blocked by scenery"}
 var ammo=String(weapon.settings.ammo_id);var count=int(magic_items.quantities.get(ammo,0))
 if count<=0 or not actor.can_afford(float(weapon.settings.stamina)):
  weapon.cancel();return {"ok":false,"error":"Bow resources unavailable"}
 var charge=weapon.last_charge
 var context=weapon.action_context();context.damage=roundi(float(weapon.settings.damage)*lerpf(.55,1.0,charge))
 if not weapon.release_primary():return {"ok":false,"error":"Bow release rejected"}
 actor.spend_stamina(float(weapon.settings.stamina));magic_items.quantities[ammo]=count-1
 if count==1:magic_items.quantities.erase(ammo);magic_items.owned.erase(ammo)
 actor.emit_presentation("weapon.bow.release",context)
 return {"ok":true,"shot":{"origin":shot.origin,"direction":shot.direction,"charge":charge,"settings":weapon.settings.duplicate(true),"context":context}}
func step(delta:float,command:Dictionary={},include_pose:bool=true) -> Dictionary:
 var stage_started=Time.get_ticks_usec() if profile_enabled else 0
 var step_started=stage_started
 previous_steel=steel();accepted_contact={}
 contact_active=false
 enemies=runtime.enemies
 combat_skills.tick(delta)
 if is_instance_valid(current_world):preload("res://scripts/wading.gd").tick(self)
 for effect in effects.duplicate():
  if not is_instance_valid(effect) or effect.is_queued_for_deletion():effects.erase(effect)
  else:effect._physics_process(delta)
 var movement=command.get("movement",[0,0]);var buttons=command.get("buttons",{})
 blocked=bool(buttons.get("blocked",false))
 driver.yaw=float(command.get("yaw",driver.yaw));driver.first_pitch=float(command.get("pitch",driver.first_pitch))
 actor.movement_camera_yaw=driver.yaw;actor.camera_relative=true
 actor.input_enabled=not blocked
 actor.set_network_input(Vector2(float(movement[0]),float(movement[1])) if not blocked else Vector2.ZERO,bool(buttons.get("sprint",false)) and not blocked)
 var jump=bool(buttons.get("jump",false))
 if jump and not last_jump and not blocked:actor.begin_jump()
 last_jump=jump
 if blocked:actor.cancel_pending_input();primary_pending=false
 if primary_pending:
  primary_clock+=delta
  if not actor.input_enabled or actor.state not in ["charge","light","roll","stand","weapon_attack","bow_draw","weapon_recovery"]:primary_pending=false
  elif not actor.thrust_charging and not actor.weapon_runtime.enabled() and primary_clock>=float(actor.combat.heavy_hold_seconds):
   primary_pending=false
   if actor.state not in ["light","roll","stand"]:actor.release_charge("heavy")
 if profile_enabled:stage_started=record_stage("preparation",stage_started)
 if actor.health>0:actor._physics_process(delta)
 if profile_enabled:stage_started=record_stage("actor_physics",stage_started)
 if actor.has_node("BetaHero"):actor.get_node("BetaHero").synchronize(delta)
 if profile_enabled:stage_started=record_stage("end_hero",stage_started)
 driver.sample_first_person(delta,true)
 if profile_enabled:stage_started=record_stage("end_view",stage_started)
 var accepted=snapshot(include_pose)
 if profile_enabled:
  record_stage("snapshot",stage_started);profile_us["total"]=Time.get_ticks_usec()-step_started
 return accepted
func steel() -> Array:
 return actor.weapon_runtime.contact_segments() if actor.weapon_runtime.enabled() else actor.blade_segment()
func contact_pose() -> Dictionary:
 var segment=steel()
 return {"frame":driver.sample_first_person(0,false),"steel":segment,"width":float(actor.weapon_runtime.settings.get("radius",.12))*2 if actor.weapon_runtime.enabled() else (preload("res://scripts/beta_sword_motion.gd").WIDTH if actor.equipment.get_meta("beta_sword",false) else .24),"transform":actor.equipment.global_transform}
func take_damage(amount:int,direction:Vector3) -> bool:return actor.take_damage(amount,direction)
func try_parry(enemy:Node3D,point:Vector3=Vector3(INF,INF,INF)) -> bool:return actor.try_parry(enemy,point)
func snapshot(include_pose:bool=true) -> Dictionary:
 var context=actor.action_context()
 var result={"position":[actor.position.x,actor.position.y,actor.position.z],"velocity":[actor.velocity.x,actor.velocity.y,actor.velocity.z],"yaw":driver.yaw,"pitch":driver.first_pitch,"health":actor.health,"max_health":actor.max_health,"stamina":actor.stamina,"max_stamina":actor.max_stamina,"action":actor.state,"action_clock":actor.state_time,"duration":actor.state_duration,"action_phase":actor.attack_phase() if actor.state in ["light","heavy","thrust"] else actor.state_time/maxf(.001,actor.state_duration),"action_id":context.action_id,"sword_drawn":actor.sword_drawn,"sword_equipped":actor.sword_equipped,"combo":actor.combo_stage,"contact_active":contact_active,"jump_velocity":actor.jump_velocity,"invulnerability":actor.invulnerability,"regen_delay":actor.stamina_delay,"weapon":magic_items.weapon_id,"action_sequence":actor.action_sequence,"charge_rush":actor.charge_rush,"thrust_charging":actor.thrust_charging,"thrust_charge_seconds":actor.thrust_charge_seconds,"dash_attack_queued":actor.dash_attack_queued,"counter_target_id":counter_target_id(),"input_state":{"primary_pending":primary_pending,"primary_clock":primary_clock,"last_jump":last_jump,"blocked":blocked},"item_state":magic_items.snapshot()}
 if include_pose:result["pose_state"]=pose_state()
 return result
func _exit_tree() -> void:
 if is_instance_valid(actor):actor.queue_free()
 for effect in effects:
  if is_instance_valid(effect):effect.queue_free()

func rebind(floor_runtime:Node) -> void:
 for effect in effects:
  if is_instance_valid(effect):effect.queue_free()
 effects.clear();combat_skills.reset()
 runtime=floor_runtime;current_world=runtime.current_world;map_id=String(runtime.map_id)
 actor.reparent(runtime.world_root,false);actor.ground_world=current_world;actor.motion_mode=CharacterBody3D.MOTION_MODE_GROUNDED
func contact_candidates(enemy:Node3D) -> bool:
 if not contact_active or enemy.health<=0:return false
 if actor.weapon_runtime.enabled():
  var previous=actor.weapon_runtime.previous_segment;var position=actor.position
  actor.weapon_runtime.previous_segment=previous_steel;actor.position=accepted_origin
  var hit=actor.weapon_runtime.hits(enemy,accepted_steel)
  actor.weapon_runtime.previous_segment=previous;actor.position=position
  return hit
 var previous=actor.blade_sweep_previous;var transform=actor.equipment.transform
 actor.blade_sweep_previous=previous_steel;actor.equipment.global_transform=accepted_transform
 var hit=actor.blade_hits(enemy)
 actor.blade_sweep_previous=previous;actor.equipment.transform=transform
 return hit
func contact_spec() -> Dictionary:
 return accepted_contact
func capture_weapon_contact(context:Dictionary,current:Array,previous:Array,settings:Dictionary,struck:Dictionary) -> void:
 contact_active=true;accepted_origin=actor.position;accepted_frame=actor.weapon_runtime.sampled_frame;accepted_steel=current.duplicate();previous_steel=previous.duplicate()
 accepted_contact={"damage":int(settings.damage),"strong":bool(settings.strong),"context":context.duplicate(true),"hits":struck}

func source_context() -> Dictionary:
 var context=actor.action_context().duplicate(true)
 context.merge({"attacker_id":id,"weapon_id":magic_items.weapon_id,"damage_kind":"melee","strike_index":actor.combo_stage},true)
 return context

func contact_capsule(at:Vector3,radius:float=.23,height:float=1.12) -> Dictionary:
 if not contact_active:return {"hit":false,"point":Vector3.ZERO}
 var margin=float(actor.weapon_runtime.settings.radius) if actor.weapon_runtime.enabled() else (preload("res://scripts/beta_sword_motion.gd").WIDTH*.5 if actor.equipment.get_meta("beta_sword",false) else .12)
 var clear=func(point:Vector3):return actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(accepted_frame.origin,point,1,[actor.get_rid()])).is_empty()
 return preload("res://scripts/steel_contact.gd").capsule(accepted_steel,previous_steel,at,radius,height,margin,clear)

func contact_player(victim:Node3D) -> Dictionary:
 if not contact_active:return {"hit":false,"point":Vector3.ZERO}
 var margin=float(actor.weapon_runtime.settings.radius) if actor.weapon_runtime.enabled() else (preload("res://scripts/beta_sword_motion.gd").WIDTH*.5 if actor.equipment.get_meta("beta_sword",false) else .12)
 var clear=func(point:Vector3):return actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(accepted_frame.origin,point,1,[actor.get_rid()])).is_empty()
 return preload("res://scripts/player_hurt.gd").steel_contact(victim,accepted_steel,previous_steel,margin,clear)

func combat_player_targets(source_actor:Node=null) -> Array:
 if runtime.has_method("combat_player_targets"):return runtime.combat_player_targets(actor if source_actor==null else source_actor)
 var result:Array=[]
 var source=actor if source_actor==null else source_actor
 var source_id=String(source.entity_id)
 var peers=runtime.get("players")
 if peers is Dictionary:
  for peer in peers.values():
   if not is_instance_valid(peer) or peer==actor or peer==source or peer.health<=0 or peer.is_queued_for_deletion() or peer.ground_world!=current_world:continue
   if not source_id.is_empty() and String(peer.entity_id)==source_id:continue
   result.append(peer)
 return result

func combat_player_exclusions(source_actor:Node=null) -> Array[RID]:
 var source=actor if source_actor==null else source_actor
 if runtime.has_method("combat_player_exclusions"):return runtime.combat_player_exclusions(source)
 var result:Array[RID]=[source.get_rid()]
 var source_id=String(source.entity_id)
 var peers=runtime.get("players")
 if peers is Dictionary and not source_id.is_empty():
  for peer in peers.values():
   if is_instance_valid(peer) and String(peer.entity_id)==source_id and peer.get_rid() not in result:result.append(peer.get_rid())
 return result

func pose_state() -> Dictionary:
 return preload("res://scripts/network/wr_actor_pose.gd").snapshot(actor)

func ground_slam(at:Vector3,heavy:bool) -> void:
 if prediction_mode or not authoritative_simulation:return
 var effect=preload("res://scripts/ground_slam.gd").new();current_world.add_child(effect)
 effect.configure(self,Vector3(at.x,current_world.ground_height(at)+.018,at.z),heavy)
 effect.set_physics_process(false);effect.visible=false;effects.append(effect)
 actor.emit_presentation("combat.slam")
func thrust_stopped(at:Vector3,direction:Vector3) -> void:
 if prediction_mode or not authoritative_simulation:return
 var effect=preload("res://scripts/thrust_gust.gd").new();current_world.add_child(effect)
 effect.configure(self,Vector3(at.x,current_world.ground_height(at)+.35,at.z),direction)
 effect.set_physics_process(false);effect.visible=false;effects.append(effect)
 actor.emit_presentation("combat.thrust_stop")

func restore_snapshot(state:Dictionary) -> void:
 # Reconciliation accepts only a server snapshot, never a client command pose.
 if state.has("item_state"):magic_items.restore(state.item_state)
 if state.has("sword_equipped"):actor.set_sword_equipped(bool(state.sword_equipped))
 if state.has("sword_drawn"):actor.set_sword_drawn(bool(state.sword_drawn))
 for key in ["health","max_health","stamina","max_stamina","sword_equipped","sword_drawn","action_sequence","invulnerability","jump_velocity"]:
  if state.has(key):actor.set(key,state[key])
 actor.state=String(state.get("action","free"));actor.state_time=float(state.get("action_clock",0));actor.state_duration=float(state.get("duration",0))
 actor.action_sequence=int(state.get("action_sequence",actor.action_sequence));actor.stamina_delay=float(state.get("regen_delay",0))
 actor.hit_ids.clear();actor.parried_threats.clear()
 var at=state.get("position",[0,0,0]);var speed=state.get("velocity",[0,0,0])
 actor.position=Vector3(at[0],at[1],at[2]);actor.velocity=Vector3(speed[0],speed[1],speed[2])
 driver.yaw=float(state.get("yaw",driver.yaw));driver.first_pitch=float(state.get("pitch",driver.first_pitch));actor.movement_camera_yaw=driver.yaw
 var accepted=state.get("input_state",{})
 primary_pending=bool(accepted.get("primary_pending",false));primary_clock=float(accepted.get("primary_clock",0));last_jump=bool(accepted.get("last_jump",false));blocked=bool(accepted.get("blocked",false))
 actor.input_enabled=not blocked
 preload("res://scripts/network/wr_actor_pose.gd").apply(actor,state.get("pose_state",{}))
 contact_active=false;accepted_contact={}
 actor.counter_target=null
 var target=resolve_counter_target(String(state.get("counter_target_id","")))
 if is_instance_valid(target):actor.counter_target=weakref(target)
func counter_target_id() -> String:
 if actor.counter_target==null:return ""
 var target=actor.counter_target.get_ref()
 if not is_instance_valid(target):return ""
 if target.get_script()==Actor and not String(target.entity_id).is_empty():return "player:"+String(target.entity_id)
 var definition=target.get("definition")
 return String(definition.get("id","")) if definition is Dictionary else ""
func resolve_counter_target(stable_id:String) -> Node3D:
 if stable_id.is_empty():return null
 if stable_id.begins_with("player:"):
  var peers=runtime.get("players")
  if peers is Dictionary and peers.has(stable_id.trim_prefix("player:")):return peers[stable_id.trim_prefix("player:")]
  var view=runtime.get("online_view")
  if is_instance_valid(view) and view.get("remotes") is Dictionary:return view.remotes.get(stable_id.trim_prefix("player:"))
  return null
 for enemy in runtime.enemies:
  if not is_instance_valid(enemy):continue
  var definition=enemy.get("definition")
  if definition is Dictionary and String(definition.get("id",""))==stable_id:return enemy
 return null

func parry_succeeded(enemy:Node3D) -> void:
 actor.emit_presentation("combat.parry")
 magic_items.parried();combat_skills.parried(enemy)
 if enemy is Rock or enemy is Shot:enemy.set_meta("reflected_by",id)
 var away=enemy.position-actor.position;away.y=0
 if enemy.has_method("repel"):enemy.repel(away,float(actor.combat.parry.knockback),float(actor.combat.parry.stun_seconds))

func record_stage(stage:String,started:int) -> int:
 var now=Time.get_ticks_usec();profile_us[stage]=now-started
 return now
