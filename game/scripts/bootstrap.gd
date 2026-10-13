extends Node
func _ready() -> void:
	var args=OS.get_cmdline_user_args()
	var builder="--map-builder" in args or "--builder-checks" in args or "--builder-capture" in args or OS.get_executable_path().get_file().to_lower()=="mapbuilder.exe"
	var scene="res://scenes/map_builder.tscn" if builder else "res://scenes/main.tscn"
	get_tree().root.call_deferred("add_child",load(scene).instantiate())
	queue_free()
