extends SceneTree
## Independent real-process client probe. No runtime world or fake authority.
const Session=preload("res://scripts/network/wr_session.gd")
const Profile=preload("res://scripts/network/wr_profile.gd")
const Storage=preload("res://scripts/network/wr_storage_codec.gd")
var session:Node
var options={"port":"24571","checkpoint":"","seconds":"12","expected":"2","recover":"false","password-file":"","role":"baseline","purchase":""}
var snapshots=0
var maximum_players=0
var maximum_enemies=0
var joined_ok=false
var departed=false
var actions=[]
var first_position=[]
var last_position=[]
var foreign_profile=false
var hash_roundtrip=false
var self_state:Dictionary={}
var exercise_started=false
var exercise_done=false
var event_ids={}
var observed_floors={}
var damaged_enemies={}
var damage_seen=false
var observed_actions={}
var own_hit_targets={}
var defeat_observations={}
var own_targeted_enemies={}
var control_yaw=0.0
var control_movement=Vector2.ZERO
var last_snapshot:Dictionary={}
var run_started=0
var network_live:Dictionary={}
func _initialize() -> void:call_deferred("run")
func receive(snapshot:Dictionary) -> void:
	last_snapshot=snapshot
	network_live=session.network_diagnostics()
	for id in snapshot.players:observed_floors[snapshot.players[id].floor]=true
	for id in snapshot.enemies:
		var enemy=snapshot.enemies[id]
		if enemy.get("target","")==session.character_id:own_targeted_enemies[id]=true
		if enemy.get("health",0)<enemy.get("max_health",0):damaged_enemies[id]=enemy.health
	for event in snapshot.get("events",[]):
		var event_id=String(event.get("id",""))
		if not event_ids.has(event_id):
			if event.get("kind","")=="hit" and event.get("owner","")==session.character_id:own_hit_targets[String(event.get("target",""))]=int(own_hit_targets.get(String(event.get("target","")),0))+1
			if event.get("kind","")=="defeat":
				var player=snapshot.players.get(session.character_id,{})
				defeat_observations[String(event.get("target",""))]={"health":player.get("health",-1),"xp":player.get("profile",{}).get("progression",{}).get("xp",-1)}
		event_ids[event_id]=event.get("kind","")
	snapshots+=1;maximum_players=maxi(maximum_players,snapshot.players.size());maximum_enemies=maxi(maximum_enemies,snapshot.enemies.size())
	for id in snapshot.players:
		if id!=session.character_id and snapshot.players[id].has("profile"):foreign_profile=true
	if snapshot.players.has(session.character_id):
		self_state=snapshot.players[session.character_id]
		observed_actions[String(self_state.action)]=true
		damage_seen=damage_seen or self_state.health<self_state.max_health
		last_position=self_state.position
		if first_position.is_empty():first_position=last_position.duplicate()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var pieces=arg.substr(2).split("=",true,1);options[pieces[0]]=pieces[1]
	session=Session.new();session.name="WorldRiseSession";session.checkpoint_path=options.checkpoint;session.reconnect_requested=options.recover=="true";root.add_child(session)
	if not options["password-file"].is_empty():session.password=FileAccess.get_file_as_string(options["password-file"]).strip_edges()
	session.snapshot_received.connect(receive)
	session.action_result.connect(func(result):actions.append(result))
	session.status_changed.connect(func(status):print("PROBE_STATUS ",status))
	session.joined.connect(func(_id):joined_ok=true;print("PROBE_JOINED ",session.character_id))
	var result=session.join("127.0.0.1",int(options.port))
	if result!=OK:print("PROBE_ERROR join ",result);quit(1);return
	var started=Time.get_ticks_msec();run_started=started;var sent=false
	while Time.get_ticks_msec()-started<int(options.seconds)*1000:
		await create_timer(.1).timeout
		if session.connected:
			session.send_input({"movement":[.2 if options.role=="baseline" else control_movement.x,control_movement.y],"yaw":control_yaw,"pitch":0.0,"buttons":{}})
			if options.role!="baseline" and not exercise_started:exercise_started=true;call_deferred("exercise")
			if not sent:
				sent=true;session.request_action("purchase",{"recipe":"unknown_recipe"});session.request_action("pvp",{"enabled":false})
	if joined_ok:
		session.leave_server()
		for i in range(500):
			await create_timer(.05).timeout
			if not session.connected:departed=true;break
	var saved=Storage.read_file(options.checkpoint,"character")
	hash_roundtrip=saved.ok and Profile.valid(saved.data) and Profile.digest(session.local_profile)==Profile.digest(saved.data)
	var event_counts={}
	for kind in event_ids.values():event_counts[kind]=int(event_counts.get(kind,0))+1
	var report={"joined":joined_ok,"departed":departed,"snapshots":snapshots,"maximum_players":maximum_players,"maximum_enemies":maximum_enemies,"foreign_profile_leaked":foreign_profile,"hash_roundtrip_stable":hash_roundtrip,"actions":actions,"first_position":first_position,"last_position":last_position,"checkpoint_exists":FileAccess.file_exists(options.checkpoint),"status":session.status,"network_diagnostics":network_live,"role":options.role,"exercise_done":exercise_done,"observed_actions":observed_actions.keys(),"observed_floors":observed_floors.keys(),"damaged_enemies":damaged_enemies,"damage_seen":damage_seen,"final_health":self_state.get("health",-1),"own_hit_targets":own_hit_targets,"own_targeted_enemies":own_targeted_enemies.keys(),"defeat_observations":defeat_observations,"event_counts":event_counts,"copper":session.local_profile.get("copper",-1),"xp":session.local_profile.get("progression",{}).get("xp",-1),"quantities":session.local_profile.get("magic_items",{}).get("quantities",{})}
	print("PROBE_RESULT ",JSON.stringify(report))
	var exercise_ok=true
	if options.role=="vendor":
		var costs={"field_spear":80,"duelist_rapier":100,"hunting_bow":75,"improved_standard_greatsword":300}
		var expected_action="bow_draw" if options.purchase=="hunting_bow" else "light" if options.purchase=="improved_standard_greatsword" else "weapon_attack"
		exercise_ok=exercise_done and observed_actions.has(expected_action) and options.purchase in session.local_profile.magic_items.owned and session.local_profile.magic_items.weapon_id==options.purchase and int(session.local_profile.copper)==1000-int(costs[options.purchase])-10
	elif options.role!="baseline":exercise_ok=exercise_done and not damaged_enemies.is_empty()
	if options.role=="fen_combat":exercise_ok=exercise_ok and int(session.local_profile.progression.xp)>1000
	quit(0 if exercise_ok and joined_ok and departed and snapshots>=10 and maximum_players>=int(options.expected) and maximum_enemies>0 and not foreign_profile and hash_roundtrip else 1)

func aim_at_fen_target() -> bool:
	if self_state.is_empty():return false
	var target={};var best=INF
	var at=Vector3(self_state.position[0],self_state.position[1],self_state.position[2])
	for id in last_snapshot.get("enemies",{}):
		var candidate=last_snapshot.enemies[id]
		if not String(id).begins_with("wr_floor_02/giant_g9") or candidate.get("health",0)<=0:continue
		var point=Vector3(candidate.position[0],candidate.position[1],candidate.position[2]);var distance=at.distance_to(point)
		if distance<best:best=distance;target=candidate
	if target.is_empty():control_movement=Vector2.ZERO;return false
	var toward=Vector3(target.position[0],target.position[1],target.position[2])-at
	control_yaw=atan2(-toward.x,-toward.z)
	control_movement=Vector2(0,-.35) if best>1.8 else Vector2.ZERO
	return true
func exercise_fen() -> void:
	var deadline=run_started+int(options.seconds)*1000-1500
	while session.connected and Time.get_ticks_msec()<deadline and self_state.get("health",0)>0:
		if not aim_at_fen_target():break
		if self_state.get("action","")=="free":
			session.request_action("primary_down");await create_timer(.05).timeout;session.request_action("primary_up")
			await create_timer(.12).timeout
		else:await create_timer(.05).timeout
	control_movement=Vector2.ZERO;exercise_done=true
func exercise() -> void:
	await create_timer(.5).timeout
	if options.role=="vendor":
		session.request_action("purchase",{"item":options.purchase})
		await create_timer(.7).timeout
		session.request_action("purchase",{"item":"wooden_arrows","count":10})
		await create_timer(.7).timeout
		session.request_action("equip",{"item":options.purchase})
		await create_timer(.7).timeout
	if not self_state.get("sword_drawn",false):session.request_action("draw")
	await create_timer(1.0).timeout
	if options.role=="fen_combat":await exercise_fen();return
	for i in range(6 if options.role=="vendor" else 12):
		if session.connected:
			session.request_action("primary_down")
			await create_timer(.35 if options.purchase=="hunting_bow" else .05).timeout
			session.request_action("primary_up")
			await create_timer(1.0).timeout
	exercise_done=true
