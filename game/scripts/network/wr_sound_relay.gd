extends RefCounted
var runtime:Node
func _init(owner_runtime:Node) -> void:runtime=owner_runtime
func play(event_id:String,at:Vector3=Vector3.ZERO,_context:Dictionary={}) -> bool:
	runtime.presentation.emit(event_id,at);return true
