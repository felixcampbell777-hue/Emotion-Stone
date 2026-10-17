extends RefCounted
const Shape=preload("res://scripts/rise_shape.gd")
const Props=preload("res://scripts/props.gd")
const Guild=preload("res://scripts/rise_guild.gd")
var guild=Guild.new()
var game:Node
var states:Dictionary={}
var flags:Array=[]
var checkpoint:Array=[0,0]
var packs:Dictionary={}
var clock=0.0
var elapsed=0.0
var day_clock=0.0
var elder_respawn=0.0
var light_clock=0.0
var night_population=false
func is_night() -> bool:return day_clock>=600 and day_clock<1080
const ELDER_ID="wr_boss_chamber/vault_elder"
func active() -> bool:return game.game_mode=="world_rise" and game.map_id=="wr_floor_01"
func reset() -> void:states.clear();flags.clear();checkpoint=[0,0];packs.clear();clock=0;elapsed=0;day_clock=0;elder_respawn=0;light_clock=0;guild.reset()
static func valid(data:Variant) -> bool:
	if not data is Dictionary:return false
	for key in ["day_clock","elder_respawn"]:
		var value=data.get(key,0)
		if not (value is float or value is int) or not is_finite(float(value)) or value<0 or value>1080:return false
	if not Guild.valid(data.get("economy",{})):return false
	var cp=data.get("checkpoint",[0,0]);var marks=data.get("flags",[]);var records=data.get("states",{})
	if not cp is Array or cp.size()!=2 or not marks is Array or marks.size()>8 or not records is Dictionary or records.size()>160:return false
	for v in cp:
		if not (v is float or v is int) or not is_finite(float(v)):return false
	if not Shape.safe(Vector3(cp[0],0,cp[1])):return false
	var ids=JSON.parse_string(FileAccess.get_file_as_string("res://content/maps/wr_floor_01.json")).enemies.map(func(e):return e.id)
	for base in ids.duplicate():ids.append(base+"_night")
	for key in records:
		if key not in ids or not records[key] is Dictionary:return false
		var e=records[key];var pos=e.get("at",[]);var hp=e.get("health",-1)
		if not (hp is float or hp is int) or not is_finite(float(hp)) or hp<0 or hp>200 or not pos is Array or pos.size()!=2:return false
		for v in pos:
			if not (v is float or v is int) or not is_finite(float(v)) or absf(v)>240:return false
	var seen=[]
	for flag in marks:
		if flag not in ["rim_watch","hollow_tree","elder_defeated"] or flag in seen:return false
		seen.append(flag)
	return true
func snapshot() -> Dictionary:
	if active():remember_all()
	return {"states":states.duplicate(true),"flags":flags.duplicate(),"checkpoint":checkpoint.duplicate(),"economy":guild.snapshot(),"day_clock":day_clock,"elder_respawn":elder_respawn}
func restore(data:Dictionary) -> void:
	states=data.get("states",{}).duplicate(true);flags=data.get("flags",[]).duplicate();checkpoint=data.get("checkpoint",[0,0]).duplicate();guild.restore(data.get("economy",{}));day_clock=fposmod(float(data.get("day_clock",0)),1080);elder_respawn=float(data.get("elder_respawn",1080 if ELDER_ID in game.defeated_enemies else 0))
	if ELDER_ID in game.defeated_enemies and "elder_defeated" not in flags:flags.append("elder_defeated")
func elder_fell() -> void:
	if "elder_defeated" not in flags:flags.append("elder_defeated")
	elder_respawn=1080
	game.hud_feedback.boss_victory()
static func daylight(at:float) -> float:
	at=fposmod(at,1080)
	if at<45:return smoothstep(-45,45,at)
	if at<555:return 1.0
	if at<645:return 1.0-smoothstep(555,645,at)
	if at<1035:return 0.0
	return smoothstep(1035,1125,at)
func cycle_lighting() -> void:
	if not active():return
	var blend=daylight(day_clock);var env=game.environment_settings
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("#718ab0").lerp(Color("#d9e5ef"),blend)
	env.ambient_light_energy=lerpf(.24,.5,blend);env.fog_light_color=Color("#172b48").lerp(Color("#c5dbdb"),blend)
	var sun=game.world_root.get_node("WorldSun");sun.light_energy=lerpf(.045,1.2,blend);sun.light_color=Color("#7899d6").lerp(Color("#fff2dc"),blend);sun.rotation_degrees=Vector3(-35-15*cos(day_clock/1080*TAU),-30+25*sin(day_clock/1080*TAU),0)
	var backdrop=game.current_world.get_node_or_null("WorldRiseBackdropRing")
	if backdrop!=null:
		for mesh in backdrop.find_children("*","MeshInstance3D",true,false):
			if mesh.material_override is ShaderMaterial:mesh.material_override.set_shader_parameter("daylight",blend)
	if env.sky!=null and env.sky.sky_material is ProceduralSkyMaterial:
		var sky=env.sky.sky_material;sky.sky_top_color=Color("#030a20").lerp(Color("#4f91c5"),blend);sky.sky_horizon_color=Color("#182941").lerp(Color("#dce9e6"),blend);sky.ground_bottom_color=Color("#081224").lerp(Color("#fff0c9"),blend);sky.ground_horizon_color=sky.sky_horizon_color
func remember_all() -> void:
	for enemy in game.enemies:
		if String(enemy.definition.id).begins_with("boars_") or String(enemy.definition.id).begins_with("wolves_"):remember(enemy)
func remember(enemy:Node3D) -> void:
	var pos=[enemy.position.x,enemy.position.z]
	if Vector2(pos[0],pos[1]).length()>239:pos=enemy.definition.at.duplicate()
	states[enemy.definition.id]={"health":enemy.health,"at":pos}
func lighting() -> void:
	if game.game_mode!="world_rise":return
	if game.map_id=="wr_boss_chamber":game.current_world.lighting(game);return
	game.environment_settings.ambient_light_source=Environment.AMBIENT_SOURCE_BG
	game.camera.far=6500;var env=game.environment_settings;env.fog_enabled=true;env.fog_density=.0006;env.fog_sky_affect=.08;env.fog_light_color=Color("#c5dbdb");env.volumetric_fog_enabled=false;env.ambient_light_energy=.5;env.tonemap_exposure=1.0;env.background_mode=Environment.BG_SKY
	var sky=Sky.new();var mat=ProceduralSkyMaterial.new();mat.sky_top_color=Color("#4f91c5");mat.sky_horizon_color=Color("#dce9e6");mat.ground_bottom_color=Color("#fff0c9");mat.ground_horizon_color=Color("#dce9e6");sky.sky_material=mat;env.sky=sky
	var sun=game.world_root.get_node("WorldSun");sun.light_energy=1.2;sun.rotation_degrees=Vector3(-42,-30,0);sun.directional_shadow_max_distance=90
	cycle_lighting()
func build_map() -> void:
	packs.clear();clock=0
	night_population=is_night()
	if game.game_mode=="world_rise" and game.map_id=="wr_boss_chamber":game.current_world.activate(game);lighting();return
	if not active():return
	lighting()
	for p in Shape.spec.packs:packs[p.id]={"spec":p,"active":false,"members":[],"engaged":false,"attack":0.0,"cursor":0}
	var hub={"id":"arrival","at":[0,8],"title":"Arrival Platform · Rest","type":"rest"}
	for entry in [hub]+Shape.spec.landmarks:
		var at=Vector3(entry.at[0],0,entry.at[1]);at.y=game.current_world.ground_height(at)
		var node=Node3D.new();game.current_world.add_child(node);node.position=at
		if entry.type=="rest":
			Props.box(node,Vector3(0,.4,0),Vector3(1.3,.8,1.3),"#697a72");var crystal=Props.cone(node,Vector3(0,1.1,0),.3,.9,"#74d4db",.06);var material=Props.mat("#74d4db");material.emission_enabled=true;material.emission=Color("#74d4db");crystal.material_override=material
		elif entry.type=="cache":
			Props.box(node,Vector3(0,.35,0),Vector3(1.5,.7,.9),"#674d37");Props.box(node,Vector3(0,.75,0),Vector3(1.6,.15,1.0),"#8d784f")
		elif entry.type=="gate":
			for x in [-5,5]:Props.box(node,Vector3(x,5,0),Vector3(2,10,2),"#8a9b92");Props.collider(node,Vector3(x,5,0),Vector3(2,10,2))
			Props.box(node,Vector3(0,10,0),Vector3(12,2,2),"#a2afa4")
		game.current_world.interactions.append({"id":entry.id,"wr_action":entry,"title":entry.title,"position":at,"actor":null,"lines":[]})
	# Long, readable aqueduct silhouette near the northern route.
	for i in range(7):
		var at=Vector3(45+i*8,0,-150);at.y=game.current_world.ground_height(at);Props.box(game.current_world,at+Vector3.UP*4,Vector3(1.4,8,1.8),"#959e87");Props.box(game.current_world,at+Vector3(3.5,8,0),Vector3(8,1,2.4),"#a0a88e");Props.collider(game.current_world,at+Vector3.UP*4,Vector3(1.4,8,1.8))
	game.current_world.update_details(game.player.position)
	guild.game=game;guild.build()
	preload("res://scripts/rise_chamber.gd").build_entrance(game.current_world)
	update_packs()
func spawn_pack(record:Dictionary) -> void:
	record.active=true;record.members=[]
	var entries=game.current_world.definition.enemies.filter(func(e):return e.pack==record.spec.id)
	if is_night():
		for base in entries.duplicate():entries.append(night_entry(base))
	for entry in entries:
		spawn_member(record,entry)
	game.wolf_packs.build(game)
func night_entry(base:Dictionary) -> Dictionary:
	var entry=base.duplicate(true);entry.id+="_night"
	for i in range(12):
		var angle=i*TAU/12;var at=Vector2(base.at[0]+sin(angle)*2,base.at[1]+cos(angle)*2)
		if Shape.safe(Vector3(at.x,0,at.y)):entry.at=[at.x,at.y];break
	return entry
func spawn_member(record:Dictionary,entry:Dictionary) -> void:
	var p=record.spec;var key="wr_floor_01/"+entry.id
	if key in game.defeated_enemies or record.members.any(func(e):return is_instance_valid(e) and e.definition.id==entry.id):return
	var saved=states.get(entry.id,{})
	var enemy=load("res://scripts/beta_enemy.gd").new() if p.kind=="beta_wolf" else load("res://scripts/library_enemy.gd").new()
	enemy.name=entry.id;enemy.configure(entry.duplicate(true),game.player,saved);enemy.game=game
	if p.kind=="library_boar":enemy.spec=enemy.spec.duplicate(true);enemy.spec.damage=9+int(p.tier)*4;enemy.spec.range=5.5;enemy.spec.windup=.8;enemy.spec.lunge_seconds=.8;enemy.spec.recovery=1.1;enemy.max_health=65+int(p.tier)*25;enemy.health=int(saved.get("health",enemy.max_health));enemy.encounter_owned=true
	if p.kind=="beta_wolf":enemy.tuning.windup=.7;enemy.tuning.recovery=1.0
	game.world_root.add_child(enemy);game.enemies.append(enemy);record.members.append(enemy)
	var pos=saved.get("at",entry.at);enemy.position=Vector3(pos[0],0,pos[1]);enemy.position.y=game.current_world.ground_height(enemy.position);enemy.home=Vector3(p.at[0],game.current_world.ground_height(Vector3(p.at[0],0,p.at[1])),p.at[1])
	enemy.defeated.connect(func():game._enemy_defeated(key,p.kind,enemy));game.add_enemy_bar(enemy)
func refresh_population() -> void:
	if not active():return
	night_population=is_night()
	for record in packs.values():
		if not record.active:continue
		if night_population:
			for base in game.current_world.definition.enemies.filter(func(e):return e.pack==record.spec.id):spawn_member(record,night_entry(base))
		else:
			for enemy in record.members.duplicate():
				if String(enemy.definition.id).ends_with("_night"):remember(enemy);record.members.erase(enemy);game.retire_transient(enemy)
	game.wolf_packs.build(game)
func update_packs() -> void:
	var remote=game.sea_dragon if is_instance_valid(game.sea_dragon) and game.sea_dragon.active else null
	for record in packs.values():
		var home=Vector3(record.spec.at[0],0,record.spec.at[1]);var distance=Vector2(game.player.position.x-home.x,game.player.position.z-home.z).length()
		if remote!=null:distance=minf(distance,Vector2(remote.global_position.x-home.x,remote.global_position.z-home.z).length())
		if distance<85 and not record.active:spawn_pack(record);return
		if distance>145 and record.active and not record.engaged and game.projectiles.is_empty():
			for enemy in record.members:
				remember(enemy);game.retire_transient(enemy)
			record.members=[];record.active=false;game.wolf_packs.build(game)
func tick(delta:float) -> void:
	if game.game_mode!="world_rise" or not game.player.input_enabled:return
	day_clock=fposmod(day_clock+delta,1080);light_clock+=delta
	if light_clock>=.1:light_clock=0;cycle_lighting()
	if elder_respawn>0:
		elder_respawn=maxf(0,elder_respawn-delta)
		if elder_respawn<=0:
			game.defeated_enemies.erase(ELDER_ID)
			if game.map_id=="wr_boss_chamber" and game.current_world.encounter=="cleared":game.current_world.encounter="waiting"
			game.notify("The Elder has returned to the Veiled Vault.")
	if not active():return
	if night_population!=is_night():refresh_population()
	clock+=delta;elapsed+=delta
	if clock>=.12:clock=0;game.current_world.update_details(game.player.position);update_packs()
	for record in packs.values():
		if not record.active or record.spec.kind!="library_boar":continue
		var center=Vector3(record.spec.at[0],0,record.spec.at[1]);var distance=Vector2(game.player.position.x-center.x,game.player.position.z-center.z).length()
		var members=record.members.filter(func(e):return is_instance_valid(e) and e.health>0 and e.ai_enabled and e.simulation_enabled)
		if members.is_empty():continue
		if (distance<20 and members.any(func(e):return can_see(e))) or (distance<42 and members.any(func(e):return e.health<e.max_health)):record.engaged=true
		if distance>42:record.engaged=false
		record.attack=maxf(0,record.attack-delta)
		var busy=members.any(func(e):return e.state in ["windup","lunge"])
		# Consume the turn only after an animal actually enters its attack.
		# Permission remains available across physics frames until then.
		if busy:
			record.attack=.75
			for i in range(members.size()):
				if members[i].state in ["windup","lunge"]:record.cursor=(i+1)%members.size()
		var chosen=null
		if record.engaged and not busy and record.attack<=0:
			for offset in range(members.size()):
				var e=members[(int(record.cursor)+offset)%members.size()]
				if e.state=="idle" and Vector2(e.position.x-game.player.position.x,e.position.z-game.player.position.z).length()<float(e.spec.range) and can_see(e):chosen=e;break
		for i in range(members.size()):
			var e=members[i];var angle=elapsed*.2+i*TAU/members.size();e.encounter_engaged=record.engaged;e.encounter_attack_allowed=e==chosen
			e.encounter_speed=1.5 if record.engaged else 1.0
			e.encounter_goal=game.player.position+Vector3(sin(angle),0,cos(angle))*2.6 if record.engaged else center+Vector3(sin(angle),0,cos(angle))*3.0
func can_see(enemy:Node3D) -> bool:
	return not game.impact_blocked(enemy.position+Vector3.UP*.6,game.player.position+Vector3.UP*.6)

func respawn_reset() -> void:
	states.clear()
	game.defeated_enemies=game.defeated_enemies.filter(func(id):return not String(id).begins_with("wr_floor_01/"))
func interact(target:Dictionary) -> bool:
	if game.game_mode=="world_rise" and target.has("wr_chamber"):
		var chamber=preload("res://scripts/rise_chamber.gd")
		if target.wr_chamber=="enter":
			remember_all()
			game.load_map("wr_boss_chamber",Vector2(0,36),true);game.camera_driver.yaw=0
		else:
			if game.map_id=="wr_boss_chamber" and game.current_world.combat_locked():return true
			game.load_map("wr_floor_01",chamber.return_point(),true);game.camera_driver.yaw=chamber.ENTRANCE_YAW
		game.camera_driver.first_pitch=0;game.camera_driver.update_first_person();return true
	if target.has("beast_loot"):guild.collect(target.beast_loot);return true
	if not active() or not target.has("wr_action"):return false
	var entry=target.wr_action
	if entry.type=="rest":
		if game.enemies.any(func(e):return e.health>0 and e.position.distance_to(game.player.position)<12):game.notify("Clear nearby enemies before resting.");return true
		checkpoint=entry.at.duplicate();respawn_reset();game.load_map("wr_floor_01",Vector2(checkpoint[0],checkpoint[1]),true);game.player.restore_health(game.player.max_health);game.player.restore_stamina(game.player.max_stamina);game.notify("Rested. Valley herds and wolf packs return.")
	elif entry.type=="view":game.notify("The Silver Verge overlooks the sunny abyss." if entry.id=="rim_watch" else "An old hollow tree marks this quiet forest clearing.")
	else:game.notify("The ascent gate is dormant. Floor Two is not available yet.")
	return true
func journal(ui:Node) -> void:
	ui.add_quest("The Verdant Reach","Exploration + combat XP","Explore from the central arrival platform.","Boar herds occupy the valleys. Elderwood lies northwest; follow its clear paths to avoid encirclement. The eastern silver rim overlooks the abyss. Rest crystals set your respawn and restore regular packs.")
	ui.add_quest("The Adventurers' Guild","Sell spoils · craft equipment","Follow the trail southeast, opposite Elderwood.","Copper is credited on kills; pick up material sacks from fallen boars and wolves. Sell at the front desk; craft hide armor or the Cruel Charm with Bram at the back. The sword merchant's shop opens later. 100 copper = 1 gold.")
	for id in Guild.catalog.contracts:
		var entry=Guild.catalog.contracts[id];var state=guild.contracts.get(id,{"active":false,"count":0})
		ui.add_quest(entry.name,"%d copper + %d XP"%[entry.reward,guild.contract_xp(id)],"Complete · reward collected." if state.get("completed",false) else "%d/10 defeated · return to the front desk"%state.count if state.active else "Accept at the guild front desk.","One-time contract. Only kills after acceptance count; ordinary packs return when you rest.")
