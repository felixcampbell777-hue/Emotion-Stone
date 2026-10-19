extends SceneTree
const Codec = preload("res://scripts/voice/voice_codec.gd")
const Voice = preload("res://scripts/voice/world_rise_voice.gd")
var service: Node
var packets := 0
var peak := 0.0
var decoder: Object
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	ProjectSettings.set_setting("audio/driver/enable_input", true)
	service = Voice.new()
	root.add_child(service)
	service.configure_session(true, 1)
	service.set_input_muted(false)
	service.set_push_to_talk("proximity", true)
	decoder = Codec.configured_native("AudioStreamOpusChunked")
	service.outgoing_frame.connect(_frame)
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		await process_frame
	service.cancel_push_to_talk()
	if not _check(service._ptt == ""): return
	service.set_input_muted(true)
	if not _check(not service._capture_running()): return
	print("VOICE DEVICE CHECK: driver=%s capture packets=%d decoded_peak=%f; PTT cancel and microphone stop passed. Audible microphone/playback quality requires human listening." % [AudioServer.get_driver_name(), packets, peak])
	service.queue_free()
	await process_frame
	print("VOICE FIXTURE CHECKS evaluated=", _evaluated_checks)
	quit()

func _frame(_channel: String, _seq: int, packet: PackedByteArray) -> void:
	packets += 1
	for sample: Vector2 in Codec.decode(decoder, packet):
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))

var _evaluated_checks := 0
func _check(condition: bool, detail: String = "") -> bool:
	_evaluated_checks += 1
	# Exported release templates remove native assert(); this check always executes.
	if "--voice-fixture-force-failure" in OS.get_cmdline_user_args(): condition = false
	if condition: return true
	push_error("VOICE FIXTURE FAIL check %d: %s" % [_evaluated_checks, detail])
	quit(1)
	return false
