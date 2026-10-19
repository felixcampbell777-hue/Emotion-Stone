class_name WorldRiseVoice
extends Node
## Opt-in capture. Never records to disk. Transport is supplied by the session.
signal outgoing_frame(channel: String, sequence: int, payload: PackedByteArray)
signal status_changed
signal voice_activity(active: bool)
const Codec = preload("res://scripts/voice/voice_codec.gd")
const NativeCapture = preload("res://scripts/voice/native_capture.gd")
const Relay = preload("res://scripts/voice/voice_relay.gd")
var session_active := false
var local_peer_id := 0
var input_muted := true
var deafened := false
var local_position := Vector3.ZERO
var local_floor := ""
var peers: Dictionary = {}
var muted_peers: Dictionary = {}
var status := "Voice off — enable your microphone in Settings"
var _ptt := ""
var _sequence := 0
var _focused := true
var _native_capture: Object
var input_device_name := "Default"
var microphone_gain := 1.0
var microphone_peak := 0.0
var _meter: ProgressBar
var _capture: AudioEffectCapture
var _microphone: AudioStreamPlayer
var _codec: RefCounted
var _speakers: Dictionary = {}
var _retired_playbacks: Dictionary = {}
var _last_audio_ms := 0
var _last_signal_ms := 0
var _panel_status: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Voice")
	if not Codec.available():
		status = "Voice codec unavailable on this platform"
		return
	_codec = Codec.new()
	if OS.get_name() == "macOS":
		_native_capture = NativeCapture.create()
		if _native_capture == null: status = NativeCapture.load_error
		return
	var bus := _ensure_bus("WorldRiseMic")
	AudioServer.set_bus_mute(bus, true)
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 0.12
	AudioServer.add_bus_effect(bus, _capture)
	_microphone = AudioStreamPlayer.new()
	_microphone.bus = "WorldRiseMic"
	_microphone.stream = AudioStreamMicrophone.new()
	add_child(_microphone)

func _ensure_bus(bus_name: String) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
	return index

func configure_session(active: bool, peer_id: int = 0) -> void:
	session_active = active
	local_peer_id = peer_id
	cancel_push_to_talk()
	for id: int in _speakers:
		_retire_player(_speakers[id])
	_speakers.clear()
	peers.clear()
	_update_capture()

func set_local_position(position: Vector3, floor_id: String) -> void:
	local_position = position
	local_floor = floor_id

func set_peer(id: int, position: Vector3, floor_id: String, group_id: String = "friends") -> void:
	if id > 0 and position.is_finite() and (peers.has(id) or peers.size() < 8):
		peers[id] = {"position": position, "floor": floor_id, "group": group_id}

func remove_peer(id: int) -> void:
	peers.erase(id)
	if _speakers.has(id):
		_retire_player(_speakers[id])
		_speakers.erase(id)

func set_input_muted(muted: bool) -> void:
	input_muted = muted
	cancel_push_to_talk()
	_update_capture()

func set_deafened(value: bool) -> void:
	deafened = value
	if value:
		cancel_push_to_talk()
	for id: int in _speakers:
		_reset_playback(_speakers[id])
		_speakers[id].pending.clear()
	_update_capture()

func set_peer_muted(id: int, value: bool) -> void:
	muted_peers[id] = value
	if _speakers.has(id):
		_reset_playback(_speakers[id])
		_speakers[id].pending.clear()

func set_input_device(device: String) -> void:
	if device not in AudioServer.get_input_device_list():
		return
	cancel_push_to_talk()
	input_device_name = device
	if _native_capture != null:
		_native_capture.call("set_device", device)
		status = str(_native_capture.call("get_status"))
		status_changed.emit()
	else:
		AudioServer.input_device = device
	_clear_capture()

func set_push_to_talk(channel: String, pressed: bool) -> void:
	if text_input_focused():
		cancel_push_to_talk()
		return
	if not pressed:
		if _ptt == channel: cancel_push_to_talk()
		return
	if channel not in ["proximity", "group"] or not session_active or input_muted or deafened or not _focused:
		return
	if not _start_microphone(false):
		cancel_push_to_talk()
		return
	_clear_capture()
	_ptt = channel
	status = "Talking nearby" if channel == "proximity" else "Talking to Friends group"
	status_changed.emit()

func cancel_push_to_talk() -> void:
	var was_talking := _ptt != ""
	_ptt = ""
	if was_talking and status.begins_with("Talking") and session_active and not input_muted and not deafened: status = "Ready — hold V nearby or B for Friends group"
	microphone_peak = 0.0
	if _native_capture != null: _native_capture.call("stop_capture")
	if is_instance_valid(_microphone): _microphone.stop()
	_clear_capture()

func _start_microphone(request_permission: bool) -> bool:
	if _native_capture != null:
		if not _native_capture.call("start_capture", request_permission):
			status = str(_native_capture.call("get_status"))
			status_changed.emit()
			return false
	elif is_instance_valid(_microphone) and AudioServer.get_driver_name() != "Dummy":
		_microphone.play()
	else:
		status = "Microphone unavailable — check audio device and system permission"
		return false
	_last_audio_ms = Time.get_ticks_msec()
	_last_signal_ms = _last_audio_ms
	return true

func set_microphone_test(active: bool) -> void:
	cancel_push_to_talk()
	if active and _start_microphone(true): status = "Microphone test — local level only; no voice transmitted"

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		cancel_push_to_talk()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true

func _update_capture() -> void:
	cancel_push_to_talk()
	if _native_capture != null:
		if session_active and not input_muted and not deafened:
			var permission := str(_native_capture.call("get_permission"))
			if permission == "not_determined":
				_native_capture.call("start_capture", true)
				status = str(_native_capture.call("get_status"))
			elif permission != "authorized": status = "Microphone permission " + permission + " — check system Privacy settings"
			else: status = "Ready — hold V nearby or B for Friends group"
		else: status = "Voice off" if input_muted else "Voice ready when connected"
	elif _microphone != null:
		status = "Microphone unavailable — check audio device and system permission" if AudioServer.get_driver_name() == "Dummy" else ("Voice off" if input_muted else "Ready — hold V nearby or B for Friends group")
	status_changed.emit()

func _process(_delta: float) -> void:
	if text_input_focused() and _capture_running(): cancel_push_to_talk()
	_play_queued_frames()
	pending_playback_count()
	if is_instance_valid(_meter): _meter.value = microphone_peak
	if is_instance_valid(_panel_status):
		_panel_status.text = status
	if not _capture_running():
		return
	# Capture rate follows the input mixer; resampling is native, on this thread.
	var sample_rate := float(_native_capture.call("get_sample_rate")) if _native_capture != null else AudioServer.get_mix_rate()
	var frames := int(round(sample_rate * 0.02))
	if _available_capture_frames() > frames * 4:
		_clear_capture()
	var budget := 3
	while budget > 0 and _available_capture_frames() >= frames:
		budget -= 1
		_last_audio_ms = Time.get_ticks_msec()
		var pcm: PackedVector2Array = _native_capture.call("get_buffer", frames) if _native_capture != null else _capture.get_buffer(frames)
		microphone_peak = 0.0
		for index in pcm.size():
			pcm[index] = Vector2(clampf(pcm[index].x * microphone_gain, -1.0, 1.0), clampf(pcm[index].y * microphone_gain, -1.0, 1.0))
			microphone_peak = maxf(microphone_peak, maxf(absf(pcm[index].x), absf(pcm[index].y)))
		for sample: Vector2 in pcm:
			if absf(sample.x) > 0.000001 or absf(sample.y) > 0.000001:
				_last_signal_ms = Time.get_ticks_msec()
				break
		if _ptt == "":
			continue
		# Codec input settings are fixed for this device's mix rate below.
		var packet: PackedByteArray = _encode_capture(pcm, frames, int(sample_rate))
		if not packet.is_empty():
			outgoing_frame.emit(_ptt, _sequence, packet)
			_sequence += 1
	if Time.get_ticks_msec() - _last_audio_ms > 2500 or Time.get_ticks_msec() - _last_signal_ms > 2500:
		status = "No microphone signal — check device and system microphone permission"
		cancel_push_to_talk()

func _encode_capture(pcm: PackedVector2Array, frames: int, sample_rate: int) -> PackedByteArray:
	# 44.1 kHz input is common on macOS. Configure before first native use only.
	if int(_codec.encoder.get("audiosamplesize")) != frames:
		_codec.encoder.set("audiosamplerate", sample_rate)
		_codec.encoder.set("audiosamplesize", frames)
	_codec.encoder.call("push_chunk", pcm)
	var packet: PackedByteArray = _codec.encoder.call("read_opus_packet", PackedByteArray())
	_codec.encoder.call("drop_chunk")
	return packet if Codec.valid_packet(packet) else PackedByteArray()

func receive_frame(id: int, channel: String, sequence: int, packet: PackedByteArray) -> void:
	if not Codec.available() or not session_active or deafened or bool(muted_peers.get(id, false)) or not peers.has(id) or not Codec.valid_packet(packet) or channel not in ["group", "proximity"]:
		return
	var peer: Dictionary = peers[id]
	if channel == "proximity" and (peer.floor != local_floor or local_position.distance_to(peer.position) > Relay.RADIUS):
		return
	if not _speakers.has(id):
		var player := AudioStreamPlayer.new()
		var generator := AudioStreamGenerator.new()
		generator.mix_rate = Codec.RATE
		generator.buffer_length = 0.16
		player.stream = generator
		player.bus = "Voice"
		add_child(player)
		player.play()
		_speakers[id] = {"player": player, "playback": player.get_stream_playback(), "decoder": Codec.configured_native("AudioStreamOpusChunked"), "sequence": -1, "last": 0, "pending": {}, "next": sequence, "deadline": Time.get_ticks_msec() + 60, "channel": channel, "delivered_frames": 0}
	var speaker: Dictionary = _speakers[id]
	if sequence < int(speaker.next) or speaker.pending.has(sequence):
		return
	if speaker.pending.size() >= 8 or sequence - int(speaker.next) > 8:
		speaker.pending.clear()
		speaker.next = sequence
		speaker.deadline = Time.get_ticks_msec() + 60
	if Time.get_ticks_msec() - int(speaker.last) > 300 and speaker.pending.is_empty():
		speaker.next = sequence
		speaker.deadline = Time.get_ticks_msec() + 60
	speaker.pending[sequence] = {"packet": packet, "channel": channel, "delivered_frames": 0}
	speaker.last = Time.get_ticks_msec()

func _play_queued_frames() -> void:
	var now := Time.get_ticks_msec()
	var active := _ptt != ""
	for id: int in _speakers:
		var speaker: Dictionary = _speakers[id]
		if speaker.pending.is_empty():
			continue
		active = true
		var budget := 3
		while now >= int(speaker.deadline) and budget > 0 and not speaker.pending.is_empty():
			budget -= 1
			var next := int(speaker.next)
			speaker.next = next + 1
			speaker.deadline = maxi(int(speaker.deadline) + 20, now - 40)
			if not speaker.pending.has(next):
				continue # Missing 20ms becomes silence; never replay stale speech.
			var frame: Dictionary = speaker.pending[next]
			speaker.pending.erase(next)
			if deafened or bool(muted_peers.get(id, false)) or not peers.has(id):
				continue
			var peer: Dictionary = peers[id]
			if frame.channel == "proximity" and (peer.floor != local_floor or local_position.distance_to(peer.position) > Relay.RADIUS):
				continue
			if speaker.channel != frame.channel:
				_reset_playback(speaker)
				speaker.channel = frame.channel
			_ensure_playback(speaker)
			var playback: AudioStreamGeneratorPlayback = speaker.playback
			if playback.get_frames_available() < Codec.FRAMES * 2:
				_reset_playback(speaker)
				_ensure_playback(speaker)
				playback = speaker.playback
			var pcm: PackedVector2Array = Codec.decode(speaker.decoder, frame.packet)
			if pcm.size() == Codec.FRAMES:
				if playback.push_buffer(pcm): speaker.delivered_frames += pcm.size()
			speaker.player.volume_db = 0.0 if frame.channel == "group" else linear_to_db(clampf(1.0 - local_position.distance_to(peer.position) / Relay.RADIUS, 0.001, 1.0))
	voice_activity.emit(active)

func settings_panel() -> Control:
	var panel := VBoxContainer.new()
	var title := Label.new()
	title.text = "Voice chat"
	panel.add_child(title)
	var instructions := Label.new()
	instructions.text = "Hold V: nearby voice • Hold B: Friends group (all connected friends, across floors)"
	panel.add_child(instructions)
	var gain := HSlider.new()
	gain.min_value = 0.0
	gain.max_value = 2.0
	gain.step = 0.05
	gain.value = microphone_gain
	gain.tooltip_text = "Microphone gain (0–200%)"
	gain.value_changed.connect(func(value: float): microphone_gain = value)
	var gain_label := Label.new()
	gain_label.text = "Microphone gain"
	panel.add_child(gain_label)
	panel.add_child(gain)
	_meter = ProgressBar.new()
	_meter.max_value = 1.0
	_meter.show_percentage = false
	_meter.custom_minimum_size.y = 12
	_meter.tooltip_text = "Live microphone level while voice is enabled"
	panel.add_child(_meter)
	var test := CheckButton.new()
	test.text = "Test microphone level (local only)"
	test.toggled.connect(func(active: bool):
		set_microphone_test(active)
		if active and not _capture_running(): test.set_pressed_no_signal(false))
	panel.add_child(test)
	panel.visibility_changed.connect(func():
		if not panel.is_visible_in_tree():
			cancel_push_to_talk()
			test.set_pressed_no_signal(false))
	_panel_status = Label.new()
	_panel_status.text = status
	panel.add_child(_panel_status)
	var enable := CheckButton.new()
	enable.text = "Enable microphone (push to talk)"
	enable.button_pressed = not input_muted
	enable.toggled.connect(func(value: bool): set_input_muted(not value))
	panel.add_child(enable)
	var device := OptionButton.new()
	for name_value: String in AudioServer.get_input_device_list():
		device.add_item(name_value)
		if name_value == input_device_name:
			device.select(device.item_count - 1)
	device.item_selected.connect(func(index: int): set_input_device(device.get_item_text(index)))
	panel.add_child(device)
	var deafen := CheckButton.new()
	deafen.text = "Mute all incoming voice"
	deafen.button_pressed = deafened
	deafen.toggled.connect(set_deafened)
	panel.add_child(deafen)
	for id: int in peers:
		var mute := CheckButton.new()
		mute.text = "Mute player %d" % id
		mute.button_pressed = bool(muted_peers.get(id, false))
		_bind_peer_mute(mute, id)
		panel.add_child(mute)
	return panel

func _bind_peer_mute(button: CheckButton, id: int) -> void:
	button.toggled.connect(func(value: bool): set_peer_muted(id, value))

func _retire_player(speaker: Dictionary) -> void:
	var player: AudioStreamPlayer = speaker.player
	if not is_instance_valid(player): return
	var playback: AudioStreamPlayback = speaker.playback
	if playback != null: _retired_playbacks[playback.get_instance_id()] = weakref(playback)
	player.stop()
	player.stream = null
	player.queue_free()
	speaker.playback = null

func _reset_playback(speaker: Dictionary) -> void:
	# Godot 4.5.1 can orphan pending generator playback when stop/play repeats
	# before the audio-server update. Retire that emitter; start its replacement lazily.
	if speaker.playback == null: return
	var old: AudioStreamPlayer = speaker.player
	var generator: AudioStream = old.stream
	var volume: float = old.volume_db
	_retire_player(speaker)
	var player := AudioStreamPlayer.new()
	player.stream = generator
	player.bus = "Voice"
	player.volume_db = volume
	add_child(player)
	speaker.player = player

func _ensure_playback(speaker: Dictionary) -> void:
	if speaker.playback != null: return
	speaker.player.play()
	speaker.playback = speaker.player.get_stream_playback()

func pending_playback_count() -> int:
	# Synchronous weak observations must not themselves retain retired audio.
	for identity in _retired_playbacks.keys():
		if _retired_playbacks[identity].get_ref() == null: _retired_playbacks.erase(identity)
	return _retired_playbacks.size()

func shutdown_and_drain(timeout_seconds: float = 1.5) -> bool:
	configure_session(false)
	var deadline := Time.get_ticks_msec() + int(maxf(0.1, timeout_seconds) * 1000)
	await get_tree().process_frame
	await get_tree().process_frame
	while pending_playback_count() > 0:
		if Time.get_ticks_msec() >= deadline:
			push_error("Voice shutdown timed out with %d playback references" % pending_playback_count())
			return false
		await get_tree().process_frame
	return true

func _exit_tree() -> void:
	cancel_push_to_talk()
	if _native_capture != null: _native_capture.call("stop_capture")
	for speaker: Dictionary in _speakers.values():
		_retire_player(speaker)
		speaker.decoder = null
	_speakers.clear()
	if is_instance_valid(_microphone): _microphone.stop()
	var bus := AudioServer.get_bus_index("WorldRiseMic")
	if bus >= 0 and _capture:
		for index in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
			if AudioServer.get_bus_effect(bus, index) == _capture: AudioServer.remove_bus_effect(bus, index)

func _clear_capture() -> void:
	if _native_capture != null: _native_capture.call("clear_buffer")
	elif _capture: _capture.clear_buffer()

func _capture_running() -> bool:
	return bool(_native_capture.call("is_running")) if _native_capture != null else (is_instance_valid(_microphone) and _microphone.playing)

func _available_capture_frames() -> int:
	return int(_native_capture.call("get_frames_available")) if _native_capture != null else (_capture.get_frames_available() if _capture else 0)

func text_input_focused() -> bool:
	if not is_inside_tree(): return false
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit
