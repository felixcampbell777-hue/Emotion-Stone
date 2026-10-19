extends SceneTree
const Native = preload("res://scripts/voice/native_capture.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var capture: Object = Native.create()
	if not _check(capture != null, Native.load_error): return
	if not _check(not capture.call("is_running")): return
	if not _check(capture.call("get_frames_available") == 0): return
	var permission_before: String = capture.call("get_permission")
	var driver_before := AudioServer.get_driver_name()
	# No prompt in automated checks. Only an existing grant permits live input.
	var started: bool = capture.call("start_capture", false)
	print("NATIVE MIC permission=", permission_before, " started=", started, " status=", capture.call("get_status"), " output_driver=", driver_before)
	if not _check(capture.call("get_permission") == permission_before, "Never change OS permission"): return
	if not _check(AudioServer.get_driver_name() == driver_before, "Capture failure must preserve output driver"): return
	if started:
		await create_timer(0.4).timeout
		if not _check(capture.call("get_frames_available") <= 19200): return
		var frames := int(capture.call("get_sample_rate") * 0.02)
		var pcm: PackedVector2Array = capture.call("get_buffer", frames)
		print("NATIVE MIC capture_rate=", capture.call("get_sample_rate"), " frames=", pcm.size(), " dropped=", capture.call("get_dropped_frames"))
	capture.call("stop_capture")
	if not _check(not capture.call("is_running")): return
	if not _check(capture.call("get_frames_available") == 0): return
	capture.call("set_device", "World Rise unavailable test microphone")
	if not _check(not capture.call("start_capture", false)): return
	capture.call("set_device", "Default")
	capture.call("stop_capture")
	if not _check(AudioServer.get_driver_name() == driver_before): return
	print("NATIVE MIC PASS: optional load, permission-safe start/failure, bounded buffers, stop/reinit/device failure preserves output")
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
