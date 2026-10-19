extends RefCounted
## Lossless network checkpoint storage. Ordinary offline saves are unrelated.
const FORMAT=1
const ENCODING="godot-variant-no-objects-v1"
const CHARACTER_LIMIT=262144
const WORLD_LIMIT=67108864
static var last_encode_error=""
static var base64_pattern:RegEx
static func raw_limit(kind:String) -> int:
 return CHARACTER_LIMIT if kind=="character" else WORLD_LIMIT if kind=="world" else 0
static func text_limit(kind:String) -> int:
 return 2*ceili(float(raw_limit(kind))/3)*4+4096
static func hash_bytes(raw:PackedByteArray) -> String:
 var context=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(raw);return context.finish().hex_encode()
static func error(message:String) -> Dictionary:
 return {"ok":false,"error":message,"data":{}}
static func safe_value(value:Variant,depth:int=0) -> bool:
 if depth>32:return false
 if value==null or value is bool or value is int or value is String or value is StringName:return true
 if value is float:return is_finite(value)
 if value is Array:
  if value.size()>1000000:return false
  for item in value:
   if not safe_value(item,depth+1):return false
  return true
 if value is Dictionary:
  if value.size()>1000000:return false
  for key in value:
   if not (key is String or key is StringName) or not safe_value(value[key],depth+1):return false
  return true
 return false
static func unsafe_path(value:Variant,path:String="$",depth:int=0) -> String:
 if depth>32:return path+": depth exceeds 32"
 if value is Dictionary:
  for key in value:
   if not (key is String or key is StringName):return path+": dictionary key type "+type_string(typeof(key))
   if not safe_value(value[key],depth+1):return unsafe_path(value[key],path+"."+key,depth+1)
 elif value is Array:
  for index in value.size():
   if not safe_value(value[index],depth+1):return unsafe_path(value[index],path+"["+str(index)+"]",depth+1)
 return path+": unsupported "+type_string(typeof(value))
static func normalized_names(value:Variant) -> Variant:
 if value is StringName:return String(value)
 if value is Dictionary:
  var result={}
  for key in value:result[String(key)]=normalized_names(value[key])
  return result
 if value is Array:
  var result=[]
  for item in value:result.append(normalized_names(item))
  return result
 return value
static func encode(value:Dictionary,kind:String) -> String:
 var maximum=raw_limit(kind)
 last_encode_error=""
 if maximum==0:last_encode_error="Unknown checkpoint kind";return ""
 if not safe_value(value):last_encode_error=unsafe_path(value).left(512);return ""
 var raw=var_to_bytes(normalized_names(value)) # Object serialization is deliberately disabled.
 if raw.size()<8 or raw.size()>maximum:last_encode_error="Raw payload size "+str(raw.size())+" exceeds "+str(maximum);return ""
 return JSON.stringify({"world_rise_storage":FORMAT,"kind":kind,"encoding":ENCODING,"raw_size":raw.size(),"sha256":hash_bytes(raw),"payload":Marshalls.raw_to_base64(raw)})
static func decode(value:Variant,kind:String) -> Dictionary:
 if not value is Dictionary or not value.has("world_rise_storage"):return error("Unsupported legacy network checkpoint. Keep this file and request an explicit migration or compatible recovery; no data was replaced.")
 if value.size()!=6 or value.get("world_rise_storage")!=FORMAT or value.get("encoding")!=ENCODING or value.get("kind")!=kind:return error("Unsupported network checkpoint version or kind; no data was replaced")
 var maximum=raw_limit(kind);var count=value.get("raw_size")
 if maximum==0 or not (count is int or count is float) or not is_finite(float(count)) or count!=int(count) or count<8 or count>maximum:return error("Network checkpoint payload size is invalid")
 var payload=value.get("payload");var checksum=value.get("sha256")
 if not payload is String or payload.length()<12 or payload.length()>ceili(float(maximum)/3)*4 or payload.length()%4!=0:return error("Network checkpoint encoding exceeds its bound")
 if not checksum is String or checksum.length()!=64:return error("Network checkpoint checksum is invalid")
 for character in checksum:
  if character not in "0123456789abcdef":return error("Network checkpoint checksum is invalid")
 if base64_pattern==null:base64_pattern=RegEx.create_from_string("\\A[A-Za-z0-9+/]*={0,2}\\z")
 if base64_pattern.search(payload)==null:return error("Network checkpoint contains invalid base64")
 var raw=Marshalls.base64_to_raw(payload)
 if raw.size()!=int(count) or hash_bytes(raw)!=checksum:return error("Network checkpoint checksum or size does not match")
 if raw.decode_u32(0)!=TYPE_DICTIONARY:return error("Network checkpoint root is not a dictionary")
 var decoded=bytes_to_var(raw) # Never bytes_to_var_with_objects.
 if not decoded is Dictionary or not safe_value(decoded):return error("Network checkpoint payload cannot be decoded safely")
 return {"ok":true,"data":normalized_names(decoded),"error":""}
static func read_file(path:String,kind:String) -> Dictionary:
 var file=FileAccess.open(path,FileAccess.READ)
 if file==null:return error("Cannot read network checkpoint")
 var length=file.get_length()
 if length<2 or length>text_limit(kind):file.close();return error("Network checkpoint file exceeds its size bound")
 var text=file.get_as_text();file.close()
 var parser=JSON.new()
 if parser.parse(text)!=OK:return error("Network checkpoint JSON is invalid")
 return decode(parser.data,kind)
