extends Button
var accent=Color.WHITE
var glyph=""
var selected=false
var learned=false
var available=false
var blocked=false

func _ready() -> void:
	flat=true
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _draw() -> void:
	var center=size*.5
	var radius=minf(size.x,size.y)*.46
	var polygon=PackedVector2Array()
	for i in range(6):
		polygon.append(center+Vector2(cos(i*TAU/6),sin(i*TAU/6))*radius)
	var fill=Color("#18242ae8").lerp(accent,.42 if learned else .13)
	if blocked: fill=Color("#20272bdb")
	draw_colored_polygon(polygon,fill)
	polygon.append(polygon[0])
	var edge=Color("#eddbac") if selected or has_focus() else accent if learned or available else Color("#53616a")
	draw_polyline(polygon,edge,3.5 if selected else 2.0,true)
	if is_hovered(): draw_polyline(polygon,Color("#f5e5c0"),3,true)
	var ink=Color("#f1ece0") if learned or available else Color("#83919a")
	if glyph=="sword":
		draw_line(center+Vector2(0,-19),center+Vector2(0,14),ink,4,true)
		draw_line(center+Vector2(-10,8),center+Vector2(10,8),ink,3,true)
		draw_line(center+Vector2(-4,21),center+Vector2(4,21),ink,3,true)
	elif glyph=="form":
		draw_circle(center+Vector2(0,-17),4,ink)
		draw_polyline(PackedVector2Array([center+Vector2(-12,-3),center+Vector2(2,-10),center+Vector2(6,3),center+Vector2(-8,19)]),ink,3,true)
		draw_polyline(PackedVector2Array([center+Vector2(6,3),center+Vector2(18,17)]),ink,3,true)
	elif glyph=="water":
		var drop=PackedVector2Array([center+Vector2(0,-22),center+Vector2(-13,1),center+Vector2(-10,15),center+Vector2(0,20),center+Vector2(10,15),center+Vector2(13,1)])
		draw_colored_polygon(drop,ink)
	else:
		var font=get_theme_default_font()
		draw_string(font,center-Vector2(font.get_string_size(glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x*.5,-8),glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,22,ink)
	if blocked:
		draw_line(center+Vector2(-22,-22),center+Vector2(22,22),Color("#68747c"),2,true)
