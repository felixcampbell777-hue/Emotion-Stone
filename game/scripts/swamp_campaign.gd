extends RefCounted
const Fen=preload("res://scripts/swamp_shape.gd")
var game:Node
var states:Dictionary={}
var unlocked:Array=["arrival"]
var checkpoint:Array=Fen.spec.arrival.duplicate()
var clock=0.0
var live:Dictionary={}
var queue:Array=[]
var last_night=false
const STATS={"giant_green_slime":[128,36,0],"green_slime":[45,8,18],"resin_slime":[100,16,18]}
static func all_entries() -> Array:
	var entries=[]
	for base in Fen.spec.enemies:
		entries.append(base)
		if base.style!="giant_green_slime":continue
		for i in range(4):
			var child=base.duplicate(true);child.id=base.id+"_split_"+str(i);child.style="green_slime";child.parent_id=base.id;child.at=[base.at[0]+sin(i*TAU/4+.4)*1.8,base.at[1]+cos(i*TAU/4+.4)*1.8];entries.append(child)
	return entries
static func legacy_ids() -> Array:
	return Fen.spec.get("legacy_enemy_ids",[])
func active() -> bool:return game!=null and game.game_mode=="world_rise" and game.map_id=="wr_floor_02"
func reset() -> void:states.clear();unlocked=["arrival"];checkpoint=Fen.spec.arrival.duplicate();live.clear();queue.clear();clock=0
static func valid(data:Variant) -> bool:
	if not data is Dictionary:return false
	var marks=data.get("unlocked",["arrival"]);var cp=data.get("checkpoint",Fen.spec.arrival);var records=data.get("states",{})
	if not marks is Array or marks.size()>Fen.spec.sites.size() or not cp is Array or cp.size()!=2 or not records is Dictionary or records.size()>240:return false
	var ids=Fen.spec.sites.map(func(s):return s.id);var seen=[]
	for id in marks:
		if not id is String or id not in ids or id in seen:return false
		seen.append(id)
	if "arrival" not in marks:return false
	for v in cp:
		if not (v is int or v is float) or not is_finite(float(v)):return false
	if not Fen.dry(Vector3(cp[0],0,cp[1])):return false
	var enemies=all_entries().map(func(e):return e.id)+legacy_ids()
	for key in records:
		if not key is String or key.trim_suffix("_night") not in enemies or not records[key] is Dictionary:return false
		var e=records[key];var at=e.get("at",[]);var hp=e.get("health",-1)
		if not at is Array or at.size()!=2 or not (hp is int or hp is float) or not is_finite(float(hp)) or hp<0 or hp>210:return false
		for v in at:
			if not (v is int or v is float) or not is_finite(float(v)) or absf(v)>240:return false
	return true
func snapshot() -> Dictionary:
	if active():
		for enemy in live.values():
			if is_instance_valid(enemy):states[enemy.definition.id]={"health":enemy.health,"at":[enemy.position.x,enemy.position.z]}
	return {"states":states.duplicate(true),"unlocked":unlocked.duplicate(),"checkpoint":checkpoint.duplicate()}
func restore(data:Dictionary) -> void:
	states=data.get("states",{}).duplicate(true);unlocked=data.get("unlocked",["arrival"]).duplicate();checkpoint=data.get("checkpoint",Fen.spec.arrival).duplicate();live.clear();queue.clear()
	for id in states.keys():
		if String(id).trim_suffix("_night") in legacy_ids():states.erase(id)
func build() -> void:
	live.clear();queue.clear();clock=0;last_night=game.worldrise.is_night();lighting()
	game.worldrise.guild.game=game;game.worldrise.guild.build();stream()
func entry_for(base:Dictionary,_night:bool) -> Dictionary:return base.duplicate(true)
func available(entry:Dictionary) -> bool:
	return not entry.has("parent_id") or "wr_floor_02/"+entry.parent_id in game.defeated_enemies
func stream() -> void:
	for e in all_entries():
		if not available(e):continue
		var distance=Vector2(game.player.position.x-e.at[0],game.player.position.z-e.at[1]).length()
		if distance<50 and not live.has(e.id) and "wr_floor_02/"+e.id not in game.defeated_enemies and not queue.any(func(q):return q.id==e.id):queue.append(e)
	for id in live.keys():
		var enemy=live[id]
		if not is_instance_valid(enemy):live.erase(id);continue
		if enemy.health<=0 or enemy.position.distance_squared_to(game.player.position)>8100:
			states[id]={"health":enemy.health,"at":[enemy.position.x,enemy.position.z]};live.erase(id);game.retire_transient(enemy)
func fell(entry:Dictionary,enemy:Node3D) -> void:
	game._enemy_defeated("wr_floor_02/"+entry.id,entry.style,enemy)
	states[entry.id]={"health":0,"at":[enemy.position.x,enemy.position.z]}
	if entry.style!="giant_green_slime":return
	# Fixed child IDs prevent duplicate XP/loot, including after save/load or travel.
	for child in all_entries().filter(func(e):return e.get("parent_id","")==entry.id):
		var i=int(String(child.id).get_slice("_split_",1));var at=enemy.position+Vector3(sin(i*TAU/4+.4),0,cos(i*TAU/4+.4))*1.8
		at=game.current_world.safe_landing(at);states[child.id]={"health":45,"at":[at.x,at.z]}
		queue.append(child)
func spawn(entry:Dictionary) -> void:
	if Vector2(entry.at[0]-game.player.position.x,entry.at[1]-game.player.position.z).length()>70:return
	if not available(entry) or live.has(entry.id) or "wr_floor_02/"+entry.id in game.defeated_enemies:return
	var source_style="green_slime" if entry.style=="giant_green_slime" else entry.style
	var specimen=game.menagery.catalog.monsters.filter(func(e):return e.style==source_style)[0].duplicate(true)
	var stats=STATS[entry.style];specimen.health=stats[0];specimen.damage=stats[1];specimen.windup=maxf(float(specimen.windup),.75)
	if entry.style=="giant_green_slime":specimen.style=entry.style;specimen.size="large";specimen.speed=1.25
	elif entry.style=="green_slime":specimen.attack_speed=7.0;specimen.speed=2.5
	var enemy=load("res://scripts/giant_green_slime.gd" if entry.style=="giant_green_slime" else "res://scripts/swamp_slime.gd").new();game.world_root.add_child(enemy)
	var saved=states.get(entry.id,{});var pos=saved.get("at",entry.at);enemy.setup(game,specimen,Vector3(pos[0],0,pos[1]));enemy.definition.id=entry.id;enemy.definition.kind=entry.style;enemy.definition.display_name="Giant Green Slime" if entry.style=="giant_green_slime" else "Sticky Slime" if entry.style=="resin_slime" else "Green Slime";enemy.max_health=int(stats[0]);enemy.health=int(saved.get("health",stats[0]));enemy.home=Vector3(entry.at[0],game.current_world.ground_height(Vector3(entry.at[0],0,entry.at[1])),entry.at[1])
	game.EnvironmentArt.creature_quality(enemy,game.environment_profile);game.enemies.append(enemy);game.add_enemy_bar(enemy);live[entry.id]=enemy
	enemy.defeated.connect(func():fell(entry,enemy))
func tick(delta:float) -> void:
	if not active():return
	game.current_world.animate_water(delta)
	if game.worldrise.checkpoints.tick(delta):return
	if not queue.is_empty():spawn(queue.pop_front())
	clock+=delta
	if clock>=.15:clock=0;game.current_world.update_details(game.player.position);stream()
func respawn_reset() -> void:
	states.clear();queue.clear()
	for enemy in live.values():
		if is_instance_valid(enemy):game.retire_transient(enemy)
	live.clear()
	game.defeated_enemies=game.defeated_enemies.filter(func(id):return not String(id).begins_with("wr_floor_02/"))
func unlocked_floor_two() -> bool:return "elder_defeated" in game.worldrise.flags
func at_platform() -> bool:
	var at=Fen.arrival() if active() else Vector2.ZERO
	return (game.worldrise.active() or active()) and Vector2(game.player.position.x-at.x,game.player.position.z-at.y).length()<=6
func travel_floor(number:int) -> bool:
	var cp=game.worldrise.checkpoints
	if not at_platform() or not cp.block_reason().is_empty():game.notify("Use the arrival platform when no enemies are pursuing you.");return false
	if number==2 and not unlocked_floor_two():game.notify("Defeat the Elder to unlock Floor Two.");return false
	if (number==2)==active():return false
	game.worldrise.snapshot();var yaw=game.camera_driver.yaw;game.inventory.close()
	var at=Fen.arrival() if number==2 else Vector2.ZERO
	game.load_map("wr_floor_02" if number==2 else "wr_floor_01",at)
	cp.armed=false;cp.hold=0;game.camera_driver.yaw=yaw;game.camera_driver.first_pitch=0;game.camera_driver.update_first_person()
	# Floor travel is an explicit checkpoint transition: resume on the last floor visited.
	var saved=game.Save.write(game.save_data(),game.current_save_path())==OK
	game.notify("Floor %d reached. Progress saved."%number if saved else "Floor reached; could not save. Use Save in the pause menu.")
	return true
func lighting() -> void:
	if not active():return
	var blend=game.worldrise.daylight(game.worldrise.day_clock);var env=game.environment_settings
	env.background_mode=Environment.BG_SKY
	if env.sky==null or not env.sky.sky_material is ProceduralSkyMaterial:
		env.sky=Sky.new();env.sky.sky_material=ProceduralSkyMaterial.new()
	var sky=env.sky.sky_material;sky.sky_top_color=Color("#667d72");sky.sky_horizon_color=Color("#899480");sky.ground_bottom_color=Color("#d9d9ad");sky.ground_horizon_color=sky.sky_horizon_color
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("#77967f");env.ambient_light_energy=lerpf(.38,.68,blend)
	env.fog_enabled=true;env.fog_height_density=0;env.fog_density=.055;env.fog_sky_affect=.94;env.fog_light_color=Color("#52685d").lerp(Color("#91a28c"),blend);env.volumetric_fog_enabled=false;env.tonemap_exposure=1.0
	game.current_world.deep_fog_material.set_shader_parameter("fog_colour",Color("#203c2d").lerp(Color("#64785b"),blend))
	var sun=game.world_root.get_node("WorldSun");sun.light_energy=lerpf(.12,.65,blend);sun.light_color=Color("#dde8c9");sun.rotation_degrees=Vector3(-52,-25,0);sun.directional_shadow_max_distance=48;game.camera.far=6500
