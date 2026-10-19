extends SceneTree
class ConditionedSession extends "res://scripts/network/wr_session.gd":
	func start_client_voice() -> void:
		var conditioned_port := int(OS.get_environment("WORLD_RISE_TEST_VOICE_PORT"))
		if conditioned_port > 0: voice_port = conditioned_port
		super.start_client_voice()
const Voice = preload("res://scripts/voice/world_rise_voice.gd")
const Codec = preload("res://scripts/voice/voice_codec.gd")
var session: Node
var service: Node
var server_mode := false
var expected := 2
var port := 25483
var password_file := ""
var deadline := 0
var started := 0
var next_send := 0
var sequence := 0
var received := 0
var senders: Dictionary = {}
var packet: PackedByteArray
var roster_size := 0
var max_pending := 0
var decoded_streams := 0
var crossfloor := false
var moved_floor := false
var crossfloor_group := 0
var crossfloor_proximity := 0
var finishing := false
var printed_diagnostics := false
var channels_received: Dictionary = {}
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	server_mode = "--server" in args
	crossfloor = "--crossfloor" in args
	for index in args.size():
		if args[index] == "--peers": expected = int(args[index + 1])
		if args[index] == "--port": port = int(args[index + 1])
		if args[index] == "--password-file" and index + 1 < args.size(): password_file = args[index + 1]
	deadline = Time.get_ticks_msec() + 25000
	call_deferred("run")
func run() -> void:
	session = ConditionedSession.new()
	session.name = "Session"
	root.add_child(session)
	if not password_file.is_empty():
		var secret := FileAccess.open(password_file, FileAccess.READ)
		if secret == null or secret.get_length() > 4096:
			print("VOICE TRANSPORT FAIL: cannot read bounded password file")
			quit(1)
			return
		session.password = secret.get_as_text().strip_edges()
		secret.close()
	if server_mode:
		if not _check(session.start_server(port, "user://voice-check-server", session.password) == OK): return
	else:
		service = Voice.new()
		root.add_child(service)
		session.snapshot_received.connect(_snapshot)
		session.voice_received.connect(_received)
		session.joined.connect(_joined)
		if not _check(session.join("127.0.0.1", port) == OK): return
		var codec := Codec.new()
		var pcm := PackedVector2Array()
		for frame in Codec.FRAMES:
			pcm.append(Vector2.ONE * sin(float(frame) / Codec.RATE * TAU * 440) * .1)
		packet = codec.encode(pcm)
func _process(_delta: float) -> bool:
	var now := Time.get_ticks_msec()
	if finishing: return false
	if now > deadline:
		print("VOICE TRANSPORT FAIL timeout server=", server_mode, " roster=", roster_size, " received=", received, " status=", session.status)
		quit(1)
		return false
	if server_mode:
		if session.members.size() == expected and started == 0: started = now
		if started > 0 and now - started > 3500 and not printed_diagnostics:
			print("VOICE RELAY DIAGNOSTICS peers=",session.relay.peers," limits=",session.relay.limits)
			printed_diagnostics = true
		if crossfloor and started > 0 and now - started > 1000 and not moved_floor:
			var peer_id: int = session.members.keys().back()
			session.authority.players[session.members[peer_id]].floor = "wr_floor_02"
			moved_floor = true
		if started > 0 and now - started >= 6500:
			print("VOICE TRANSPORT SERVER PASS peers=", expected, " received=",session.relay.received_frames," accepted=",session.relay.accepted_frames," forwarded=",session.relay.recipient_frames," transport=authenticated_udp udp=", session.voice_udp.statistics)
			session.leave_server()
			quit()
		return false
	if roster_size == expected and started == 0 and session.voice_udp != null and session.voice_udp.is_ready():
		started = now
		next_send = now
	if started == 0: return false
	var catchup_budget := 4
	while now >= next_send and sequence < 200 and catchup_budget > 0 and now - started < 4200:
		session.send_voice("group" if sequence % 2 else "proximity", sequence, packet)
		sequence += 1
		next_send += 20
		catchup_budget -= 1
	for speaker: Dictionary in service._speakers.values(): max_pending = maxi(max_pending, speaker.pending.size())
	if now - started >= 5000:
		for speaker: Dictionary in service._speakers.values():
			if int(speaker.delivered_frames) > 0: decoded_streams += 1
		var required_frames := (95 if crossfloor else 190) * (expected - 1)
		var quality_frames := int(channels_received.get("group", 0)) if crossfloor else received
		var success := quality_frames >= required_frames and senders.size() == expected - 1 and decoded_streams == expected - 1 and max_pending <= 8 and crossfloor_proximity == 0 and (not crossfloor or crossfloor_group > 0)
		print("VOICE TRANSPORT ", "PASS" if success else "FAIL", " peers=", expected, " sent=", sequence, " received=", received, " streams=", senders.size(), " decoded_streams=", decoded_streams, " max_jitter_packets=", max_pending, " crossfloor_group=", crossfloor_group, " crossfloor_proximity=", crossfloor_proximity, " channels=", channels_received, " transport=authenticated_udp udp=", session.voice_udp.statistics)
		finish(success)
	return false
func _snapshot(snapshot: Dictionary) -> void:
	if finishing or not is_instance_valid(service): return
	var roster: Dictionary = snapshot.get("voice_roster", {})
	if roster.is_empty():
		for character: Dictionary in snapshot.players.values():
			if character.has("peer_id"): roster[str(character.peer_id)] = character
	roster_size = roster.size()
	for id_value in roster:
		var peer: Dictionary = roster[id_value]
		var id := int(peer.get("peer_id", id_value))
		var position_data: Array = peer.position
		var position := Vector3(float(position_data[0]), float(position_data[1]), float(position_data[2]))
		if id == session.local_peer_id: service.set_local_position(position, peer.floor)
		else: service.set_peer(id, position, peer.floor)
func _received(id: int, channel: String, seq: int, payload: PackedByteArray) -> void:
	if finishing or not is_instance_valid(service): return
	received += 1
	channels_received[channel] = int(channels_received.get(channel, 0)) + 1
	senders[id] = true
	if service.peers.has(id) and service.peers[id].floor != service.local_floor:
		if channel == "group": crossfloor_group += 1
		else: crossfloor_proximity += 1
	service.receive_frame(id, channel, seq, payload)

func finish(success: bool) -> void:
	finishing = true
	session.leave_server()
	if not await service.shutdown_and_drain(): success = false
	service.queue_free()
	await process_frame
	quit(0 if success else 1)

func _joined(_id: String) -> void:
	service.configure_session(true, session.local_peer_id)

var _evaluated_checks := 0
func _check(condition: bool, detail: String = "") -> bool:
	_evaluated_checks += 1
	# Exported release templates remove native assert(); this check always executes.
	if "--voice-fixture-force-failure" in OS.get_cmdline_user_args(): condition = false
	if condition: return true
	push_error("VOICE FIXTURE FAIL check %d: %s" % [_evaluated_checks, detail])
	quit(1)
	return false
