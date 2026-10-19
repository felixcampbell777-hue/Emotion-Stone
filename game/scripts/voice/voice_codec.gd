class_name WorldRiseVoiceCodec
extends RefCounted
## TwoVoIP 3.10 is used only on the main thread. Godot owns capture/playback.
const RATE := 48000
const FRAMES := 960
const MAX_PACKET := 400
var encoder: Object

static func available() -> bool:
	return ClassDB.class_exists("AudioEffectOpusChunked") and ClassDB.class_exists("AudioStreamOpusChunked")

static func configured_native(native_class: String) -> Object:
	if not ClassDB.class_exists(native_class):
		return null
	var result: Object = ClassDB.instantiate(native_class)
	result.set("audiosamplerate", RATE)
	result.set("audiosamplesize", FRAMES)
	result.set("opussamplerate", RATE)
	result.set("opusframesize", FRAMES)
	result.set("audiosamplechunks", 8)
	return result

func _init() -> void:
	if available():
		encoder = configured_native("AudioEffectOpusChunked")
		encoder.set("opusbitrate", 24000)

func encode(pcm: PackedVector2Array) -> PackedByteArray:
	if encoder == null or pcm.size() != FRAMES:
		return PackedByteArray()
	encoder.call("push_chunk", pcm)
	var packet: PackedByteArray = encoder.call("read_opus_packet", PackedByteArray())
	encoder.call("drop_chunk")
	return packet if valid_packet(packet) else PackedByteArray()

static func valid_packet(packet: PackedByteArray) -> bool:
	# Only one 20 ms Opus frame, no packet aggregation. Bound work before native decode.
	if packet.size() < 2 or packet.size() > MAX_PACKET or (packet[0] & 3) != 0:
		return false
	var config := packet[0] >> 3
	return (config >= 16 and (config & 3) == 3) or (config < 12 and (config & 3) == 1) or (config >= 12 and config < 16 and (config & 1) == 1)

static func decode(decoder: Object, packet: PackedByteArray) -> PackedVector2Array:
	if decoder == null or not valid_packet(packet):
		return PackedVector2Array()
	decoder.call("push_opus_packet", packet, 0, 0)
	var pcm: PackedVector2Array = decoder.call("pop_front_chunk", FRAMES)
	return pcm
