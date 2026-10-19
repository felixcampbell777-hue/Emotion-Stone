class_name WorldRiseNativeCapture
extends RefCounted
## macOS-only capture loader. Only the pinned shipped payload is materialized.
const PAYLOAD := "res://addons/world_rise_mic/libs/world_rise_mic.macos.universal.bin"
const EXPECTED_SHA256 := "6f77395a4484d176edab8e94cb920dca6d44ed40c6c87f285943528007fb2c51"
static var load_error := ""

static func create() -> Object:
	if OS.get_name() != "macOS":
		return null
	if ClassDB.class_exists("WorldRiseMicCapture"):
		return ClassDB.instantiate("WorldRiseMicCapture")
	if not FileAccess.file_exists(PAYLOAD) or FileAccess.get_sha256(PAYLOAD) != EXPECTED_SHA256:
		load_error = "Microphone native payload missing or failed integrity verification"
		return null
	var cache := "user://voice-native/" + EXPECTED_SHA256
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache)) != OK:
		load_error = "Cannot prepare microphone runtime cache"
		return null
	var binary := cache.path_join("world_rise_mic.dylib")
	if not FileAccess.file_exists(binary) or FileAccess.get_sha256(binary) != EXPECTED_SHA256:
		var source := FileAccess.open(PAYLOAD, FileAccess.READ)
		var target := FileAccess.open(binary, FileAccess.WRITE)
		if source == null or target == null:
			load_error = "Cannot materialize microphone runtime"
			return null
		target.store_buffer(source.get_buffer(source.get_length()))
		target.close()
	var descriptor := ConfigFile.new()
	descriptor.set_value("configuration", "entry_symbol", "world_rise_mic_init")
	descriptor.set_value("configuration", "compatibility_minimum", "4.5")
	descriptor.set_value("libraries", "macos", ProjectSettings.globalize_path(binary))
	var path := cache.path_join("world_rise_mic.gdextension")
	if descriptor.save(path) != OK:
		load_error = "Cannot prepare microphone extension descriptor"
		return null
	var result := GDExtensionManager.load_extension(path)
	if result not in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED] or not ClassDB.class_exists("WorldRiseMicCapture"):
		load_error = "Microphone native extension could not load"
		return null
	return ClassDB.instantiate("WorldRiseMicCapture")
