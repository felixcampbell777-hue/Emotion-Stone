extends RefCounted
## Atomic, versioned save data. Verification uses a different filename from player saves.
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
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	if parsed.get("version")!=1 or not parsed.get("map") is String or not parsed.get("position") is Array:
		return {}
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
	if int(width) not in [320,640] or float(width)!=int(width):
		return {}
	if not FileAccess.file_exists("res://content/maps/"+parsed.map+".json") or "/" in parsed.map or ".." in parsed.map:
		return {}
	return parsed
