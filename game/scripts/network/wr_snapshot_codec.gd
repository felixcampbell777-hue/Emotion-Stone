extends RefCounted
## Versioned bounded snapshot bytes. No object deserialization is enabled.
const MAGIC=[87,82,90,1] # WRZ, codec format 1: sized Zstandard + payload digest.
const HEADER=40
const MAX_RAW=2097152
const MAX_PACKET=128*900
static func hash_bytes(value:PackedByteArray) -> PackedByteArray:
 var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(value);return hash.finish()
static func encode_raw(raw:PackedByteArray) -> PackedByteArray:
 if raw.size()<8 or raw.size()>MAX_RAW:return PackedByteArray()
 var compressed=raw.compress(FileAccess.COMPRESSION_ZSTD)
 if compressed.is_empty() or compressed.size()+HEADER>MAX_PACKET:return PackedByteArray()
 var packet=PackedByteArray(MAGIC);packet.resize(8);packet.encode_u32(4,raw.size());packet.append_array(hash_bytes(packet.slice(4,8)+compressed));packet.append_array(compressed)
 return packet
static func decode(packet:PackedByteArray) -> Dictionary:
 if packet.size()<=HEADER or packet.size()>MAX_PACKET:return {}
 if packet.slice(0,4)!=PackedByteArray(MAGIC):return {}
 var size=packet.decode_u32(4)
 if size<8 or size>MAX_RAW:return {}
 var compressed=packet.slice(HEADER)
 if hash_bytes(packet.slice(4,8)+compressed)!=packet.slice(8,HEADER):return {}
 # The exact size is bounded before allocation. Dynamic ZSTD decompression is
 # intentionally unused: Godot 4.5 supports dynamic only for DEFLATE and GZIP.
 var raw=compressed.decompress(size,FileAccess.COMPRESSION_ZSTD)
 if raw.size()!=size or raw.decode_u32(0)!=TYPE_DICTIONARY:return {}
 var value=bytes_to_var(raw) # Deliberately never bytes_to_var_with_objects.
 if not value is Dictionary:return {}
 for key in ["players","enemies","projectiles","native_effects","claims","voice_roster"]:
  if not value.get(key) is Dictionary:return {}
 if not value.get("events") is Array or not value.get("flags") is Array:return {}
 if not (value.get("tick") is int or value.get("tick") is float) or not is_finite(float(value.tick)) or value.tick<0 or value.tick!=int(value.tick):return {}
 if not (value.get("clock") is int or value.get("clock") is float) or not is_finite(float(value.clock)) or value.clock<0 or value.clock>=1080:return {}
 if not preload("res://scripts/network/wr_profile.gd").identifier(value.get("world_id")):return {}
 return value
