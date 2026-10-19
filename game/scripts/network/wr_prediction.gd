extends RefCounted
## A bounded, camera-free playable Actor predicts only this client's inputs.
## Authoritative state is restored before replay; rewards, projectiles, sounds and
## damage are never connected to the shadow Actor's presentation/contact signals.
signal reconciled(details:Dictionary)
const Bridge=preload("res://scripts/network/wr_actor_bridge.gd")
const MAX_FRAMES=120
const MAX_ACTIONS=64
const MAX_AHEAD_SECONDS=.5
var game:Node
var bridge:Node
var frames:Array=[]
var actions:Array=[]
var tick=-1
var acknowledged_input=-1
var acknowledged_action=0
var newest_input=-1
var frame_number=0
var ready=false
var ahead_seconds=0.0
var replay_steps=0
var corrections=0
var outside_physics_calls=0
var largest_correction=0.0
var overflowed=false
var floor_id=""
var pending_state:Dictionary={}
var pending_tick=-1
func configure(owner_game:Node) -> void:
 game=owner_game
func clear() -> void:
 if is_instance_valid(bridge):bridge.queue_free()
 bridge=null;frames.clear();actions.clear();tick=-1;acknowledged_input=-1
 acknowledged_action=0;newest_input=-1;frame_number=0;ready=false;ahead_seconds=0
 overflowed=false;floor_id="";pending_state.clear();pending_tick=-1
func _create(profile:Dictionary) -> void:
 if is_instance_valid(bridge):bridge.queue_free()
 bridge=Bridge.new();bridge.prediction_mode=true;bridge.authoritative_simulation=false
 game.add_child(bridge)
 bridge.setup(game,profile,String(game.wr_session.character_id))
 bridge.actor.collision_layer=0
 bridge.actor.collision_mask=game.player.collision_mask
 bridge.actor.add_collision_exception_with(game.player)
 # Collision remains real. The shadow is never an authority or an enemy target.
 bridge.actor.damage_authority=false
 bridge.actor.set_meta("prediction_replay",true)
 floor_id=String(game.map_id)
func queue_snapshot(state:Dictionary,server_tick:int) -> void:
 # ENet snapshots may arrive during idle polling. CharacterBody.move_and_slide
 # must replay during the real physics callback so its implicit delta is correct.
 if server_tick<=tick or server_tick<=pending_tick:return
 pending_state=state.duplicate(true);pending_tick=server_tick
func record_input(sequence:int,command:Dictionary,delta:float) -> void:
 if not Engine.is_in_physics_frame():
  outside_physics_calls+=1;return
 if not pending_state.is_empty():
  var accepted=pending_state;var accepted_tick=pending_tick
  pending_state={};pending_tick=-1
  reconcile(accepted,accepted_tick)
 if sequence<=newest_input or not is_finite(delta) or delta<=0:return
 newest_input=sequence;frame_number+=1
 if not ready:return
 var duration=minf(delta,.05)
 var frame={"seq":sequence,"command":command.duplicate(true),"dt":duration,"frame":frame_number}
 frames.append(frame)
 if frames.size()>MAX_FRAMES:
  frames.pop_front();overflowed=true
 if not overflowed and ahead_seconds+duration<=MAX_AHEAD_SECONDS:
  bridge.step(duration,command);ahead_seconds+=duration
  _present()
func predict_action(kind:String,payload:Dictionary,sequence:int) -> void:
 if not ready or sequence<=acknowledged_action:return
 # Only Actor input edges belong here. Economy/travel/PvP stay authoritative.
 if kind not in ["cancel","cancel_primary","focus_lost","draw","jump","parry","dodge","shift_down","shift_up","dash_charge","dash_release","dash_attack","primary_down","bow_draw","charge","primary_up","release","fire","attack","weapon_equipped","bow_cancel"]:return
 if actions.any(func(edge):return int(edge.seq)==sequence):return
 actions.append({"seq":sequence,"kind":kind,"payload":payload.duplicate(true),"frame":frame_number+1})
 if actions.size()>MAX_ACTIONS:
  actions.pop_front();overflowed=true
 if not overflowed and ahead_seconds<MAX_AHEAD_SECONDS:
  bridge.action(kind,payload);_present()
func reconcile(state:Dictionary,server_tick:int) -> bool:
 var reconciliation_started=Time.get_ticks_usec()
 if server_tick<=tick:return false
 var ack=int(state.get("input_seq",-1));var action_ack=int(state.get("action_ack",0))
 if ready and (ack<acknowledged_input or action_ack<acknowledged_action):return false
 if newest_input>=0 and ack>newest_input:return false
 if not frames.is_empty() and not Engine.is_in_physics_frame():
  queue_snapshot(state,server_tick);return false
 tick=server_tick;acknowledged_input=ack;acknowledged_action=action_ack
 var recreate=not is_instance_valid(bridge) or floor_id!=String(game.map_id)
 if recreate:
  frames.clear();actions.clear();_create(state.get("profile",{}))
 elif state.has("profile"):bridge.refresh(state.profile)
 var previous:Vector3=bridge.actor.position
 var accepted_at=state.get("position",[0,0,0])
 bridge.restore_snapshot(state)
 frames=frames.filter(func(frame):return int(frame.seq)>ack)
 actions=actions.filter(func(edge):return int(edge.seq)>action_ack)
 ahead_seconds=0;replay_steps=0
 # Once a full history was lost, discard speculative input and resume from the
 # accepted baseline. Never replay an incomplete action sequence or fast-forward.
 if overflowed:frames.clear();actions.clear();overflowed=false
 var replay_started=Time.get_ticks_usec()
 var edge_index=0
 var replayed_all=true
 for frame in frames:
  if ahead_seconds+float(frame.dt)>MAX_AHEAD_SECONDS:
   replayed_all=false;break
  while edge_index<actions.size() and int(actions[edge_index].frame)<=int(frame.frame):
   var edge:Dictionary=actions[edge_index];bridge.action(edge.kind,edge.payload);edge_index+=1
  bridge.step(float(frame.dt),frame.command);ahead_seconds+=float(frame.dt);replay_steps+=1
 while replayed_all and edge_index<actions.size() and ahead_seconds<MAX_AHEAD_SECONDS:
  var edge:Dictionary=actions[edge_index];bridge.action(edge.kind,edge.payload);edge_index+=1
 ready=true;corrections+=1
 var correction=previous.distance_to(bridge.actor.position)
 if not recreate:largest_correction=maxf(largest_correction,correction)
 if not reconciled.get_connections().is_empty():
  reconciled.emit({"tick":server_tick,"input_ack":ack,"action_ack":action_ack,"pending_actions":actions.map(func(edge):return {"seq":edge.seq,"kind":edge.kind,"frame":edge.frame}),"newest_input":newest_input,"oldest_input":int(frames.front().seq) if not frames.is_empty() else -1,"input_received_seq":int(state.get("input_received_seq",-1)),"ack_gap":newest_input-ack,"history":frames.size(),"replay_steps":replay_steps,"replay_usec":Time.get_ticks_usec()-replay_started,"reconciliation_usec":Time.get_ticks_usec()-reconciliation_started,"ahead_seconds":ahead_seconds,"admission":recreate,"correction_metres":correction,"before":[previous.x,previous.y,previous.z],"accepted_position":accepted_at,"accepted_velocity":state.get("velocity",[]),"accepted_sword_drawn":bool(state.get("sword_drawn",false)),"accepted_input_age":float(state.get("input_age",-1)),"accepted_slow_sources":state.get("pose_state",{}).get("slow_sources",{}),"shadow_sword_drawn":bridge.actor.sword_drawn,"shadow_walk_speed":bridge.actor.walk_speed,"shadow_terrain_scale":bridge.actor.terrain_speed_scale(),"shadow_velocity":[bridge.actor.velocity.x,bridge.actor.velocity.y,bridge.actor.velocity.z],"after":[bridge.actor.position.x,bridge.actor.position.y,bridge.actor.position.z],"health":bridge.actor.health,"knockback":[bridge.actor.knockback.x,bridge.actor.knockback.y,bridge.actor.knockback.z],"action":bridge.actor.state,"input":frames.back().command.duplicate(true) if not frames.is_empty() else {},"physics_frame":Engine.is_in_physics_frame()})
 _present()
 return true
func _present() -> void:
 if not is_instance_valid(bridge):return
 # Root corrections are immediate and collision-safe. Interpolating a physical
 # root through scenery would introduce wall penetration and false contacts.
 game.online_view.apply_actor(game.player,bridge.snapshot(),true)
