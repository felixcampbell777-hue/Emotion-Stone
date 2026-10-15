extends Control
var tree:Control
func _draw() -> void:
	draw_style_box(tree.game.style(Color("#101923e8"),Color("#53697b"),8),Rect2(Vector2.ZERO,size))
	for i in range(150):
		var at=Vector2(fposmod(i*137.51,size.x),fposmod(i*83.17,size.y))
		draw_circle(at,1.0 if i%5 else 1.7,Color(.6,.78,1,.18 if i%5 else .38))
	for id in tree.cards:
		if not tree.cards[id].visible:continue
		var child=tree.cards[id].position+Vector2(0,21)
		for parent in tree.game.progression.skill(id).requires:
			if not tree.cards.has(parent) or not tree.cards[parent].visible:continue
			var start=tree.cards[parent].position+Vector2(0,21)
			var tint=Color("#99cce4") if tree.game.progression.has(id) else Color("#506a7e")
			draw_line(start,child,Color(tint,.12),8,true);draw_line(start,child,tint,1.5,true)
