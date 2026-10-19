extends SceneTree
const Codec=preload("res://scripts/network/wr_storage_codec.gd")
var checks=0
var failures:Array=[]
func check(value:bool,label:String) -> void:
 checks+=1
 if not value:failures.append(label)
func parsed(text:String) -> Variant:
 var parser=JSON.new();parser.parse(text);return parser.data
func _init() -> void:
 var samples:Array=[.44999999999999996,.45000000000000007,1.0/60,63.12345678901234]
 var stamina=0.0;var cooldown=60.0;var healing=0.0
 for i in 3601:
  samples.append(stamina);samples.append(cooldown);samples.append(healing)
  stamina+=26.0/60;cooldown=maxf(0,cooldown-1.0/60);healing+=1.0/60
 var random=RandomNumberGenerator.new();random.seed=918273
 for i in 30000:samples.append(random.randf_range(0,100000))
 var names={};names[StringName("target")]=StringName("friend")
 var normalized=Codec.decode(parsed(Codec.encode(names,"world")),"world")
 check(normalized.ok and typeof(normalized.data.keys()[0])==TYPE_STRING and typeof(normalized.data.target)==TYPE_STRING,"legitimate StringName keys/values normalize without data loss")
 var original={"samples":samples,"nested":{"float":.0166666666666666664,"integer":42}}
 var envelope=parsed(Codec.encode(original,"world"));var decoded=Codec.decode(envelope,"world")
 check(decoded.ok and var_to_bytes(decoded.data)==var_to_bytes(original),"all %d trajectory/boundary/random doubles retain exact bits"%samples.size())
 check(not Codec.decode(envelope,"character").ok,"wrong checkpoint kind rejected")
 var corrupt=envelope.duplicate(true);corrupt.world_rise_storage=2;check(not Codec.decode(corrupt,"world").ok,"unknown version rejected")
 corrupt=envelope.duplicate(true);corrupt.encoding="unsafe";check(not Codec.decode(corrupt,"world").ok,"unknown encoding rejected")
 corrupt=envelope.duplicate(true);corrupt.raw_size=Codec.WORLD_LIMIT+1;check(not Codec.decode(corrupt,"world").ok,"oversize raw declaration rejected before allocation")
 corrupt=envelope.duplicate(true);corrupt.raw_size+=1;check(not Codec.decode(corrupt,"world").ok,"wrong bounded size rejected")
 corrupt=envelope.duplicate(true);corrupt.sha256="0".repeat(64);check(not Codec.decode(corrupt,"world").ok,"corrupt checksum rejected")
 corrupt=envelope.duplicate(true);corrupt.payload="@".repeat(12);check(not Codec.decode(corrupt,"world").ok,"invalid base64 rejected before decode")
 var small=parsed(Codec.encode({"value":1.0/60},"character"));corrupt=small.duplicate(true);corrupt.payload="A".repeat(ceili(float(Codec.CHARACTER_LIMIT)/3)*4+4)
 check(not Codec.decode(corrupt,"character").ok,"oversize base64 rejected before allocation")
 check(not Codec.decode({"schema":1},"world").ok,"legacy plain JSON rejected explicitly")
 check(Codec.encode({"invalid":NAN},"world").is_empty(),"nonfinite data cannot be written")
 var object=Node.new();check(Codec.encode({"invalid":object},"world").is_empty(),"objects cannot enter checkpoint encoding");object.free()
 var path="user://oversize-character.json";var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(" ".repeat(Codec.text_limit("character")+1));file.close()
 check(not Codec.read_file(path,"character").ok,"oversize file rejected before text parsing")
 var wrong_root=var_to_bytes([1,2,3]);var wrong={"world_rise_storage":1,"kind":"world","encoding":Codec.ENCODING,"raw_size":wrong_root.size(),"sha256":Codec.hash_bytes(wrong_root),"payload":Marshalls.raw_to_base64(wrong_root)}
 check(not Codec.decode(wrong,"world").ok,"valid checksum cannot admit non-dictionary root")
 print("WR_STORAGE_CODEC_CHECKS ",JSON.stringify({"checks":checks,"float_samples":samples.size(),"failures":failures}))
 quit(0 if failures.is_empty() else 1)
