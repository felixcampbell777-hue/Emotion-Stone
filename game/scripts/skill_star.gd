extends "res://scripts/skill_hex.gd"
func _draw() -> void:
	var at=size*.5
	var ink=accent if learned else Color("#c2d4df")
	for i in range(5,0,-1):draw_circle(at,5+i*3,Color(ink,.035 if learned else .015))
	draw_line(at-Vector2(12,0),at+Vector2(12,0),Color(ink,.55),1,true)
	draw_line(at-Vector2(0,12),at+Vector2(0,12),Color(ink,.55),1,true)
	draw_circle(at,5 if learned else 3,ink)
	if selected or is_hovered() or has_focus():draw_arc(at,16,0,TAU,32,Color("#f0dcac"),1.5,true)
