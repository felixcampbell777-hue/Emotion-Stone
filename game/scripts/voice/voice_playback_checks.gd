extends SceneTree
const Voice = preload("res://scripts/voice/world_rise_voice.gd")
const Codec = preload("res://scripts/voice/voice_codec.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	ProjectSettings.set_setting("audio/driver/enable_input", true)
	var service := Voice.new()
	root.add_child(service)
	service.configure_session(true, 1)
	service.set_local_position(Vector3.ZERO, "one")
	service.set_peer(2, Vector3(2, 0, 0), "one")
	var codec := Codec.new()
	var pcm := PackedVector2Array()
	pcm.resize(Codec.FRAMES)
	for i in pcm.size():
		pcm[i] = Vector2.ONE * sin(float(i) / Codec.RATE * TAU * 440) * 0.1
	var packet: PackedByteArray = codec.encode(pcm)
	service.receive_frame(2, "proximity", 10, packet)
	service.receive_frame(2, "proximity", 12, packet)
	service.receive_frame(2, "proximity", 11, packet)
	if not _check(service._speakers[2].pending.size() == 3, "Reordering must retain missing predecessor"): return
	service.receive_frame(2, "proximity", 11, packet)
	if not _check(service._speakers[2].pending.size() == 3, "Reject duplicate"): return
	service._speakers[2].deadline = Time.get_ticks_msec() - 100
	service._play_queued_frames()
	if not _check(service._speakers[2].pending.is_empty(), "Playout must drain bounded jitter buffer"): return
	service.set_peer_muted(2, true)
	service.receive_frame(2, "group", 13, packet)
	if not _check(service._speakers[2].pending.is_empty(), "Mute before decode"): return
	service.set_input_muted(false)
	service.set_push_to_talk("proximity", true)
	service._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	if not _check(service._ptt == "", "Focus loss stops talk"): return
	service.set_deafened(true)
	service.configure_session(false)
	if not _check(service._speakers.is_empty()): return
	if not _check(await service.shutdown_and_drain(), "Initial rapid mute/deafen/disconnect drains playback"): return
	for cycle in 8:
		service.configure_session(true, 1)
		service.set_local_position(Vector3.ZERO, "one")
		service.set_peer(2, Vector3.ZERO, "one")
		service.set_peer_muted(2, false)
		service.set_deafened(false)
		for index in 16:
			service.receive_frame(2, "group", index, packet)
			service._speakers[2].deadline = Time.get_ticks_msec() - 1
			service._play_queued_frames()
			if not _check(service._speakers[2].delivered_frames == (index + 1) * Codec.FRAMES, "Normal decode survives repeated resets"): return
			service.set_peer_muted(2, true)
			service.set_deafened(true)
			service.set_peer_muted(2, false)
			service.set_deafened(false)
		if not _check(service.pending_playback_count() <= 16, "Repeated resets retain bounded weak observations"): return
		if not _check(await service.shutdown_and_drain(), "Repeated reset cycle must release every playback"): return
		if not _check(service.pending_playback_count() == 0, "No playback survives drained cycle"): return
	service.queue_free()
	await process_frame
	print("VOICE PLAYBACK PASS: Godot generator playback, reordered20ms frames, duplicate/mute/focus/disconnect guards")
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
