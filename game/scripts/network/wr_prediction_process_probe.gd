extends SceneTree
## Actual main scene, session transport, client view, input and production predictor.
## Run behind the QA UDP proxy with disposable checkpoint and userdata paths.
var options={"port":"24571","checkpoint":"user://prediction/character.json","seconds":"12","password-file":"","fps":"60"}
var game:Node
var snapshots=0
var immediate_action=false
var started_position=Vector3.ZERO
var max_history=0
var max_actions=0
var max_replay=0
var max_lead=0.0
var correction_sum=0.0
var last_position=Vector3.ZERO
var predicted_frames=0
var joined_ok=false
var errors:Array=[]
var probe_started=0
var last_impact_at=-10000
var phase_errors:Dictionary={"admission":[],"movement":[],"action":[],"hit_push":[],"steady_idle":[]}
var trace:Array=[]
var recent_trace:Array=[]
var cap_mismatches=0
var render_samples=0
var render_started=0
var sampling_render=false
var diagnostics_active=true
var largest_observed_correction=0.0
var reconciliation_gaps:Array=[]
var action_requests:Array=[]
var last_reconciliation_at=0
var reconciliation_timing:Array=[]
var replay_timing:Array=[]
var throttle_histogram:Dictionary={}
var input_expiry_samples=0
func _initialize() -> void:call_deferred("run")
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--") and "=" in arg:
   var pieces=arg.substr(2).split("=",true,1);options[pieces[0]]=pieces[1]
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 await process_frame;await process_frame
 game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide();game._refresh_simulation()
 game.render_budget.select_fps(int(options.fps),false)
 game.prediction.reconciled.connect(observe_reconciliation)
 game.wr_session.action_requested.connect(func(kind,_payload,sequence):
  if diagnostics_active and action_requests.size()<32:action_requests.append({"kind":kind,"seq":sequence,"elapsed_ms":Time.get_ticks_msec()-probe_started if probe_started>0 else -1}))
 game.wr_session.checkpoint_path=options.checkpoint
 if not options["password-file"].is_empty():game.wr_session.password=FileAccess.get_file_as_string(options["password-file"]).strip_edges()
 game.wr_session.status_changed.connect(func(status):print("PREDICTION_PROBE_STATUS ",status))
 game.wr_session.snapshot_received.connect(func(snapshot):
  snapshots+=1
  for event in snapshot.get("events",[]):
   if event.get("kind","")=="damage" and event.get("owner","")==game.wr_session.character_id:last_impact_at=Time.get_ticks_msec()
  if snapshot.players.has(game.wr_session.character_id):
   var state:Dictionary=snapshot.players[game.wr_session.character_id]
   var at:Vector3=Vector3(state.position[0],state.position[1],state.position[2])
   max_lead=maxf(max_lead,game.player.position.distance_to(at)))
 var result=game.wr_session.join("127.0.0.1",int(options.port))
 if result!=OK:print("PREDICTION_PROBE_RESULT ",JSON.stringify({"error":"Join failed","code":result}));quit(1);return
 var deadline=Time.get_ticks_msec()+20000
 while not game.prediction.ready and Time.get_ticks_msec()<deadline:await process_frame
 if not game.prediction.ready:print("PREDICTION_PROBE_RESULT ",JSON.stringify({"error":"No accepted prediction baseline","snapshots":snapshots}));quit(1);return
 game.render_budget.select_fps(int(options.fps),false)
 assert(Engine.max_fps==int(options.fps),"Requested probe frame cap was not applied")
 joined_ok=true;started_position=game.player.position;last_position=started_position
 var started=Time.get_ticks_msec();probe_started=started;render_started=started;sampling_render=true;call_deferred("sample_render")
 var drew=false;var attacked=false;var released=false
 Input.action_press("move_right")
 while Time.get_ticks_msec()-started<int(options.seconds)*1000:
  await physics_frame
  var elapsed=Time.get_ticks_msec()-started
  if elapsed>5000 and not drew:
   drew=true;game.wr_session.request_action("draw")
   immediate_action=game.player.state in ["draw","sheathe"]
  if elapsed>7500 and not attacked:
   attacked=true;game.wr_session.request_action("primary_down")
  if elapsed>7600 and not released:
   released=true;game.wr_session.request_action("primary_up")
  if elapsed>9000:Input.action_release("move_right")
  max_history=maxi(max_history,game.prediction.frames.size());max_actions=maxi(max_actions,game.prediction.actions.size());max_replay=maxi(max_replay,game.prediction.replay_steps)
  if game.player.position.distance_to(last_position)>.0001:predicted_frames+=1
  last_position=game.player.position
 Input.action_release("move_right")
 sampling_render=false;diagnostics_active=false
 var render_elapsed=maxf(.001,(Time.get_ticks_msec()-render_started)/1000.0)
 var predictor=game.prediction
 var movement=started_position.distance_to(game.player.position)
 var report={"joined":joined_ok,"snapshots":snapshots,"immediate_action":immediate_action,"moved_metres":movement,"predicted_frames":predicted_frames,"max_history":max_history,"max_actions":max_actions,"max_replay_steps":max_replay,"max_snapshot_lead_metres":max_lead,"corrections":predictor.corrections,"largest_correction_metres":predictor.largest_correction,"largest_correction_including_admission_metres":largest_observed_correction,"overflowed":predictor.overflowed,"shadow_self_exception":game.player in predictor.bridge.actor.get_collision_exceptions(),"shadow_effects":predictor.bridge.effects.size(),"outside_physics_calls":predictor.outside_physics_calls,"render_fps_cap":Engine.max_fps,"requested_fps":int(options.fps),"network_diagnostics":game.wr_session.network_diagnostics(),"cap_mismatches":cap_mismatches,"observed_render_fps":render_samples/render_elapsed,"phase_corrections":summarize_phases(),"action_requests":action_requests,"enet_throttle_histogram":throttle_histogram,"input_expiry_samples":input_expiry_samples,"correction_spike_trace":trace,"recent_reconciliation_trace":recent_trace,"reconciliation_gap_ms":summarize(reconciliation_gaps),"reconciliation_usec":summarize(reconciliation_timing),"replay_usec":summarize(replay_timing)}
 var ok=joined_ok and snapshots>=20 and immediate_action and movement>.5 and predicted_frames>30 and max_replay>0 and max_history<=120 and max_actions<=64 and not predictor.overflowed and game.player in predictor.bridge.actor.get_collision_exceptions() and predictor.bridge.effects.is_empty() and predictor.outside_physics_calls==0 and Engine.max_fps==int(options.fps) and cap_mismatches==0
 game.wr_session.leave_server()
 var leave_deadline=Time.get_ticks_msec()+30000
 while game.wr_session.connected and Time.get_ticks_msec()<leave_deadline:await process_frame
 report.departed=not game.wr_session.connected
 var stored=preload("res://scripts/network/wr_storage_codec.gd").read_file(options.checkpoint,"character")
 var profile_api=preload("res://scripts/network/wr_profile.gd")
 report.checkpoint_valid=stored.ok and profile_api.valid(stored.data) and profile_api.digest(stored.data)==profile_api.digest(game.wr_session.local_profile)
 ok=ok and report.departed and report.checkpoint_valid
 report.audio_drained=true
 if game.audio!=null:report.audio_drained=await game.audio.shutdown_and_drain()
 ok=ok and report.audio_drained
 print("PREDICTION_PROBE_RESULT ",JSON.stringify(report))
 game.queue_free();await process_frame;quit(0 if ok else 1)

func sample_render() -> void:
 while sampling_render:
  await process_frame
  if not sampling_render:break
  render_samples+=1
  if Engine.max_fps!=int(options.fps):cap_mismatches+=1
func observe_reconciliation(details:Dictionary) -> void:
 if not diagnostics_active:return
 largest_observed_correction=maxf(largest_observed_correction,float(details.correction_metres))
 if reconciliation_timing.size()<1024:
  reconciliation_timing.append(int(details.get("reconciliation_usec",0)));replay_timing.append(int(details.get("replay_usec",0)))
 var now=Time.get_ticks_msec()
 if last_reconciliation_at>0:
  reconciliation_gaps.append(now-last_reconciliation_at)
  if reconciliation_gaps.size()>1024:reconciliation_gaps.pop_front()
 last_reconciliation_at=now
 var elapsed=now-probe_started if probe_started>0 else 0
 var phase="admission"
 if not details.admission and probe_started>0 and elapsed>=1000:
  var push:Array=details.get("knockback",[0,0,0])
  if now-last_impact_at<700 or Vector3(push[0],push[1],push[2]).length()>.05:phase="hit_push"
  elif details.action not in ["free","stand"] or (elapsed>=5000 and elapsed<10000):phase="action"
  elif elapsed<5000:phase="movement"
  else:phase="steady_idle"
 if not phase_errors.has(phase):phase_errors[phase]=[]
 if phase_errors[phase].size()<1024:phase_errors[phase].append(float(details.correction_metres))
 var record=details.duplicate(true);record.elapsed_ms=elapsed;record.phase=phase
 if float(details.get("accepted_input_age",0))>=.3:input_expiry_samples+=1
 var native_peer=game.wr_session.peer.get_peer(1)
 if native_peer!=null and native_peer.is_active():
  var throttle=int(native_peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE))
  throttle_histogram[str(throttle)]=int(throttle_histogram.get(str(throttle),0))+1
  record.enet={"throttle":throttle,"throttle_limit":native_peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_LIMIT),"rtt":native_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME),"rtt_variance":native_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME_VARIANCE),"last_rtt":native_peer.get_statistic(ENetPacketPeer.PEER_LAST_ROUND_TRIP_TIME),"last_rtt_variance":native_peer.get_statistic(ENetPacketPeer.PEER_LAST_ROUND_TRIP_TIME_VARIANCE),"packet_loss":native_peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS)}
 record.peers=[]
 for id in game.online_view.remote_targets:
  var target:Dictionary=game.online_view.remote_targets[id]
  var remote=game.online_view.remotes.get(id)
  record.peers.append({"id":id,"accepted_position":target.get("position",[]),"accepted_velocity":target.get("velocity",[]),"interpolated_position":[remote.position.x,remote.position.y,remote.position.z] if is_instance_valid(remote) else [],"sword_drawn":target.get("sword_drawn",false)})
 recent_trace.append(record)
 if recent_trace.size()>24:recent_trace.pop_front()
 if float(details.correction_metres)>.25:
  if trace.size()<64:trace.append(record)
func summarize(values:Array) -> Dictionary:
 if values.is_empty():return {"count":0}
 var ordered=values.duplicate();ordered.sort();var total=0.0
 for value in ordered:total+=float(value)
 return {"count":ordered.size(),"mean":total/ordered.size(),"p50":ordered[int((ordered.size()-1)*.5)],"p95":ordered[int((ordered.size()-1)*.95)],"p99":ordered[int((ordered.size()-1)*.99)],"max":ordered.back()}
func summarize_phases() -> Dictionary:
 var result:Dictionary={}
 for phase in phase_errors:result[phase]=summarize(phase_errors[phase])
 return result
