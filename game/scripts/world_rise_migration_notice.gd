extends RefCounted
## Local presentation preference only; never changes signed progression/checkpoints.
const PATH="user://world-rise-migration-notices.cfg"
const MAX_ONLINE=128
static func valid_key(key:String) -> bool:
	if key=="offline":return true
	if not key.begins_with("online:") or key.length()!=39:return false
	for ch in key.substr(7):
		if ch not in "0123456789abcdef":return false
	return true
static func receipt_hash(receipt:Dictionary) -> String:
	return JSON.stringify(receipt,"",true,true).sha256_text()
static func key_for(game:Node) -> String:
	if game.online_session_active() and game.wr_session!=null:
		var id=String(game.wr_session.local_profile.get("character_id",""))
		if valid_key("online:"+id):return "online:"+id
	return "offline"
static func entries(path:String) -> Dictionary:
	var config=ConfigFile.new()
	if config.load(path)!=OK:return {}
	var saved=config.get_value("notices","acknowledged",{})
	if not saved is Dictionary or saved.size()>MAX_ONLINE+1:return {}
	for key in saved:
		if not key is String or not valid_key(key) or not saved[key] is String or saved[key].length()!=64:return {}
		for ch in saved[key]:
			if ch not in "0123456789abcdef":return {}
	return saved.duplicate()
static func acknowledged(key:String,receipt:Dictionary,path:String=PATH) -> bool:
	return valid_key(key) and not receipt.is_empty() and entries(path).get(key,"")==receipt_hash(receipt)
static func remember(key:String,receipt:Dictionary,path:String=PATH) -> bool:
	if not valid_key(key) or receipt.is_empty():return false
	var saved=entries(path)
	# Insertion order gives a bounded most-recently-dismissed list without storing clocks.
	saved.erase(key);saved[key]=receipt_hash(receipt)
	var online_count=saved.size()-(1 if saved.has("offline") else 0)
	while online_count>MAX_ONLINE:
		for old_key in saved:
			if old_key!="offline":saved.erase(old_key);online_count-=1;break
	var config=ConfigFile.new();config.set_value("notices","acknowledged",saved)
	if config.save(path+".tmp")!=OK:return false
	return DirAccess.rename_absolute(path+".tmp",path)==OK
