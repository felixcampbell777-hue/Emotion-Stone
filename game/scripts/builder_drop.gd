extends TextureRect
var editor
func _can_drop_data(_position:Vector2,data:Variant) -> bool:
 return data is Dictionary and data.has("tool")
func _drop_data(position:Vector2,data:Variant) -> void:
 editor.place(data,editor.ground_point(position))
func _gui_input(event:InputEvent) -> void:
 editor.canvas_input(event)
