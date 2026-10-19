extends SceneTree
func _initialize() -> void:
	print("VOICE DEVICE INVENTORY driver=", AudioServer.get_driver_name(), " mix_rate=", AudioServer.get_mix_rate(), " input=", AudioServer.get_input_device_list(), " selected_input=", AudioServer.input_device, " output=", AudioServer.get_output_device_list(), " selected_output=", AudioServer.output_device)
	quit()
