extends "res://scripts/network/wr_pvp_process_probe.gd"
## Real dedicated-authority damage through Main's accepted snapshot integration.
## Reuses authenticated peers, ordinary input, equipment and physical contact helpers.
var hurt_observations:Array=[]
var damage_snapshots:Array=[]
var observed_event_ids:Dictionary={}
var blood_before=0

func observe(index:int,snapshot:Dictionary) -> void:
 super.observe(index,snapshot)
 if index!=0 or game==null or game.blood==null:return
 for event in snapshot.get("events",[]):
  if event.get("kind","")!="audio" or event.get("event","")!="player.hurt":continue
  var identity=String(event.get("id",""))
  if observed_event_ids.has(identity):continue
  observed_event_ids[identity]=true
  hurt_observations.append({"event":event.duplicate(true),"tick":snapshot.tick,"local":String(event.get("actor_id",""))==peers[0].character_id,"feedback_hits":game.blood.accepted_hits,"vignette":game.blood.vignette_remaining,"world_blood_absent":game.world_root.get_node_or_null("HumanHitSplashes")==null and game.blood.get_child_count()==0,"camera_mode":game.camera_mode})
  damage_snapshots.append(snapshot.duplicate(true))

func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--") and "=" in arg:
   var pair=arg.substr(2).split("=",true,1);options[pair[0]]=pair[1]
 var registry=JSON.parse_string(FileAccess.get_file_as_string(options.registry))
 initial_yaws=[float(registry.clients[0].yaw),float(registry.clients[1].yaw)];second_yaw=initial_yaws[1]
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;await process_frame
 game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide();game._refresh_simulation()
 game.blood.level="full"
 var second=Session.new();second.name="IndependentBloodPeer";root.add_child(second)
 peers=[game.wr_session,second]
 for index in range(2):
  var at=index
  peers[index].checkpoint_path=registry.clients[index].checkpoint
  peers[index].snapshot_received.connect(func(snapshot):observe(at,snapshot))
  peers[index].action_result.connect(func(result):replies[at].append(result))
  check(peers[index].join("127.0.0.1",int(options.port))==OK,"Blood peer %d starts authenticated Session join"%index)
 ready=true
 var deadline=Time.get_ticks_msec()+30000
 while (snapshots[0]<10 or snapshots[1]<10) and Time.get_ticks_msec()<deadline:await process_frame
 check(snapshots[0]>=10 and snapshots[1]>=10,"Actual Main and independent Session receive real dedicated snapshots",snapshots)
 if snapshots[0]<10 or snapshots[1]<10:await finish();return
 game.camera_driver.yaw=initial_yaws[0];game.camera_driver.first_pitch=0.0
 starting_positions=[own(0).position.duplicate(),own(1).position.duplicate()]
 check(game.blood.accepted_hits==0,"Joining native world replays no historical blood")
 await equip(0,"standard_greatsword");await equip(1,"standard_greatsword")
 await consent(0,true);await consent(1,true)
 game.camera_driver.set_mode("first_person")
 await stance(1,"standard_greatsword",2.0)
 blood_before=game.blood.accepted_hits
 var health_before=hp(0)
 await attack(1)
 check(hp(0)<health_before,"Remote participant's actual native greatsword damages Main victim",{"before":health_before,"after":hp(0),"attack":attack_history[-1]})
 var local_hits=hurt_observations.filter(func(item):return item.local)
 check(local_hits.size()==1 and game.blood.accepted_hits==blood_before+1,"Local accepted physical hit produces exactly one blood event",local_hits)
 if not local_hits.is_empty():
  check(float(local_hits[0].vignette)>0 and local_hits[0].camera_mode=="first_person","Actual online Main routes victim hurt into red first-person feedback",local_hits[0])
  check(local_hits[0].world_blood_absent,"Actual local hurt creates no world-space blood objects")
 var accepted=game.blood.accepted_hits;var stable_health=hp(0)
 game.camera_driver.set_mode("third_person");await pause(.25)
 game.camera_driver.set_mode("first_person");await pause(.25)
 check(game.blood.accepted_hits==accepted and hp(0)==stable_health,"First/third-person toggles replay neither blood nor damage")
 await stance(0,"standard_greatsword",2.0)
 blood_before=game.blood.accepted_hits
 health_before=hp(1)
 await attack(0)
 check(hp(1)<health_before,"Main's actual native greatsword damages the remote human",{"before":health_before,"after":hp(1),"attack":attack_history[-1]})
 var remote_hits=hurt_observations.filter(func(item):return not item.local)
 check(remote_hits.size()==1 and game.blood.accepted_hits==blood_before,"Remote accepted human damage produces no local feedback event",remote_hits)
 if not remote_hits.is_empty():
  check(remote_hits[0].world_blood_absent and float(remote_hits[0].vignette)==0,"Remote accepted damage changes neither local screen nor world blood objects",remote_hits[0])
 accepted=game.blood.accepted_hits
 var healths=[hp(0),hp(1)]
 for snapshot in damage_snapshots:
  game.online_view.receive(snapshot)
  game.online_view.receive(snapshot)
 await pause(.2)
 check(game.blood.accepted_hits==accepted and game.world_root.get_node_or_null("HumanHitSplashes")==null,"Replaying captured real dedicated damage snapshots cannot duplicate presentation")
 check([hp(0),hp(1)]==healths,"Repeated accepted presentation cannot alter health")
 check(hurt_observations.all(func(item):return float(item.event.get("amount",0))>0 and String(item.event.get("actor_id","")) in [peers[0].character_id,peers[1].character_id]),"Every observed hurt event is a real server-confirmed positive human health delta",hurt_observations)
 await finish()

func finish() -> void:
 ready=false
 for peer in peers:peer.leave_server()
 var deadline=Time.get_ticks_msec()+35000
 while peers.any(func(peer):return peer.connected) and Time.get_ticks_msec()<deadline:await process_frame
 for i in range(peers.size()):
  var saved=Storage.read_file(peers[i].checkpoint_path,"character")
  check(not peers[i].connected and saved.ok and Profile.valid(saved.data) and Profile.digest(saved.data)==Profile.digest(peers[i].local_profile),"Blood peer %d lossless durable graceful departure"%i)
 if game.voice!=null:check(await game.voice.shutdown_and_drain(),"Actual Main voice drains")
 if game.audio!=null:check(await game.audio.shutdown_and_drain(),"Actual Main audio drains")
 print("BLOOD_ONLINE_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"snapshots":snapshots,"hurt_observations":hurt_observations,"attack_observations":attack_history,"routing_history":routing_history}))
 game.queue_free();peers[1].queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
