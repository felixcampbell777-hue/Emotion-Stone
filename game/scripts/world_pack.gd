extends RefCounted
## Public offline world-file contract. Custom worlds never overwrite bundled maps.
static var directory="user://worlds"
const MAX_BYTES=4194304
static func valid_id(value:Variant) -> bool:
	if not value is String or value.length()>48: return false
	if value in ["con","prn","aux","nul"] or (value.length()==4 and value.substr(0,3) in ["com","lpt"] and value[3].is_valid_int()): return false
	var regex=RegEx.new(); regex.compile("^[a-z][a-z0-9_]*$")
	return regex.search(value)!=null
static func finite_number(value:Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
static func point(value:Variant) -> bool:
	return value is Array and value.size()==2 and value.all(func(n): return finite_number(n) and absf(n)<=100)
static func rect(value:Variant) -> bool:
	return value is Array and value.size()==4 and value.all(finite_number) and value[2]>0 and value[3]>0
static func bounds_rect(area:Dictionary) -> Rect2:
	var b=area.bounds; return Rect2(b[0],b[1],b[2]-b[0],b[3]-b[1])
static func catalog() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://content/menagery.json"))
static func error_at(message:String,area:String="") -> String:
	return (area+": " if not area.is_empty() else "")+message
static func validate(pack:Variant,allow_incomplete:bool=false) -> Array:
	var errors:Array=[]
	if not pack is Dictionary: return ["World file must contain an object."]
	if pack.get("format","")!="coastal_world" or pack.get("version",0)!=1: return ["Unsupported world format/version."]
	if not valid_id(pack.get("id")): errors.append("World ID must use lowercase letters, numbers and underscores.")
	if not pack.get("name") is String or pack.get("name","").strip_edges().is_empty(): errors.append("Give the world a name.")
	if not pack.get("maps") is Array or pack.maps.is_empty() or pack.maps.size()>32: return errors+["A world needs 1-32 areas."]
	var by_id={}; var features={}; var monsters={}
	for entry in catalog().features: features[entry.code]=entry
	for entry in catalog().monsters: monsters[entry.code]=entry
	for area in pack.maps:
		if not area is Dictionary: errors.append("Area must contain an object."); continue
		var id=area.get("id","")
		if not valid_id(id) or by_id.has(id): errors.append("Area IDs must be valid and unique."); continue
		by_id[id]=area
		for key in area:
			if key not in ["id","display_name","subtitle","seed","bounds","spawn","sea","cave","props","terrain_regions","exits","catalog_enemies","npcs","interactions","biome","sculpted_terrain"]: errors.append(error_at("Unsupported area field: "+key,id))
		if area.get("biome","woodland") not in ["woodland","jungle"]: errors.append(error_at("Unknown biome.",id))
		if not finite_number(area.get("seed",1)) or area.get("seed",1)<0 or area.get("seed",1)!=int(area.get("seed",1)): errors.append(error_at("Seed must be a nonnegative integer.",id))
		if not area.get("sea",false) is bool or not area.get("cave",false) is bool: errors.append(error_at("Sea/cave options must be true or false.",id))
		if not area.get("npcs",[]) is Array or not area.get("interactions",[]) is Array or not area.get("npcs",[]).is_empty() or not area.get("interactions",[]).is_empty(): errors.append(error_at("Story NPCs/dialogue are not supported in editable worlds.",id))
		if not area.get("display_name") is String or area.display_name.is_empty(): errors.append(error_at("Give the area a name.",id))
		var b=area.get("bounds")
		if not b is Array or b.size()!=4 or not b.all(func(n): return finite_number(n) and n==int(n) and absf(n)<=100) or b[2]<=b[0] or b[3]<=b[1] or b[2]-b[0]<12 or b[3]-b[1]<12:
			errors.append(error_at("Bounds need integer coordinates and at least 12m width/depth, within -100..100.",id)); continue
		if not point(area.get("spawn")) or not bounds_rect(area).grow(-.35).has_point(Vector2(area.spawn[0],area.spawn[1])): errors.append(error_at("Start position is outside the area.",id))
		if area.get("cave",false) and (b[0]!=-8 or b[1]!=-9 or b[2]!=8 or b[3]!=8): errors.append(error_at("The reusable cave room uses bounds -8,-9,8,8.",id))
		for field in ["props","terrain_regions","exits","catalog_enemies"]:
			if not area.get(field) is Array or area.get(field,[]).size()>256: errors.append(error_at(field+" must be a list with at most 256 entries.",id))
		if not errors.is_empty(): continue
		var sculpt=area.get("sculpted_terrain",[])
		if not sculpt is Array or sculpt.size()>64: errors.append(error_at("Terrain sculpt needs at most 64 patches.",id)); continue
		var terrain_ids={}
		for piece in sculpt:
			if not piece is Dictionary or not valid_id(piece.get("id")) or terrain_ids.has(piece.get("id")) or not point(piece.get("at")) or piece.get("profile") not in ["smooth","bluff","overhang"]: errors.append(error_at("Invalid terrain patch.",id)); continue
			terrain_ids[piece.id]=true
			if not finite_number(piece.get("radius")) or piece.radius<1 or piece.radius>16 or not finite_number(piece.get("height")) or piece.height< -6 or piece.height>10 or not finite_number(piece.get("rotation",0)): errors.append(error_at("Terrain height/radius/rotation is out of range.",id)); continue
			if area.get("cave",false): errors.append(error_at("Sculpting is supported in outdoor areas.",id))
			if piece.profile=="overhang" and piece.height<2.6: errors.append(error_at("Overhang height must be at least 2.6m.",id))
			var dimensions_valid=true
			for dimension in ["plateau_width","plateau_depth"]:
				if piece.has(dimension) and (not finite_number(piece[dimension]) or piece[dimension]<1): dimensions_valid=false
			if not dimensions_valid: errors.append(error_at("Plateau dimensions must be finite and at least 1m.",id)); continue
			if not load("res://scripts/sculpt_terrain.gd").fits(piece,bounds_rect(area)): errors.append(error_at("Terrain patch extends past the boundary.",id))
		var ids={}
		for prop in area.get("props",[]):
			if not prop is Dictionary or not valid_id(prop.get("id")) or ids.has(prop.get("id")) or prop.get("kind")!="catalog_feature" or not features.has(prop.get("catalog_code")) or not point(prop.get("at")):
				errors.append(error_at("Scenery needs a unique ID and a known catalog code/position.",id)); continue
			ids[prop.id]=true
			if not finite_number(prop.get("rotation",0)) or not finite_number(prop.get("scale",1)) or prop.get("scale",1)<.1 or prop.get("scale",1)>4: errors.append(error_at("Scenery rotation must be finite; scale must be 0.1-4.",id)); continue
			var at=Vector2(prop.at[0],prop.at[1])
			if not bounds_rect(area).has_point(at): errors.append(error_at("Scenery "+prop.id+" is outside the area.",id))
			if prop.catalog_code.ends_with("F"):
				var angle=deg_to_rad(float(prop.get("rotation",0))); var scale=float(prop.get("scale",1))
				for corner in [Vector2(-6,-5),Vector2(6,-5),Vector2(-6,5),Vector2(6,5)]:
					if not bounds_rect(area).grow(.01).has_point(at+corner.rotated(-angle)*scale): errors.append(error_at("Terrain "+prop.id+" extends past the boundary.",id)); break
		for mob in area.get("catalog_enemies",[]):
			if not mob is Dictionary or not valid_id(mob.get("id")) or ids.has(mob.get("id")) or not monsters.has(mob.get("code")) or not point(mob.get("at")): errors.append(error_at("Creature needs a unique ID and a known E code/position.",id)); continue
			ids[mob.id]=true
			if not mob.get("ambush_group","") is String or mob.get("ambush_group","").length()>48: errors.append(error_at("Ambush group must be short text.",id))
			if mob.get("spawn_mode","ground") not in ["ground","tree_drop"]: errors.append(error_at("Unknown creature spawn mode.",id))
			if mob.get("spawn_mode","ground")=="tree_drop" and monsters[mob.code].style not in ["green_slime","moss_slime","resin_slime","bramble_slime"]: errors.append(error_at("Only ordinary slimes can drop from trees.",id))
			for tuning in [["drop_height",2,8,3.8],["trigger_radius",2,12,6],["respawn_seconds",0,3600,0]]:
				var value=mob.get(tuning[0],tuning[3])
				if not finite_number(value) or value<tuning[1] or value>tuning[2]: errors.append(error_at("Ambush "+tuning[0]+" is out of range.",id))
			if not bounds_rect(area).grow(-.5).has_point(Vector2(mob.at[0],mob.at[1])): errors.append(error_at("Creature is outside the area.",id))
		for region in area.get("terrain_regions",[]):
			if not region is Dictionary or not rect(region.get("rect")) or region.get("kind") not in ["grass","path","sand","water","cobble"]: errors.append(error_at("Paint region is invalid.",id)); continue
			var r=region.rect
			if not bounds_rect(area).grow(.01).encloses(Rect2(r[0],r[1],r[2],r[3])): errors.append(error_at("Paint region extends outside the area.",id))
		for exit in area.get("exits",[]):
			if not exit is Dictionary or not valid_id(exit.get("id")) or ids.has(exit.get("id")) or not rect(exit.get("rect")) or not valid_id(exit.get("target")) or not point(exit.get("spawn")) or not exit.get("label") is String: errors.append(error_at("Transition needs a unique ID, rectangle, target, landing and label.",id)); continue
			ids[exit.id]=true
			var r=exit.rect
			if not bounds_rect(area).encloses(Rect2(r[0],r[1],r[2],r[3])): errors.append(error_at("Transition extends outside the boundary.",id))
	if not by_id.has(pack.get("start_map","")): errors.append("Choose an existing starting area.")
	if not errors.is_empty() or allow_incomplete: return errors
	for area in pack.maps:
		for exit in area.get("exits",[]):
			if not by_id.has(exit.target): errors.append(error_at("Transition points to a missing area: "+exit.target,area.id)); continue
			var landing=Vector2(exit.spawn[0],exit.spawn[1]); var target=by_id[exit.target]
			if not walkable(target,landing): errors.append(error_at("Transition landing is blocked or outside "+exit.target,area.id))
			for gate in target.exits:
				var r=gate.rect
				if not gate.get("interact",false) and Rect2(r[0],r[1],r[2],r[3]).grow(.35).has_point(landing): errors.append(error_at("Automatic transition landing overlaps another gate; move it away to prevent loops.",area.id))
		if not walkable(area,Vector2(area.spawn[0],area.spawn[1])): errors.append(error_at("Start position is blocked by water, scenery or a cliff edge.",area.id))
	# Every area must be reachable from the start through outgoing transitions.
	var visited={pack.start_map:true}; var pending=[pack.start_map]
	while not pending.is_empty():
		for exit in by_id[pending.pop_front()].exits:
			if by_id.has(exit.target) and not visited.has(exit.target): visited[exit.target]=true; pending.append(exit.target)
	for id in by_id:
		if not visited.has(id): errors.append("Area "+id+" cannot be reached from the starting area.")
	return errors
static func walkable(area:Dictionary,at:Vector2) -> bool:
	if not bounds_rect(area).grow(-.35).has_point(at): return false
	var model=load("res://scripts/world.gd").new(); model.definition=normalized(area); model.bounds=bounds_rect(area)
	var safe=model.safe_position(Vector3(at.x,0,at.y)); model.free()
	if not safe: return false
	for prop in area.props:
		var code=prop.catalog_code
		if code.ends_with("F") or code in ["1D","2D","3D","4D","5D","6D","3C","4C","5C","7C","8C","9C","7D"]: continue
		var p=(at-Vector2(prop.at[0],prop.at[1])).rotated(deg_to_rad(float(prop.get("rotation",0))))/float(prop.get("scale",1))
		var radius=.6 if code.ends_with("B") else .5
		if code in ["1G","2G","10C"]:
			if absf(p.x)>1.0 and absf(p.x)<2 and absf(p.y)<.8: return false
		elif code=="1C":
			if absf(p.x)<1.5 and absf(p.y)<.5: return false
		elif p.length()<radius+.23: return false
	return true
static func normalized(area:Dictionary) -> Dictionary:
	var result=area.duplicate(true)
	for key in ["props","terrain_regions","exits","catalog_enemies","npcs","interactions"]:
		if not result.has(key): result[key]=[]
	result["seed"]=int(result.get("seed",1)); result["sea"]=bool(result.get("sea",false)); result["subtitle"]=str(result.get("subtitle","Custom area"))
	return result
static func read_file(path:String) -> Dictionary:
	if not FileAccess.file_exists(path) or FileAccess.get_file_as_bytes(path).size()>MAX_BYTES: return {}
	var parser=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK or not validate(parser.data).is_empty(): return {}
	return parser.data
static func file_path(id:String) -> String:
	return directory.path_join(id+".coastworld.json") if valid_id(id) else ""
static func installed(id:String) -> Dictionary:
	return read_file(file_path(id))
static func install(pack:Dictionary) -> Error:
	if not validate(pack).is_empty(): return ERR_INVALID_DATA
	DirAccess.make_dir_recursive_absolute(directory)
	return write_file(file_path(pack.id),pack)
static func write_file(path:String,pack:Dictionary) -> Error:
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(pack,"	")); file.flush(); file.close()
	return DirAccess.rename_absolute(path+".tmp",path)
static func list_installed() -> Array:
	var result=[]
	if not DirAccess.dir_exists_absolute(directory): return result
	for name in DirAccess.get_files_at(directory):
		if not name.ends_with(".coastworld.json"): continue
		var pack=read_file(directory.path_join(name))
		if not pack.is_empty(): result.append(pack)
	result.sort_custom(func(a,b): return a.name.naturalnocasecmp_to(b.name)<0)
	return result
static func runtime_id(world:String,area:String) -> String:
	return "w_"+world+"_"+area
static func definition(id:String,world:String="") -> Dictionary:
	if world.is_empty():
		var path="res://content/maps/"+id+".json"
		return JSON.parse_string(FileAccess.get_file_as_string(path)) if valid_id(id) and FileAccess.file_exists(path) else {}
	var pack=installed(world)
	if pack.is_empty(): return {}
	for area in pack.maps:
		if runtime_id(world,area.id)!=id: continue
		var data=normalized(area); data.id=id
		for exit in data.exits: exit.target=runtime_id(world,exit.target)
		return data
	return {}
static func defeats(world:String) -> Array:
	var result=[]; var pack=installed(world)
	for area in pack.get("maps",[]):
		for mob in area.get("catalog_enemies",[]): result.append(runtime_id(world,area.id)+"/"+mob.id)
	return result
static func save_path(world:String) -> String:
	if world.is_empty(): return "user://save-v1.json"
	DirAccess.make_dir_recursive_absolute("user://world-saves")
	return "user://world-saves/"+world+".json"
