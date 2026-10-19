extends RefCounted
## The same allowlisted value object is used by the editor, saves and sessions.
const CATALOG_PATH="res://content/world_rise/appearance.json"
const COLOR_KEYS=["skin","hair","eyes","cloth","leather"]

static func catalog() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))

static func default_profile() -> Dictionary:
	return {"appearance_version":1,"catalog_version":2,"base_id":"wr_heroine","face_id":"default","hair_id":"chestnut_layers","skin_id":"default_freckled","body_id":"default","colors":{"skin":"#FFFFFF","hair":"#FFFFFF","eyes":"#FFFFFF","cloth":"#FFFFFF","leather":"#FFFFFF"},"morphs":{}}

static func valid(value:Variant) -> bool:
	if not value is Dictionary:return false
	var defaults=default_profile()
	if value.size()!=defaults.size():return false
	for key in value:
		if not defaults.has(key):return false
	for key in ["appearance_version","catalog_version"]:
		if not (value[key] is int or value[key] is float) or not is_finite(float(value[key])):return false
	if value.appearance_version!=1 or (value.catalog_version!=1 and value.catalog_version!=2):return false
	for key in ["base_id","face_id","hair_id","skin_id","body_id"]:
		if not value[key] is String:return false
	if value.base_id!="wr_heroine" or value.skin_id!="default_freckled":return false
	if value.face_id not in ["default","soft_cheeks"] or value.hair_id not in ["chestnut_layers","short_layers"] or value.body_id not in ["default","subtle_shape"]:return false
	if value.catalog_version==1 and (value.face_id!="default" or value.hair_id!="chestnut_layers" or value.body_id!="default"):return false
	if not value.colors is Dictionary or value.colors.size()!=COLOR_KEYS.size():return false
	for key in COLOR_KEYS:
		if not value.colors.has(key) or not value.colors[key] is String:return false
		var color:String=value.colors[key]
		if color.length()!=7 or not color.begins_with("#"):return false
		for digit in color.substr(1).to_upper():
			if not digit in "0123456789ABCDEF":return false
	# Geometry uses reviewed preset IDs; arbitrary numeric target combinations are rejected.
	return value.morphs is Dictionary and value.morphs.is_empty()

static func normalized(value:Variant) -> Dictionary:
	if not valid(value):return {}
	var result:Dictionary=value.duplicate(true)
	result.appearance_version=1;result.catalog_version=2
	for key in COLOR_KEYS:result.colors[key]=String(result.colors[key]).to_upper()
	return result

static func snapshot(value:Variant) -> Dictionary:
	return normalized(value)

static func revision_key(value:Variant) -> String:
	var result=normalized(value)
	if result.is_empty():return "invalid"
	var key="1:2:wr_heroine:"+result.face_id+":"+result.hair_id+":default_freckled:"+result.body_id
	for channel in COLOR_KEYS:key+=":"+result.colors[channel]
	return key
