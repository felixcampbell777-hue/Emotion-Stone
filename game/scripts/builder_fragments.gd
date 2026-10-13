extends RefCounted
const Packs=preload("res://scripts/world_pack.gd")
static var directory="user://world-fragments"
static func create(source:Dictionary,title:String) -> Dictionary:
	var section=source.duplicate(true)
	section.id="fragment"; section.display_name=title.strip_edges(); section.exits=[]; section.npcs=[]; section.interactions=[]
	return {"format":"coastal_fragment","version":1,"name":title.strip_edges(),"area":section}
static func document(fragment:Dictionary) -> Dictionary:
	return {"format":"coastal_world","version":1,"id":"fragment_world","name":fragment.name,"start_map":"fragment","maps":[fragment.area.duplicate(true)]}
static func validate(fragment:Variant) -> Array:
	if not fragment is Dictionary or fragment.get("format")!="coastal_fragment" or fragment.get("version")!=1 or not fragment.get("name") is String or fragment.name.strip_edges().is_empty() or fragment.name.length()>80 or not fragment.get("area") is Dictionary: return ["Not a valid named Coastal fragment."]
	if fragment.area.get("id")!="fragment" or not fragment.area.get("exits",[]).is_empty(): return ["Fragments cannot contain links to external areas."]
	return Packs.validate(document(fragment),true)
static func entries() -> Array:
	var result=[]
	DirAccess.make_dir_recursive_absolute(directory)
	for file in DirAccess.get_files_at(directory):
		if not file.ends_with(".coastfragment.json"): continue
		var path=directory.path_join(file)
		var data=read(path)
		if not data.is_empty(): result.append({"path":path,"data":data})
	result.sort_custom(func(a,b): return a.data.name.naturalnocasecmp_to(b.data.name)<0)
	return result
static func read(path:String) -> Dictionary:
	if not FileAccess.file_exists(path) or FileAccess.get_file_as_bytes(path).size()>Packs.MAX_BYTES: return {}
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if validate(data).is_empty() else {}
static func save(fragment:Dictionary,path:String="") -> Dictionary:
	var errors=validate(fragment)
	if not errors.is_empty(): return {"error":" / ".join(errors.slice(0,3))}
	DirAccess.make_dir_recursive_absolute(directory)
	if path.is_empty(): path=directory.path_join("fragment_"+str(Time.get_ticks_usec())+".coastfragment.json")
	var code=Packs.write_file(path,fragment)
	return {"path":path} if code==OK else {"error":error_string(code)}
static func stamp(source:Dictionary,target:Dictionary,anchor:Vector2,prefix:String) -> Dictionary:
	if source.get("cave",false) or target.get("cave",false): return {"error":"Cave room templates open as areas; outdoor fragments can be stamped on outdoor terrain."}
	var copy=target.duplicate(true)
	var b=Packs.bounds_rect(source); var offset=anchor-b.get_center()
	for field in ["props","terrain_regions","catalog_enemies","sculpted_terrain"]:
		if not copy.has(field): copy[field]=[]
		for original in source.get(field,[]):
			var item=original.duplicate(true)
			if item.has("id"): item.id=prefix+"_"+field.left(4)+"_"+str(copy[field].size())
			if item.has("at"): item.at=[item.at[0]+offset.x,item.at[1]+offset.y]
			if item.has("rect"): item.rect[0]+=offset.x; item.rect[1]+=offset.y
			if not str(item.get("ambush_group","")).is_empty(): item.ambush_group=prefix+"_"+str(item.ambush_group).left(16)
			copy[field].append(item)
	var errors=Packs.validate({"format":"coastal_world","version":1,"id":"stamp_check","name":"Stamp","start_map":copy.id,"maps":[copy]},true)
	return {"area":copy} if errors.is_empty() else {"error":"Fragment does not fit here: "+" / ".join(errors.slice(0,2))}

static func rename(path:String,title:String) -> Dictionary:
	var fragment=read(path)
	if fragment.is_empty(): return {"error":"Cannot rename an unreadable fragment."}
	fragment.name=title.strip_edges(); fragment.area.display_name=fragment.name
	return save(fragment,path)
