extends RefCounted
## Presentation of acknowledged session state; never awards loot or inflicts damage.
const Actor=preload("res://scripts/actor.gd")
var game:Node
var remote_targets:Dictionary={}
var remotes:Dictionary={}
var claims:Dictionary={}
var projectiles:Dictionary={}
var server_tick=-1
func configure(owner_game:Node) -> void:game=owner_game
func vector(value:Array) -> Vector3:return Vector3(float(value[0]),float(value[1]),float(value[2]))
func clear() -> void:
	for actor in remotes.values():
		if is_instance_valid(actor):actor.queue_free()
	remotes.clear();remote_targets.clear()
	for projectile in projectiles.values():
		if is_instance_valid(projectile):projectile.queue_free()
	projectiles.clear()
	for marker in claims.values():
		if is_instance_valid(marker):marker.queue_free()
	claims.clear();server_tick=-1
func receive(snapshot:Dictionary) -> void:
	if not game.online_session_active() or int(snapshot.get("tick",-1))<=server_tick:return
	server_tick=int(snapshot.tick)
	var members:Dictionary=snapshot.get("players",{})
	var own_id:String=game.wr_session.character_id
	if not members.has(own_id):return
	var own:Dictionary=members[own_id]
	game.online_pvp=bool(own.get("pvp",false))
	if own.floor!=game.map_id:
		game.load_map(own.floor,Vector2(float(own.position[0]),float(own.position[2])))
		clear();server_tick=int(snapshot.tick)
	game.apply_online_profile(own.get("profile",{}))
	if game.prediction!=null:game.prediction.queue_snapshot(own,int(snapshot.tick))
	else:apply_actor(game.player,own,true)
	game.worldrise.day_clock=float(snapshot.get("clock",game.worldrise.day_clock))
	if snapshot.has("flags"):game.worldrise.flags=snapshot.flags.duplicate()
	game.worldrise.guild.contracts=own.get("contracts",{}).duplicate(true)
	var discovered:Dictionary=own.get("discoveries",{})
	game.worldrise.checkpoints.unlocked=discovered.get("wr_floor_01",["arrival"]).duplicate()
	game.worldrise.swamp.unlocked=discovered.get("wr_floor_02",["arrival"]).duplicate()
	for id in members:
		if id==own_id:continue
		var state:Dictionary=members[id]
		if state.floor!=game.map_id:continue
		var actor=remotes.get(id)
		if not is_instance_valid(actor):
			actor=Actor.new();actor.name="Remote_"+String(id).left(12);actor.entity_id=id
			actor.configure(game.read_data("res://content/characters/hero.json"));game.world_root.add_child(actor)
			actor.controllable=true;actor.ground_world=game.current_world;actor.set_physics_process(false);actor.set_process_input(false)
			actor.collision_layer=2;actor.collision_mask=0;actor.damage_authority=false
			actor.weapon_runtime=preload("res://scripts/weapon_runtime.gd").new();actor.weapon_runtime.configure(game,actor)
			game.apply_character_art(actor)
			var driver=preload("res://scripts/network/wr_view_frame.gd").new();driver.bind(actor,game.config.follow_camera)
			actor.set_meta("canonical_manual_step",true)
			remotes[id]=actor
		var previous_position:Vector3=actor.position
		apply_actor(actor,state,false)
		remote_targets[id]=state.duplicate(true)
		if previous_position.distance_to(actor.position)<8:actor.position=previous_position
	for id in remotes.keys():
		if not members.has(id) or members[id].floor!=game.map_id:
			if is_instance_valid(remotes[id]):remotes[id].queue_free()
			remotes.erase(id);remote_targets.erase(id)
	if game.get("blood")!=null:game.get("blood").snapshot_events(snapshot.get("events",[]),own_id,game.map_id,int(snapshot.tick))
	for event in snapshot.get("events",[]):
		if event.get("floor",game.map_id)!=game.map_id or game.audio==null:continue
		var at=vector(event.get("position",[0,0,0]))
		var context={"identity":"net:"+String(event.id)}
		if event.get("kind")=="action" and event.get("owner")!=own_id:game.audio.emit_event({"id":"action."+String(event.get("action","")),"actor_id":String(event.get("owner","")),"action_id":String(event.id),"event_index":0,"at":at})
		elif event.get("kind")=="audio":
			var event_id=String(event.get("event",""))
			var own_event=String(event.get("actor_id",""))==own_id
			var synthesized=event_id.begins_with("combat.swing.") or event_id in ["weapon.spear.thrust","weapon.rapier.thrust","weapon.bow.draw","weapon.bow.release"]
			if not synthesized and not (own_event and event_id.begins_with("action.")):
				var audible=event.duplicate();audible["id"]=event_id;audible["at"]=at;audible["identity"]=context.identity
				game.audio.emit_event(audible)
		elif event.get("kind")=="parry":game.audio.play("combat.parry",at,context)
		elif event.get("kind")=="hit":
			var record:Dictionary=snapshot.get("enemies",{}).get(event.get("target",""),{})
			var kind=String(record.get("kind",""));game.audio.play("combat.hit."+("gel" if "slime" in kind else "stone" if kind in ["vault_elder","warden"] else "flesh"),at,context)
	var live:Dictionary=snapshot.get("projectiles",{})
	for id in live:
		var state:Dictionary=live[id]
		if state.floor!=game.map_id:continue
		var arrow=projectiles.get(id)
		if not is_instance_valid(arrow):
			arrow=MeshInstance3D.new();var mesh=CylinderMesh.new();mesh.top_radius=.008;mesh.bottom_radius=.008;mesh.height=.72
			arrow.mesh=mesh;var material=StandardMaterial3D.new();material.albedo_color=Color("#A07A49");arrow.material_override=material
			game.current_world.add_child(arrow);projectiles[id]=arrow
		arrow.position=vector(state.position)
		var direction=vector(state.velocity).normalized()
		if direction.length_squared()>.01:
			var right=direction.cross(Vector3.UP).normalized()
			if right.is_zero_approx():right=Vector3.RIGHT
			arrow.basis=Basis(right,direction,right.cross(direction)).orthonormalized()
	for id in projectiles.keys():
		if not live.has(id) or live[id].floor!=game.map_id:
			if is_instance_valid(projectiles[id]):projectiles[id].queue_free()
			projectiles.erase(id)
	game.current_world.interactions=game.current_world.interactions.filter(func(entry):return not entry.has("wr_claim"))
	var personal:Dictionary=snapshot.get("claims",{})
	for id in personal:
		var claim:Dictionary=personal[id]
		if claim.floor!=game.map_id or (claim.get("owner","")!=own_id and not claim.get("arrow",false)):continue
		var marker=claims.get(id)
		if not is_instance_valid(marker):
			marker=MeshInstance3D.new();var mesh=SphereMesh.new();mesh.radius=.12;mesh.height=.24;marker.mesh=mesh
			var material=StandardMaterial3D.new();material.albedo_color=Color("#ECD19B");material.emission_enabled=true;material.emission=Color("#6B5432");marker.material_override=material
			game.current_world.add_child(marker);claims[id]=marker
		marker.position=vector(claim.position)+Vector3.UP*.18
		game.current_world.interactions.append({"id":"online_loot","wr_claim":id,"title":"Recover arrow" if claim.get("arrow",false) else "Collect loot","position":marker.position,"actor":null})
	for id in claims.keys():
		if not personal.has(id) or personal[id].floor!=game.map_id:
			if is_instance_valid(claims[id]):claims[id].queue_free()
			claims.erase(id)
	game.worldrise.cycle_lighting()
	game.worldrise.apply_authoritative_enemies(snapshot.get("enemies",{}).values())
	game.worldrise.apply_authoritative_effects(snapshot.get("native_effects",{}))
	if game.voice!=null:
		var roster:Dictionary=snapshot.get("voice_roster",{})
		var peer_ids:Array=[]
		for id in roster:
			var peer_id=int(id);peer_ids.append(peer_id)
			if peer_id==game.wr_session.local_peer_id:continue
			var member:Dictionary=roster[id]
			game.voice.set_peer(peer_id,vector(member.position),member.floor,member.get("group","friends"))
		for peer_id in game.voice.peers.keys():
			if peer_id not in peer_ids:game.voice.remove_peer(peer_id)
		game.voice.set_local_position(game.player.position,game.map_id)
func tick(delta:float) -> void:
	for id in remotes:
		var actor=remotes[id]
		if not is_instance_valid(actor) or not remote_targets.has(id):continue
		var target:Dictionary=remote_targets[id]
		var previous:Vector3=actor.position
		actor.position=actor.position.lerp(vector(target.position),1-exp(-delta*18))
		var distance=actor.position.distance_to(previous)
		if actor.state=="free":actor.animator.advance(delta)
		if actor.weapon_runtime.enabled():actor.weapon_runtime.pose("ready",0)
		if actor.has_node("BetaHero"):actor.get_node("BetaHero").gait.advance_distance(actor,distance,delta)
		var grounded=absf(actor.position.y-game.current_world.ground_height(actor.position))<.3
		if game.audio!=null and actor.state=="free" and grounded and distance>.0001 and distance<2:
			var stride=float(actor.get_meta("audio_stride",0.0))+distance
			if stride>=.7:
				stride=fmod(stride,.7)
				var surface=preload("res://scripts/audio/audio_surface_resolver.gd").surface(game,actor.position)
				game.audio.play("enemy.step."+surface,actor.position,{"actor_id":id})
			actor.set_meta("audio_stride",stride)
		elif distance>=2 or not grounded:actor.set_meta("audio_stride",0.0)

func apply_actor(actor:Node,state:Dictionary,local:bool) -> void:
	var weapon=String(state.get("weapon","standard_greatsword"))
	if actor.get_meta("online_weapon","")!=weapon:
		actor.set_meta("online_weapon",weapon);actor.set_weapon_visual(weapon)
		if local:game.apply_skill_stats()
	actor.position=vector(state.position);actor.velocity=vector(state.velocity)
	actor.max_health=int(state.max_health);actor.max_stamina=float(state.max_stamina)
	var previously_alive=actor.health>0
	actor.health=int(state.health);actor.stamina=float(state.stamina)
	actor.sword_equipped=bool(state.get("sword_equipped",true))
	actor.sword_drawn=bool(state.sword_drawn)
	var parent=actor.visual if actor.sword_drawn or state.action in ["draw","sheathe"] else actor.back_socket
	if actor.equipment.get_parent()!=parent:actor.equipment.reparent(parent,false)
	if not local and actor.first_person_driver!=null:
		actor.first_person_driver.yaw=float(state.yaw);actor.first_person_driver.first_pitch=float(state.pitch)
	actor.visual.rotation.y=float(state.yaw)+PI;actor.movement_camera_yaw=float(state.yaw)
	var action=String(state.action)
	if actor.weapon_type in ["spear","rapier"] and action in ["light","heavy","thrust"]:action="weapon_attack"
	if actor.weapon_type=="bow" and action=="fire":action="weapon_recovery"
	var accepted_action=String(state.get("action_id",""))
	if accepted_action!=String(actor.get_meta("online_action_id","")):
		actor.set_meta("online_action_id",accepted_action)
		actor.combo_stage=maxi(1,int(state.get("combo",1))) if action=="light" else 0
		actor.attack_yaw=float(state.yaw)+PI
		actor.attack_direction=-Vector3(sin(float(state.yaw)),0,cos(float(state.yaw)))
		actor.roll_restore_drawn=actor.sword_drawn
		var clip="attack_"+action if action in ["light","heavy","thrust"] else "parry_guard" if action=="parry" else "draw_sword" if action=="draw" else "sheathe_sword" if action=="sheathe" else "dodge_roll" if action=="dodge" else ""
		if not clip.is_empty() and actor.clips.has(clip):actor.play_clip(clip,0)
	if action=="dodge":action="roll"
	if not (local and actor.state in ["bow_draw","charge"] and action=="free"):
		actor.state=action;actor.state_duration=maxf(.001,float(state.get("duration",1.0)))
		actor.state_time=float(state.get("action_clock",float(state.action_phase)*actor.state_duration))
	if game.audio!=null and accepted_action!=String(actor.get_meta("audible_action","")):
		var phase=float(state.action_phase)
		var tuning:Dictionary=actor.combat.get(action,{})
		var event_id=""
		if action in ["light","heavy","thrust"] and phase>=maxf(0,float(tuning.get("active_start",.4))-.08):event_id="combat.swing."+action
		elif action=="weapon_attack":event_id="weapon."+actor.weapon_type+".thrust"
		elif action=="bow_draw":event_id="weapon.bow.draw"
		elif action=="weapon_recovery" and actor.weapon_type=="bow":event_id="weapon.bow.release"
		if not event_id.is_empty():
			actor.set_meta("audible_action",accepted_action)
			game.audio.play(event_id,actor.position,{"identity":"actor-action:"+accepted_action+":"+event_id})
	if local:
		if state.has("item_state"):
			var items:Dictionary=state.item_state
			game.magic_items.quantities=items.get("quantities",{}).duplicate()
			game.magic_items.owned=items.get("owned",[]).duplicate()
			game.magic_items.healing=items.get("healing",[]).duplicate(true)
			game.magic_items.phoenix_cooldown=float(items.get("phoenix_cooldown",0))
		actor.health_changed.emit(actor.health,actor.max_health);actor.stamina_changed.emit(actor.stamina,actor.max_stamina)
		if previously_alive and actor.health<=0:game._player_defeated()
		if actor.health>0 and game.recovering:
			game.recovering=false;game.death_screen.hide();game.death_veil.hide()
	else:
		if state.has("appearance") and preload("res://scripts/appearance_profile.gd").valid(state.appearance):preload("res://scripts/character_appearance.gd").apply(actor,state.appearance)
		actor.play_clip("drag_walk_loop" if actor.sword_drawn and actor.velocity.length_squared()>.05 else "walk_loop" if actor.velocity.length_squared()>.05 else "drag_idle_loop" if actor.sword_drawn else "idle_loop")
		actor.animator.advance(.05)
		var clip="attack_"+action if action in ["light","heavy","thrust"] else "parry_guard" if action=="parry" else "draw_sword" if action=="draw" else "sheathe_sword" if action=="sheathe" else ""
		if not clip.is_empty() and actor.clips.has(clip):
			actor.play_clip(clip,0)
			actor.animator.seek(float(state.action_phase)*actor.animator.get_animation(actor.clips[clip]).length,true)
		if actor.weapon_runtime.enabled():actor.weapon_runtime.pose("ready",0)
		if actor.sword_drawn:
			actor._pose_sword("light" if action=="light" else "heavy" if action=="heavy" else "thrust" if action=="thrust" else "parry" if action=="parry" else "drag",float(state.action_phase))

	if state.has("pose_state"):
		preload("res://scripts/network/wr_actor_pose.gd").apply(actor,state.pose_state)
		if actor.weapon_runtime.enabled():actor.weapon_runtime.pose("ready",0)
	if state.has("action_sequence"):actor.action_sequence=int(state.action_sequence)
