extends Control
const Shape=preload("res://scripts/rise_shape.gd")
const West=preload("res://scripts/west_islands.gd")
var game:Control
var selected="arrival"
var heading:Label
var status:Label
var destinations:VBoxContainer
var scroll:ScrollContainer
var travel_button:Button
var terrain:Array=[]
var plot=Rect2()
var scale_factor=1.0
var origin=Vector2.ZERO
var elapsed=0.0
var signature=""
var last_size=Vector2.ZERO
func configure(owner_game:Control) -> void:
	game=owner_game;mouse_filter=Control.MOUSE_FILTER_STOP
	heading=game.label("FLOOR ONE · CHECKPOINT MAP",22,Color("#e9c894"));heading.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(heading)
	status=game.label("",16);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(status)
	scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
	destinations=VBoxContainer.new();destinations.size_flags_horizontal=Control.SIZE_EXPAND_FILL;destinations.add_theme_constant_override("separation",6);scroll.add_child(destinations)
	for index in range(game.worldrise.checkpoints.sites().size()):
		var entry=game.worldrise.checkpoints.sites()[index]
		var button=game.button("%d · %s"%[index+1,entry.title],func():choose(entry.id))
		button.add_theme_font_size_override("font_size",16);button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;button.custom_minimum_size.y=34;destinations.add_child(button)
	travel_button=game.button("Travel to selected",func():game.worldrise.checkpoints.travel(selected));travel_button.add_theme_font_size_override("font_size",18);add_child(travel_button)
	visible=false
func choose(id:String) -> void:
	selected=id;signature="";refresh_status();queue_redraw()
func _process(delta:float) -> void:
	if not is_visible_in_tree():return
	if size!=last_size:
		last_size=size;layout();queue_redraw()
	elapsed+=delta
	if elapsed>=.25:elapsed=0;refresh_status()
func layout() -> void:
	heading.position=Vector2.ZERO;heading.size=Vector2(size.x,28)
	status.position=Vector2(0,32);status.size=Vector2(size.x,36)
	plot=Rect2(0,76,size.x*.69,size.y-80)
	var sidebar=Vector2(size.x*.72,76)
	scroll.position=sidebar;scroll.size=Vector2(size.x-sidebar.x,size.y-134)
	travel_button.position=Vector2(sidebar.x,size.y-49);travel_button.size=Vector2(scroll.size.x,45)
	scale_factor=minf((plot.size.x-30)/740.0,(plot.size.y-48)/500.0)
	origin=plot.get_center()-Vector2(-120,0)*scale_factor
func project(at:Vector2) -> Vector2:return origin+at*scale_factor
func refresh_status() -> void:
	var checkpoints=game.worldrise.checkpoints;var source=checkpoints.nearby();var reason=checkpoints.block_reason()
	var locked=selected not in checkpoints.unlocked
	var next_signature=selected+str(source.get("id",""))+reason+str(game.player.position)+str(checkpoints.unlocked)
	if next_signature==signature:return
	signature=next_signature
	status.text=reason if not reason.is_empty() else "Near "+str(source.title)+" · choose another checkpoint on the map or list."
	if locked:status.text="Visit the selected checkpoint to unlock it. "+reason
	status.modulate=Color("#efb5a5") if not reason.is_empty() else Color("#a9ded7")
	travel_button.disabled=locked or not reason.is_empty() or selected==source.get("id","")
	var sites=checkpoints.sites()
	for index in range(sites.size()):
		var button=destinations.get_child(index)
		var available=sites[index].id in checkpoints.unlocked
		button.text="%d · %s%s"%[index+1,sites[index].title,"" if available else " · Locked"]
		button.modulate=Color.WHITE if available else Color("#8b9298")
		button.add_theme_stylebox_override("normal",game.style(Color("#5a4a2fee") if sites[index].id==selected else Color("#203a33ee"),Color("#e2c277") if sites[index].id==selected else Color("#66877a")))
	queue_redraw()
func _gui_input(event:InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and plot.has_point(event.position):
		for entry in game.worldrise.checkpoints.sites():
			if event.position.distance_to(project(Vector2(entry.at[0],entry.at[1])))<=20:choose(entry.id);accept_event();return
func _draw() -> void:
	if game==null or plot.size.y<=0:return
	draw_style_box(game.style(Color("#14252aee"),Color("#66877a")),plot)
	if terrain.is_empty():
		for x in range(-232,240,16):
			for z in range(-232,240,16):
				if Vector2(x,z).length()>232:continue
				var height=Shape.height(Vector3(x,0,z))
				terrain.append([Vector2(x,z),Color("#426940").lerp(Color("#b2b28a"),clampf(height/100.0,0,1))])
	for cell in terrain:draw_rect(Rect2(project(cell[0])-Vector2.ONE*8*scale_factor,Vector2.ONE*16.2*scale_factor),cell[1])
	draw_arc(project(Vector2.ZERO),240*scale_factor,0,TAU,128,Color("#b3c9bf"),2,true)
	var woods=PackedVector2Array()
	for i in range(64):woods.append(project(Vector2(Shape.spec.forest.at[0],Shape.spec.forest.at[1])+Vector2(cos(i*TAU/64)*Shape.spec.forest.radii[0],sin(i*TAU/64)*Shape.spec.forest.radii[1])))
	draw_colored_polygon(woods,Color("#214d39d9"))
	var road=PackedVector2Array()
	for at in Shape.spec.trail:road.append(project(Vector2(at[0],at[1])))
	draw_polyline(road,Color("#d4bf92"),3,true)
	for link in West.links():draw_line(project(Vector2(link[0].x,link[0].z)),project(Vector2(link[1].x,link[1].z)),Color("#d0bd96"),maxf(2,4.8*scale_factor),true)
	for island in West.ISLANDS:
		var at=project(Vector2(island.center.x,island.center.z));draw_circle(at,island.radius*scale_factor,Color("#648755"));draw_arc(at,island.radius*scale_factor,0,TAU,40,Color("#b3c9bf"),2,true)
	var font=get_theme_default_font()
	draw_string(font,plot.position+Vector2(12,23),"N ↑",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#e2e9df"))
	draw_string(font,project(Vector2(-100,-175)),"ELDERWOOD",HORIZONTAL_ALIGNMENT_CENTER,-1,13,Color("#cbe0c2"))
	draw_string(font,project(Vector2(146,146))+Vector2(-15,18),"GUILD",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#efe1b9"))
	var sites=game.worldrise.checkpoints.sites()
	for index in range(sites.size()):
		var entry=sites[index];var at=project(Vector2(entry.at[0],entry.at[1]));var color=Color("#f6d17f") if entry.id==selected else Color("#8ae4df")
		if entry.id not in game.worldrise.checkpoints.unlocked:color=Color("#858b92")
		draw_circle(at,9,color);draw_arc(at,12,0,TAU,24,color,1.5,true)
		draw_string(font,at+Vector2(-4,5),str(index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#15272a"))
	if game.worldrise.active():
		var at=project(Vector2(game.player.position.x,game.player.position.z))
		draw_colored_polygon(PackedVector2Array([at+Vector2(0,-8),at+Vector2(-6,6),at+Vector2(6,6)]),Color.WHITE)
	draw_string(font,Vector2(plot.position.x+12,plot.end.y-12),"White: you   ·   grey: visit to unlock   ·   cyan: unlocked",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("#d2ddd5"))
