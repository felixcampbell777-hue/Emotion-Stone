extends SceneTree
## Two real authenticated Session peers, with one actual main scene, against a separate server.
## Uses normal input/actions/checkpoints exclusively; never mutates authority or actor health.
const Session=preload("res://scripts/network/wr_session.gd")
const Profile=preload("res://scripts/network/wr_profile.gd")
const Storage=preload("res://scripts/network/wr_storage_codec.gd")
var game:Node
var peers:Array=[]
var latest:Array=[{},{}]
var replies:Array=[[],[]]
var checks:Array=[]
var failures:Array=[]
var options={"port":"24931","registry":"","health":"","mode":"full"}
var snapshots=[0,0]
var input_clock=0.0
var second_yaw=PI
var initial_yaws=[0.0,PI]
var wall_hint:Dictionary={}
var occlusion_hint:Dictionary={}
var second_pitch=0.0
var second_move=Vector2.ZERO
var starting_positions:Array=[]
var ready=false
var observed_contact_clock:Dictionary={}
var capture_weapon=""
var capture_victim_health=0.0
var network_live:Array=[{},{}]
var routing_history:Array=[]
var attack_observation:Dictionary={}
var attack_history:Array=[]
func _initialize() -> void:call_deferred("run")
func _process(delta:float) -> bool:
 if not ready:return false
 input_clock+=delta
 if input_clock>=.05:
  input_clock=0
  peers[1].send_input({"movement":[second_move.x,second_move.y],"yaw":second_yaw,"pitch":second_pitch,"buttons":{}})
 return false
func check(ok:bool,label:String,detail:Variant=null) -> void:
 checks.append({"label":label,"passed":ok,"detail":detail})
 print("PVP_CHECK ","PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func own(index:int) -> Dictionary:return latest[index].get("players",{}).get(peers[index].character_id,{})
func hp(index:int) -> float:return float(own(index).get("health",-1))
func read_server_health() -> Dictionary:
 if options.health.is_empty() or not FileAccess.file_exists(options.health):return {}
 var parser=JSON.new()
 if parser.parse(FileAccess.get_file_as_string(options.health))!=OK:return {}
 return parser.data if parser.data is Dictionary else {}
func character_arrow_contacts() -> Array:return read_server_health().get("performance",{}).get("pvp",{}).get("character_arrow_interceptions",[])
func pause(seconds:float) -> void:await create_timer(seconds).timeout
func command(index:int,kind:String,payload:Dictionary={}) -> Dictionary:
 var before=replies[index].size();peers[index].request_action(kind,payload)
 var deadline=Time.get_ticks_msec()+3000
 while Time.get_ticks_msec()<deadline:
  for result in replies[index].slice(before):
   if result.get("kind","")==kind:return result
  await process_frame
 return {"ok":false,"error":"No matching action reply","kind":kind}
func consent(index:int,enabled:bool) -> void:
 var result=await command(index,"pvp",{"enabled":enabled})
 check(result.get("ok",false),"Peer %d PvP consent transition to %s is accepted"%[index,str(enabled)],result)
 var deadline=Time.get_ticks_msec()+2000
 while bool(own(index).get("pvp",not enabled))!=enabled and Time.get_ticks_msec()<deadline:await process_frame
 check(bool(own(index).get("pvp",not enabled))==enabled,"Accepted PvP consent appears in authoritative peer state")
func equip(index:int,item:String) -> void:
 check((await command(index,"equip",{"item":item})).get("ok",false),"Peer %d equips %s"%[index,item])
 await pause(.15)
 if not own(index).get("sword_drawn",false):await command(index,"draw")
 await pause(1.8)
func observe(index:int,snapshot:Dictionary) -> void:
 latest[index]=snapshot;snapshots[index]+=1;network_live[index]=peers[index].network_diagnostics()
 if index==0 and not attack_observation.is_empty():
  for i in range(2):
   var state=snapshot.get("players",{}).get(peers[i].character_id,{})
   attack_observation.minimum_health[i]=minf(float(attack_observation.minimum_health[i]),float(state.get("health",INF)))
   attack_observation.parried[i]=bool(attack_observation.parried[i]) or (i==int(attack_observation.guard) and state.get("action","")=="parry" and bool(state.get("pose_state",{}).get("parry_resolved",false)))
  if attack_observation.projectiles.size()<16:
   for shot in snapshot.get("projectiles",{}).values():
    attack_observation.projectiles.append({"position":shot.get("position"),"velocity":shot.get("velocity")})
 if index==0 and not capture_weapon.is_empty() and peers.size()==2:
  var attacker=snapshot.get("players",{}).get(peers[0].character_id,{})
  var victim=snapshot.get("players",{}).get(peers[1].character_id,{})
  if not attacker.is_empty() and not victim.is_empty() and float(victim.health)<capture_victim_health:
   observed_contact_clock[capture_weapon]=float(attacker.get("action_clock",0));capture_weapon=""
func attack(index:int,bow:bool=false,guard:int=-1,aim:float=NAN) -> void:
 attack_observation={"attacker":index,"guard":guard,"weapon":own(index).get("weapon"),"minimum_health":[hp(0),hp(1)],"parried":[false,false],"projectiles":[],"initial_positions":[own(0).position,own(1).position],"initial_yaws":[own(0).get("yaw"),own(1).get("yaw")],"initial_states":[own(0).get("action"),own(1).get("action")]}
 if index==0 and guard<0:
  capture_weapon=String(own(0).get("weapon",""));capture_victim_health=hp(1)
 var weapon_kind=String(own(index).get("weapon","standard_greatsword"))
 var pitch=aim if is_finite(aim) else .3 if bow else 0.0
 if index==0:game.camera_driver.first_pitch=pitch
 else:second_pitch=pitch
 await pause(.1)
 attack_observation["down_reply"]=await command(index,"primary_down")
 await pause(.38 if bow else .04)
 if bow and guard>=0:check((await command(guard,"parry")).get("ok",false),"Native bow parry request is accepted")
 attack_observation["up_reply"]=await command(index,"primary_up")
 if not bow and guard>=0:
  var active_time=.682
  var weapon=String(own(index).get("weapon","standard_greatsword"))
  if weapon=="field_spear":active_time=.88*.32
  elif weapon=="duelist_rapier":active_time=.46*.28
  active_time=float(observed_contact_clock.get(weapon,active_time))
  var deadline=Time.get_ticks_msec()+2500
  while float(own(index).get("action_clock",0))<maxf(0,active_time-.10) and Time.get_ticks_msec()<deadline:await process_frame
  check((await command(guard,"parry")).get("ok",false),"Native melee parry request is accepted for "+weapon)
 await pause(2.0)
 if bow:
  var completed_tick=int(latest[0].get("tick",-1));var diagnostic_deadline=Time.get_ticks_msec()+3000
  while int(read_server_health().get("tick",-1))<completed_tick and Time.get_ticks_msec()<diagnostic_deadline:await pause(.05)
 attack_history.append(attack_observation.duplicate(true));attack_observation={}
func reset_positions(strength:float=.4,budget:float=5.0) -> void:
 game.camera_driver.yaw=initial_yaws[0];game.camera_driver.first_pitch=0.0;second_yaw=initial_yaws[1];second_pitch=0
 var deadline=Time.get_ticks_msec()+int(budget*1000)
 var trace_clock=0
 while Time.get_ticks_msec()<deadline:
  var done=true
  for i in range(2):
   var point=own(i).get("position",starting_positions[i]);var target=starting_positions[i]
   var delta=Vector3(target[0]-point[0],0,target[2]-point[2])
   if delta.length()>.08:done=false
   var axis=Vector2.ZERO if delta.length()<=.08 else Vector2(delta.x,delta.z).normalized()*strength
   if i==1:
    var local=Vector3(axis.x,0,axis.y).rotated(Vector3.UP,-second_yaw);second_move=Vector2(local.x,local.z)
   else:
    var local=Vector3(axis.x,0,axis.y).rotated(Vector3.UP,-initial_yaws[0]);axis=Vector2(local.x,local.z)
    for action in ["move_left","move_right","move_up","move_down"]:Input.action_release(action)
    if axis.x<-.01:Input.action_press("move_left",-axis.x)
    if axis.x>.01:Input.action_press("move_right",axis.x)
    if axis.y<-.01:Input.action_press("move_up",-axis.y)
    if axis.y>.01:Input.action_press("move_down",axis.y)
  if Time.get_ticks_msec()>=trace_clock:
   trace_clock=Time.get_ticks_msec()+250
   routing_history.append({"positions":[own(0).get("position"),own(1).get("position")],"targets":starting_positions.duplicate(true),"yaw":[game.camera_driver.yaw,second_yaw],"second_move":[second_move.x,second_move.y],"main_move":[Input.get_vector("move_left","move_right","move_up","move_down").x,Input.get_vector("move_left","move_right","move_up","move_down").y]})
   if routing_history.size()>32:routing_history.pop_front()
  if done:break
  await pause(.05)
 second_move=Vector2.ZERO
 for action in ["move_left","move_right","move_up","move_down"]:Input.action_release(action)
 await pause(.2)
func walk_route(index:int,points:Array) -> void:
 for point in points:
  var health_before=[hp(0),hp(1)]
  starting_positions[index]=point.duplicate()
  await reset_positions(1.0,12.0)
  var actual=own(index).position
  var distance=Vector3(actual[0]-point[0],actual[1]-point[1],actual[2]-point[2]).length()
  check(distance<.15,"Normal input reaches authored occlusion route waypoint",{"peer":index,"distance":distance,"actual":actual,"target":point})
  var engagements=[]
  for enemy in latest[0].get("enemies",{}).values():
   var native=enemy.get("native_state",{})
   var active=bool(native.get("encounter_engaged",false)) or bool(native.get("pack_engaged",false)) or bool(native.get("engaged",false)) or enemy.get("state","") in ["windup","lunge","strike","rush","howl","leap","giant_jump","giant_warn"]
   if active and String(enemy.get("target","")) in [peers[0].character_id,peers[1].character_id]:engagements.append({"target":enemy.target,"state":enemy.get("state"),"kind":enemy.get("kind"),"position":enemy.get("position"),"native_state":native})
  check(engagements.is_empty(),"Authored occlusion route does not engage a PvE enemy",engagements)
  check([hp(0),hp(1)]==health_before,"Ordinary fixture routing causes no unrelated player health loss",{"before":health_before,"after":[hp(0),hp(1)]})
  if distance>=.15:return
func restore_after_respawn() -> void:
 # The last greatsword lunge may cross the victim's checkpoint. Walk around the
 # real solid body, then restore each stance; never force actors through peers.
 var homes=starting_positions.duplicate(true)
 var at=own(0).position;var yaw=float(initial_yaws[0]);var right=Vector3(cos(yaw),0,-sin(yaw))
 var bypass=Vector3(at[0],at[1],at[2])+right*.9
 starting_positions[1]=own(1).position.duplicate()
 await walk_route(0,[[bypass.x,bypass.y,bypass.z]])
 await walk_route(1,[homes[1]])
 await walk_route(0,[homes[0]])
func stance(index:int,weapon:String,distance_override:float=-1.0) -> bool:
 # Positive-contact placements independently measured with real native trajectories.
 # Spear shaft is not damaging; aim at the actual blade and physical hurt capsule.
 var distance=distance_override if distance_override>0 else 3.5 if weapon=="field_spear" else 1.75 if weapon=="duelist_rapier" else 2.0
 var lateral=0.0
 var yaw=float(initial_yaws[index]);var forward=-Vector3(sin(yaw),0,cos(yaw));var right=Vector3(cos(yaw),0,-sin(yaw))
 var other=starting_positions[1-index];var point=Vector3(other[0],other[1],other[2])-forward*distance-right*lateral
 starting_positions[index]=[point.x,point.y,point.z]
 await reset_positions(.7,8.0)
 var settled=true
 for peer_index in range(2):
  var actual=own(peer_index).position;var expected=starting_positions[peer_index]
  var error=Vector3(actual[0]-expected[0],actual[1]-expected[1],actual[2]-expected[2]).length()
  check(error<.15,"Authoritative peer %d settles at positive-contact stance for %s"%[peer_index,weapon],{"actual":actual,"target":expected,"error":error})
  settled=settled and error<.15
 return settled
func heal(index:int) -> void:
 for n in range(4):
  if hp(index)>=float(own(index).get("max_health",100)):break
  await command(index,"drink",{"item":"guild_healing_potion"});await pause(.15)
 await pause(1.1)
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--") and "=" in arg:
   var pair=arg.substr(2).split("=",true,1);options[pair[0]]=pair[1]
 var registry=JSON.parse_string(FileAccess.get_file_as_string(options.registry))
 initial_yaws=[float(registry.clients[0].yaw),float(registry.clients[1].yaw)];second_yaw=initial_yaws[1]
 wall_hint=registry.get("near_wall_hint",{});occlusion_hint=registry.get("occlusion_hint",{})
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;await process_frame
 game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide();game._refresh_simulation()
 var second=Session.new();second.name="IndependentPvPPeer";root.add_child(second)
 peers=[game.wr_session,second]
 for index in range(2):
  var at=index
  peers[index].checkpoint_path=registry.clients[index].checkpoint
  peers[index].snapshot_received.connect(func(snapshot):observe(at,snapshot))
  peers[index].action_result.connect(func(result):replies[at].append(result))
  check(peers[index].join("127.0.0.1",int(options.port))==OK,"Peer %d starts real join"%index)
 ready=true
 var deadline=Time.get_ticks_msec()+30000
 while (snapshots[0]<10 or snapshots[1]<10) and Time.get_ticks_msec()<deadline:await process_frame
 check(snapshots[0]>=10 and snapshots[1]>=10,"Both independent peers receive native-world snapshots",snapshots)
 if snapshots[0]<10 or snapshots[1]<10:await finish();return
 game.camera_driver.yaw=initial_yaws[0];game.camera_driver.first_pitch=0.0
 starting_positions=[own(0).position.duplicate(),own(1).position.duplicate()]
 if options.mode=="repair":
  await run_repairs();await finish();return
 await equip(0,"standard_greatsword");await equip(1,"standard_greatsword");await stance(0,"standard_greatsword")
 var original_progression=[peers[0].local_profile.progression.duplicate(true),peers[1].local_profile.progression.duplicate(true)]
 var original_xp=[peers[0].local_profile.progression.xp,peers[1].local_profile.progression.xp]
 var original_copper=[peers[0].local_profile.copper,peers[1].local_profile.copper]
 check(not own(0).get("pvp",true) and not own(1).get("pvp",true),"Both peers start with explicit authoritative PvP consent disabled")
 var before=hp(1)
 await attack(0)
 check(hp(1)==before,"Neither opted in: real steel causes no PvP damage",[before,hp(1)])
 await reset_positions()
 await consent(0,true);await attack(0)
 check(hp(1)==before,"Only attacker opted in: real steel causes no damage",[before,hp(1)])
 await reset_positions()
 await pause(10.1) # Real combat cooldown also applies to an opted-in attacker whose target opted out.
 await consent(0,false);await consent(1,true)
 await attack(0)
 check(hp(1)==before,"Only defender opted in: real steel causes no damage",[before,hp(1)])
 await reset_positions();await consent(0,true)
 for weapon in ["standard_greatsword","field_spear","duelist_rapier","hunting_bow"]:
  await equip(0,weapon);await heal(1);await stance(0,weapon)
  before=hp(1);await attack(0,weapon=="hunting_bow")
  check(hp(1)>0 and hp(1)<before,"Both opted in: actual %s damages remote player"%weapon,[before,hp(1),own(0).get("position"),own(1).get("position")])
  if options.get("control-only","false")=="true":await finish();return
  var denial=await command(0,"pvp",{"enabled":false})
  check(not denial.get("ok",true),"%s combat denies immediate PvP opt-out"%weapon,denial)
  await heal(1);await stance(0,weapon)
  before=hp(1);await attack(0,weapon=="hunting_bow",1)
  check(hp(1)==before and attack_history[-1].parried[1],"Actual outside-body parry blocks %s"%weapon,{"health_before":before,"health_after":hp(1),"actual_parry_resolved":attack_history[-1].parried[1]})
 # Explicit upper-body positives use the real shared native-pose hurt regions.
 await equip(0,"hunting_bow");await stance(0,"hunting_bow")
 for test in [{"region":"head","pitch":-.10},{"region":"torso","pitch":0.0}]:
  await heal(1);await reset_positions()
  var prior=[]
  for event in character_arrow_contacts():prior.append(event.arrow_id)
  game.camera_driver.yaw=float(initial_yaws[0])-.09
  before=hp(1);await attack(0,true,-1,float(test.pitch))
  var hit={}
  for event in character_arrow_contacts():
   if event.arrow_id not in prior and event.character_id==peers[1].character_id:hit=event
  check(hp(1)<before and hit.get("part","")==test.region and hit.get("outcome","")=="damage","Actual Session arrow damages native "+String(test.region),{"health_before":before,"health_after":hp(1),"contact":hit})
 await heal(1);await reset_positions()
 var previous_interceptions=[]
 for event in character_arrow_contacts():previous_interceptions.append(event.arrow_id)
 game.camera_driver.yaw=float(initial_yaws[0])-.09
 before=hp(1);await attack(0,true,-1,-.23)
 var false_hit=false
 for event in character_arrow_contacts():
  if event.arrow_id not in previous_interceptions and event.character_id==peers[1].character_id:false_hit=true
 var miss_flight=attack_history[-1]
 check(hp(1)==before and not false_hit and miss_flight.up_reply.get("ok",false) and not miss_flight.projectiles.is_empty(),"Arrow above the native head silhouette is a genuine near miss",{"health_before":before,"health_after":hp(1),"intercepted":false_hit,"flight":attack_history[-1].projectiles})
 # A real overlay disables local controls while the remote canonical body remains vulnerable.
 await equip(1,"field_spear");await heal(0);await stance(1,"field_spear");await pause(1)
 game.toggle_inventory();await pause(.15)
 before=hp(0);var local_menu_health=game.player.health;await attack(1)
 check(game.inventory.visible and not game.player.input_enabled and hp(0)<before and game.player.health<local_menu_health,"Inventory overlay stays vulnerable to remote canonical steel",[before,hp(0)])
 game.inventory.close();game._refresh_simulation()
 check([peers[0].local_profile.progression.xp,peers[1].local_profile.progression.xp]==original_xp and [peers[0].local_profile.copper,peers[1].local_profile.copper]==original_copper,"PvP gives no XP or copper rewards")
 # A genuine PvP defeat must not create PvE progression or reward claims.
 await equip(0,"standard_greatsword");await heal(0);await stance(0,"standard_greatsword")
 var claims_before=latest[0].get("claims",{}).keys()
 for attempt in range(12):
  if hp(1)<=0:break
  await attack(0)
  if hp(1)>0:await reset_positions()
 check(hp(1)<=0,"Real PvP combat can defeat a remote player")
 check([peers[0].local_profile.progression.xp,peers[1].local_profile.progression.xp]==original_xp and [peers[0].local_profile.copper,peers[1].local_profile.copper]==original_copper and latest[0].get("claims",{}).keys().all(func(id):return id in claims_before),"PvP defeat creates no XP, copper or loot claims")
 check(Profile.digest(peers[0].local_profile.progression)==Profile.digest(original_progression[0]) and Profile.digest(peers[1].local_profile.progression)==Profile.digest(original_progression[1]),"PvP cannot farm any progression fields, including Greatsword kill counters")
 if hp(1)<=0:
  check((await command(1,"respawn")).get("ok",false),"Defeated peer uses the normal authoritative respawn request")
  await pause(1);await restore_after_respawn()
 else:await reset_positions()
 # An opted-out friend's physical interception must cause no damage and leave one recoverable miss.
 await pause(10.5)
 check((await command(1,"pvp",{"enabled":false})).get("ok",false),"PvP opt-out accepted after the actual combat cooldown")
 await equip(0,"hunting_bow");await stance(0,"hunting_bow")
 var friendly_health=hp(1)
 var friendly_before=own(1).position.duplicate()
 await pause(.2)
 var ammo_before=int(peers[0].local_profile.magic_items.quantities.get("wooden_arrows",0))+int(peers[1].local_profile.magic_items.quantities.get("wooden_arrows",0))
 var previous_claims=latest[0].get("claims",{}).keys()
 await attack(0,true)
 var claim_id=""
 for id in latest[0].get("claims",{}):
  if id not in previous_claims and latest[0].claims[id].get("arrow",false):claim_id=id;break
 var friendly_after=own(1).position
 var friendly_step=Vector3(friendly_before[0],friendly_before[1],friendly_before[2]).distance_to(Vector3(friendly_after[0],friendly_after[1],friendly_after[2]))
 check(hp(1)==friendly_health and friendly_step<.03,"Opted-out friend physically intercepts arrow without damage or recoil",{"health_before":friendly_health,"health_after":hp(1),"displacement":friendly_step})
 check(not claim_id.is_empty(),"Physical friendly interception creates one recoverable missed arrow")
 if not claim_id.is_empty():
  var positions=[own(0).position,own(1).position];var at=latest[0].claims[claim_id].position
  var target=Vector3(at[0],at[1],at[2]);var distances=[]
  var friend_contact={}
  for event in character_arrow_contacts():
   if event.arrow_id==claim_id and event.character_id==peers[1].character_id:friend_contact=event
  check(friend_contact.get("outcome","")=="friend" and friend_contact.get("claim_created",false),"Recovered arrow was physically intercepted by the friend's shared native hurt volume",friend_contact)
  for point in positions:distances.append(Vector3(point[0],point[1],point[2]).distance_to(target))
  check(distances[0]<=3 and distances[1]<=3,"Both peers are eligible for the same physical claim",distances)
  var result_sizes=[replies[0].size(),replies[1].size()]
  peers[0].request_action("loot",{"claim":claim_id});peers[1].request_action("loot",{"claim":claim_id})
  await pause(1)
  var successes=0
  for i in range(2):
   for result in replies[i].slice(result_sizes[i]):
    if result.get("kind","")=="loot" and result.get("ok",false):successes+=1
  var ammo_after=int(peers[0].local_profile.magic_items.quantities.get("wooden_arrows",0))+int(peers[1].local_profile.magic_items.quantities.get("wooden_arrows",0))
  check(successes==1 and ammo_after==ammo_before and not latest[0].get("claims",{}).has(claim_id),"Concurrent recovery restores exactly one arrow and removes one claim",{"successes":successes,"ammo_before_shot":ammo_before,"ammo_after_race":ammo_after})
 # Reach a real authored wall through ordinary movement, then attempt a blocked release.
 if not wall_hint.is_empty():
  var original=starting_positions[0].duplicate();starting_positions[0]=wall_hint.position
  await reset_positions()
  var actual_wall_point=own(0).position
  var wall_distance=Vector3(actual_wall_point[0],actual_wall_point[1],actual_wall_point[2]).distance_to(Vector3(wall_hint.position[0],wall_hint.position[1],wall_hint.position[2]))
  check(wall_distance<.15,"Normal movement reaches the authored wall test standpoint",wall_distance)
  game.camera_driver.yaw=float(wall_hint.yaw);game.camera_driver.first_pitch=0.0;await pause(.2)
  var wall_ammo=int(peers[0].local_profile.magic_items.quantities.get("wooden_arrows",0))
  var wall_stamina=float(own(0).stamina)
  var drawing=await command(0,"primary_down");await pause(.35)
  var denied=await command(0,"primary_up");await pause(.25)
  check(drawing.get("ok",false) and not denied.get("ok",true) and own(0).get("action","")=="free" and int(peers[0].local_profile.magic_items.quantities.get("wooden_arrows",0))==wall_ammo and float(own(0).stamina)>=wall_stamina-.01,"Actual wall-denied bow release is free and spends no ammo or stamina",{"denial":denied,"action":own(0).get("action","")})
  starting_positions[0]=original;await reset_positions()
  var rearmed=await command(0,"primary_down");await pause(.15)
  check(rearmed.get("ok",false) and own(0).get("action","")=="bow_draw","Bow can rearm after a denied wall release")
  await command(0,"cancel");await pause(.1)
 else:check(false,"Authored wall hint supplied for release-denial integration")
 await run_occlusion()
 await finish()
func run_repairs() -> void:
 await consent(0,true);await consent(1,true)
 await equip(1,"standard_greatsword");await equip(0,"duelist_rapier")
 if not await stance(0,"duelist_rapier",1.75):return
 var before=hp(1);await attack(0)
 check(hp(1)<before,"Focused actual Session rapier control causes real damage",attack_history[-1])
 await heal(1)
 if not await stance(0,"duelist_rapier",1.75):return
 before=hp(1);await attack(0,false,1)
 check(hp(1)==before and attack_history[-1].parried[1],"Focused actual Session settled rapier strike is genuinely parried",attack_history[-1])
 await run_occlusion()
func run_occlusion() -> void:
 var before=0.0
 # Walk through the authored door to put a real retained wall between peers.
 if not occlusion_hint.is_empty():
  await heal(0);await heal(1);await consent(1,true)
  await walk_route(1,occlusion_hint.outside_walk_route)
  await walk_route(0,occlusion_hint.inside_walk_route)
  initial_yaws[0]=float(occlusion_hint.inside_yaw);initial_yaws[1]=float(occlusion_hint.outside_yaw)
  await reset_positions()
  var from=Vector3(own(0).position[0],own(0).position[1]+1.4,own(0).position[2])
  var to=Vector3(own(1).position[0],own(1).position[1]+1.4,own(1).position[2])
  var wall=game.player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1))
  check(not wall.is_empty(),"Actual authored solid bay occludes the line between the reached peer positions",{"from":[from.x,from.y,from.z],"to":[to.x,to.y,to.z],"hit_position":([wall.position.x,wall.position.y,wall.position.z] if not wall.is_empty() else []),"collider_path":(str(wall.collider.get_path()) if not wall.is_empty() else "")})
  await equip(0,"standard_greatsword");before=hp(1);await attack(0,false,-1,0.0)
  check(hp(1)==before and attack_history[-1].down_reply.get("ok",false) and attack_history[-1].up_reply.get("ok",false),"Retained authored wall blocks actual Session steel damage",attack_history[-1])
  await equip(0,"hunting_bow");before=hp(1)
  var prior=[]
  for event in character_arrow_contacts():prior.append(event.arrow_id)
  await attack(0,true,-1,0.0)
  var wall_leak=false
  for event in character_arrow_contacts():
   if event.arrow_id not in prior and event.character_id==peers[1].character_id:wall_leak=true
  check(hp(1)==before and not wall_leak and attack_history[-1].down_reply.get("ok",false) and (attack_history[-1].up_reply.get("ok",false) or "scenery" in String(attack_history[-1].up_reply.get("error",""))),"Retained authored wall blocks actual Session arrow before the far player's native upper body",attack_history[-1])
  var ammo=int(peers[0].local_profile.magic_items.quantities.get("wooden_arrows",0));var stamina=float(own(0).stamina)
  var down=await command(0,"primary_down");await pause(.35);var up=await command(0,"primary_up");await pause(.25)
  check(down.get("ok",false) and not up.get("ok",true) and "scenery" in String(up.get("error","")) and own(0).action=="free" and int(peers[0].local_profile.magic_items.quantities.get("wooden_arrows",0))==ammo and float(own(0).stamina)>=stamina-.01,"Nearest solid bay rejects bow release without ammo or stamina spend",{"down":down,"up":up,"action":own(0).action})
  var rearmed=await command(0,"primary_down");await pause(.15)
  check(rearmed.get("ok",false) and own(0).action=="bow_draw","Solid-bay denied release can immediately rearm")
  await command(0,"cancel")
 else:check(false,"Authored opposite-wall route supplied for combat occlusion")
func finish() -> void:
 ready=false
 for peer in peers:peer.leave_server()
 var deadline=Time.get_ticks_msec()+35000
 while peers.any(func(peer):return peer.connected) and Time.get_ticks_msec()<deadline:await process_frame
 for i in range(peers.size()):
  var saved=Storage.read_file(peers[i].checkpoint_path,"character")
  check(not peers[i].connected and saved.ok and Profile.valid(saved.data) and Profile.digest(saved.data)==Profile.digest(peers[i].local_profile),"Peer %d lossless durable graceful departure"%i)
 if game.audio!=null:check(await game.audio.shutdown_and_drain(),"Actual main audio playback drain completes")
 print("PVP_PROBE_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"snapshots":snapshots,"observed_control_contact_clocks":observed_contact_clock,"attack_observations":attack_history,"routing_history":routing_history,"fixture_mode":options.mode,"character_arrow_interceptions":character_arrow_contacts(),"network_diagnostics":network_live}))
 game.queue_free();peers[1].queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
