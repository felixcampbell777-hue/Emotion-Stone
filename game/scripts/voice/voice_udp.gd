class_name WorldRiseVoiceUDP
extends Node
## Bounded authenticated voice-only UDP. Keys arrive over the authenticated game session.
## HMAC authenticates packets; encryption is supplied by the required trusted LAN/VPN.
signal frame_received(peer_id: int, channel: String, sequence: int, payload: PackedByteArray)
signal status_changed(message: String)
const Codec = preload("res://scripts/voice/voice_codec.gd")
const MAX_DATAGRAM := 512
const HEADER := 28
const TAG := 32
const HELLO := 0
const VOICE := 1
const RELAY := 2
const ACK := 3
const DOMAIN_C2S := "WorldRiseVoice1/client-to-server"
const DOMAIN_S2C := "WorldRiseVoice1/server-to-client"
var statistics := {"sent": 0, "received": 0, "authenticated": 0, "rejected": 0, "delivered": 0, "bytes_sent": 0}
var _socket: PacketPeerUDP
var _server := false
var _active := false
var _registered := false
var _relay: RefCounted
var _members: Dictionary = {}
var _local_peer := 0
var _key := PackedByteArray()
var _packet_sequence := 0
var _server_replay := {"highest": -1, "seen": {}}
var _server_ip := ""
var _server_port := 0
var _heartbeat_at := 0
var _last_ack := 0
var _client_window := 0
var _client_packets := 0
var _client_bytes := 0
var egress_limit_bytes_per_second := 524288
var _egress_window := 0
var _egress_bytes := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

static func canonical_ip(address: String) -> String:
	var value := address.to_lower()
	if value.is_valid_ip_address() and value.begins_with("::ffff:") and "." in value.substr(7) and value.substr(7).is_valid_ip_address(): return value.substr(7)
	if ":" in value and value.is_valid_ip_address():
		var halves := value.split("::", true)
		var left: Array = Array(halves[0].split(":", false))
		var right: Array = Array(halves[1].split(":", false)) if halves.size() == 2 else []
		var expanded: Array = left.duplicate()
		if halves.size() == 2:
			while expanded.size() + right.size() < 8: expanded.append("0")
			expanded.append_array(right)
		if expanded.size() == 8:
			for index in 8: expanded[index] = String.num_int64(str(expanded[index]).hex_to_int(), 16)
			if expanded.slice(0, 6) == ["0", "0", "0", "0", "0", "ffff"]:
				var high := str(expanded[6]).hex_to_int()
				var low := str(expanded[7]).hex_to_int()
				return "%d.%d.%d.%d" % [high >> 8, high & 255, low >> 8, low & 255]
			return ":".join(expanded)
	return value

func start_server(port: int, relay: RefCounted, bind_address: String = "127.0.0.1") -> Error:
	stop()
	if port < 1024 or port > 65535 or relay == null: return ERR_INVALID_PARAMETER
	_socket = PacketPeerUDP.new()
	var result := _socket.bind(port, bind_address, 262144)
	if result != OK:
		status_changed.emit("Voice UDP port unavailable")
		return result
	_server = true
	_active = true
	_relay = relay
	return OK

func add_member(peer_id: int, token: PackedByteArray, expected_enet_ip: String) -> bool:
	var ip := canonical_ip(expected_enet_ip)
	if not _server or peer_id <= 0 or peer_id > 2147483647 or token.size() != 32 or not ip.is_valid_ip_address() or (not _members.has(peer_id) and _members.size() >= 8): return false
	_members[peer_id] = {"key": token.duplicate(), "expected_ip": ip, "ip": "", "port": 0, "last": 0, "out_sequence": 0,
		"replay": {"highest": -1, "seen": {}}, "window": 0, "packets": 0, "bytes": 0, "hellos": 0}
	return true

func remove_member(peer_id: int) -> void:
	_members.erase(peer_id)

func start_client(host: String, port: int, peer_id: int, token: PackedByteArray) -> Error:
	stop()
	if port < 1024 or port > 65535 or peer_id <= 0 or peer_id > 2147483647 or token.size() != 32: return ERR_INVALID_PARAMETER
	var resolved := host if host.is_valid_ip_address() else IP.resolve_hostname(host, IP.TYPE_IPV4)
	if not resolved.is_valid_ip_address(): return ERR_CANT_RESOLVE
	_socket = PacketPeerUDP.new()
	var result := _socket.bind(0, "*", 262144)
	if result != OK: return result
	result = _socket.connect_to_host(resolved, port)
	if result != OK:
		_socket.close()
		return result
	_server_ip = canonical_ip(resolved)
	_server_port = port
	_local_peer = peer_id
	_key = token.duplicate()
	_active = true
	_last_ack = Time.get_ticks_msec()
	_send_hello()
	return OK

func is_ready() -> bool:
	return _active and (_server or _registered)

func send_frame(channel: String, sequence: int, payload: PackedByteArray) -> void:
	if not _active or channel not in ["proximity", "group"] or sequence < 0 or not Codec.valid_packet(payload): return
	if _server:
		if _members.has(1): _route(1, channel, sequence, payload)
		return
	if not _registered: return
	_send_client(VOICE, channel, sequence, payload)

func _process(_delta: float) -> void:
	if not _active: return
	if not _server:
		if _registered and Time.get_ticks_msec() - _last_ack > 5000:
			_registered = false
			status_changed.emit("Voice UDP reconnecting")
		if Time.get_ticks_msec() >= _heartbeat_at: _send_hello()
	var budget := 64
	while _active and _socket != null and budget > 0 and _socket.get_available_packet_count() > 0:
		budget -= 1
		var packet := _socket.get_packet()
		var ip := canonical_ip(_socket.get_packet_ip())
		var port := _socket.get_packet_port()
		statistics.received += 1
		if _socket.get_packet_error() != OK or packet.size() < HEADER + TAG or packet.size() > MAX_DATAGRAM:
			statistics.rejected += 1
			continue
		var frame := unpack_header(packet)
		if frame.is_empty():
			statistics.rejected += 1
			continue
		if _server: _receive_server(packet, frame, ip, port)
		else: _receive_client(packet, frame, ip, port)

static func unpack_header(packet: PackedByteArray) -> Dictionary:
	if packet.size() < HEADER + TAG or packet.size() > MAX_DATAGRAM: return {}
	if packet[0] != 87 or packet[1] != 82 or packet[2] != 86 or packet[3] != 49: return {}
	var size := packet.decode_u16(26)
	if size > Codec.MAX_PACKET or packet.size() != HEADER + size + TAG: return {}
	var sequence := packet.decode_u64(10)
	var frame_sequence := packet.decode_u64(18)
	if sequence < 0 or frame_sequence < 0: return {}
	return {"kind": int(packet[4]), "channel": int(packet[5]), "peer": int(packet.decode_u32(6)), "sequence": sequence, "frame_sequence": frame_sequence, "size": size}

static func _mac(key: PackedByteArray, body: PackedByteArray, from_client: bool) -> PackedByteArray:
	var hmac := HMACContext.new()
	if hmac.start(HashingContext.HASH_SHA256, key) != OK: return PackedByteArray()
	hmac.update((DOMAIN_C2S if from_client else DOMAIN_S2C).to_utf8_buffer())
	hmac.update(body)
	return hmac.finish()

static func _authenticated(packet: PackedByteArray, key: PackedByteArray, from_client: bool) -> bool:
	var expected := _mac(key, packet.slice(0, packet.size() - TAG), from_client)
	if expected.size() != TAG: return false
	var difference := 0
	for index in TAG: difference |= int(expected[index]) ^ int(packet[packet.size() - TAG + index])
	return difference == 0

static func _fresh(state: Dictionary, sequence: int) -> bool:
	if sequence < 0 or sequence <= int(state.highest) - 64 or state.seen.has(sequence): return false
	state.highest = maxi(int(state.highest), sequence)
	state.seen[sequence] = true
	for old in state.seen.keys():
		if int(old) <= int(state.highest) - 64: state.seen.erase(old)
	return true

func _receive_server(packet: PackedByteArray, frame: Dictionary, ip: String, port: int) -> void:
	if frame.kind not in [HELLO, VOICE] or not _members.has(frame.peer):
		statistics.rejected += 1
		return
	var member: Dictionary = _members[frame.peer]
	# No endpoint mutation or response before membership, ENet IP and HMAC all agree.
	if ip != member.expected_ip or not _authenticated(packet, member.key, true) or not _fresh(member.replay, frame.sequence):
		statistics.rejected += 1
		return
	var now := Time.get_ticks_msec()
	if now - int(member.window) >= 1000:
		member.window = now; member.packets = 0; member.bytes = 0; member.hellos = 0
	if int(member.packets) >= 80 or int(member.bytes) + packet.size() > 45000:
		statistics.rejected += 1
		return
	member.packets += 1
	member.bytes += packet.size()
	statistics.authenticated += 1
	if frame.kind == HELLO:
		if frame.size != 0 or frame.channel != 2 or frame.frame_sequence != 0 or int(member.hellos) >= 4: return
		member.hellos += 1
		member.ip = ip; member.port = port; member.last = now
		_send_server(frame.peer, ACK, frame.peer, "", 0, PackedByteArray())
		return
	if member.ip != ip or int(member.port) != port or frame.channel not in [0, 1]: return
	member.last = now
	var payload := packet.slice(HEADER, HEADER + int(frame.size))
	if Codec.valid_packet(payload): _route(frame.peer, "proximity" if frame.channel == 0 else "group", frame.frame_sequence, payload)

func _route(sender: int, channel: String, sequence: int, payload: PackedByteArray) -> void:
	for recipient: int in _relay.recipients(sender, channel, sequence, payload, Time.get_ticks_msec()):
		if recipient == 1 and _members.has(1):
			statistics.delivered += 1
			frame_received.emit(sender, channel, sequence, payload)
		elif _members.has(recipient): _send_server(recipient, RELAY, sender, channel, sequence, payload)

func _receive_client(packet: PackedByteArray, frame: Dictionary, ip: String, port: int) -> void:
	if ip != _server_ip or port != _server_port or frame.kind not in [ACK, RELAY] or not _authenticated(packet, _key, false) or not _fresh(_server_replay, frame.sequence):
		statistics.rejected += 1
		return
	var now := Time.get_ticks_msec()
	if now - _client_window >= 1000:
		_client_window = now; _client_packets = 0; _client_bytes = 0
	if _client_packets >= 512 or _client_bytes + packet.size() > 262144:
		statistics.rejected += 1
		return
	_client_packets += 1
	_client_bytes += packet.size()
	statistics.authenticated += 1
	if frame.kind == ACK:
		if frame.peer != _local_peer or frame.size != 0 or frame.channel != 2: return
		_registered = true
		_last_ack = now
		status_changed.emit("Voice UDP connected")
	elif _registered and frame.peer > 0 and frame.peer != _local_peer and frame.channel in [0, 1]:
		var payload := packet.slice(HEADER, HEADER + int(frame.size))
		if Codec.valid_packet(payload):
			statistics.delivered += 1
			frame_received.emit(frame.peer, "proximity" if frame.channel == 0 else "group", frame.frame_sequence, payload)

static func _packet(kind: int, channel: String, peer_id: int, packet_sequence: int, frame_sequence: int, payload: PackedByteArray, key: PackedByteArray, from_client: bool) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(HEADER)
	bytes[0] = 87; bytes[1] = 82; bytes[2] = 86; bytes[3] = 49
	bytes[4] = kind
	bytes[5] = 0 if channel == "proximity" else (1 if channel == "group" else 2)
	bytes.encode_u32(6, peer_id)
	bytes.encode_u64(10, packet_sequence)
	bytes.encode_u64(18, frame_sequence)
	bytes.encode_u16(26, payload.size())
	bytes.append_array(payload)
	bytes.append_array(_mac(key, bytes, from_client))
	return bytes

func _send_client(kind: int, channel: String, sequence: int, payload: PackedByteArray) -> void:
	var bytes := _packet(kind, channel, _local_peer, _packet_sequence, sequence, payload, _key, true)
	_packet_sequence += 1
	if _socket.put_packet(bytes) == OK:
		statistics.sent += 1; statistics.bytes_sent += bytes.size()

func _send_server(recipient: int, kind: int, source: int, channel: String, sequence: int, payload: PackedByteArray) -> void:
	var member: Dictionary = _members[recipient]
	var now := Time.get_ticks_msec()
	if now - _egress_window >= 1000:
		_egress_window = now; _egress_bytes = 0
	if _egress_bytes + HEADER + TAG + payload.size() > egress_limit_bytes_per_second:
		statistics.rejected += 1
		return
	if int(member.port) <= 0 or Time.get_ticks_msec() - int(member.last) > 10000: return
	var bytes := _packet(kind, channel, source, member.out_sequence, sequence, payload, member.key, false)
	member.out_sequence += 1
	_socket.set_dest_address(member.ip, member.port)
	if _socket.put_packet(bytes) == OK:
		statistics.sent += 1; statistics.bytes_sent += bytes.size()
		_egress_bytes += bytes.size()

func _send_hello() -> void:
	_send_client(HELLO, "", 0, PackedByteArray())
	_heartbeat_at = Time.get_ticks_msec() + (1000 if _registered else 250)

func stop() -> void:
	_active = false
	_registered = false
	if _socket != null: _socket.close()
	_socket = null
	_members.clear()
	_key.fill(0)
	_key = PackedByteArray()
	_server = false
	_local_peer = 0
	_packet_sequence = 0
	_server_replay = {"highest": -1, "seen": {}}
	_relay = null
	_server_ip = ""
	_server_port = 0
	_last_ack = 0
	_heartbeat_at = 0
	_client_window = 0
	_client_packets = 0
	_client_bytes = 0
	_egress_window = 0
	_egress_bytes = 0

func _exit_tree() -> void:
	stop()
