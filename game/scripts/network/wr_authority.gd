extends RefCounted
## Server-only world state; clients never supply transforms, damage or rewards.
const Profile=preload("res://scripts/network/wr_profile.gd")
const Adapter=preload("res://scripts/network/wr_world_adapter.gd")
const Profiles=preload("res://scripts/weapon_profiles.gd")
const Motion=preload("res://scripts/weapon_motion.gd")
const Stats=preload("res://scripts/network/wr_actor_stats.gd")
const Economy=preload("res://scripts/network/wr_economy.gd")
const Bridge=preload("res://scripts/network/wr_actor_bridge.gd")
var world=Adapter.new()
var store:RefCounted
var players:Dictionary={}
var enemies:Dictionary={}
var arrows:Dictionary={}
var events:Array=[]
var pvp_diagnostics:Dictionary={}
var tick=0
var clock=0.0
var elapsed=0.0
var pending_settlements:Dictionary={}
var unsettled_deaths:Array=[]
var rng=RandomNumberGenerator.new()
var combat=JSON.parse_string(FileAccess.get_file_as_string("res://content/combat.json"))
var sword=preload("res://scripts/first_person_sword.gd").new()
var persistence_failed=false
var runtimes:Dictionary={}
var stage_samples:Dictionary={}
var runtime_owner:Node
func attach(owner:Node) -> void:
 runtime_owner=owner
func ensure_runtime(floor_id:String) -> Node:
 if runtimes.has(floor_id):return runtimes[floor_id]
 if runtime_owner==null:return null
 var runtime=preload("res://scripts/network/wr_floor_runtime.gd").new()
 runtime_owner.add_child(runtime);runtime.setup(floor_id,world);runtimes[floor_id]=runtime
 runtime.parry_handler=func(id:String,enemy:Node,contact_point:Variant):return try_native_parry(id,enemy,contact_point)
 runtime.player_damaged.connect(func(id:String,amount:int,_away:Vector3):
  if players.has(id):damage_player(players[id],amount,"enemy"))
 runtime.presentation.connect(func(event_id:String,at:Vector3):events.append({"id":Profile.random_id(),"kind":"audio","event":event_id,"floor":floor_id,"position":arr(at)}))
 runtime.enemy_damaged.connect(func(id:String,amount:int,context:Dictionary):
  var key=floor_id+"/"+id
  if not enemies.has(key) and runtime.authored.has(id):
   var authored=runtime.authored[id].duplicate(true);authored.key=key;authored.generation=int(runtime.generation.get(id,0));authored.contributors={};authored.cooldown_remaining=0.0;enemies[key]=authored
  if not enemies.has(key):return
  var e=enemies[key];var source=context.get("source",context)
  var attacker=String(context.get("actor_id",source.get("attacker_id",source.get("actor_id",""))))
  e["last_weapon"]=""
  e["last_attacker"]=attacker if players.has(attacker) else ""
  if players.has(attacker):
   e.contributors[attacker]=elapsed;players[attacker].last_combat=elapsed
   if amount>0 and context.get("damage_kind","") in ["melee","projectile"]:
    var weapon=String(source.get("weapon_type",""))
    record_weapon_contribution(e,attacker,weapon))
 runtime.enemy_defeated.connect(func(id:String,_kind:String):
  var key=floor_id+"/"+id
  if not enemies.has(key) and runtime.authored.has(id):
   var authored=runtime.authored[id].duplicate(true);authored.key=key;authored.generation=int(runtime.generation.get(id,0));authored.contributors={};authored.cooldown_remaining=0.0;enemies[key]=authored
  if enemies.has(key):
   var e=enemies[key];inherit_participation(e);e.health=0;e.generation=int(runtime.generation.get(id,e.generation));settle_kill(e,String(e.get("last_attacker",""))))
 for e in enemies.values():
  if e.floor!=floor_id:continue
  runtime.generation[e.id]=int(e.generation)
  if e.has("native_state"):runtime.queue_enemy_state(e.id,e.native_state)
  if e.health<=0:runtime.defeated_enemies.append(e.key)
  elif e.health<e.max_health:
   var state={"health":e.health,"at":[e.position[0],e.position[2]]}
   runtime.worldrise.states[e.id]=state;runtime.worldrise.swamp.states[e.id]=state
 return runtime
func record_weapon_contribution(e:Dictionary,attacker:String,weapon:String) -> void:
 if not players.has(attacker) or weapon not in ["greatsword","spear","rapier","bow"]:return
 if not e.has("practice_contributors"):e["practice_contributors"]={}
 if not e.practice_contributors.has(attacker):e.practice_contributors[attacker]=[]
 if weapon not in e.practice_contributors[attacker]:e.practice_contributors[attacker].append(weapon)
 e["last_weapon"]=weapon
func inherit_participation(e:Dictionary) -> void:
 if e.has("parent_id"):
  var parent=enemies.get(e.floor+"/"+e.parent_id,{})
  for id in parent.get("contributors",{}):e.contributors[id]=parent.contributors[id]
func try_native_parry(id:String,enemy:Node,contact_point:Variant) -> bool:
 if not players.has(id):return false
 var p=players[id]
 if p.has("bridge"):return p.bridge.actor.try_parry(enemy,contact_point if contact_point is Vector3 else Vector3(INF,INF,INF))
 if p.action!="parry" or p.action_clock>.18:return false
 var at=contact_point if contact_point is Vector3 else enemy.global_position
 var offset=at-(vec(p.position)+Vector3.UP*.8)
 var forward=Basis(Vector3.UP,p.yaw)*Vector3.FORWARD
 if offset.length()>float(combat.parry.contact_range)+.25 or forward.dot(offset.normalized())<0:return false
 if runtimes[p.floor].impact_blocked(vec(p.position)+Vector3.UP*.8,at):return false
 p.last_combat=elapsed
 if p.hits.has(str(enemy.get_instance_id())):return false
 p.hits[str(enemy.get_instance_id())]=true
 if enemy.has_method("repel"):
  var away=(enemy.global_position-vec(p.position)).normalized()
  enemy.repel(away,float(p.stats.combat.parry.knockback),float(p.stats.combat.parry.stun_seconds))
 return true
func configure(storage:RefCounted) -> void:
 store=storage;clock=float(store.data.day_clock);elapsed=float(store.data.get("elapsed",0));rng.randomize()
 for floor_id in Adapter.FLOORS:
  for entry in world.encounter_entries(floor_id):
   var key=floor_id+"/"+entry.id
   var e=entry.duplicate(true);e["key"]=key;e["generation"]=0;e["state"]="idle";e["timer"]=0.0;e["empty"]=0.0;e["contributors"]={};e["target"]="";e["cooldown_remaining"]=0.0
   var saved=store.data.encounters.get(key,{})
   for field in ["position","health","generation","cooldown_remaining","native_state","practice_contributors"]:
    if saved.has(field):e[field]=saved[field]
   for contributor in e.get("practice_contributors",{}):e.contributors[contributor]=elapsed
   enemies[key]=e
func add_player(profile:Dictionary) -> Dictionary:
 var id=profile.character_id
 if players.has(id):return {}
 var visitor=store.data.visitors.get(id,{})
 var floor_id=String(visitor.get("floor","wr_floor_01"))
 if floor_id not in Adapter.FLOORS:floor_id="wr_floor_01"
 var runtime=ensure_runtime(floor_id)
 var at=world.floor_arrival(floor_id)
 if visitor.get("position",[]) is Array and visitor.get("position",[]).size()==3:
  var proposed=vec(visitor.position)
  if runtime.valid_player_position(proposed) if runtime!=null else world.safe_position(floor_id,proposed):at=proposed
 at=free_position(floor_id,at,id)
 if not at.is_finite():return {}
 var p={"id":id,"profile":profile.duplicate(true),"floor":floor_id,"position":arr(at),"velocity":[0,0,0],"yaw":0.0,"pitch":0.0,"health":100,"max_health":100,"stamina":100.0,"max_stamina":100.0,"action":"free","action_phase":0.0,"action_clock":0.0,"duration":0.0,"action_id":"","hits":{},"sword_drawn":false,"weapon":profile.magic_items.get("weapon_id","standard_greatsword"),"pvp":false,"last_combat":-100.0,"input_seq":-1,"input_received_seq":-1,"action_ack":0,"input":{},"input_age":0.0,"regen_delay":0.0,"invulnerability":0.0,"jump_velocity":0.0,"disconnected":0.0,"discoveries":visitor.get("discoveries",{}),"checkpoint":visitor.get("checkpoint",{}),"combo":0}
 var growth=preload("res://scripts/progression.gd").new();growth.restore(profile.progression)
 var gain=1+.01*(growth.level()-1);p.max_health=roundi(100*gain);p.max_stamina=100*gain;p.health=p.max_health;p.stamina=p.max_stamina
 refresh_stats(p)
 p.health=mini(p.max_health,int(profile.get("resources",{}).get("health",p.max_health)));p.stamina=minf(p.max_stamina,float(profile.get("resources",{}).get("stamina",p.max_stamina)));p["sword_equipped"]=true
 players[id]=p
 if runtime!=null:
  var bridge=Bridge.new();bridge.profile_enabled=OS.get_environment("WORLD_RISE_PROFILE_RUNTIME")=="1";runtime_owner.add_child(bridge);bridge.setup(runtime,p.profile,id);bridge.set_pose(at,p.yaw,p.pitch);bridge.actor.health=p.health;bridge.actor.stamina=p.stamina;p["bridge"]=bridge
  bridge.presentation.connect(func(event:Dictionary):
   var emitted=event.duplicate(true);emitted["event"]=String(event.get("id",""));emitted["id"]=String(event.get("action_id",""))+":"+str(event.get("event_index",0));emitted["kind"]="audio";emitted["floor"]=p.floor;emitted["position"]=p.position.duplicate();events.append(emitted))
  bridge.actor.damaged.connect(func(_amount):p.last_combat=elapsed)
  runtime.sync_players(players.values())
 return p
func free_position(floor_id:String,origin:Vector3,exclude_id:String="") -> Vector3:
 var runtime=ensure_runtime(floor_id)
 var excluded:Array[RID]=[]
 if players.has(exclude_id) and players[exclude_id].has("bridge"):
  var body=players[exclude_id].bridge.actor
  if is_instance_valid(body):excluded.append(body.get_rid())
 for index in range(49):
  var candidate=origin
  if index>0:
   var ring=1+(index-1)/8;var angle=float((index-1)%8)*TAU/8
   candidate+=Vector3(cos(angle),0,sin(angle))*.85*ring
   candidate.y=maxf(origin.y,world.ground_height(floor_id,candidate))
  if runtime!=null and not runtime.valid_player_position(candidate,4,excluded):continue
  var occupied=false
  for other in players.values():
   if other.id!=exclude_id and other.floor==floor_id and vec(other.position).distance_to(candidate)<.65:occupied=true;break
  if not occupied:return candidate
 return Vector3(INF,INF,INF)
func release_player(id:String) -> void:
 if not players.has(id):return
 var record=players[id]
 for runtime in runtimes.values():
  if runtime.has_method("detach_player"):runtime.detach_player(id)
 if record.has("bridge"):record.bridge.queue_free()
 players.erase(id)
func refresh_stats(p:Dictionary) -> void:
 var stats=Stats.build(p.profile);p["stats"]=stats;p.max_health=stats.max_health;p.max_stamina=stats.max_stamina
 p.health=mini(int(p.health),int(p.max_health));p.stamina=minf(float(p.stamina),float(p.max_stamina))
 if p.has("bridge"):p.bridge.refresh(p.profile)
func vec(value:Array) -> Vector3:return Vector3(float(value[0]),float(value[1]),float(value[2]))
func arr(value:Vector3) -> Array:return [value.x,value.y,value.z]
func finite_number(value:Variant,maximum:float) -> bool:return (value is int or value is float) and is_finite(float(value)) and absf(float(value))<=maximum
func input(id:String,command:Dictionary) -> bool:
 if not players.has(id) or command.size()>8:return false
 var p=players[id]
 if not Profile.integer(command.get("seq"),2147483647) or int(command.seq)<=int(p.input_received_seq):return false
 var movement=command.get("movement",[])
 if not movement is Array or movement.size()!=2 or not finite_number(movement[0],1.01) or not finite_number(movement[1],1.01):return false
 if not finite_number(command.get("yaw"),100000) or not finite_number(command.get("pitch"),1.16):return false
 var buttons=command.get("buttons",{})
 if not buttons is Dictionary or buttons.size()>8:return false
 for key in buttons:
  if key not in ["sprint","jump","blocked"] or not buttons[key] is bool:return false
 p.input_received_seq=int(command.seq);p.input=command.duplicate(true);p.input_age=0.0;p.yaw=fposmod(float(command.yaw),TAU);p.pitch=float(command.pitch)
 return true
func action(id:String,kind:String,payload:Dictionary={}) -> Dictionary:
 if not players.has(id):return fail("Unknown character")
 if persistence_failed:return fail("Storage unavailable; pending reward settlement is being retried")
 var p=players[id]
 if JSON.stringify(payload).length()>8192:return fail("Request too large")
 if kind=="pvp":
  if not payload.get("enabled") is bool:return fail("Invalid PvP state")
  if not payload.enabled and elapsed-float(p.last_combat)<10:return fail("PvP can be disabled ten seconds after combat")
  p.pvp=payload.enabled;return success()
 if kind=="respawn":
  if p.health>0:return fail("Character is alive")
  var at=world.floor_arrival(p.floor)
  if p.checkpoint.has(p.floor):at=vec(p.checkpoint[p.floor])
  at=free_position(p.floor,at,p.id)
  if not at.is_finite():return fail("No clear respawn position is available near this checkpoint; try again when the area is clear")
  p.position=arr(at);p.health=p.max_health;p.stamina=p.max_stamina;p.action="free";p.jump_velocity=0.0
  if p.has("bridge"):
   p.bridge.set_pose(at,p.yaw,p.pitch);p.bridge.actor.health=p.max_health;p.bridge.actor.restore_stamina(p.max_stamina);p.bridge.actor.state="free"
  return success()
 if p.health<=0:return fail("Character is defeated")
 if kind in ["loot","purchase","sell","contract","equip","drink","learn","attribute","refund","reset_attributes","appearance","skill_loadout","heavy_attack"]:return economy(p,kind,payload)
 if p.has("bridge") and kind in ["draw","jump","parry","dodge","dash","dash_charge","dash_release","dash_attack","primary_down","primary_up","charge","release","fire","attack","light","heavy","thrust","bow_draw","bow_cancel","cancel","focus_lost","weapon_equipped","shift_down","shift_up","cancel_primary"]:
  return bridge_action(p,kind,payload)
 if kind=="weapon_equipped":
  if not payload.get("enabled") is bool:return fail("Invalid equipment state")
  p.sword_equipped=payload.enabled
  if not p.sword_equipped:p.sword_drawn=false
  return success()
 if kind=="bow_draw":
  if Profiles.kind(p.weapon)!="bow" or not p.sword_drawn or p.action!="free":return fail("Cannot draw bow now")
  p["bow_draw_started"]=elapsed;return success()
 if kind=="bow_cancel":p.erase("bow_draw_started");return success()
 if kind in ["rest","travel","checkpoint"]:return travel(p,kind,payload)
 if p.action!="free":return fail("Finish the current action")
 if kind=="draw":
  p.sword_drawn=not p.sword_drawn;return begin(p,"draw",float(p.stats.combat.draw_seconds),0)
 if kind=="jump":
  if absf(p.jump_velocity)>.01:return fail("Already airborne")
  var accepted=begin(p,"jump",1.0,12)
  if accepted.ok:p.jump_velocity=6.0
  return accepted
 if kind=="parry":
  if not p.sword_drawn:return fail("Draw your weapon")
  return begin(p,"parry",float(p.stats.combat.parry.duration),float(p.stats.combat.parry.stamina_cost))
 if kind in ["dodge","dash"]:
  var required="belly_roll" if kind=="dodge" else "dash"
  if required not in p.profile.progression.learned:return fail("Learn this ability first")
  return begin(p,kind,float(p.stats.combat.dodge.duration) if kind=="dodge" else .3,float(p.stats.combat.dodge.stamina_cost) if kind=="dodge" else 12*float(p.stats.dash_stamina_multiplier))
 if kind in ["attack","light","heavy","thrust","fire","release"]:
  if not p.sword_drawn:return fail("Draw your weapon")
  var weapon=p.stats.weapon
  if weapon.kind=="bow":return shoot(p,payload)
  var attack="heavy" if kind=="heavy" else "thrust" if kind=="thrust" else "light"
  var tuning=weapon if not weapon.legacy else p.stats.combat[attack]
  p["attack_spec"]={"damage":int(tuning.damage),"active_start":float(tuning.active_start),"active_end":float(tuning.active_end),"radius":float(weapon.get("radius",.05)),"kind":weapon.kind}
  p.last_combat=elapsed
  return begin(p,attack,float(tuning.duration),float(tuning.get("stamina",tuning.get("stamina_cost",20))))
 return fail("Unknown action")
func bridge_action(p:Dictionary,kind:String,payload:Dictionary) -> Dictionary:
 var bridge=p.bridge;var before_stamina=bridge.actor.stamina
 if kind in ["fire","release","primary_up"] and bridge.actor.weapon_type=="bow" and arrows.size()>=128:return fail("Too many active arrows; wait for existing shots")
 var mapped="attack" if kind=="light" else "dash_charge" if kind=="dash" else kind
 var result=bridge.action(mapped,payload)
 if not result.ok:return result
 if result.has("shot"):
  var profile=p.profile.duplicate(true);profile.magic_items=bridge.magic_items.snapshot()
  var next=store.data.duplicate(true);var exported=Profile.checkpoint(profile,store.data.world_id,store.data.characters.get(p.id,{}));next.characters[p.id]=exported
  if not store.commit(next):
   bridge.refresh(p.profile);bridge.actor.stamina=before_stamina;bridge.actor.state="free";return fail(store.last_error)
  p.profile=exported
  var shot=result.shot;var shot_id=Profile.random_id();var settings=shot.settings
  arrows[shot_id]={"id":shot_id,"owner":p.id,"floor":p.floor,"position":arr(shot.origin),"velocity":arr(preload("res://scripts/arrow_ballistics.gd").velocity(shot.direction,shot.charge,settings)),"life":float(settings.lifetime),"damage":roundi(float(shot.context.damage)*float(p.stats.weapon_multiplier)),"gravity":float(settings.gravity),"weapon_kind":"bow","weapon_item":p.weapon,"context":shot.context}
 p.merge(bridge.snapshot(),true)
 if mapped in ["attack","primary_up","fire","release","parry"]:p.last_combat=elapsed
 return success()
func bridge_melee(p:Dictionary) -> void:
 var runtime=runtimes[p.floor];var bridge=p.bridge;var spec=bridge.contact_spec();var actor=bridge.actor
 for enemy in runtime.enemies:
  if not is_instance_valid(enemy) or enemy.health<=0 or spec.hits.has(enemy.get_instance_id()):continue
  if not bridge.contact_candidates(enemy):continue
  if runtime.impact_blocked(bridge.accepted_origin+Vector3.UP*.65,enemy.position+Vector3.UP*.65):continue
  spec.hits[enemy.get_instance_id()]=true
  var key=p.floor+"/"+String(enemy.definition.id)
  if not enemies.has(key):continue
  var e=enemies[key];e.contributors[p.id]=elapsed;e["last_attacker"]=p.id;e["last_weapon"]=actor.weapon_type
  var multiplier=float(p.stats.weapon_multiplier)*(1+float(p.stats.canine_bonus) if enemy.mob_category=="canine" else 1)
  var weakspot=enemy.sword_weakspot_open()
  if bridge.combat_skills.exposed.has(enemy.get_instance_id()):multiplier*=1.2
  var amount=roundi(float(spec.damage)*multiplier);var before=enemy.health
  runtime.apply_enemy_damage(String(enemy.definition.id),amount,(enemy.position-actor.position).normalized(),{"damage_kind":"melee","strong":spec.strong,"force":float(spec.get("recoil_multiplier",1+float(p.stats.sword_recoil))),"actor_id":p.id,"source":spec.context})
  if persistence_failed:return
  bridge.magic_items.sword_hit(enemy,before)
  bridge.combat_skills.sword_hit(enemy,before,weakspot,bool(spec.strong))
  p.profile.magic_items=bridge.magic_items.snapshot()
  events.append({"id":String(spec.context.action_id)+":"+key,"kind":"hit","owner":p.id,"target":key,"floor":p.floor,"position":arr(enemy.position)})
 for victim in players.values():
  if victim.id==p.id or victim.floor!=p.floor or victim.health<=0 or not p.pvp or not victim.pvp or not victim.has("bridge") or spec.hits.has(victim.id):continue
  var player_contact=bridge.contact_player(victim.bridge.actor)
  var weapon_key=String(p.weapon)
  if not pvp_diagnostics.has(weapon_key):pvp_diagnostics[weapon_key]={"candidates":0,"contacts":0,"parries":0,"damaged":0,"damage_rejected":0,"minimum_steel_distance":100000.0}
  var diagnostic=pvp_diagnostics[weapon_key];diagnostic.candidates+=1
  if bridge.accepted_steel.size()==2:
   var nearest=Geometry3D.get_closest_points_between_segments(bridge.accepted_steel[0],bridge.accepted_steel[1],vec(victim.position)+Vector3.UP*.23,vec(victim.position)+Vector3.UP*.89)
   var geometry={"steel":[arr(bridge.accepted_steel[0]),arr(bridge.accepted_steel[1])],"victim":victim.position.duplicate(),"frame":arr(bridge.accepted_frame.origin),"frame_basis":[arr(bridge.accepted_frame.basis.x),arr(bridge.accepted_frame.basis.y),arr(bridge.accepted_frame.basis.z)],"accepted_origin":arr(bridge.accepted_origin),"yaw":p.yaw,"pitch":p.pitch,"phase":p.action_phase}
   var distance=nearest[0].distance_to(nearest[1])
   if distance<float(diagnostic.minimum_steel_distance):diagnostic.minimum_steel_distance=distance;diagnostic["minimum_geometry"]=geometry
   diagnostic["last_geometry"]=geometry
  if not player_contact.hit:continue
  diagnostic.contacts+=1;diagnostic["last_contact"]={"point":arr(player_contact.point),"region":player_contact.get("region","")};spec.hits[victim.id]=true
  var point:Vector3=player_contact.point
  var defender=victim.bridge.actor;var amount=roundi(float(spec.damage)*float(p.stats.weapon_multiplier))
  diagnostic["last_damage"]={"amount":amount,"health_before":defender.health,"invulnerability":defender.invulnerability,"simulation":defender.simulation_active(),"authority":defender.damage_authority,"state":defender.state}
  if defender.try_parry(actor,point):diagnostic.parries+=1
  elif defender.take_damage(amount,(vec(victim.position)-actor.position).normalized()):diagnostic.damaged+=1
  else:diagnostic.damage_rejected+=1
  diagnostic.last_damage["health_after"]=defender.health
  victim.last_combat=elapsed;p.last_combat=elapsed
func begin(p:Dictionary,kind:String,duration:float,cost:float) -> Dictionary:
 if p.stamina<cost:return fail("Not enough stamina")
 p.stamina-=cost;p.regen_delay=.8;p.action=kind;p.action_clock=0.0;p.duration=duration;p.action_phase=0.0;p.action_id=Profile.random_id();p.hits={}
 events.append({"id":p.action_id,"kind":"action","owner":p.id,"action":kind,"floor":p.floor,"position":p.position.duplicate()})
 return success()
func success() -> Dictionary:return {"ok":true}
func fail(message:String) -> Dictionary:return {"ok":false,"error":message}
func step(delta:float) -> void:
 tick+=1
 for claim_id in store.data.claims.keys():
  if store.data.claims[claim_id].get("arrow",false) and float(store.data.claims[claim_id].get("expires",INF))<=elapsed:store.data.claims.erase(claim_id)
 if not pending_settlements.is_empty():
  for transaction_id in pending_settlements.keys():
   var transaction=pending_settlements[transaction_id]
   if store.commit(transaction.next):
    for id in transaction.recipients:
     if players.has(id):players[id].profile=store.data.characters[id].duplicate(true);refresh_stats(players[id])
    pending_settlements.erase(transaction_id)
  persistence_failed=not pending_settlements.is_empty()
  if not pending_settlements.is_empty():return
 if not unsettled_deaths.is_empty():
  var backlog=unsettled_deaths.duplicate();unsettled_deaths.clear()
  for death in backlog:settle_kill(death.enemy,death.killer)
  if not pending_settlements.is_empty():return
 if players.is_empty():return
 elapsed+=delta
 clock=fposmod(clock+delta,1080)
 var actor_started=Time.get_ticks_usec()
 var bridge_totals={}
 for p in players.values():
  p.input_age+=delta;p.invulnerability=maxf(0,p.invulnerability-delta);p.regen_delay=maxf(0,p.regen_delay-delta)
  if p.disconnected>0:
   p.disconnected-=delta
   if p.disconnected<=0:
    if not save_departure(p.id).is_empty():
     release_player(p.id)
    else:p.disconnected=.5
    continue
  if p.has("bridge"):
   var command=p.input.duplicate(true) if p.input_age<.3 and p.disconnected<=0 and not p.get("departing",false) else {"movement":[0,0],"yaw":p.yaw,"pitch":p.pitch,"buttons":{}}
   p.merge(p.bridge.step(delta,command,false),true)
   if p.bridge.profile_enabled:
    for stage in p.bridge.profile_us:bridge_totals[stage]=int(bridge_totals.get(stage,0))+int(p.bridge.profile_us[stage])
   if command.has("seq"):p.input_seq=int(command.seq)
   p.profile.magic_items=p.bridge.magic_items.snapshot()
   if p.contact_active:bridge_melee(p)
   if persistence_failed:break
   discover(p)
   continue
  if p.health<=0:continue
  var previous=float(p.action_phase)
  if p.action!="free":
   p.action_clock+=delta;p.action_phase=clampf(p.action_clock/maxf(.001,p.duration),0,1)
  move_player(p,delta);discover(p)
  if p.action in ["light","heavy","thrust"]:
   var spec=p.attack_spec
   if p.action_phase>=spec.active_start and previous<=spec.active_end:melee(p,previous,p.action_phase)
  if p.action_phase>=1:p.action="free";p.action_phase=0.0
  if p.regen_delay<=0 and p.action=="free":p.stamina=minf(p.max_stamina,p.stamina+26*delta)
 for stage in bridge_totals:sample_stage("bridge/"+stage,int(bridge_totals[stage]))
 sample_stage("actors",Time.get_ticks_usec()-actor_started)
 var native_started=Time.get_ticks_usec()
 if not runtimes.is_empty():
  for e in enemies.values():
   if float(e.cooldown_remaining)>0:
    e.cooldown_remaining=maxf(0,float(e.cooldown_remaining)-delta)
    if e.cooldown_remaining<=0 and runtimes.has(e.floor):
     e.health=e.max_health;e.generation+=1;e.contributors={};e.erase("practice_contributors");e.erase("last_attacker");e.erase("last_weapon");runtimes[e.floor].allow_boss_respawn(e.id)
  for runtime in runtimes.values():
   runtime.sync_players(players.values());runtime.set_day_clock(clock);runtime.step(delta)
   for id in runtime.generation:
    var key=runtime.map_id+"/"+id
    if enemies.has(key) and int(runtime.generation[id])>int(enemies[key].generation):
     enemies[key].generation=runtime.generation[id];enemies[key].health=enemies[key].max_health;enemies[key].native_state={};enemies[key].state="idle";enemies[key].target="";enemies[key].contributors={};enemies[key].erase("practice_contributors");enemies[key].erase("last_attacker");enemies[key].erase("last_weapon")
   for record in runtime.enemy_records():
    var key=record.floor+"/"+record.id
    if not enemies.has(key):
     var base=runtime.authored.get(record.id,{})
     if base.is_empty():continue
     enemies[key]=base.duplicate(true);enemies[key].key=key;enemies[key].contributors={};enemies[key].generation=0;enemies[key].cooldown_remaining=0.0
    var e=enemies[key]
    inherit_participation(e)
    for field in ["position","health","max_health","state","target","state_time","yaw","visual_position","visual_scale","animation","animation_time","attack_kind","duration","moving","native_state"]:e[field]=record.get(field,e.get(field))
    e.generation=int(runtime.generation.get(record.id,e.generation))
    var target_id=String(record.get("target",""))
    if players.has(target_id) and String(record.get("state","idle")) not in ["idle","patrol","sleep"] and vec(players[target_id].position).distance_to(vec(e.position))<=Adapter.PARTICIPATION_RADIUS:e.contributors[target_id]=elapsed;players[target_id].last_combat=elapsed
   if runtime.profile_timings:
    for field in runtime.perf:
     if String(field).ends_with("_ms") and field!="effect_records_ms":sample_stage(runtime.map_id+"/"+field,roundi(float(runtime.perf[field])*1000))
  for p in players.values():
   if p.has("bridge"):p.merge(p.bridge.snapshot(false),true)
 else:
  for enemy in enemies.values():enemy_step(enemy,delta)
 sample_stage("native_worlds",Time.get_ticks_usec()-native_started)
 var arrow_started=Time.get_ticks_usec()
 for arrow in arrows.values():
  if persistence_failed:break
  arrow_step(arrow,delta)
 for id in arrows.keys():
  if arrows[id].life<=0:arrows.erase(id)
 sample_stage("arrows",Time.get_ticks_usec()-arrow_started)
func sample_stage(label:String,duration:int) -> void:
 if not stage_samples.has(label):stage_samples[label]=[]
 stage_samples[label].append(duration)
 if stage_samples[label].size()>600:stage_samples[label].pop_front()
func stage_status() -> Dictionary:
 var result={}
 for label in stage_samples:
  var samples=stage_samples[label].duplicate();samples.sort()
  if not samples.is_empty():result[label]={"p95_ms":float(samples[mini(samples.size()-1,floori(samples.size()*.95))])/1000.0,"max_ms":float(samples[-1])/1000.0,"samples":samples.size()}
 return result
func discover(p:Dictionary) -> void:
 var sites=checkpoints(p.floor)
 for checkpoint_id in sites:
  if vec(p.position).distance_to(vec(sites[checkpoint_id]))<6:
   if not p.discoveries.has(p.floor):p.discoveries[p.floor]=[]
   if checkpoint_id not in p.discoveries[p.floor]:p.discoveries[p.floor].append(checkpoint_id)
func move_player(p:Dictionary,delta:float) -> void:
 var command=p.input if p.input_age<.3 and p.disconnected<=0 else {}
 var movement=command.get("movement",[0,0]);var buttons=command.get("buttons",{})
 var axis=Vector2(movement[0],movement[1]).limit_length()
 if buttons.get("blocked",false) or p.get("departing",false):axis=Vector2.ZERO
 var speed=float(p.stats.combat.drawn_walk_speed) if p.sword_drawn else float(p.stats.walk_speed)
 if buttons.get("sprint",false) and axis.length_squared()>.01 and p.stamina>0 and p.action=="free":
  speed=float(p.stats.combat.drawn_sprint_speed) if p.sword_drawn else float(p.stats.combat.sprint_speed);p.stamina=maxf(0,p.stamina-float(p.stats.combat.drawn_sprint_drain if p.sword_drawn else p.stats.combat.sprint_drain)*delta);p.regen_delay=.8
 if p.action in ["light","heavy","thrust"]:speed*=.4
 if p.action=="dash":speed=9.0*float(p.stats.dash_distance_multiplier)
 if p.action=="dodge":speed=float(p.stats.combat.dodge.speed)
 if p.floor=="wr_floor_02":
  var terrain=preload("res://scripts/swamp_shape.gd")
  var factor=terrain.movement_factor(vec(p.position))
  if float(p.stats.terrain_water_speed)>0 and terrain.depth(vec(p.position))>.03:factor=float(p.stats.terrain_water_speed)
  speed*=factor
 var direction=Basis(Vector3.UP,p.yaw)*Vector3(axis.x,0,axis.y)
 var old=vec(p.position);var next=world.safe_move(p.floor,old,old+direction*speed*delta)
 if runtimes.has(p.floor):
  var runtime=runtimes[p.floor];runtime.sync_players(players.values())
  var vertical=p.jump_velocity
  if vertical!=0:vertical-=18*delta;p.jump_velocity=vertical
  var moved=runtime.move_player(p.id,direction*speed+Vector3.UP*vertical,delta)
  if not moved.is_empty():
   p.position=moved.position;p.velocity=moved.velocity
   if absf(float(moved.velocity[1]))<.01:p.jump_velocity=0.0
   if p.floor=="wr_floor_02" and preload("res://scripts/swamp_shape.gd").depth(vec(p.position))>1.35:damage_player(p,1000,"")
   return
 var ground=world.ground_height(p.floor,next)
 if p.jump_velocity!=0 or old.y>ground+.02:
  p.jump_velocity-=18*delta;next.y=maxf(ground,old.y+p.jump_velocity*delta)
  if next.y<=ground:p.jump_velocity=0.0
 p.velocity=arr((next-old)/delta);p.position=arr(next)
 if p.floor=="wr_floor_02" and preload("res://scripts/swamp_shape.gd").depth(next)>1.35:damage_player(p,1000,"")
 if ground< -20:damage_player(p,1000,"")
func steel(p:Dictionary,phase:float) -> Array:
 var frame=Transform3D(Basis(Vector3.UP,p.yaw)*Basis(Vector3.RIGHT,-p.pitch),vec(p.position)+Vector3.UP*1.52)
 var weapon=Profiles.profile(p.weapon)
 if weapon.kind!="greatsword":return Motion.contact_segments(Motion.weapon_transform(frame,Motion.sample(weapon.kind,"attack",phase)),weapon)
 var pose=sword.sample(p.action,phase)
 var reach=(preload("res://scripts/beta_sword_motion.gd").GRIP-preload("res://scripts/beta_sword_motion.gd").TIP)*float(combat.sword_scale)
 var placement=sword.contact_pose(frame,pose,p.action,phase,reach,world.ground_height(p.floor,frame*pose.grip))
 return [placement.grip+placement.direction*(preload("res://scripts/beta_sword_motion.gd").GRIP-preload("res://scripts/beta_sword_motion.gd").BLADE_BASE)*float(combat.sword_scale),placement.tip]

func melee(p:Dictionary,previous:float,current:float) -> void:
 var spec=p.attack_spec;var steps=maxi(1,ceili((current-previous)*120))
 for sample_index in range(steps+1):
  var phase=lerpf(previous,current,float(sample_index)/steps)
  if phase<spec.active_start or phase>spec.active_end:continue
  var rails=steel(p,phase)
  for enemy in enemies.values():
   if enemy.floor!=p.floor or enemy.health<=0 or not enemy_active(enemy) or p.hits.has(enemy.key):continue
   if contact(p.floor,rails,vec(enemy.position),.65 if enemy.kind=="vault_elder" else .45):
    p.hits[enemy.key]=true;enemy.contributors[p.id]=clock;enemy["last_attacker"]=p.id;enemy["last_weapon"]=Profiles.kind(p.weapon);p.last_combat=elapsed
    if runtimes.has(p.floor):runtimes[p.floor].apply_enemy_damage(enemy.id,weapon_damage(p,int(spec.damage)),(vec(enemy.position)-vec(p.position)).normalized(),{"actor_id":p.id,"damage_kind":"melee","source":{"weapon_type":Profiles.kind(p.weapon)}})
    else:record_weapon_contribution(enemy,p.id,Profiles.kind(p.weapon));enemy.health=maxi(0,int(enemy.health)-weapon_damage(p,int(spec.damage)))
    events.append({"id":p.action_id+enemy.key,"kind":"hit","owner":p.id,"target":enemy.key,"floor":p.floor,"position":enemy.position})
    if enemy.health<=0:settle_kill(enemy,p.id)
  for victim in players.values():
   if victim.id==p.id or victim.floor!=p.floor or not p.pvp or not victim.pvp or victim.health<=0 or p.hits.has(victim.id):continue
   if contact(p.floor,rails,vec(victim.position),.3):p.hits[victim.id]=true;incoming(victim,p,int(spec.damage))
func contact(floor_id:String,rails:Array,at:Vector3,radius:float) -> bool:
 var closest=Geometry3D.get_closest_points_between_segments(rails[0],rails[1],at+Vector3.UP*.25,at+Vector3.UP*1.4)
 return closest[0].distance_to(closest[1])<=radius+.05 and not blocked(floor_id,rails[0],closest[0])
func blocked(floor_id:String,origin:Vector3,destination:Vector3) -> bool:
 if runtimes.has(floor_id):return runtimes[floor_id].impact_blocked(origin,destination)
 return world.impact_blocked(floor_id,origin,destination)
func weapon_damage(p:Dictionary,amount:int) -> int:
 # Greatsword combat damage already includes the shared WorldRiseStats passives.
 return roundi(amount*float(p.stats.weapon_multiplier))
func incoming(victim:Dictionary,attacker:Dictionary,amount:int) -> bool:
 var offset=vec(attacker.position)-vec(victim.position);var facing=Basis(Vector3.UP,victim.yaw)*Vector3.FORWARD
 if victim.action=="parry" and victim.action_clock<=.18 and offset.length()<=4.8 and facing.dot(offset.normalized())>0 and not world.impact_blocked(victim.floor,vec(victim.position)+Vector3.UP,vec(attacker.position)+Vector3.UP):
  if attacker.has("timer"):attacker.state="recover";attacker.timer=1.0
  events.append({"id":Profile.random_id(),"kind":"parry","owner":victim.id,"floor":victim.floor,"position":victim.position});return false
 damage_player(victim,amount,attacker.get("id",attacker.get("key","")));return true
func damage_player(p:Dictionary,amount:int,source:String) -> void:
 if p.has("bridge"):
  p.bridge.actor.take_damage(amount,Vector3.ZERO);p.merge(p.bridge.snapshot(false),true);return
 if p.health<=0 or p.invulnerability>0:return
 var reduction=clampf(float(p.stats.damage_reduction)+float(p.stats.gear_armor),0,1)
 p.health=maxi(0,p.health-roundi(amount*(1-reduction)));p.invulnerability=.9;p.last_combat=elapsed
 p.erase("bow_draw_started")
 if p.action in ["fire","thrust","heavy"]:p.action="stagger";p.action_clock=0.0;p.duration=.8;p.action_phase=0.0
 if p.health<=0:p.action="dead"
 events.append({"id":Profile.random_id(),"kind":"damage","owner":p.id,"source":source,"floor":p.floor,"position":p.position})
func enemy_active(e:Dictionary) -> bool:
 if runtimes.has(e.floor):
  var actual=runtimes[e.floor].enemy_node(String(e.id))
  return actual!=null and actual.health>0
 if e.get("night_only",false) and clock<600:return false
 if e.has("parent_id"):
  var parent=enemies.get(e.floor+"/"+e.parent_id,{})
  if parent.is_empty() or parent.health>0:return false
 return true
func enemy_step(e:Dictionary,delta:float) -> void:
 var nearby=players.values().filter(func(p):return p.floor==e.floor and p.health>0 and vec(p.position).distance_to(vec(e.position))<90)
 if nearby.is_empty():
  e.empty+=delta
  if e.empty>=Adapter.RESET_EMPTY_SECONDS and not e.get("cooldown",0)>0 and (e.health<e.max_health or e.state!="idle"):
   e.health=e.max_health;e.position=e.get("home",world.floor_arrival(e.floor) if not e.has("at") else [e.at[0],world.ground_height(e.floor,Vector3(e.at[0],0,e.at[1])),e.at[1]]).duplicate();e.state="idle";e.contributors={};e.erase("practice_contributors");e.generation+=1
  return
 e.empty=0.0
 if e.cooldown_remaining>0:
  e.cooldown_remaining=maxf(0,e.cooldown_remaining-delta)
  if e.cooldown_remaining<=0:e.health=e.max_health;e.generation+=1;e.contributors={};e.erase("practice_contributors")
 if e.health<=0 or not enemy_active(e):return
 var target:Dictionary={};var nearest=float(e.get("aggro",18))
 for p in nearby:
  var distance=vec(p.position).distance_to(vec(e.position))
  if distance<nearest:target=p;nearest=distance
 if target.is_empty():return
 e.target=target.id;e.timer=maxf(0,e.timer-delta)
 if e.state=="recover":
  if e.timer<=0:e.state="idle"
  return
 if e.state=="windup":
  if e.timer<=0:
   if nearest<=float(e.get("range",3.5))+1.0:incoming(target,e,int(e.damage));e.contributors[target.id]=clock
   e.state="recover";e.timer=float(e.get("recovery",1.4))
  return
 if nearest<float(e.get("range",3.6)):
  e.state="windup";e.timer=float(e.get("windup",.8));return
 var origin=vec(e.position);var home=vec(e.get("home",e.position));var proposed=origin+(vec(target.position)-origin).normalized()*float(e.get("speed",1.6))*delta
 if proposed.distance_to(home)<float(e.get("leash",32)):e.position=arr(world.safe_move(e.floor,origin,proposed,.35))
func settle_kill(e:Dictionary,killer:String) -> void:
 if not pending_settlements.is_empty():
  if not unsettled_deaths.any(func(death):return death.enemy.key==e.key and death.enemy.generation==e.generation):unsettled_deaths.append({"enemy":e,"killer":killer})
  return
 var tx=store.data.world_id+"/"+e.key+"/"+str(e.generation)
 if store.data.transactions.get(e.key,-1)==int(e.generation):return
 var next=store.data.duplicate(true);next.transactions[e.key]=int(e.generation)
 var candidates=players.values().filter(func(p):return p.floor==e.floor and p.health>0 and e.contributors.has(p.id) and vec(p.position).distance_to(vec(e.position))<=Adapter.PARTICIPATION_RADIUS)
 for p in candidates:
  var profile=p.profile.duplicate(true);var reward=world.roll_rewards(e,rng);var xp=int(reward.xp)
  if e.has("first_flag") and e.first_flag not in profile.bonus_claims:profile.bonus_claims.append(e.first_flag);xp+=int(e.first_bonus)
  profile.progression.xp=mini(10000000,int(profile.progression.xp)+xp);profile.copper=mini(100000000,int(profile.copper)+int(reward.copper))
  if xp>0 and not e.get("practice_contributors",{}).get(p.id,[]).is_empty():
   var growth=preload("res://scripts/progression.gd").new();growth.restore(profile.progression)
   for weapon in e.practice_contributors[p.id]:growth.award_practice(String(weapon),1)
   profile.progression=growth.snapshot()
  var claim=tx+"/"+p.id
  if not reward.items.is_empty():next.claims[claim]={"owner":p.id,"floor":e.floor,"position":e.position.duplicate(),"items":reward.items,"arrow":false}
  Economy.record_kill(next,p.id,e.kind)
  var exported=Profile.checkpoint(profile,store.data.world_id,store.data.characters.get(p.id,{}));next.characters[p.id]=exported
 if e.kind=="vault_elder" and "elder_defeated" not in next.flags:next.flags.append("elder_defeated")
 e.cooldown_remaining=float(e.get("cooldown",0));next.encounters[e.key]=encounter_save(e)
 if not store.commit(next):
  persistence_failed=true;pending_settlements[tx]={"next":next,"recipients":candidates.map(func(player):return player.id)};return
 pending_settlements.erase(tx);persistence_failed=false
 for p in candidates:p.profile=store.data.characters[p.id].duplicate(true);refresh_stats(p)
 events.append({"id":tx,"kind":"defeat","target":e.key,"floor":e.floor,"position":e.position})
func encounter_save(e:Dictionary) -> Dictionary:return {"position":e.position.duplicate(),"health":e.health,"generation":e.generation,"cooldown_remaining":e.cooldown_remaining,"native_state":e.get("native_state",{}).duplicate(true),"practice_contributors":e.get("practice_contributors",{}).duplicate(true)}
func checkpoint_all() -> bool:
 if not pending_settlements.is_empty() or not unsettled_deaths.is_empty():return false
 var next=store.data.duplicate(true);next.day_clock=clock;next["elapsed"]=elapsed
 for e in enemies.values():next.encounters[e.key]=encounter_save(e)
 for p in players.values():
  if p.has("bridge"):p.merge(p.bridge.snapshot(false),true);p.profile.magic_items=p.bridge.magic_items.snapshot()
  var profile=p.profile.duplicate(true);profile["resources"]={"health":p.health,"stamina":p.stamina}
  next.characters[p.id]=Profile.checkpoint(profile,store.data.world_id,store.data.characters.get(p.id,{}))
  var visitor=next.visitors.get(p.id,{}).duplicate(true)
  visitor.merge({"floor":p.floor,"position":p.position.duplicate(),"checkpoint":p.checkpoint.duplicate(true),"discoveries":p.discoveries.duplicate(true)},true);next.visitors[p.id]=visitor
 if not store.commit(next):return false
 persistence_failed=not pending_settlements.is_empty()
 for p in players.values():p.profile=store.data.characters[p.id].duplicate(true)
 return true
func save_departure(id:String) -> Dictionary:
 if not players.has(id) or not pending_settlements.is_empty() or not unsettled_deaths.is_empty():return {}
 var p=players[id];var next=store.data.duplicate(true);next.day_clock=clock;next["elapsed"]=elapsed
 if p.has("bridge"):p.merge(p.bridge.snapshot(false),true);p.profile.magic_items=p.bridge.magic_items.snapshot()
 p.profile["resources"]={"health":p.health,"stamina":p.stamina}
 for e in enemies.values():next.encounters[e.key]=encounter_save(e)
 var exported=Profile.checkpoint(p.profile,store.data.world_id,store.data.characters.get(id,{}));next.characters[id]=exported
 var visitor=next.visitors.get(id,{}).duplicate(true)
 visitor.merge({"floor":p.floor,"position":p.position.duplicate(),"checkpoint":p.checkpoint.duplicate(true),"discoveries":p.discoveries.duplicate(true)},true);next.visitors[id]=visitor
 if not store.commit(next):return {}
 persistence_failed=not pending_settlements.is_empty();p.profile=exported;return exported
func travel(p:Dictionary,kind:String,payload:Dictionary) -> Dictionary:
 if p.action!="free":return fail("Finish your action")
 var origin=vec(p.position)
 for e in enemies.values():
  if e.floor!=p.floor or e.health<=0 or not enemy_active(e):continue
  var distance=origin.distance_to(vec(e.position))
  var native=e.get("native_state",{})
  var engaged=not String(e.get("target","")).is_empty() and (String(e.get("state","idle")) not in ["idle","patrol","sleep"] or native.get("engaged",false) or native.get("pack_engaged",false) or native.get("encounter_engaged",false))
  if distance<30 and engaged:return fail("Active enemies are nearby")
  if kind=="rest" and distance<12:return fail("Enemies are too close to rest")
 if kind=="rest":
  var previous_health=int(p.health);var previous_stamina=float(p.stamina);var previous_checkpoint=p.checkpoint.duplicate(true);var previous_profile=p.profile.duplicate(true)
  var sites=checkpoints(p.floor);var found=false
  for site in sites:
   if origin.distance_to(vec(sites[site]))<=6:p.checkpoint[p.floor]=sites[site].duplicate();found=true
  if not found:return fail("Rest at a crystal")
  p.health=p.max_health;p.stamina=p.max_stamina
  if p.has("bridge"):p.bridge.actor.restore_health(p.max_health);p.bridge.actor.restore_stamina(p.max_stamina)
  if not save_departure(p.id).is_empty():return success()
  p.health=previous_health;p.stamina=previous_stamina;p.checkpoint=previous_checkpoint;p.profile=previous_profile
  if p.has("bridge"):p.bridge.actor.health=previous_health;p.bridge.actor.stamina=previous_stamina
  return fail(store.last_error)
 if kind=="checkpoint":
  var sites=checkpoints(p.floor);var selected=String(payload.get("checkpoint",""));var near=false
  for point in sites.values():
   if origin.distance_to(vec(point))<=6:near=true
  if not near:return fail("Move near a source crystal")
  if not sites.has(selected) or selected not in p.discoveries.get(p.floor,[]):return fail("Discover this crystal first")
  var old_position=p.position.duplicate()
  var landing=free_position(p.floor,vec(sites[selected]),p.id)
  if not landing.is_finite():return fail("Crystal landing is occupied")
  p.position=arr(landing);p.input={};p.jump_velocity=0.0
  if p.has("bridge"):p.bridge.set_pose(vec(p.position),p.yaw,p.pitch)
  if not save_departure(p.id).is_empty():return success()
  p.position=old_position
  if p.has("bridge"):p.bridge.set_pose(vec(old_position),p.yaw,p.pitch)
  return fail(store.last_error)
 var destination=String(payload.get("floor",p.floor));var at=world.floor_arrival(destination)
 if destination not in Adapter.FLOORS:return fail("Unknown floor")
 if destination=="wr_floor_02" and "elder_defeated" not in store.data.flags:return fail("Defeat the Elder first")
 if destination=="wr_boss_chamber":
  if p.floor!="wr_floor_01" or Vector2(origin.x+168,origin.z+125).length()>12:return fail("Use the Vault entrance")
 elif p.floor!="wr_boss_chamber" and origin.distance_to(world.floor_arrival(p.floor))>6:return fail("Use the arrival platform")
 if p.floor=="wr_boss_chamber":
  if destination!="wr_floor_01" or origin.distance_to(Vector3(0,0,38))>6 or runtimes[p.floor].current_world.combat_locked() or not runtimes[p.floor].current_world.bridge_open:return fail("Use the open Vault return arch")
  var exit=preload("res://scripts/rise_chamber.gd").return_point();at=Vector3(exit.x,world.ground_height(destination,Vector3(exit.x,0,exit.y)),exit.y)
 at=free_position(destination,at,p.id)
 if not at.is_finite():return fail("Destination landing is occupied")
 var old_floor=String(p.floor);var old_at=vec(p.position)
 p.floor=destination;p.position=arr(at);p.input={};p.jump_velocity=0.0
 var destination_runtime=ensure_runtime(destination)
 if p.has("bridge"):
  p.bridge.rebind(destination_runtime);p.bridge.set_pose(at,p.yaw,p.pitch)
 var exported=save_departure(p.id)
 if not exported.is_empty():return success()
 p.floor=old_floor;p.position=arr(old_at)
 if p.has("bridge"):p.bridge.rebind(runtimes[old_floor]);p.bridge.set_pose(old_at,p.yaw,p.pitch)
 return fail(store.last_error)
func checkpoints(floor_id:String) -> Dictionary:
 var sites={"arrival":arr(world.floor_arrival(floor_id))}
 if floor_id=="wr_floor_01":
  for entry in preload("res://scripts/rise_shape.gd").spec.landmarks:
   if entry.type=="rest":sites[entry.id]=[entry.at[0],world.ground_height(floor_id,Vector3(entry.at[0],0,entry.at[1])),entry.at[1]]
 if floor_id=="wr_floor_02":
  for entry in preload("res://scripts/swamp_shape.gd").spec.sites:
   sites[entry.id]=[entry.at[0],world.ground_height(floor_id,Vector3(entry.at[0],0,entry.at[1])),entry.at[1]]
 return sites
func live_resources(p:Dictionary) -> Dictionary:
 if p.has("bridge"):return {"health":p.bridge.actor.health,"stamina":p.bridge.actor.stamina}
 return {"health":p.health,"stamina":p.stamina}
func economy(p:Dictionary,kind:String,payload:Dictionary) -> Dictionary:
 if kind in ["purchase","sell","contract"]:return Economy.transact(self,p,kind,payload)
 var profile=p.profile.duplicate(true);var next=store.data.duplicate(true)
 profile["resources"]=live_resources(p)
 var post_heal=0
 if kind=="equip":
  var item=String(payload.get("item",""))
  if not item.is_empty() and item not in profile.magic_items.owned:return fail("Item not owned")
  if p.action!="free":return fail("Finish your action")
  var equipment=preload("res://scripts/magic_items.gd").new();var entry=equipment.item(item)
  var growth=preload("res://scripts/progression.gd").new();growth.restore(profile.progression)
  if not item.is_empty() and growth.level()<int(entry.get("effects",{}).get("level",1)):return fail("Level requirement not met")
  if payload.has("slot"):
   var magic=preload("res://scripts/magic_items.gd").new();var slot=String(payload.slot)
   if slot not in magic.SLOTS:return fail("Invalid equipment slot")
   if item.is_empty():profile.magic_items.slots.erase(slot)
   elif entry.get("category","")!=magic.category(slot):return fail("Invalid equipment slot")
   else:profile.magic_items.slots[slot]=item
  else:
   if not Profiles.valid_item(item):return fail("Invalid weapon")
   profile.magic_items.weapon_id=item
 elif kind=="drink":
  var item=String(payload.get("item",""));var magic=preload("res://scripts/magic_items.gd").new();var entry=magic.item(item)
  if item not in profile.magic_items.owned or entry.get("category","")!="consumable" or item=="wooden_arrows":return fail("Potion not owned")
  profile.magic_items.quantities[item]-=1
  if profile.magic_items.quantities[item]<=0:profile.magic_items.quantities.erase(item);profile.magic_items.owned.erase(item)
  post_heal=int(entry.effects.get("burst_heal",0))
  if float(entry.effects.get("regen_seconds",0))>0:
   if profile.magic_items.healing.size()>=297:return fail("Too many active potion effects")
   profile.magic_items.healing.append({"id":item,"remaining":float(entry.effects.regen_seconds),"clock":0.0})
 elif kind=="skill_loadout":
  var skill=String(payload.get("skill",""))
  if skill not in ["dash","jump","flowing_counter"] or not payload.get("enabled") is bool:return fail("Invalid skill loadout")
  if payload.enabled and skill!="jump" and skill not in profile.progression.learned:return fail("Learn this ability first")
  if not profile.has("skill_loadout"):profile.skill_loadout={"dash":false,"jump":true,"flowing_counter":false}
  profile.skill_loadout[skill]=payload.enabled
 elif kind=="heavy_attack":
  var style=String(payload.get("style",""))
  if style not in ["overhead","charge_thrust"] or (style=="charge_thrust" and "charge_thrust" not in profile.progression.learned):return fail("Learn this heavy style first")
  profile.heavy_attack=style
 elif kind in ["learn","attribute","refund","reset_attributes"]:
  if p.health<=0 or p.action!="free" or (p.has("bridge") and p.bridge.actor.state!="free"):return fail("Finish your action before changing progression")
  var growth=preload("res://scripts/progression.gd").new();growth.restore(profile.progression)
  var changed=false
  if kind=="learn":changed=growth.learn(String(payload.get("skill","")))
  elif kind=="attribute":changed=growth.increase_attribute(String(payload.get("attribute","")))
  elif kind=="refund":changed=growth.refund(String(payload.get("skill","")))
  else:changed=growth.reset_attributes()
  if not changed:return fail("Progression requirements not met")
  profile.progression=growth.snapshot()
  for ability in ["dash","flowing_counter"]:
   if not growth.has(ability):profile.skill_loadout[ability]=false
  if not growth.has("charge_thrust"):profile.heavy_attack="overhead"
 elif kind=="loot":
  var claim_id=String(payload.get("claim",payload.get("id","")));var claim=next.claims.get(claim_id,{})
  if claim.is_empty() or claim.floor!=p.floor or (claim.owner!=p.id and not claim.get("arrow",false)) or vec(claim.position).distance_to(vec(p.position))>3:return fail("Loot is unavailable")
  if claim.get("arrow",false):
   if int(profile.magic_items.quantities.get("wooden_arrows",0))>=99:return fail("Arrow stack is full")
   profile.magic_items.quantities["wooden_arrows"]=int(profile.magic_items.quantities.get("wooden_arrows",0))+1
   if "wooden_arrows" not in profile.magic_items.owned:profile.magic_items.owned.append("wooden_arrows")
  else:
   for id in claim.items:
    if id in preload("res://scripts/rise_guild.gd").catalog.materials:profile.materials[id]=mini(99999,int(profile.materials.get(id,0))+int(claim.items[id]))
    else:
     var item=preload("res://scripts/magic_items.gd").new().item(id)
     if item.is_empty():return fail("Unknown loot item")
     if item.category=="consumable":
      if int(profile.magic_items.quantities.get(id,0))+int(claim.items[id])>99:return fail("Item stack is full")
      profile.magic_items.quantities[id]=int(profile.magic_items.quantities.get(id,0))+int(claim.items[id])
     if id not in profile.magic_items.owned:profile.magic_items.owned.append(id)
  next.claims.erase(claim_id)
 elif kind=="purchase":
  return purchase(p,payload)
 elif kind=="appearance":
  var appearance=payload.get("profile",{})
  if not preload("res://scripts/appearance_profile.gd").valid(appearance):return fail("Invalid appearance")
  profile.appearance=appearance.duplicate(true)
 else:return fail("Unknown transaction")
 if post_heal>0:profile.resources.health=mini(int(Profile.resource_maxima(profile).health),int(profile.resources.health)+post_heal)
 var exported=Profile.checkpoint(profile,store.data.world_id,store.data.characters.get(p.id,{}))
 if not Profile.valid(exported):return fail("Transaction would invalidate the profile")
 next.characters[p.id]=exported
 if not store.commit(next):return fail(store.last_error)
 p.profile=exported;p.weapon=exported.magic_items.weapon_id;p.health=exported.resources.health;p.stamina=exported.resources.stamina;refresh_stats(p)
 if post_heal>0 and p.has("bridge"):p.bridge.actor.restore_health(p.health)
 return success()
func finish_economy(p:Dictionary,profile:Dictionary,next:Dictionary) -> Dictionary:
 profile["resources"]=live_resources(p)
 var exported=Profile.checkpoint(profile,store.data.world_id,store.data.characters.get(p.id,{}))
 if not Profile.valid(exported):return fail("Transaction would invalidate profile")
 next.characters[p.id]=exported
 if not store.commit(next):return fail(store.last_error)
 p.profile=exported;p.weapon=exported.magic_items.weapon_id;p.health=exported.resources.health;p.stamina=exported.resources.stamina;refresh_stats(p)
 return success()
func purchase(p:Dictionary,payload:Dictionary) -> Dictionary:
 var catalog=preload("res://scripts/rise_guild.gd").catalog
 var at=vec(p.position);var vendor=Vector3(146,world.ground_height(p.floor,Vector3(146,0,146)),146)
 if p.floor=="wr_floor_02":
  var raft=preload("res://scripts/swamp_shape.gd").spec.raft;vendor=Vector3(raft.anchor[0]+16,at.y,raft.anchor[1])
 if at.distance_to(vendor)>15:return fail("Speak to the vendor nearby")
 var id=String(payload.get("item",""));var recipe:Dictionary=catalog.get("recipes",{}).get(id,{})
 # New weapon vendor entries are handled by their normal content table.
 if recipe.is_empty():return fail("Unknown vendor item")
 var cost=int(recipe.get("copper",recipe.get("cost",0)));var profile=p.profile.duplicate(true)
 if cost<0 or profile.copper<cost:return fail("Not enough copper")
 if id in profile.magic_items.owned:return fail("Item already owned")
 for material in recipe.get("materials",{}):
  if int(profile.materials.get(material,0))<int(recipe.materials[material]):return fail("Missing materials")
 var growth=preload("res://scripts/progression.gd").new();growth.restore(profile.progression)
 if growth.level()<int(recipe.get("level",1)):return fail("Level requirement not met")
 profile.copper-=cost
 for material in recipe.get("materials",{}):profile.materials[material]-=int(recipe.materials[material])
 profile.magic_items.owned.append(id)
 var exported=Profile.checkpoint(profile,store.data.world_id,store.data.characters.get(p.id,{}))
 if not Profile.valid(exported):return fail("Invalid purchase")
 var next=store.data.duplicate(true);next.characters[p.id]=exported
 if not store.commit(next):return fail(store.last_error)
 p.profile=exported;return success()
func shoot(p:Dictionary,payload:Dictionary) -> Dictionary:
 if int(p.profile.magic_items.quantities.get("wooden_arrows",0))<=0:return fail("Buy arrows from a vendor")
 if not p.has("bow_draw_started"):return fail("Start drawing the bow first")
 var raw_charge=payload.get("charge",0)
 if not finite_number(raw_charge,1) or raw_charge<0:return fail("Invalid draw strength")
 var weapon=p.stats.weapon
 var charge=clampf((elapsed-float(p.bow_draw_started))/float(weapon.draw_max_seconds),0,1)
 if p.stamina<float(weapon.stamina):return fail("Not enough stamina")
 var basis=Basis(Vector3.UP,p.yaw)*Basis(Vector3.RIGHT,-p.pitch);var eye=vec(p.position)+Vector3.UP*1.52
 var origin=eye+basis*Vector3(-.24,-.22,-1.34+.435*charge)
 if blocked(p.floor,eye,origin):return fail("The bow is obstructed")
 var profile=p.profile.duplicate(true);profile.magic_items.quantities["wooden_arrows"]-=1
 if profile.magic_items.quantities["wooden_arrows"]<=0:profile.magic_items.quantities.erase("wooden_arrows");profile.magic_items.owned.erase("wooden_arrows")
 var exported=Profile.checkpoint(profile,store.data.world_id,store.data.characters.get(p.id,{}));var next=store.data.duplicate(true);next.characters[p.id]=exported
 if not store.commit(next):return fail(store.last_error)
 p.profile=exported;p.erase("bow_draw_started")
 var result=begin(p,"fire",float(weapon.duration),float(weapon.stamina))
 arrows[p.action_id]={"id":p.action_id,"owner":p.id,"floor":p.floor,"position":arr(origin),"velocity":arr(-basis.z*lerpf(weapon.minimum_speed,weapon.maximum_speed,charge)),"life":float(weapon.lifetime),"damage":weapon_damage(p,int(weapon.damage)),"gravity":float(weapon.gravity),"weapon_kind":"bow","weapon_item":p.weapon}
 return result
func arrow_step(a:Dictionary,delta:float) -> void:
 a.life-=delta
 var start=vec(a.position);var velocity=vec(a.velocity)
 var next=preload("res://scripts/arrow_ballistics.gd").advance(start,velocity,delta,float(a.gravity));a.position=arr(next.position);a.velocity=arr(next.velocity)
 if not runtimes.has(a.floor):a.life=0;return
 var excludes:Array[RID]=[]
 var candidates:Array=[]
 var runtime=runtimes[a.floor]
 if players.has(a.owner) and players[a.owner].has("bridge"):excludes.append(players[a.owner].bridge.actor.get_rid())
 for body in players.values():
  if body.floor==a.floor and body.has("bridge") and body.health>0:candidates.append(body.bridge.actor)
 var hit=preload("res://scripts/arrow_ballistics.gd").sweep(runtime.world_root.get_world_3d().direct_space_state,start,next.position,excludes,candidates)
 if hit.is_empty():return
 a.life=0;a.position=arr(hit.position)
 var collider=hit.collider
 if collider!=null and collider.has_meta("character_id"):
  var id=String(collider.get_meta("character_id"))
  # First combat body intercepts; non-PvP friends take no damage/recoil.
  var interception={"arrow_id":a.id,"character_id":id,"position":arr(hit.position),"part":hit.get("player_region",""),"outcome":"friend","claim_created":false}
  pvp_diagnostics["last_character_arrow_interception"]=interception
  if not pvp_diagnostics.has("character_arrow_interceptions"):pvp_diagnostics["character_arrow_interceptions"]=[]
  pvp_diagnostics.character_arrow_interceptions.append(interception)
  if pvp_diagnostics.character_arrow_interceptions.size()>8:pvp_diagnostics.character_arrow_interceptions.pop_front()
  if players.has(id) and players.has(a.owner) and players[id].pvp and players[a.owner].pvp:
   players[id].last_combat=elapsed;players[a.owner].last_combat=elapsed
   if preload("res://scripts/network/wr_arrow_threat.gd").blocked_by(collider,runtime.world_root,hit.position,a.id):
    interception.outcome="parry";recover_arrow(a,hit.position);interception.claim_created=store.data.claims.has(a.id);return
   interception.outcome="damage" if collider.take_damage(int(a.damage),velocity.normalized()) else "damage_rejected"
  else:
   recover_arrow(a,hit.position);interception.claim_created=store.data.claims.has(a.id)
  return
 if collider!=null and collider.get("definition") is Dictionary:
  var definition:Dictionary=collider.definition;var key=a.floor+"/"+String(definition.get("id",""))
  if enemies.has(key):
   var e=enemies[key];e.contributors[a.owner]=elapsed;e["last_attacker"]=a.owner;e["last_weapon"]=a.weapon_kind
   runtime.apply_enemy_damage(e.id,int(a.damage),velocity.normalized(),{"damage_kind":"projectile","actor_id":a.owner,"source":{"weapon_type":a.weapon_kind,"actor_id":a.owner}})
   events.append({"id":a.id+":hit","kind":"hit","owner":a.owner,"target":key,"floor":a.floor,"position":arr(hit.position)})
   return
 recover_arrow(a,hit.position)
 events.append({"id":a.id+":impact","kind":"audio","event":"projectile.impact.stone","floor":a.floor,"position":arr(hit.position)})
func recover_arrow(a:Dictionary,at:Vector3) -> void:
 var proposal=store.data.duplicate(true)
 proposal.claims[a.id]={"owner":a.owner,"floor":a.floor,"position":arr(at),"items":{},"arrow":true,"expires":elapsed+90.0}
 if not store.commit(proposal):
  # Retry the identical single claim after storage recovery; no phantom pickup.
  pending_settlements["arrow/"+a.id]={"next":proposal,"recipients":[]};persistence_failed=true
func snapshot() -> Dictionary:
 var visible={}
 var native_effects={}
 for runtime in runtimes.values():
  if runtime.has_method("effect_records"):
   native_effects.merge(runtime.effect_records())
   if runtime.profile_timings:sample_stage(runtime.map_id+"/effect_records_ms",roundi(float(runtime.perf.get("effect_records_ms",0))*1000))
 for id in players:
  var p=players[id].duplicate(true)
  if players[id].has("bridge"):p["pose_state"]=players[id].bridge.pose_state()
  p["contracts"]=store.data.visitors.get(id,{}).get("contracts",{}).duplicate(true)
  p.appearance=p.profile.appearance.duplicate(true)
  for secret in ["input","hits","attack_spec","stats","bridge"]:p.erase(secret)
  p.state=p.action;visible[id]=p
 return {"tick":tick,"clock":clock,"world_id":store.data.world_id,"players":visible,"enemies":enemies.duplicate(true),"projectiles":arrows.duplicate(true),"native_effects":native_effects,"claims":store.data.claims.duplicate(true),"events":events.duplicate(true),"storage_error":store.last_error,"flags":store.data.flags.duplicate()}
