extends SceneTree
## Native playable Actor versus network adapter over the same accepted commands.
const Bridge=preload("res://scripts/network/wr_actor_bridge.gd")
const View=preload("res://scripts/network/wr_view_frame.gd")
var failures:Array=[]
var checks=0
var max_steel={}
var held_clock=0.0
var pending=false
var native_contact_expected=false
var native_contact_value=false
var max_frame={}
var draw_only="--draw-only" in OS.get_cmdline_user_args()
class CounterTarget extends Node3D:
 var health=10
 var definition={"id":"fixture_counter_enemy","kind":"slime","combat_radius":.23,"combat_height":1.12}
 var size_class="small"
 var repel_count=0
 func repel(_away:Vector3,_force:float,_stun:float) -> void:repel_count+=1
class ContactRuntime extends "res://scripts/weapon_runtime.gd":
 var contact_observer:Callable
 func tick(delta:float) -> void:
  var prior=previous_segment.duplicate()
  super.tick(delta)
  if actor.state!="weapon_attack":return
  var phase=actor.state_time/actor.state_duration
  if phase<float(settings.active_start) or phase>float(settings.active_end):return
  var saved=previous_segment;previous_segment=prior
  if contact_observer.is_valid():contact_observer.call(self,contact_segments())
  previous_segment=saved
class FloorContext extends Node:
 var map_id="wr_floor_01"
 var enemies:Array=[]
 var current_world:Node3D
 var world_root:Node3D
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
 checks+=1
 if not ok:failures.append(message);push_error(message)
func direct(actor:Node,kind:String) -> bool:
 match kind:
  "draw":return actor.toggle_sword()
  "attack":return actor.begin_attack("light")
  "down":
   held_clock=0;pending=actor.begin_charge();return pending
  "up":
   if not pending:return true
   pending=false
   return actor.release_charge("heavy" if actor.thrust_charging and held_clock>=float(actor.combat.heavy_hold_seconds) else "light")
  "parry":pending=false;actor.cancel_pending_input();return actor.begin_parry()
  "dodge":return actor.request_dodge()
  "dash_down":return actor.begin_dash_charge()
  "dash_up":return actor.release_dash()
  "dash_attack":return actor.queue_dash_attack()
  "jump":return actor.begin_jump()
  "cancel":
   pending=false;actor.cancel_pending_input()
   if actor.state=="bow_draw":actor.weapon_runtime.cancel()
   return true
 return false
func run() -> void:
 var g=load("res://scenes/main.tscn").instantiate();root.add_child(g);await process_frame;await process_frame
 g.game_mode="world_rise";g.start_new_game(false);g.title_screen.hide();g._refresh_simulation();g.set_process(false);g.set_physics_process(false)
 for e in g.enemies:e.ai_enabled=false;e.set_physics_process(false)
 var local=g.player;local.set_physics_process(false);local.set_meta("canonical_manual_step",true);local.get_node("BetaHero").set_process(false);local.set_process_input(false);local.collision_mask=1|4
 g.progression.xp=10000000;g.progression.greatsword_kills=1000
 for skill in ["iron_body","honed_arms","swiftfoot","dash","streaming_dash","lightstep","belly_roll","roly_poly","speed_freak","great_greatsword","charge_thrust","fast_thrust","basher"]:g.progression.learn(skill)
 var floor_context=FloorContext.new();floor_context.current_world=g.current_world;floor_context.world_root=g.world_root;root.add_child(floor_context)
 var local_driver=View.new()
 for item in ["standard_greatsword","field_spear","duelist_rapier","hunting_bow"]:
  local.free();local=preload("res://scripts/actor.gd").new();g.player=local
  local.controllable=true;local.configure(JSON.parse_string(FileAccess.get_file_as_string("res://content/characters/"+String(g.config.player_character)+".json")))
  g.world_root.add_child(local);local.set_physics_process(false);local.set_process_input(false);local.set_meta("canonical_manual_step",true);local.collision_mask=1|4;local.ground_world=g.current_world
  local.weapon_runtime=ContactRuntime.new();local.weapon_runtime.configure(g,local)
  preload("res://scripts/beta_hero.gd").apply(local,true);local.get_node("BetaHero").set_process(false)
  local_driver=View.new();local_driver.bind(local,g.config.follow_camera)
  if item not in g.magic_items.owned:g.magic_items.owned.append(item)
  g.magic_items.weapon_id=item
  if item=="hunting_bow":
   if "wooden_arrows" not in g.magic_items.owned:g.magic_items.owned.append("wooden_arrows")
   g.magic_items.quantities["wooden_arrows"]=99
  local.set_weapon_visual(item);g.apply_skill_stats()
  local.dash_equipped=true;local.heavy_style="charge_thrust" if item=="standard_greatsword" else "overhead"
  local.get_node("BetaHero").gait=preload("res://scripts/beta_gait.gd").new()
  local.first_person_sword=preload("res://scripts/first_person_sword.gd").new()
  local.set_sword_drawn(false);local.health=local.max_health;local.restore_stamina(local.max_stamina);local.invulnerability=0;local.knockback=Vector3.ZERO
  var profile={"progression":g.progression.snapshot(),"magic_items":g.magic_items.snapshot(),"skill_loadout":{"dash":true},"heavy_attack":local.heavy_style}
  var bridge=Bridge.new();root.add_child(bridge);bridge.setup(floor_context,profile,"parity")
  check(bridge.actor.motion_mode==CharacterBody3D.MOTION_MODE_GROUNDED,item+" authority starts grounded before native floor step")
  bridge.actor.collision_mask=1|4
  var presentation_copy=Bridge.new();root.add_child(presentation_copy);presentation_copy.setup(floor_context,profile,"presentation")
  presentation_copy.actor.collision_layer=0;presentation_copy.actor.collision_mask=0
  var start=Vector3(0,g.current_world.ground_height(Vector3.ZERO),0)
  local.position=start;local_driver.yaw=PI;local_driver.first_pitch=.12;bridge.set_pose(start,PI,.12)
  local.visual.rotation.y=0;bridge.actor.visual.rotation.y=0;pending=false;held_clock=0
  for warmup in range(90):
   local.set_network_input(Vector2.ZERO,false);local._physics_process(1.0/60);local.get_node("BetaHero").synchronize(1.0/60);local_driver.sample_first_person(1.0/60,true)
   bridge.step(1.0/60,{"movement":[0,0],"yaw":PI,"pitch":.12,"buttons":{}})
  var probe=CounterTarget.new();floor_context.world_root.add_child(probe)
  local.attack_contact.connect(func(_kind,_direction,_hits):
   var segment=local.blade_segment();probe.position=segment[0].lerp(segment[1],.5)-Vector3.UP*.56
   native_contact_expected=true;native_contact_value=local.blade_hits(probe))
  local.weapon_runtime.contact_observer=func(weapon,segment):
   probe.position=segment[0].lerp(segment[1],.5)-Vector3.UP*.56
   native_contact_expected=true;native_contact_value=weapon.hits(probe,segment)
  var copied_next_frame=-1
  var copied_next_state:Dictionary={}
  var copied_next_steel:Array=[]
  var copied_next_view=Transform3D.IDENTITY
  var commands={0:"draw",85:"down",88:"up",96:"down",99:"up",125:"down",128:"up",220:"down",320:"up",420:"dash_down",460:"dash_attack",475:"dash_up",600:"dodge",610:"down",613:"up",710:"jump",780:"down",820:"parry",850:"down",870:"cancel"}
  for frame in range(45 if draw_only else 960):
   var movement=Vector2(0,-1) if frame>=330 and frame<420 else Vector2.ZERO
   var blocked=frame>=900 and frame<925
   var sprint=frame>=330 and frame<420
   local.input_enabled=not blocked;local.online_mode=true;local.set_network_input(movement,sprint);local.movement_camera_yaw=PI
   if blocked:local.cancel_pending_input()
   if frame==340:
    local.slow_sources["fixture"]={"factor":.5,"remaining":.4}
    bridge.actor.slow_sources["fixture"]={"factor":.5,"remaining":.4}
   if frame in [250,605,915]:
    var damaged_local=local.take_damage(7,Vector3.RIGHT)
    var damaged_remote=bridge.take_damage(7,Vector3.RIGHT)
    check(damaged_local==damaged_remote and local.health==bridge.actor.health,item+" accepted damage during action/menu @"+str(frame))
   if frame==780 and item=="standard_greatsword":local.heavy_style="overhead";bridge.actor.heavy_style="overhead"
   if commands.has(frame):
    var kind=commands[frame];var mapped={"down":"primary_down","up":"primary_up","dash_down":"dash_charge","dash_up":"dash_release"}.get(kind,kind)
    if item=="hunting_bow" and kind=="up" and local.state=="bow_draw":
     local.weapon_runtime.last_charge=clampf(local.state_time/float(local.weapon_runtime.settings.draw_max_seconds),0,1)
     bridge.actor.weapon_runtime.last_charge=clampf(bridge.actor.state_time/float(bridge.actor.weapon_runtime.settings.draw_max_seconds),0,1)
     var local_shot=local.weapon_runtime.launch_spec();var remote_shot=bridge.actor.weapon_runtime.launch_spec()
     check(local_shot.valid==remote_shot.valid and local_shot.origin.distance_to(remote_shot.origin)<.00001 and local_shot.direction.distance_to(remote_shot.direction)<.00001,"Canonical bow actual socket/aim @"+str(frame))
    var accepted=direct(local,kind);var result=bridge.action(mapped)
    check(accepted==bool(result.ok),item+" command acceptance "+kind+" @"+str(frame))
   if blocked:pending=false
   if pending:
    held_clock+=1.0/60
    if not local.input_enabled or local.state not in ["charge","light","roll","stand","weapon_attack","bow_draw","weapon_recovery"]:pending=false
    elif not local.thrust_charging and not local.weapon_runtime.enabled() and held_clock>=float(local.combat.heavy_hold_seconds):
     pending=false
     if local.state not in ["light","roll","stand"]:local.release_charge("heavy")
   native_contact_expected=false;native_contact_value=false
   local._physics_process(1.0/60);local.get_node("BetaHero").synchronize(1.0/60);local_driver.sample_first_person(1.0/60,true)
   var state=bridge.step(1.0/60,{"movement":[movement.x,movement.y],"yaw":PI,"pitch":.12,"buttons":{"sprint":sprint,"blocked":blocked}})
   var repeated_contact=true
   if native_contact_expected:
    var equipment_before=bridge.actor.equipment.transform
    var first=bridge.contact_candidates(probe);var second=bridge.contact_candidates(probe)
    repeated_contact=first==native_contact_value and second==first and equipment_before==bridge.actor.equipment.transform
   check(bridge.contact_active==native_contact_expected and repeated_contact,item+" canonical native repeated swept contact preserves local steel @"+str(frame))
   var native_frame=local_driver.sample_first_person(0,false);var lean_frame=bridge.driver.sample_first_person(0,false)
   var error=maxf(native_frame.origin.distance_to(lean_frame.origin),maxf(native_frame.basis.x.distance_to(lean_frame.basis.x),maxf(native_frame.basis.y.distance_to(lean_frame.basis.y),native_frame.basis.z.distance_to(lean_frame.basis.z))))
   max_frame[item]=maxf(float(max_frame.get(item,0)),error)
   check(error<.00001,item+" native head frame/basis @"+str(frame))
   if frame==copied_next_frame:
    var current=bridge.steel()
    var current_view=bridge.driver.sample_first_person(0,false)
    check(copied_next_view.origin.distance_to(current_view.origin)<.00001 and copied_next_view.basis.x.distance_to(current_view.basis.x)<.00001 and copied_next_view.basis.y.distance_to(current_view.basis.y)<.00001 and copied_next_view.basis.z.distance_to(current_view.basis.z)<.00001,item+" correction next native frame keeps actual head/basis @"+str(frame))
    check(copied_next_state.action==state.action and absf(float(copied_next_state.action_clock)-float(state.action_clock))<.000001 and copied_next_steel[0].distance_to(current[0])<.00001 and copied_next_steel[1].distance_to(current[1])<.00001,item+" mid-draw correction next native frame keeps global steel @"+str(frame))
   check(local.state==state.action and local.combo_stage==state.combo,item+" state/combos @"+str(frame))
   check(local.health==state.health and absf(local.state_time-state.action_clock)<.000001 and absf(local.stamina-state.stamina)<.00001,item+" clock/resource @"+str(frame))
   check(local.position.distance_to(bridge.actor.position)<.00001,item+" collision/locomotion @"+str(frame))
   if frame in [3,10,30,90,260,350,480,615,780,915]:
    var accepted_state=bridge.snapshot()
    var portable=bytes_to_var(var_to_bytes(accepted_state))
    var disk_precision=JSON.parse_string(JSON.stringify(accepted_state,"",true,true))
    check(preload("res://scripts/network/wr_actor_pose.gd").decode_transform(disk_precision.pose_state.equipment_transform)==bridge.actor.equipment.transform,item+" full-precision JSON retains stored float32 equipment pose @"+str(frame))
    presentation_copy.restore_snapshot(portable)
    check((presentation_copy.actor.equipment.get_parent()==presentation_copy.actor.visual)==(bridge.actor.equipment.get_parent()==bridge.actor.visual) and presentation_copy.actor.equipment.global_transform.is_equal_approx(bridge.actor.equipment.global_transform) and presentation_copy.actor.equipment.transform.is_equal_approx(bridge.actor.equipment.transform) and is_equal_approx(presentation_copy.actor.thrust_windup_seconds,bridge.actor.thrust_windup_seconds),item+" Binary parent/global presentation pose/heldthrust roundtrip @"+str(frame))
    var original_steel=bridge.steel();var restored_steel=presentation_copy.steel()
    check(original_steel[0].distance_to(restored_steel[0])<.00001 and original_steel[1].distance_to(restored_steel[1])<.00001,item+" Binary correction restores actual global steel @"+str(frame))
    if frame in [3,10,30]:
     copied_next_state=presentation_copy.step(1.0/60,{"movement":[0,0],"yaw":PI,"pitch":.12,"buttons":{}})
     copied_next_steel=presentation_copy.steel();copied_next_view=presentation_copy.driver.sample_first_person(0,false);copied_next_frame=frame+1
   var a=local.weapon_runtime.contact_segments() if local.weapon_runtime.enabled() else local.blade_segment();var b=bridge.steel()
   if a.size()==2 and b.size()==2:max_steel[item]=maxf(float(max_steel.get(item,0)),maxf(a[0].distance_to(b[0]),a[1].distance_to(b[1])))
   check(a.size()==b.size() and (a.is_empty() or (a[0].distance_to(b[0])<.00001 and a[1].distance_to(b[1])<.00001)),item+" live steel @"+str(frame))
  if item=="hunting_bow":
   for denial in ["ammo","stamina"]:
    local.set_sword_drawn(true);bridge.actor.set_sword_drawn(true)
    local.restore_stamina(local.max_stamina);bridge.actor.restore_stamina(bridge.actor.max_stamina)
    g.magic_items.quantities["wooden_arrows"]=1;bridge.magic_items.quantities["wooden_arrows"]=1
    check(local.begin_charge() and bridge.action("primary_down").ok,"Native/server bow begin before "+denial+" denial")
    if denial=="ammo":g.magic_items.quantities["wooden_arrows"]=0;bridge.magic_items.quantities["wooden_arrows"]=0
    else:local.stamina=0;bridge.actor.stamina=0
    var native_release=local.release_charge("light");var rejected=bridge.action("primary_up")
    check(not native_release and not rejected.ok and local.state=="free" and bridge.actor.state=="free" and local.stamina==bridge.actor.stamina and g.magic_items.quantities["wooden_arrows"]==bridge.magic_items.quantities["wooden_arrows"],"Native/server denied "+denial+" bow release cancels without spending")
   local.set_sword_drawn(true);bridge.actor.set_sword_drawn(true)
   local.restore_stamina(local.max_stamina);bridge.actor.restore_stamina(bridge.actor.max_stamina)
   g.magic_items.quantities["wooden_arrows"]=1;bridge.magic_items.quantities["wooden_arrows"]=1
   check(local.begin_charge() and bridge.action("primary_down").ok,"Native/server bow begin before scenery denial")
   var frame=bridge.driver.sample_first_person(0,false)
   var wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0;g.current_world.add_child(wall)
   var collider=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(2,2,.08);collider.shape=box;wall.add_child(collider)
   wall.global_transform=Transform3D(frame.basis,frame*Vector3(-.12,-.11,-.30))
   await physics_frame
   check(not local.weapon_runtime.launch_spec().valid and not bridge.actor.weapon_runtime.launch_spec().valid,"Actual shared scenery blocks native/server bow socket")
   var native_release=local.release_charge("light");var rejected=bridge.action("primary_up")
   check(not native_release and not rejected.ok and local.state=="free" and bridge.actor.state=="free" and local.stamina==local.max_stamina and bridge.actor.stamina==bridge.actor.max_stamina and g.magic_items.quantities["wooden_arrows"]==1 and bridge.magic_items.quantities["wooden_arrows"]==1,"Native/server blocked bow release cancels without arrow/stamina spend")
   wall.free()
  bridge.actor.motion_mode=CharacterBody3D.MOTION_MODE_FLOATING;bridge.rebind(floor_context)
  check(bridge.actor.motion_mode==CharacterBody3D.MOTION_MODE_GROUNDED,item+" floor rebind restores native grounded motion")
  var lean=bridge.snapshot(false)
  check(not lean.has("pose_state") and lean.input_state==bridge.snapshot().input_state,item+" lean snapshot retains accepted input without serializing bones")
  var counter=CounterTarget.new();floor_context.world_root.add_child(counter);counter.position=bridge.actor.position+Vector3.FORWARD*2
  floor_context.enemies.append(counter);bridge.actor.set_sword_drawn(true);bridge.actor.restore_stamina(bridge.actor.max_stamina)
  counter.position=bridge.actor.position+Vector3.BACK*.75
  check(bridge.actor.begin_parry() and bridge.actor.try_parry(counter,counter.position) and counter.repel_count==1,item+" native parry emits exactly one canonical recoil")
  var rock=preload("res://scripts/rock_projectile.gd").new();floor_context.world_root.add_child(rock);rock.configure(bridge,counter,Vector3.FORWARD);rock.set_physics_process(false)
  rock.position=bridge.actor.position+Vector3.BACK*.75
  bridge.actor.set_sword_drawn(true)
  check(bridge.actor.begin_parry() and bridge.actor.try_parry(rock,rock.position) and rock.reflected and rock.get_meta("reflected_by","")==bridge.id,item+" native projectile reflection retains canonical player attribution")
  rock.free();bridge.actor.set_sword_drawn(true);bridge.actor.counter_target=weakref(counter);bridge.actor.counter_remaining=.7
  var correction=JSON.parse_string(JSON.stringify(bridge.snapshot(),"",true,true))
  presentation_copy.restore_snapshot(correction)
  presentation_copy.actor.counter_unlocked=true;presentation_copy.actor.counter_equipped=true
  check(correction.counter_target_id=="fixture_counter_enemy" and presentation_copy.actor.counter_target.get_ref()==counter and presentation_copy.actor.counter_ready(),item+" stable counter target restores a native ready counter")
  floor_context.enemies.erase(counter);counter.free();presentation_copy.restore_snapshot(correction)
  check(presentation_copy.actor.counter_target==null and not presentation_copy.actor.counter_ready(),item+" removed counter target cannot resurrect from stable correction")
  presentation_copy.actor.state="free";presentation_copy.actor.health=presentation_copy.actor.max_health;presentation_copy.actor.invulnerability=0
  presentation_copy.actor.input_enabled=false;presentation_copy.actor.online_mode=true
  var pvp_health=presentation_copy.actor.health
  check(not presentation_copy.actor.try_parry(bridge.actor,bridge.actor.position) and presentation_copy.actor.take_damage(7,Vector3.RIGHT),item+" native remote Actor receives unguarded PvP damage while controls blocked")
  check(presentation_copy.actor.health<pvp_health and presentation_copy.snapshot(false).health==presentation_copy.actor.health,item+" native PvP health persists into canonical snapshot")
  probe.free();presentation_copy.free();bridge.free()
 if g.audio!=null:check(await g.audio.shutdown_and_drain(),"Audio mixer refs drain before bridge fixture exit")
 print("ACTOR_BRIDGE_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"max_steel":max_steel,"max_frame":max_frame}))
 g.free();floor_context.free()
 await process_frame;await process_frame
 quit(0 if failures.is_empty() else 1)
