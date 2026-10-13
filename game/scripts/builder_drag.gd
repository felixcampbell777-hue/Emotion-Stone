extends Button
var payload:Dictionary
func _get_drag_data(_position:Vector2):
 var preview=Label.new(); preview.text=text; set_drag_preview(preview)
 return payload.duplicate(true)
