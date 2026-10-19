extends SceneTree
const Voice = preload("res://scripts/voice/world_rise_voice.gd")
class FakeMic extends RefCounted:
	var active := false
	var starts := 0
	func start_capture(_request: bool) -> bool: active = true; starts += 1; return true
	func stop_capture() -> void: active = false
	func is_running() -> bool: return active
	func clear_buffer() -> void: pass
	func get_status() -> String: return "test"
	func get_permission() -> String: return "authorized"
	func get_frames_available() -> int: return 0
	func get_sample_rate() -> int: return 48000
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var voice := Voice.new()
	root.add_child(voice)
	var microphone := FakeMic.new()
	voice._native_capture = microphone
	voice.configure_session(true, 1)
	voice.set_input_muted(false)
	var field := LineEdit.new()
	root.add_child(field)
	field.grab_focus()
	if not _check(voice.text_input_focused()): return
	voice.set_push_to_talk("proximity", true)
	voice.set_push_to_talk("group", true)
	if not _check(microphone.starts == 0 and not microphone.active and voice._ptt == "", "Typing V/B must not start capture"): return
	field.release_focus()
	voice.set_push_to_talk("proximity", true)
	if not _check(microphone.active and voice._ptt == "proximity"): return
	field.grab_focus()
	voice._process(0.016)
	if not _check(not microphone.active and voice._ptt == "", "Entering editable text cancels held speech"): return
	field.release_focus()
	voice._process(0.016)
	if not _check(not microphone.active and voice._ptt == "", "Leaving field must require a fresh press"): return
	var text := TextEdit.new()
	root.add_child(text)
	text.grab_focus()
	voice.set_push_to_talk("group", true)
	if not _check(not microphone.active): return
	voice.queue_free()
	field.queue_free()
	text.queue_free()
	await process_frame
	print("VOICE TEXT FOCUS PASS: LineEdit/TextEdit V/B suppressed, held capture stops on focus, fresh press required")
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
