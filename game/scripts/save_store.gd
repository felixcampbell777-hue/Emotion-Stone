extends RefCounted
## Atomic, versioned save data. Verification uses a different filename from player saves.
const Progression=preload("res://scripts/progression.gd")
const WorldPacks=preload("res://scripts/world_pack.gd")
const SAVE_PATH = "user://save-v1.json"

static func write(data: Dictionary, path: String = SAVE_PATH) -> Error:
	var temporary = path+".tmp"
	var file = FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data,"\t"))
	file.flush()
	file.close()
	return DirAccess.rename_absolute(temporary,path)

static func read(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK:
		return {}
	var parsed=parser.data
	if not parsed is Dictionary:
		return {}
	if parsed.get("version")!=1 or not parsed.get("map") is String or not parsed.get("position") is Array:
		return {}
	var mode=parsed.get("game_mode","alpha")
	if not preload("res://scripts/alpha2_campaign.gd").valid_mode(mode,parsed.map,parsed.get("world_id","")): return {}
	if parsed.has("heavy_attack") and parsed.heavy_attack not in ["overhead","charge_thrust"]:
		return {}
	if parsed.get("camera_mode","follow") not in ["follow","overhead","first_person"]: return {}
	if parsed.get("environment_profile","original") not in ["original","darkwood"]: return {}
	if parsed.get("character_profile","game") not in ["game","standalone"]: return {}
	if parsed.has("environment_revision") and (not (parsed.environment_revision is int or parsed.environment_revision is float) or parsed.environment_revision!=1): return {}
	for field in ["camera_yaw","camera_pitch","camera_distance","first_person_pitch"]:
		if parsed.has(field) and (not (parsed[field] is int or parsed[field] is float) or not is_finite(float(parsed[field]))): return {}
	if parsed.has("camera_pitch") and (parsed.camera_pitch<.14 or parsed.camera_pitch>.96): return {}
	if parsed.has("first_person_pitch") and absf(parsed.first_person_pitch)>1.15: return {}
	if parsed.has("camera_distance") and (parsed.camera_distance<3 or parsed.camera_distance>8): return {}
	if parsed.has("home_layout") and (not (parsed.home_layout is int or parsed.home_layout is float) or int(parsed.home_layout) not in [1,2] or float(parsed.home_layout)!=int(parsed.home_layout)): return {}
	if parsed.has("ground_y") and (not WorldPacks.finite_number(parsed.ground_y) or parsed.ground_y< -6 or parsed.ground_y>(140 if mode=="world_rise" else 12)): return {}
	if mode=="world_rise" and not preload("res://scripts/world_rise.gd").valid(parsed.get("world_rise",{})):return {}
	var at = parsed.position
	if at.size()!=2:
		return {}
	for value in at:
		if not (value is float or value is int) or not is_finite(float(value)):
			return {}
	if not parsed.get("facing",0) is float and not parsed.get("facing",0) is int:
		return {}
	if not is_finite(float(parsed.get("facing",0))):
		return {}
	var width=parsed.get("resolution",640)
	if not (width is float or width is int):
		return {}
	if int(width) not in [0,320,640,960] or float(width)!=int(width):
		return {}
	var growth=parsed.get("progression",{"xp":0,"learned":[]})
	if mode!="world_rise" and growth.get("profile","")=="world_rise":return {}
	if not Progression.valid(growth):
		return {}
	var state=Progression.new()
	state.restore(growth)
	var loadout=parsed.get("skill_loadout",{})
	if not loadout is Dictionary: return {}
	for key in loadout:
		if key not in ["dash","jump","flowing_counter"] or not loadout[key] is bool or (key!="jump" and loadout[key] and not state.has(key)): return {}
	var equipment=parsed.get("magic_items",{})
	var magic=preload("res://scripts/magic_items.gd").new()
	if not magic.valid_save(equipment): return {}
	if not preload("res://scripts/monster_cores.gd").valid_save(parsed.get("monster_cores",{}),str(parsed.get("world_id",""))): return {}
	magic.restore(equipment)
	var maximum=int(JSON.parse_string(FileAccess.get_file_as_string("res://content/combat.json")).max_health)+int(state.bonus("health"))+roundi(magic.bonus("health"))
	if growth.get("tree_version",1)==1 and "steady_heart" in growth.get("learned",[]):
		maximum+=15
	var health=parsed.get("health",maximum)
	if state.world_rise:maximum=roundi(maximum*(1+.01*(state.level()-1)))
	if not (health is int or health is float) or float(health)!=int(health) or health<1 or health>maximum:
		return {}
	var max_stamina=float(JSON.parse_string(FileAccess.get_file_as_string("res://content/combat.json")).max_stamina)+state.bonus("stamina")
	if state.world_rise:max_stamina*=1+.01*(state.level()-1)
	if growth.get("tree_version",1)==1 and "deep_breath" in growth.get("learned",[]):
		max_stamina+=15
	var stamina=parsed.get("stamina",max_stamina)
	if not (stamina is int or stamina is float) or not is_finite(float(stamina)) or stamina<0 or stamina>max_stamina:
		return {}
	for key in ["sword_drawn","sword_equipped","mother_unwrapped","home_intro_complete"]:
		if parsed.has(key) and not parsed[key] is bool:
			return {}
	if parsed.has("special_attack") and (not parsed.special_attack is String or parsed.special_attack not in ["water_sweep","water_lance","sea_dragon","undertow"]):
		return {}
	var world=parsed.get("world_id","")
	if not world is String or (not world.is_empty() and not WorldPacks.valid_id(world)): return {}
	if WorldPacks.definition(parsed.map,world).is_empty() or "/" in parsed.map or ".." in parsed.map:
		return {}
	if not parsed.get("quest_stage","not_started") is String:
		return {}
	if parsed.get("quest_stage","")=="herbs_ready":
		parsed.quest_stage="component_ready"
	if parsed.get("quest_stage","not_started") not in ["not_started","active","component_ready","completed"]:
		return {}
	if parsed.get("well_gift_stage","not_started") not in ["not_started","coin_ready","potion_owned"]:
		return {}
	var defeated=parsed.get("defeated_enemies",[])
	if not defeated is Array or defeated.size()>(512 if mode=="world_rise" else 128):
		return {}
	var allowed_story=["slime_forest/forest_slime","herb_glade/briar_boar","herb_glade/thorn_wisp","herb_glade/briar_boar_second","herb_glade/stone_warden"]
	if mode=="world_rise":allowed_story.append("wr_floor_01/ashfang")
	for map_name in ["wr_floor_01","wr_floor_02","wr_boss_chamber","jungle_approach","queen_arena","beta_meadow"]+JSON.parse_string(FileAccess.get_file_as_string("res://content/alpha2.json")).maps:
		var area=WorldPacks.definition(map_name)
		for mob in area.get("catalog_enemies",[]): allowed_story.append(map_name+"/"+mob.id)
		for mob in area.get("enemies",[]):
			allowed_story.append(map_name+"/"+mob.id)
			if map_name in ["wr_floor_01","wr_floor_02"]:allowed_story.append(map_name+"/"+mob.id+"_night")
	for map_name in ["goblin_approach","goblin_cave","goblin_depths"]:
		for mob in WorldPacks.definition(map_name).get("enemies",[]): allowed_story.append(map_name+"/"+mob.id)
	if not preload("res://scripts/goblin_campaign.gd").valid_save(parsed.get("goblin_campaign",{}),defeated): return {}
	if not preload("res://scripts/alpha2_campaign.gd").valid_save(parsed.get("alpha2",{}),defeated): return {}
	var seen=[]
	for id in defeated:
		if not id is String or id not in allowed_story or id in seen:
			return {}
		seen.append(id)
	if "herb_glade/thorn_wisp" in defeated:
		defeated.erase("herb_glade/thorn_wisp")
		if not "herb_glade/briar_boar_second" in defeated:
			defeated.append("herb_glade/briar_boar_second")
	if parsed.get("quest_stage","") in ["component_ready","completed"] and not "herb_glade/stone_warden" in defeated:
		return {}
	var custom=parsed.get("world_defeats",[])
	if not custom is Array or custom.size()>512: return {}
	var allowed=WorldPacks.defeats(world) if not world.is_empty() else []
	var custom_seen=[]
	for id in custom:
		if not id is String or id not in allowed or id in custom_seen: return {}
		custom_seen.append(id)
	var timers=parsed.get("respawn_timers",{})
	if not timers is Dictionary or timers.size()>512: return {}
	for key in timers:
		if not key is String or "/" not in key: return {}
		var split=key.rfind("/")
		var area=WorldPacks.definition(key.left(split),world)
		if area.is_empty(): return {}
		var matches=area.get("catalog_enemies",[]).filter(func(mob): return mob.id==key.substr(split+1))
		if matches.is_empty() or matches[0].get("respawn_seconds",0)<=0: return {}
		var remaining=timers[key]
		if not WorldPacks.finite_number(remaining) or remaining<=0 or remaining>matches[0].respawn_seconds: return {}
	return parsed
