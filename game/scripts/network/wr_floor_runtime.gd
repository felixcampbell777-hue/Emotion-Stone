extends Control
## One real authored floor and its existing AI, in an isolated physics space.
## Authority drives step(), never the local UI or SceneTree's automatic clocks.
signal player_damaged(character_id:String,amount:int,away:Vector3)
signal enemy_defeated(id:String,kind:String)
signal enemy_damaged(id:String,amount:int,context:Dictionary)
signal presentation(event_id:String,at:Vector3)
const EnvironmentArt=preload("res://scripts/environment_art.gd")
const Proxy=preload("res://scripts/network/wr_player_proxy.gd")
var adapter:RefCounted
var game_mode="world_rise"
var map_id=""
var gallery_mode=false
var audio=null
var world_root:Node3D
var current_world:Node3D
var worldrise=preload("res://scripts/world_rise.gd").new()
var wolf_packs=preload("res://scripts/wolf_packs.gd").new()
var menagery={"catalog":JSON.parse_string(FileAccess.get_file_as_string("res://content/menagery.json"))}
var enemies:Array=[]
var projectiles:Array=[]
var defeated_enemies:Array=[]
var environment_profile="darkwood"
var sea_dragon=null
var player:Node3D
var players:Dictionary={}
var viewport:SubViewport
var authored:Dictionary={}
var spawn_queue:Array=[]
var empty_clocks:Dictionary={}
var generation:Dictionary={}
var elapsed=0.0
var step_clock=0.0
var day_clock=0.0
var parry_handler:Callable
var profile_timings=OS.get_environment("WORLD_RISE_PROFILE_RUNTIME")=="1"
var perf:Dictionary={}

func setup(floor_id:String,world_adapter:RefCounted) -> void:
	map_id=floor_id;adapter=world_adapter;audio=preload("res://scripts/network/wr_sound_relay.gd").new(self);worldrise.game=self;worldrise.swamp.game=self;worldrise.guild.game=self
	viewport=SubViewport.new();viewport.world_3d=World3D.new();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(viewport)
	world_root=Node3D.new();viewport.add_child(world_root)
	var script_path={"wr_floor_01":"rise_floor","wr_floor_02":"swamp_floor","wr_boss_chamber":"rise_chamber"}[map_id]
	current_world=load("res://scripts/"+script_path+".gd").new();world_root.add_child(current_world)
	current_world.build(JSON.parse_string(FileAccess.get_file_as_string("res://content/maps/"+map_id+".json")))
	if map_id=="wr_floor_01":
		preload("res://scripts/rise_chamber.gd").build_entrance(current_world)
		# Same authored aqueduct colliders added by local world_rise.build_map.
		for i in range(7):
			var at=Vector3(45+i*8,0,-150);at.y=current_world.ground_height(at);preload("res://scripts/props.gd").collider(current_world,at+Vector3.UP*4,Vector3(1.4,8,1.8))
		for p in worldrise.Shape.spec.packs:worldrise.packs[p.id]={"spec":p,"active":false,"members":[],"engaged":false,"attack":0.0,"cursor":0}
	for entry in adapter.encounter_entries(map_id):authored[entry.id]=entry;generation[entry.id]=0
	# Visuals stay out of rendering; retain their source nodes because some authored
	# controllers animate them and collision children must never be removed.
	current_world.visible=false;current_world.set_physics_process(false)
	set_physics_process(false)

func simulation_active() -> bool:return true
func notify(_message:String) -> void:pass
func add_enemy_bar(enemy:Node) -> void:
	enemy.set_physics_process(false)
	connect_enemy_damage(enemy)
	var id=String(enemy.definition.id)
	if id.begins_with("ashfang_wolf_"):
		if not authored.has(id):
			var entry=adapter.base_entry(map_id,enemy.definition,"beta_wolf",enemy.max_health,12,adapter.xp_for("beta_wolf"))
			entry.summoned=true;entry.parent_boss="ashfang";authored[id]=entry
		generation[id]=int(generation.get("ashfang",0))
		enemy.defeated.connect(func():_enemy_defeated(map_id+"/"+id,"beta_wolf",enemy))
func gain_xp(_amount:int) -> void:pass # Reward transactions are emitted to authority.
func enemy_xp_reward(kind:String) -> int:return adapter.xp_for(kind)
func retire_transient(node:Node) -> void:
	enemies.erase(node);projectiles.erase(node)
	if is_instance_valid(node):node.queue_free()
func _enemy_defeated(key:String,kind:String,_enemy:Node=null) -> void:
	if key not in defeated_enemies:defeated_enemies.append(key);enemy_defeated.emit(key.get_slice("/",1),kind)
func _ground_slam(at:Vector3,_heavy:bool=false) -> void:presentation.emit("enemy.elder.slam",at)
func impact_blocked(origin:Vector3,destination:Vector3) -> bool:
	return not world_root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,destination,1)).is_empty()
func body_live(body:Variant) -> bool:
	return is_instance_valid(body) and not body.is_queued_for_deletion()
func detach_player(id:String) -> void:
	# Remove the registry reference BEFORE ownership frees or reparents the Actor.
	var departing=players.get(id)
	players.erase(id)
	if not body_live(player) or player==departing:player=null
	for enemy in enemies:
		if not body_live(enemy):continue
		if not body_live(enemy.player) or enemy.player==departing or character_id(enemy.player)==id:
			enemy.player=null;enemy.velocity=Vector3.ZERO;enemy.lunge_hit=true
			if enemy.state not in ["idle","patrol","circle","forming"]:enemy.state="recover";enemy.state_time=.45
	if is_instance_valid(world_root) and is_instance_valid(current_world):
		for effect in world_root.get_children()+current_world.get_children():
			if body_live(effect) and String(effect.get_meta("target_character",""))==id:effect.queue_free()
	if body_live(departing) and departing is Proxy:departing.health=0;departing.queue_free()
	if not body_live(player):
		for body in players.values():
			if body_live(body):player=body;break
func prune_players() -> void:
	for id in players.keys():
		if not body_live(players[id]):detach_player(String(id))
	if not body_live(player):
		player=null
		for body in players.values():
			if body_live(body):player=body;break
func sync_players(records:Array) -> void:
	prune_players()
	var retained=[]
	for record in records:
		if String(record.get("floor",map_id))!=map_id:continue
		var id=String(record.get("character_id",record.get("id","")))
		if id.is_empty():continue
		if record.has("bridge"):
			var bridge=record.bridge
			if not body_live(bridge) or not body_live(bridge.actor):detach_player(id);continue
			if players.has(id) and players[id]!=bridge.actor:detach_player(id)
			players[id]=bridge.actor;bridge.actor.set_meta("character_id",id);retained.append(id)
			continue
		retained.append(id)
		if not players.has(id):
			var body=Proxy.new();body.character_id=id;body.runtime=self;body.ground_world=current_world;body.parry_handler=parry_handler;world_root.add_child(body);players[id]=body
		var body=players[id];var at=record.get("position",[0,0,0]);body.position=at if at is Vector3 else Vector3(at[0],at[1],at[2]);body.health=int(record.get("health",100));body.parry_handler=parry_handler
		if record.has("profile"):
			var signature=JSON.stringify(record.profile.get("magic_items",{}))
			if body.gear_signature!=signature:body.magic_gear.restore(record.profile.get("magic_items",{}));body.gear_signature=signature
		var speed=record.get("velocity",Vector3.ZERO);body.velocity=speed if speed is Vector3 else Vector3(speed[0],speed[1],speed[2])
	for id in players.keys():
		if id not in retained:detach_player(String(id))
	prune_players()
func nearest(at:Vector3) -> Node3D:
	var selected:Node3D=null;var distance=INF
	for body in players.values():
		if not body_live(body) or body.health<=0:continue
		var d=at.distance_squared_to(body.position)
		if d<distance:selected=body;distance=d
	return selected
func interested(at:Vector3,distance:float) -> bool:
	return players.values().any(func(body):return body_live(body) and body.health>0 and body.position.distance_squared_to(at)<distance*distance)
func spawn_entry(entry:Dictionary) -> void:
	player=nearest(Vector3(entry.at[0],0,entry.at[1]))
	if player==null:return
	if map_id=="wr_floor_02":
		var definition=entry.duplicate(true);definition.style=entry.kind
		worldrise.swamp.spawn(definition)
	elif entry.id=="ashfang":worldrise.day_clock=day_clock;worldrise.spawn_ashfang()
	elif entry.get("summoned",false):
		var aid=load("res://scripts/beta_enemy.gd").new();aid.game=self;aid.configure({"id":entry.id,"kind":"beta_wolf","pack":"ashfang_aid","at":entry.at},player,worldrise.states.get(entry.id,{}));world_root.add_child(aid);enemies.append(aid);aid.position.y=current_world.ground_height(aid.position);add_enemy_bar(aid)
	elif entry.id=="vault_elder":
		var boss=load("res://scripts/elder_boss.gd").new();boss.game=self;boss.configure({"id":"vault_elder","kind":"vault_elder","at":[0,-5],"size":"giant"},player);boss.health=int(worldrise.states.get("vault_elder",{}).get("health",boss.max_health));world_root.add_child(boss);enemies.append(boss);boss.set_physics_process(false)
		current_world.boss=boss;current_world.encounter="forming";current_world.set_bridge(false)
		boss.defeated.connect(func():_enemy_defeated(map_id+"/vault_elder","vault_elder",boss);current_world.encounter="cleared";current_world.set_bridge(true))
	else:
		var base=JSON.parse_string(FileAccess.get_file_as_string("res://content/maps/wr_floor_01.json")).enemies.filter(func(e):return e.id==String(entry.id).trim_suffix("_night"))
		if base.is_empty():return
		var data=worldrise.night_entry(base[0]) if String(entry.id).ends_with("_night") else base[0].duplicate(true);data.id=entry.id
		var record=worldrise.packs[data.pack];record.active=true;worldrise.spawn_member(record,data)
	for enemy in enemies:
		if not body_live(enemy):continue
		enemy.set_physics_process(false)
		connect_enemy_damage(enemy)
		if pending_native_states.has(enemy.definition.id):restore_enemy_state(enemy,pending_native_states[enemy.definition.id]);pending_native_states.erase(enemy.definition.id)
	wolf_packs.build(self)

func step(delta:float) -> void:
	var stage_started=Time.get_ticks_usec() if profile_timings else 0
	var frame_started=stage_started
	prune_players()
	elapsed+=delta;worldrise.elapsed=elapsed;worldrise.day_clock=day_clock
	process_empty_resets(delta)
	if profile_timings:perf.reset_ms=(Time.get_ticks_usec()-stage_started)/1000.0;stage_started=Time.get_ticks_usec()
	if player==null or not is_instance_valid(player):
		if profile_timings:
			for stage in ["interest_ms","ai_ms","coordination_ms","effects_ms"]:perf[stage]=0.0
			perf.total_ms=(Time.get_ticks_usec()-frame_started)/1000.0;perf.enemy_count=enemies.size();perf.authored_count=authored.size()
		return
	# Interest is the union of all players, preserving distinct floors and distant fights.
	for entry in authored.values():
		if entry.get("summoned",false) and not pending_native_states.has(entry.id):continue
		if entry.has("parent_id") and map_id+"/"+entry.parent_id not in defeated_enemies:continue
		if entry.get("night_only",false) and day_clock<600:continue
		if entry.get("arena",false) and not players.values().any(func(body):return body_live(body) and body.health>0 and body.position.y>=-.2 and body.position.y<4.5 and Vector2(body.position.x/23.0,body.position.z/25.0).length()<.94):continue
		if entry.id in spawn_queue or map_id+"/"+entry.id in defeated_enemies or enemies.any(func(e):return body_live(e) and e.definition.id==entry.id):continue
		if interested(Vector3(entry.at[0],0,entry.at[1]),85.0):spawn_queue.append(entry.id)
	if not spawn_queue.is_empty():spawn_entry(authored[spawn_queue.pop_front()])
	if profile_timings:perf.interest_ms=(Time.get_ticks_usec()-stage_started)/1000.0;stage_started=Time.get_ticks_usec()
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy):enemies.erase(enemy);continue
		if enemy.health<=0:continue
		# Retain the committed target through the full authored attack/recovery.
		if is_instance_valid(enemy.player) and enemy.player not in players.values():
			enemy.state="recover";enemy.state_time=.45;enemy.lunge_hit=true;enemy.velocity=Vector3.ZERO
		if enemy.state in ["idle","circle","patrol"] or not is_instance_valid(enemy.player) or enemy.player.health<=0 or enemy.player not in players.values():
			var next=nearest(enemy.position)
			if next!=null:enemy.player=next
		if not is_instance_valid(enemy.player) or enemy.player not in players.values():continue
		player=enemy.player
		enemy.simulation_enabled=true;enemy.ai_enabled=true

		enemy._physics_process(delta)
	if profile_timings:perf.ai_ms=(Time.get_ticks_usec()-stage_started)/1000.0;stage_started=Time.get_ticks_usec()
	worldrise.coordinate_boars(delta)
	wolf_packs.tick(delta)
	if profile_timings:perf.coordination_ms=(Time.get_ticks_usec()-stage_started)/1000.0;stage_started=Time.get_ticks_usec()
	for effect in world_root.get_children()+current_world.get_children():
		if not body_live(effect):continue
		if effect in enemies or effect==current_world or effect in players.values():continue
		if effect.get_script()==null or effect.get("game")!=self:continue
		effect.set_physics_process(false)
		if effect.has_meta("target_character"):
			var target_id=String(effect.get_meta("target_character"))
			if not players.has(target_id) or not body_live(players[target_id]):effect.queue_free();continue
			player=players[target_id]
		if effect.has_method("_physics_process"):effect._physics_process(delta)
	if profile_timings:perf.effects_ms=(Time.get_ticks_usec()-stage_started)/1000.0;perf.total_ms=(Time.get_ticks_usec()-frame_started)/1000.0;perf.enemy_count=enemies.size();perf.authored_count=authored.size()

func enemy_records() -> Array:
	var started=Time.get_ticks_usec() if profile_timings else 0
	var result=[]
	for enemy in enemies:
		if not is_instance_valid(enemy):continue
		var record={"id":enemy.definition.id,"kind":enemy.definition.kind,"floor":map_id,"position":[enemy.position.x,enemy.position.y,enemy.position.z],"health":enemy.health,"max_health":enemy.max_health,"state":enemy.state,"state_time":enemy.state_time,"yaw":enemy.visual.rotation.y,"target":character_id(enemy.player),"moving":enemy.velocity.length_squared()>.01,"visual_position":[enemy.visual.position.x,enemy.visual.position.y,enemy.visual.position.z],"visual_scale":[enemy.visual.scale.x,enemy.visual.scale.y,enemy.visual.scale.z]}
		record.native_state=capture_enemy_state(enemy)
		var animator=enemy.get("animator")
		if animator is AnimationPlayer:record.animation=animator.current_animation;record.animation_time=animator.current_animation_position
		if enemy.definition.kind=="vault_elder":record.attack_kind=enemy.attack_kind;record.duration=enemy.duration
		result.append(record)
	if profile_timings:perf.records_ms=(Time.get_ticks_usec()-started)/1000.0
	return result
func enemy_node(id:String) -> Node3D:
	for enemy in enemies:
		if is_instance_valid(enemy) and String(enemy.definition.id)==id:return enemy
	return null
func apply_enemy_damage(id:String,amount:int,away:Vector3,context:Dictionary={}) -> bool:
	var enemy=enemy_node(id)
	if enemy==null or enemy.health<=0:return false
	enemy.set_meta("pending_damage_context",context.duplicate(true))
	if String(context.get("damage_kind",""))=="melee":enemy.take_sword_damage(amount,away,bool(context.get("strong",false)),float(context.get("recoil_multiplier",context.get("force",1.0))))
	else:enemy.take_damage(amount,away)
	return true

func move_player(id:String,motion:Vector3,delta:float) -> Dictionary:
	if not players.has(id) or not body_live(players[id]):detach_player(id);return {}
	var body=players[id]
	var factor=1.0
	for source in body.slow_sources.keys():
		var slow=body.slow_sources[source];slow.remaining=maxf(0,float(slow.remaining)-delta)
		if slow.remaining<=0:body.slow_sources.erase(source)
		else:factor=minf(factor,float(slow.factor))
	body.velocity=Vector3(motion.x*factor,motion.y,motion.z*factor)+body.knockback
	body.knockback=body.knockback.move_toward(Vector3.ZERO,delta*18)
	body.jump_velocity=motion.y
	body.jump_active=absf(motion.y)>.001 or body.position.y>current_world.ground_height(body.position)+.02
	current_world.move_grounded(body,delta)
	return {"position":[body.position.x,body.position.y,body.position.z],"velocity":[body.velocity.x,body.velocity.y,body.velocity.z]}
func raycast(origin:Vector3,destination:Vector3,mask:int=1) -> Dictionary:
	return world_root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,destination,mask))
func set_day_clock(value:float) -> void:
	var clock_started=Time.get_ticks_usec() if profile_timings else 0
	day_clock=fposmod(value,1080)
	if map_id!="wr_floor_01":
		if profile_timings:perf.day_clock_ms=(Time.get_ticks_usec()-clock_started)/1000.0
		return
	if day_clock>=600:
		for base in authored.values().duplicate():
			if not base.get("night_double",false) or String(base.id).ends_with("_night"):continue
			var entry=base.duplicate(true);entry.id+="_night";authored[entry.id]=entry
	else:
		for id in authored.keys():
			if String(id).ends_with("_night"):authored.erase(id)
		for enemy in enemies.duplicate():
			if not body_live(enemy):enemies.erase(enemy);continue
			if String(enemy.definition.id).ends_with("_night") or enemy.definition.id=="ashfang" or enemy.definition.get("pack","")=="ashfang_aid":
				queue_enemy_state(String(enemy.definition.id),capture_enemy_state(enemy));worldrise.remember(enemy);retire_transient(enemy)
	if profile_timings:perf.day_clock_ms=(Time.get_ticks_usec()-clock_started)/1000.0
func safe_to_reset(entry:Dictionary) -> bool:
	var center=entry.get("home",entry.position);var at=Vector3(center[0],center[1],center[2])
	var radius=maxf(float(entry.get("leash",entry.get("aggro",18))),18)+12
	if players.values().any(func(body):return body_live(body) and body.position.distance_squared_to(at)<=radius*radius):return false
	var group=String(entry.get("pack",entry.get("parent_id",entry.id)))
	return not enemies.any(func(enemy):return is_instance_valid(enemy) and enemy.health>0 and String(enemy.definition.get("pack",String(enemy.definition.id).get_slice("_split_",0)))==group and enemy.state in ["windup","lunge","strike","rush","howl","leap","giant_jump","giant_warn"] and is_instance_valid(enemy.player) and enemy.player.health>0 and enemy.player.position.distance_squared_to(at)<=radius*radius)
func process_empty_resets(delta:float) -> void:
	for entry in authored.values():
		if entry.has("cooldown"):continue
		var id=String(entry.id)
		if not safe_to_reset(entry):empty_clocks.erase(id);continue
		empty_clocks[id]=float(empty_clocks.get(id,0))+delta
		if empty_clocks[id]<adapter.RESET_EMPTY_SECONDS:continue
		var key=map_id+"/"+id
		var changed=key in defeated_enemies or enemies.any(func(enemy):return is_instance_valid(enemy) and enemy.definition.id==id and enemy.health<enemy.max_health)
		if not changed:continue
		for enemy in enemies.duplicate():
			if is_instance_valid(enemy) and enemy.definition.id==id:retire_transient(enemy)
		defeated_enemies.erase(key);pending_native_states.erase(id);worldrise.states.erase(id);worldrise.swamp.states.erase(id);worldrise.swamp.live.erase(id);generation[id]=int(generation.get(id,0))+1;empty_clocks[id]=0.0

func bind_effect(effect:Node) -> void:
	if is_instance_valid(player):effect.set_meta("target_character",character_id(player))
func combat_players() -> Array:
	return players.values().filter(func(body):return body_live(body) and body.health>0)

func combat_target(at:Vector3) -> Node3D:return nearest(at)

func allow_boss_respawn(id:String) -> void:
	generation[id]=int(generation.get(id,0))+1
	pending_native_states.erase(id)
	defeated_enemies.erase(map_id+"/"+id)
	worldrise.states.erase(id)
	if id=="ashfang":
		worldrise.ashfang_respawn=0
		for aid in authored.values():
			if aid.get("parent_boss","")=="ashfang":
				generation[aid.id]=generation[id];defeated_enemies.erase(map_id+"/"+aid.id)
	if id=="vault_elder":current_world.encounter="waiting"
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and enemy.definition.id==id:retire_transient(enemy)

func character_id(body:Variant) -> String:
	if not is_instance_valid(body):return ""
	return String(body.get_meta("character_id",body.character_id if body is Proxy else body.get("entity_id")))

const NATIVE_STATE_FIELDS=["state","state_time","direction","knockback","phase","home","lunge_hit","half_called","engaged","circle_clock","leap_start","leap_target","attacks","attack_kind","duration","exposed","target_point","strikes","pursuit_time","turns","cooldown","jump_origin","jump_target","jump_clock","bounce_count","regen_clock","resin_dash_active","dash_target","pack_target","pack_speed","pack_engaged","encounter_engaged","encounter_attack_allowed","encounter_goal"]
# Controller fields are Variants: clocks may currently contain integer zero.
# Restore uses their persistent schema, never that temporary current value.
const NATIVE_STATE_TYPES={
	"state":TYPE_STRING,
	"state_time":TYPE_FLOAT,
	"direction":TYPE_VECTOR3,
	"knockback":TYPE_VECTOR3,
	"phase":TYPE_FLOAT,
	"home":TYPE_VECTOR3,
	"lunge_hit":TYPE_BOOL,
	"half_called":TYPE_BOOL,
	"engaged":TYPE_BOOL,
	"circle_clock":TYPE_FLOAT,
	"leap_start":TYPE_VECTOR3,
	"leap_target":TYPE_VECTOR3,
	"attacks":TYPE_INT,
	"attack_kind":TYPE_STRING,
	"duration":TYPE_FLOAT,
	"exposed":TYPE_FLOAT,
	"target_point":TYPE_VECTOR3,
	"strikes":TYPE_INT,
	"pursuit_time":TYPE_FLOAT,
	"turns":TYPE_INT,
	"cooldown":TYPE_FLOAT,
	"jump_origin":TYPE_VECTOR3,
	"jump_target":TYPE_VECTOR3,
	"jump_clock":TYPE_FLOAT,
	"bounce_count":TYPE_INT,
	"regen_clock":TYPE_FLOAT,
	"resin_dash_active":TYPE_BOOL,
	"dash_target":TYPE_VECTOR3,
	"pack_target":TYPE_VECTOR3,
	"pack_speed":TYPE_FLOAT,
	"pack_engaged":TYPE_BOOL,
	"encounter_engaged":TYPE_BOOL,
	"encounter_attack_allowed":TYPE_BOOL,
	"encounter_goal":TYPE_VECTOR3,
}
var pending_native_states:Dictionary={}
func capture_enemy_state(enemy:Node) -> Dictionary:
	var result={}
	var fields=enemy.get_meta("native_state_fields",[])
	if fields.is_empty():
		var available={}
		for property in enemy.get_property_list():available[property.name]=true
		for field in NATIVE_STATE_FIELDS:
			if available.has(field):fields.append(field)
		enemy.set_meta("native_state_fields",fields)
	for field in fields:
		var value=enemy.get(field)
		if value is Vector3:result[field]={"vector3":[value.x,value.y,value.z]}
		elif value is String or value is bool or value is int or value is float:result[field]=value
	result["target"]=character_id(enemy.player)
	return result
func queue_enemy_state(id:String,state:Dictionary) -> void:
	pending_native_states[id]=state.duplicate(true)
func restore_enemy_state(enemy:Node,state:Dictionary) -> void:
	var fields={}
	for property in enemy.get_property_list():fields[property.name]=true
	for field in NATIVE_STATE_FIELDS:
		if not state.has(field) or not fields.has(field):continue
		var value=state[field];var expected_type=NATIVE_STATE_TYPES[field]
		if expected_type==TYPE_VECTOR3:
			if not value is Dictionary or value.size()!=1 or not value.get("vector3") is Array:continue
			var at=value.vector3
			if at.size()!=3 or not at.all(func(component):return (component is float or component is int) and is_finite(float(component))):continue
			value=Vector3(float(at[0]),float(at[1]),float(at[2]))
		elif expected_type==TYPE_STRING:
			if not value is String or value.length()>64:continue
		elif expected_type==TYPE_BOOL:
			if not value is bool:continue
		elif expected_type==TYPE_FLOAT:
			if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value))>100000000:continue
			value=float(value)
		elif expected_type==TYPE_INT:
			if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value))>2147483647 or float(value)!=floorf(float(value)):continue
			value=int(value)
		else:continue
		enemy.set(field,value)
	var target_id=String(state.get("target",""))
	if players.has(target_id) and body_live(players[target_id]):enemy.player=players[target_id]
	elif enemy.state not in ["idle","patrol","circle","forming"]:enemy.state="recover";enemy.state_time=maxf(.45,enemy.state_time)
	if String(enemy.definition.id)=="vault_elder":
		enemy.collision_layer=0 if enemy.state=="forming" else 4;enemy.collision.set_deferred("disabled",enemy.state=="forming")
		enemy.present_network(0)

func valid_player_position(at:Vector3,additional_mask:int=0,exclude:Array[RID]=[]) -> bool:
	# Saved position validation uses the actual retained collision, including guild
	# furniture and raft rails. Interaction markers need not be standable points.
	if not at.is_finite() or absf(at.y)>256:return false
	if map_id=="wr_floor_01" and Vector2(at.x,at.z).length()>240.15 and is_nan(preload("res://scripts/west_islands.gd").support(at)):return false
	if map_id=="wr_floor_02" and Vector2(at.x,at.z).length()>239:return false
	if map_id=="wr_boss_chamber" and not current_world.supported(at):return false
	var capsule=CapsuleShape3D.new();capsule.radius=.23;capsule.height=1.12
	var query=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1|additional_mask;query.exclude=exclude;query.margin=.001;query.transform=Transform3D(Basis.IDENTITY,at+Vector3.UP*.575)
	return world_root.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func effect_records() -> Dictionary:
	var started=Time.get_ticks_usec() if profile_timings else 0
	var result={}
	for effect in world_root.get_children()+current_world.get_children():
		if not body_live(effect) or effect.get_script()==null:continue
		var kind=String(effect.get_script().resource_path).get_file().trim_suffix(".gd")
		if kind not in ["elder_stone","rock_projectile","resin_gloop","menagery_projectile","menagery_hazard","ashfang_impact"]:continue
		var id="native/"+map_id+"/"+str(effect.get_instance_id())
		var record={"id":id,"floor":map_id,"kind":kind,"position":[effect.global_position.x,effect.global_position.y,effect.global_position.z]}
		for field in ["direction","origin","landing","reflected","radius","sticky","age","life","lifetime","duration","height"]:
			var value=effect.get(field)
			if value is Vector3:record[field]=[value.x,value.y,value.z]
			elif value is bool or value is int or value is float:record[field]=value
		var source=effect.get("thrower") if kind in ["elder_stone","rock_projectile"] else effect.get("source")
		if body_live(source) and source.get("definition") is Dictionary:record.source=String(source.definition.get("id",""))
		result[id]=record
	if profile_timings:perf.effect_records_ms=(Time.get_ticks_usec()-started)/1000.0
	return result

func connect_enemy_damage(enemy:Node) -> void:
	if enemy.get_meta("authority_damage_connected",false):return
	enemy.set_meta("authority_damage_connected",true)
	enemy.damaged.connect(func(amount:int):enemy_damaged.emit(String(enemy.definition.id),amount,enemy.get_meta("last_damage_context",{}).duplicate(true)))
