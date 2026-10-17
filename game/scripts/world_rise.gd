extends RefCounted
const Shape=preload("res://scripts/rise_shape.gd")
const Props=preload("res://scripts/props.gd")
var game:Node
var states:Dictionary={}
var flags:Array=[]
var checkpoint:Array=[0,0]
var packs:Dictionary={}
var clock=0.0
var elapsed=0.0
func active() -> bool:return game.game_mode=="world_rise" and game.map_id=="wr_floor_01"
func reset() -> void:states.clear();flags.clear();checkpoint=[0,0];packs.clear();clock=0;elapsed=0
static func valid(data:Variant) -> bool:
	if not data is Dictionary:return false
	var cp=data.get("checkpoint",[0,0]);var marks=data.get("flags",[]);var records=data.get("states",{})
	if not cp is Array or cp.size()!=2 or not marks is Array or marks.size()>8 or not records is Dictionary or records.size()>80:return false
	for v in cp:
		if not (v is float or v is int) or not is_finite(float(v)):return false
	if not Shape.safe(Vector3(cp[0],0,cp[1])):return false
	var ids=JSON.parse_string(FileAccess.get_file_as_string("res://content/maps/wr_floor_01.json")).enemies.map(func(e):return e.id)
	for key in records:
		if key not in ids or not records[key] is Dictionary:return false
		var e=records[key];var pos=e.get("at",[]);var hp=e.get("health",-1)
		if not (hp is float or hp is int) or not is_finite(float(hp)) or hp<0 or hp>200 or not pos is Array or pos.size()!=2:return false
		for v in pos:
			if not (v is float or v is int) or not is_finite(float(v)) or absf(v)>240:return false
	var seen=[]
	for flag in marks:
		if flag not in ["rim_watch","hollow_tree"] or flag in seen:return false
		seen.append(flag)
	return true
func snapshot() -> Dictionary:
	if active():remember_all()
	return {"states":states.duplicate(true),"flags":flags.duplicate(),"checkpoint":checkpoint.duplicate()}
func restore(data:Dictionary) -> void:states=data.get("states",{}).duplicate(true);flags=data.get("flags",[]).duplicate();checkpoint=data.get("checkpoint",[0,0]).duplicate()
func remember_all() -> void:
	for enemy in game.enemies:
		if String(enemy.definition.id).begins_with("boars_") or String(enemy.definition.id).begins_with("wolves_"):remember(enemy)
func remember(enemy:Node3D) -> void:
	var pos=[enemy.position.x,enemy.position.z]
	if Vector2(pos[0],pos[1]).length()>239:pos=enemy.definition.at.duplicate()
	states[enemy.definition.id]={"health":enemy.health,"at":pos}
func lighting() -> void:
	if game.game_mode!="world_rise":return
	game.camera.far=6500;var env=game.environment_settings;env.fog_enabled=true;env.fog_density=.0006;env.fog_sky_affect=.08;env.fog_light_color=Color("#c5dbdb");env.volumetric_fog_enabled=false;env.ambient_light_energy=.5;env.tonemap_exposure=1.0;env.background_mode=Environment.BG_SKY
	var sky=Sky.new();var mat=ProceduralSkyMaterial.new();mat.sky_top_color=Color("#4f91c5");mat.sky_horizon_color=Color("#dce9e6");mat.ground_bottom_color=Color("#fff0c9");mat.ground_horizon_color=Color("#dce9e6");sky.sky_material=mat;env.sky=sky
	var sun=game.world_root.get_node("WorldSun");sun.light_energy=1.2;sun.rotation_degrees=Vector3(-42,-30,0);sun.directional_shadow_max_distance=90
func build_map() -> void:
	packs.clear();clock=0
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
	update_packs()
func spawn_pack(record:Dictionary) -> void:
	record.active=true;record.members=[]
	var p=record.spec;var entries=game.current_world.definition.enemies.filter(func(e):return e.pack==p.id)
	for entry in entries:
		var key="wr_floor_01/"+entry.id
		if key in game.defeated_enemies:continue
		var saved=states.get(entry.id,{})
		var enemy=load("res://scripts/beta_enemy.gd").new() if p.kind=="beta_wolf" else load("res://scripts/library_enemy.gd").new()
		enemy.name=entry.id;enemy.configure(entry.duplicate(true),game.player,saved);enemy.game=game
		if p.kind=="library_boar":enemy.spec=enemy.spec.duplicate(true);enemy.spec.damage=9+int(p.tier)*4;enemy.max_health=65+int(p.tier)*25;enemy.health=int(saved.get("health",enemy.max_health));enemy.encounter_owned=true
		game.world_root.add_child(enemy);game.enemies.append(enemy);record.members.append(enemy)
		var pos=saved.get("at",entry.at);enemy.position=Vector3(pos[0],0,pos[1]);enemy.position.y=game.current_world.ground_height(enemy.position);enemy.home=Vector3(p.at[0],game.current_world.ground_height(Vector3(p.at[0],0,p.at[1])),p.at[1])
		enemy.defeated.connect(func():game._enemy_defeated(key,p.kind,enemy));game.add_enemy_bar(enemy)
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
	if not active() or not game.player.input_enabled:return
	clock+=delta;elapsed+=delta
	if clock>=.12:clock=0;game.current_world.update_details(game.player.position);update_packs()
	for record in packs.values():
		if not record.active or record.spec.kind!="library_boar":continue
		var center=Vector3(record.spec.at[0],0,record.spec.at[1]);var distance=Vector2(game.player.position.x-center.x,game.player.position.z-center.z).length()
		var members=record.members.filter(func(e):return is_instance_valid(e) and e.health>0)
		if members.is_empty():continue
		if (distance<17 and members.any(func(e):return not game.impact_blocked(e.position,game.player.position))) or (distance<36 and members.any(func(e):return e.health<e.max_health)):record.engaged=true
		if distance>36:record.engaged=false
		record.attack=maxf(0,record.attack-delta)
		var busy=members.any(func(e):return e.state in ["windup","lunge"])
		for i in range(members.size()):
			var e=members[i];var angle=elapsed*.2+i*TAU/members.size();e.encounter_engaged=record.engaged;e.encounter_attack_allowed=false
			e.encounter_goal=game.player.position+Vector3(sin(angle),0,cos(angle))*3.8 if record.engaged else center+Vector3(sin(angle),0,cos(angle))*3.0
			if record.engaged and not busy and record.attack<=0 and i==int(record.cursor)%members.size():e.encounter_attack_allowed=true;record.attack=1.8;record.cursor+=1
func respawn_reset() -> void:
	states.clear()
	game.defeated_enemies=game.defeated_enemies.filter(func(id):return not String(id).begins_with("wr_floor_01/"))
func interact(target:Dictionary) -> bool:
	if not active() or not target.has("wr_action"):return false
	var entry=target.wr_action
	if entry.type=="rest":
		if game.enemies.any(func(e):return e.health>0 and e.position.distance_to(game.player.position)<12):game.notify("Clear nearby enemies before resting.");return true
		checkpoint=entry.at.duplicate();respawn_reset();game.load_map("wr_floor_01",Vector2(checkpoint[0],checkpoint[1]),true);game.player.restore_health(game.player.max_health);game.player.restore_stamina(game.player.max_stamina);game.notify("Rested. Valley herds and wolf packs return.")
	elif entry.type=="cache":
		if entry.id in flags:game.notify("This cache is empty.");return true
		flags.append(entry.id);game.alpha2.grant("windstep" if entry.id=="rim_watch" else "spring_elixir",1 if entry.id=="rim_watch" else 3);game.gain_xp(100);game.notify("Treasure recovered · +100 XP. Open Inventory to inspect it.")
	else:game.notify("The ascent gate is dormant. Floor Two is not available yet.")
	return true
func journal(ui:Node) -> void:
	ui.add_quest("The Verdant Reach","Exploration + combat XP","Explore from the central arrival platform.","Boar herds occupy the valleys. Elderwood lies northwest; follow its clear paths to avoid encirclement. The eastern silver rim overlooks the abyss. Rest crystals set your respawn and restore regular packs.")
	ui.add_quest("Hidden treasures","Magic equipment and remedies","%d/2 caches discovered"%flags.size(),"Search the eastern rim lookout and a hollow clearing deep in Elderwood. Levels and skills are earned fresh in World Rise.")
