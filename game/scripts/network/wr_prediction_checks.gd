extends SceneTree
## Real production prediction adapter and playable Actor under deterministic WAN
## delay, jitter, loss and snapshot reordering. Disposable user data only.
const Bridge=preload("res://scripts/network/wr_actor_bridge.gd")
const Prediction=preload("res://scripts/network/wr_prediction.gd")
var failures:Array=[]
var checks=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
 checks+=1;print("PREDICTION_CHECK ",label," ",ok)
 if not ok:failures.append(label)
func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 await process_frame;await process_frame
 game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide();game._refresh_simulation()
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 for enemy in game.enemies:enemy.set_physics_process(false);enemy.ai_enabled=false
 game.wr_session.character_id="prediction-fixture"
 var profile={"progression":game.progression.snapshot(),"magic_items":game.magic_items.snapshot(),"skill_loadout":{},"heavy_attack":"overhead"}
 var server=Bridge.new();server.prediction_mode=true;server.authoritative_simulation=false;root.add_child(server);server.setup(game,profile,"prediction-fixture")
 server.actor.collision_layer=0;server.actor.add_collision_exception_with(game.player)
 server.set_pose(game.player.position,0,0)
 var predictor=Prediction.new();predictor.configure(game)
 var baseline=server.snapshot();baseline.merge({"profile":profile,"input_seq":-1,"action_ack":0})
 check(predictor.reconcile(baseline,0),"Initial accepted state initializes shadow")
 var commands:Array=[];var snapshots:Array=[];var latest:Dictionary={"movement":[0,0],"yaw":0.0,"pitch":0.0,"buttons":{}}
 var ack=-1;var action_ack=0;var errors:Array=[];var presented_immediately=false;var restored=false
 var old_snapshot=baseline.duplicate(true)
 for frame in range(240):
  await physics_frame
  var move=.5 if frame<140 else 0.0
  var command={"seq":frame+1,"movement":[move,0],"yaw":0.0,"pitch":0.0,"buttons":{"blocked":frame>=110 and frame<125}}
  if frame%50!=17:commands.append({"at":frame+4+(frame%2)+(frame%3)-1,"command":command})
  if frame==20:
   predictor.predict_action("draw",{},1)
   presented_immediately=predictor.bridge.actor.state=="draw" and game.player.state=="draw"
  if frame==25:server.action("draw");action_ack=1
  for queued in commands.duplicate():
   if int(queued.at)<=frame:
    if int(queued.command.seq)>ack:latest=queued.command;ack=int(latest.seq)
    commands.erase(queued)
  server.step(1.0/60,latest)
  predictor.record_input(frame+1,command,1.0/60)
  if frame%3==0:
   var state=server.snapshot();state.merge({"profile":profile,"input_seq":ack,"action_ack":action_ack})
   if int(frame/3)%50!=17:snapshots.append({"at":frame+4+(int(frame/3)%2)+(int(frame/3)%3)-1,"tick":frame+1,"state":state})
  for queued in snapshots.duplicate():
   if int(queued.at)<=frame:
    predictor.reconcile(queued.state,int(queued.tick));snapshots.erase(queued)
  errors.append(predictor.bridge.actor.position.distance_to(server.actor.position))
  if frame%60==0:check(predictor.frames.size()<=Prediction.MAX_FRAMES and predictor.actions.size()<=Prediction.MAX_ACTIONS,"Bounded retained commands @"+str(frame))
  if frame==100:
   var prior=predictor.bridge.actor.position
   restored=not predictor.reconcile(old_snapshot,0) and prior==predictor.bridge.actor.position
 check(presented_immediately,"Draw edge is visible before network acknowledgement")
 check(restored,"Reordered old snapshot cannot rewind local prediction")
 var stream_largest_correction=predictor.largest_correction
 var accepted=server.snapshot();accepted.merge({"profile":profile,"input_seq":240,"action_ack":1})
 predictor.reconcile(accepted,1000)
 check(predictor.frames.is_empty() and predictor.actions.is_empty(),"Acknowledgement prunes command and action history")
 check(predictor.bridge.actor.position.distance_to(server.actor.position)<.00001,"Final accepted correction is exact")
 var native=predictor.bridge.actor.skeleton.get_bone_pose_rotation(0)
 predictor.reconcile(accepted,1001)
 check(native.is_equal_approx(predictor.bridge.actor.skeleton.get_bone_pose_rotation(0)),"Repeated baseline restores native quaternion without decomposition drift")
 var before=predictor.bridge.actor.position
 var impossible=accepted.duplicate(true);impossible.input_seq=999999;impossible.position=[100,100,100]
 check(not predictor.reconcile(impossible,1002) and predictor.bridge.actor.position==before,"Future input acknowledgement cannot teleport prediction")
 check(not predictor.reconcile(accepted,1001),"Duplicate snapshot is ignored")
 for index in range(150):predictor.record_input(241+index,{"movement":[1,0],"yaw":0.0,"pitch":0.0,"buttons":{}},1.0/60)
 check(predictor.frames.size()==Prediction.MAX_FRAMES and predictor.ahead_seconds<=Prediction.MAX_AHEAD_SECONDS,"Loss burst bounds both history and prediction horizon")
 var reset=accepted.duplicate(true);reset.input_seq=390
 predictor.reconcile(reset,1003)
 check(not predictor.overflowed and predictor.frames.is_empty() and predictor.bridge.actor.position.distance_to(server.actor.position)<.00001,"History overflow safely resumes accepted baseline")
 check(game.player in predictor.bridge.actor.get_collision_exceptions(),"Shadow excludes its own visible local body")
 var bow_profile=profile.duplicate(true)
 bow_profile.magic_items.owned.append_array(["hunting_bow","wooden_arrows"])
 bow_profile.magic_items.weapon_id="hunting_bow";bow_profile.magic_items.quantities.wooden_arrows=3
 server.refresh(bow_profile);server.actor.set_sword_drawn(true)
 var bow=server.snapshot();bow.merge({"profile":bow_profile,"input_seq":390,"action_ack":1})
 predictor.reconcile(bow,1004)
 predictor.predict_action("primary_down",{},2);server.action("primary_down")
 for frame in range(30):
  var cmd={"movement":[0,0],"yaw":0.0,"pitch":0.0,"buttons":{}}
  predictor.record_input(391+frame,cmd,1.0/60);server.step(1.0/60,cmd)
  if frame==14:
   var before_model=predictor.bridge.actor.weapon_runtime.model
   var drawing=server.snapshot();drawing.merge({"profile":bow_profile,"input_seq":405,"action_ack":2})
   predictor.reconcile(drawing,1005)
   check(predictor.bridge.actor.state=="bow_draw" and predictor.bridge.actor.weapon_runtime.model==before_model and int(predictor.bridge.magic_items.quantities.wooden_arrows)==3,"Acknowledged profile during bow draw preserves nock and ammunition")
 predictor.predict_action("primary_up",{},3);server.action("primary_up")
 check(int(predictor.bridge.magic_items.quantities.get("wooden_arrows",0))==2,"Predicted bow release spends shadow ammunition once")
 var accepted_bow=server.snapshot();accepted_bow.merge({"profile":bow_profile,"input_seq":420,"action_ack":3})
 predictor.reconcile(accepted_bow,1006);predictor.reconcile(accepted_bow,1007)
 check(int(predictor.bridge.magic_items.quantities.get("wooden_arrows",0))==2,"Stale profile plus acknowledged bow state cannot spend ammunition twice")
 check(predictor.bridge.effects.is_empty(),"Prediction never creates combat world emitters")
 var collision_start=Vector3(0,game.current_world.ground_height(Vector3.ZERO),0)
 var proxy=CharacterBody3D.new();proxy.collision_layer=2;proxy.collision_mask=0
 var capsule=CollisionShape3D.new();var capsule_shape=CapsuleShape3D.new();capsule_shape.radius=.23;capsule_shape.height=1.12;capsule.shape=capsule_shape;capsule.position.y=.56;proxy.add_child(capsule)
 game.world_root.add_child(proxy);proxy.position=collision_start+Vector3(1,0,0)
 await physics_frame
 server.actor.state="free";server.actor.velocity=Vector3.ZERO;server.set_pose(collision_start,0,0)
 var collision_base=server.snapshot();collision_base.merge({"profile":bow_profile,"input_seq":420,"action_ack":3})
 predictor.reconcile(collision_base,1008)
 for index in range(30):
  var cmd={"movement":[1,0],"yaw":0.0,"pitch":0.0,"buttons":{}}
  predictor.record_input(421+index,cmd,1.0/60)
  await physics_frame
 check(predictor.bridge.actor.position.x<.55 and predictor.bridge.actor.position.x>.1,"Predicted locomotion collides with solid remote capsule")
 check(proxy.position==collision_start+Vector3(1,0,0),"Prediction never pushes the remote presentation body")
 proxy.queue_free()
 var wall=StaticBody3D.new();wall.collision_layer=1
 var wall_shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(.2,3,4);wall_shape.shape=box;wall_shape.position.y=1;wall.add_child(wall_shape)
 game.world_root.add_child(wall);wall.position=collision_start+Vector3(.6,0,0)
 await physics_frame
 collision_base.input_seq=450
 predictor.reconcile(collision_base,1009)
 for index in range(30):
  predictor.record_input(451+index,{"movement":[1,0],"yaw":0.0,"pitch":0.0,"buttons":{}},1.0/60)
  await physics_frame
 check(predictor.bridge.actor.position.x<.28 and predictor.bridge.actor.position.x>=0,"Prediction root never crosses actual terrain wall collision")
 wall.queue_free()
 var peak=0.0
 for error in errors:peak=maxf(peak,float(error))
 check(peak<.8,"Delayed movement correction remains bounded below 0.8 metres")
 print("PREDICTION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"frames":240,"rtt_ms":150,"jitter_ms":20,"loss_percent":2,"peak_prediction_lead_metres":peak,"corrections":predictor.corrections,"largest_stream_correction_metres":stream_largest_correction}))
 if game.audio!=null:
  var drained=await game.audio.shutdown_and_drain()
  if not drained:failures.append("Audio playback did not drain")
 predictor.clear();server.queue_free();game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
