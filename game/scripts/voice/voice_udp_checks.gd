extends SceneTree
const UDP = preload("res://scripts/voice/voice_udp.gd")
const Relay = preload("res://scripts/voice/voice_relay.gd")
const Codec = preload("res://scripts/voice/voice_codec.gd")
var received: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not _check(UDP.canonical_ip("::1") == UDP.canonical_ip("0:0:0:0:0:0:0:1")): return
	if not _check(UDP.canonical_ip("::ffff:127.0.0.1") == "127.0.0.1"): return
	if not _check(UDP.canonical_ip("0:0:0:0:0:ffff:7f00:1") == "127.0.0.1"): return
	var key := Crypto.new().generate_random_bytes(32)
	var codec := Codec.new()
	var pcm := PackedVector2Array()
	pcm.resize(960)
	var payload: PackedByteArray = codec.encode(pcm)
	var signed := UDP._packet(UDP.VOICE, "group", 2, 1, 1, payload, key, true)
	if not _check(signed.size() <= 512 and not UDP.unpack_header(signed).is_empty()): return
	if not _check(UDP._authenticated(signed, key, true)): return
	if not _check(not UDP._authenticated(signed, key, false), "Direction reflection denied"): return
	var corrupt := signed.duplicate()
	corrupt[UDP.HEADER] ^= 1
	if not _check(not UDP._authenticated(corrupt, key, true)): return
	var replay := {"highest": -1, "seen": {}}
	if not _check(UDP._fresh(replay, 2) and UDP._fresh(replay, 1) and not UDP._fresh(replay, 1)): return
	var relay := Relay.new()
	relay.set_peer(2, Vector3.ZERO, "one")
	relay.set_peer(3, Vector3.ZERO, "one")
	var server := UDP.new()
	var first := UDP.new()
	var second := UDP.new()
	root.add_child(server);root.add_child(first);root.add_child(second)
	if not _check(server.start_server(25491, relay) == OK): return
	var second_key := Crypto.new().generate_random_bytes(32)
	if not _check(server.add_member(2, key, "127.0.0.1")): return
	if not _check(server.add_member(3, second_key, "127.0.0.1")): return
	second.frame_received.connect(func(id, channel, seq, packet): received.append([id, channel, seq, packet]))
	if not _check(first.start_client("127.0.0.1", 25491, 2, key) == OK): return
	if not _check(second.start_client("127.0.0.1", 25491, 3, second_key) == OK): return
	var deadline := Time.get_ticks_msec() + 2000
	while not first.is_ready() or not second.is_ready():
		if not _check(Time.get_ticks_msec() < deadline): return
		await process_frame
	first.send_frame("group", 2, payload)
	first.send_frame("group", 1, payload)
	while received.size() < 2:
		if not _check(Time.get_ticks_msec() < deadline): return
		await process_frame
	if not _check(received[0][0] == 2 and received[0][1] == "group" and received[0][3] == payload): return
	if not _check(received[1][2] == 1, "Relay permits authenticated bounded reordering"): return
	var before := int(server.statistics.sent)
	var stranger := PacketPeerUDP.new()
	if not _check(stranger.set_dest_address("127.0.0.1", 25491) == OK): return
	stranger.put_packet(corrupt)
	stranger.put_packet(signed) # Valid key, repeated packet-sequence and unregistered endpoint.
	if not _check(server.add_member(4, key, "127.0.0.2")): return
	stranger.put_packet(UDP._packet(UDP.HELLO, "", 4, 0, 0, PackedByteArray(), key, true))
	stranger.put_packet(UDP._packet(UDP.VOICE, "group", 2, 100, 100, payload, second_key, true))
	var oversized := PackedByteArray()
	oversized.resize(513)
	stranger.put_packet(oversized)
	await create_timer(0.05).timeout
	if not _check(int(server.statistics.sent) == before, "No unauthenticated reflection or replay forwarding"): return
	if not _check(int(server._members[4].port) == 0, "Authenticated token still requires actual ENet source IP"): return
	for id in range(5, 10):
		if not _check(server.add_member(id, key, "127.0.0.1")): return
	if not _check(not server.add_member(10, key, "127.0.0.1"), "Eight member bound"): return
	for seq in range(3, 203): first.send_frame("group", seq, payload)
	var settle := Time.get_ticks_msec() + 150
	while Time.get_ticks_msec() < settle: await process_frame
	if not _check(relay.accepted_frames <= 60, "Relay rejects authenticated frame spam"): return
	if not _check(int(server.statistics.rejected) > 0, "Packet and byte budgets reject overload"): return
	stranger.close()
	server.stop();first.stop();second.stop()
	server.queue_free();first.queue_free();second.queue_free()
	await process_frame
	print("VOICE UDP PASS: real sockets, HMAC both directions, endpoint auth, corruption/spoof/reflection/replay/IP rejection, bounded members/rate and reordered relay")
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
