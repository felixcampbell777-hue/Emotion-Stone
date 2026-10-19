class_name WorldRiseVoiceRelay
extends RefCounted
## Server-only routing. Identity/position/group come from the authenticated registry.
const Codec = preload("res://scripts/voice/voice_codec.gd")
const RADIUS := 35.0
const MAX_PEERS := 8
var peers: Dictionary = {}
var limits: Dictionary = {}
var received_frames := 0
var accepted_frames := 0
var recipient_frames := 0

func set_peer(id: int, position: Vector3, floor_id: String, group_id: String = "friends") -> void:
	if id <= 0 or not position.is_finite() or (not peers.has(id) and peers.size() >= MAX_PEERS):
		return
	peers[id] = {"position": position, "floor": floor_id, "group": group_id}

func remove_peer(id: int) -> void:
	peers.erase(id)
	limits.erase(id)

func recipients(sender: int, channel: String, sequence: int, packet: PackedByteArray, now_ms: int) -> Array[int]:
	received_frames += 1
	var result: Array[int] = []
	if not peers.has(sender) or channel not in ["proximity", "group"] or sequence < 0 or not Codec.valid_packet(packet):
		return result
	var state: Dictionary = limits.get(sender, {"start": now_ms, "count": 0, "bytes": 0, "sequence": -1, "seen": {}})
	if sequence <= int(state.sequence) - 64 or state.seen.has(sequence):
		return result
	if now_ms - int(state.start) >= 1000:
		state.start = now_ms
		state.count = 0
		state.bytes = 0
	# 50 x20ms/s with a small scheduling tolerance. Global across both channels.
	if int(state.count) >= 60 or int(state.bytes) + packet.size() > 16000:
		return result
	state.count += 1
	state.bytes += packet.size()
	state.sequence = maxi(sequence, int(state.sequence))
	state.seen[sequence] = true
	for old in state.seen.keys():
		if int(old) <= int(state.sequence) - 64: state.seen.erase(old)
	limits[sender] = state
	accepted_frames += 1
	var source: Dictionary = peers[sender]
	for id: int in peers:
		if id == sender:
			continue
		var target: Dictionary = peers[id]
		if channel == "group":
			if source.group != "" and source.group == target.group:
				result.append(id)
		elif source.floor == target.floor and source.position.distance_squared_to(target.position) <= RADIUS * RADIUS:
			result.append(id)
	recipient_frames += result.size()
	return result
