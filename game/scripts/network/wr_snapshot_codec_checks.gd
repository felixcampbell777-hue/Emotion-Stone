extends SceneTree
const Codec=preload("res://scripts/network/wr_snapshot_codec.gd")
var failures:Array=[]
var checks=0
func check(value:bool,label:String) -> void:
 checks+=1
 if not value:failures.append(label)
func _init() -> void:
 var snapshot={"tick":123,"clock":25.5,"world_id":"0123456789abcdef0123456789abcdef","players":{},"enemies":{},"projectiles":{},"native_effects":{},"claims":{},"voice_roster":{},"events":[],"flags":[]}
 var packet=Codec.encode_raw(var_to_bytes(snapshot))
 check(Codec.decode(packet)==snapshot,"sized ZSTD snapshot exact roundtrip")
 for size in [0,1,39,40]:check(Codec.decode(packet.slice(0,size)).is_empty(),"truncated header %d"%size)
 var corrupt=packet.duplicate();corrupt[0]^=1;check(Codec.decode(corrupt).is_empty(),"unsupported codec/version rejected")
 corrupt=packet.duplicate();corrupt[-1]^=1;check(Codec.decode(corrupt).is_empty(),"corrupt compressed bytes rejected before decompression")
 corrupt=packet.duplicate();corrupt.encode_u32(4,Codec.MAX_RAW+1);check(Codec.decode(corrupt).is_empty(),"oversized allocation rejected")
 corrupt=packet.duplicate();corrupt.resize(Codec.MAX_PACKET+1);check(Codec.decode(corrupt).is_empty(),"oversized wire packet rejected")
 check(Codec.decode(Codec.encode_raw(var_to_bytes("not a snapshot"))).is_empty(),"non dictionary payload rejected")
 corrupt=packet.duplicate();corrupt.encode_u32(4,packet.decode_u32(4)+1);check(Codec.decode(corrupt).is_empty(),"corrupt bounded declared size rejected before decompression")
 var object_bytes=PackedByteArray();object_bytes.resize(8);object_bytes.encode_u32(0,TYPE_OBJECT)
 check(Codec.decode(Codec.encode_raw(object_bytes)).is_empty(),"object payload rejected without deserialization")
 var invalid=snapshot.duplicate(true);invalid.players=[];check(Codec.decode(Codec.encode_raw(var_to_bytes(invalid))).is_empty(),"invalid snapshot schema rejected")
 invalid=snapshot.duplicate(true);invalid.clock=NAN;check(Codec.decode(Codec.encode_raw(var_to_bytes(invalid))).is_empty(),"nonfinite snapshot rejected")
 check(Codec.encode_raw(PackedByteArray()).is_empty(),"empty serialization rejected")
 var huge=PackedByteArray();huge.resize(Codec.MAX_RAW+1);check(Codec.encode_raw(huge).is_empty(),"oversized raw encoding rejected")
 print("WR_SNAPSHOT_CODEC_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
