extends SceneTree
const Codec = preload("res://scripts/voice/voice_codec.gd")
const Relay = preload("res://scripts/voice/voice_relay.gd")
const Voice = preload("res://scripts/voice/world_rise_voice.gd")
func _init() -> void:
	if not _check(Codec.available(), "Native codec not loaded"): return
	if not _check(Codec.configured_native("UnavailableVoiceCodec") == null): return
	var codec := Codec.new()
	var pcm := PackedVector2Array()
	for frame in Codec.FRAMES:
		var sample := 0.15 * sin(float(frame) / Codec.RATE * TAU * 440.0)
		pcm.append(Vector2(sample, sample))
	var packet: PackedByteArray = codec.encode(pcm)
	if not _check(Codec.valid_packet(packet), "Encoding failed"): return
	var decoder: Object = Codec.configured_native("AudioStreamOpusChunked")
	var decoded: PackedVector2Array = Codec.decode(decoder, packet)
	if not _check(decoded.size() == Codec.FRAMES, "Decode frame count"): return
	var energy := 0.0
	for sample: Vector2 in decoded:
		if not _check(sample.is_finite()): return
		energy += sample.length_squared()
	if not _check(energy > 0.001, "Decoded audio must carry signal"): return
	var relay := Relay.new()
	relay.set_peer(1, Vector3.ZERO, "one")
	relay.set_peer(2, Vector3(10, 0, 0), "one")
	relay.set_peer(3, Vector3.ZERO, "two")
	if not _check(relay.recipients(1, "proximity", 0, packet, 0) == [2]): return
	if not _check(relay.recipients(1, "group", 1, packet, 0) == [2, 3]): return
	if not _check(relay.recipients(1, "group", 1, packet, 0).is_empty()): return
	if not _check(relay.recipients(99, "group", 1, packet, 0).is_empty()): return
	if not _check(relay.recipients(1, "invalid", 2, packet, 0).is_empty()): return
	if not _check(not Codec.valid_packet(PackedByteArray([255, 1]))): return
	for sequence in range(2, 60):
		relay.recipients(1, "group", sequence, packet, 0)
	if not _check(relay.recipients(1, "group", 60, packet, 0).is_empty()): return
	relay.remove_peer(2)
	if not _check(not relay.peers.has(2)): return
	for id in range(4, 15):
		relay.set_peer(id, Vector3.ZERO, "one")
	if not _check(relay.peers.size() == 8, "Bounded authenticated roster"): return
	print("VOICE CHECKS PASS: native Opus encode/decode 960 frames, nonzero PCM; auth/floor/proximity/group/replay/rate/packet guards")
	print("VOICE FIXTURE CHECKS evaluated=", _evaluated_checks)
	quit()

var _evaluated_checks := 0
func _check(condition: bool, detail: String = "") -> bool:
	_evaluated_checks += 1
	# Exported release templates remove native assert(); this check always executes.
	if "--voice-fixture-force-failure" in OS.get_cmdline_user_args(): condition = false
	if condition: return true
	push_error("VOICE FIXTURE FAIL check %d: %s" % [_evaluated_checks, detail])
	quit(1)
	return false
