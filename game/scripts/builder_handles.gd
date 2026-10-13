extends Control
var editor
func _draw() -> void:
	if editor==null or editor.camera==null: return
	var points=editor.transform_screen_points()
	if not points.is_empty():
		var outline=PackedVector2Array([points[0],points[2],points[4],points[6],points[0]])
		draw_polyline(outline,Color("#ffdf80"),2.5,true)
		if editor.selected_kind=="sculpted_terrain": draw_line(points[4],points[6],Color("#78ddda"),3,true)
		for p in points:
			draw_rect(Rect2(p-Vector2(6,6),Vector2(12,12)),Color("#ffdf80"))
			draw_rect(Rect2(p-Vector2(6,6),Vector2(12,12)),Color("#17232a"),false,1.5)
	if editor.creating_terrain:
		var a=editor.creation_from; var b=editor.creation_to
		var outline=PackedVector2Array()
		for p in [a,Vector2(b.x,a.y),b,Vector2(a.x,b.y),a]: outline.append(editor.camera.unproject_position(Vector3(p.x,editor.creation_y,p.y)))
		draw_polyline(outline,Color("#78ddda"),2.5,true)
func _process(_delta:float) -> void:
	queue_redraw()
