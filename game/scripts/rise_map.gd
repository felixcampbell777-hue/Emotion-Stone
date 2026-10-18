extends Control
const Shape=preload("res://scripts/rise_shape.gd")
const West=preload("res://scripts/west_islands.gd")
var game:Control
var selected="arrival"
var heading:Label
var status:Label
var travel_button:Button
var floor_one:Button
var floor_two:Button
var last_floor=""
var swamp_texture:ImageTexture
var terrain:Array=[]
var plot=Rect2()
var scale_factor=1.0
var origin=Vector2.ZERO
var elapsed=0.0
var signature=""
var last_size=Vector2.ZERO
func configure(owner_game:Control) -> void:
	game=owner_game;mouse_filter=Control.MOUSE_FILTER_STOP
	heading=game.label("MAP",22,Color("#e9c894"));heading.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(heading)
	status=game.label("",16);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(status)
	travel_button=game.button("Travel to selected",func():game.worldrise.checkpoints.travel(selected));travel_button.add_theme_font_size_override("font_size",18);add_child(travel_button)
	floor_one=game.button("Floor 1",func():game.worldrise.swamp.travel_floor(1));add_child(floor_one)
	floor_two=game.button("Floor 2",func():game.worldrise.swamp.travel_floor(2));add_child(floor_two)
	visible=false
func choose(id:String) -> void:
	if id not in game.worldrise.checkpoints.current_unlocked():return
	selected=id;signature="";refresh_status();queue_redraw()
func _process(delta:float) -> void:
	if not is_visible_in_tree():return
	if size!=last_size or last_floor!=game.map_id:
		last_size=size;last_floor=game.map_id;layout();queue_redraw()
	elapsed+=delta
	if elapsed>=.25:elapsed=0;refresh_status()
func layout() -> void:
	heading.position=Vector2.ZERO;heading.size=Vector2(size.x,28)
	status.position=Vector2(0,32);status.size=Vector2(size.x,36)
	plot=Rect2(0,76,size.x,size.y-134)
	travel_button.position=Vector2(size.x*.5-125,size.y-49);travel_button.size=Vector2(250,45)
	floor_one.position=Vector2(0,size.y-49);floor_one.size=Vector2(110,45);floor_two.position=Vector2(120,size.y-49);floor_two.size=Vector2(110,45)
	var swamp=game.worldrise.swamp.active()
	scale_factor=minf((plot.size.x-30)/(500.0 if swamp else 740.0),(plot.size.y-48)/500.0)
	origin=plot.get_center() if swamp else plot.get_center()-Vector2(-120,0)*scale_factor
func project(at:Vector2) -> Vector2:return origin+at*scale_factor
func refresh_status() -> void:
	var checkpoints=game.worldrise.checkpoints;var source=checkpoints.nearby();var reason=checkpoints.block_reason()
	var locked=selected not in checkpoints.current_unlocked()
	floor_one.visible=game.worldrise.swamp.at_platform();floor_two.visible=floor_one.visible
	floor_one.disabled=not reason.is_empty() or not game.worldrise.swamp.active()
	floor_two.disabled=not reason.is_empty() or game.worldrise.swamp.active() or not game.worldrise.swamp.unlocked_floor_two()
	floor_two.tooltip_text="Defeat the Elder to unlock this floor." if not game.worldrise.swamp.unlocked_floor_two() else "Travel to Floor Two and save progress."
	var next_signature=selected+str(source.get("id",""))+reason+str(game.player.position)+str(checkpoints.current_unlocked())
	if next_signature==signature:return
	signature=next_signature
	status.text=reason if not reason.is_empty() else "Select a discovered marker to travel."
	if locked:status.text=reason if not reason.is_empty() else "Select a discovered marker to travel."
	status.modulate=Color("#efb5a5") if not reason.is_empty() else Color("#a9ded7")
	travel_button.disabled=locked or not reason.is_empty() or selected==source.get("id","")
	queue_redraw()
func _gui_input(event:InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and plot.has_point(event.position):
		for entry in game.worldrise.checkpoints.sites():
			if entry.id not in game.worldrise.checkpoints.current_unlocked():continue
			if event.position.distance_to(project(Vector2(entry.at[0],entry.at[1])))<=20:choose(entry.id);accept_event();return
func _draw() -> void:
	if game==null or plot.size.y<=0:return
	draw_style_box(game.style(Color("#14252aee"),Color("#66877a")),plot)
	if game.worldrise.swamp.active():draw_swamp()
	else:draw_floor_one()
	var sites=game.worldrise.checkpoints.sites()
	for index in range(sites.size()):
		var entry=sites[index]
		if entry.id not in game.worldrise.checkpoints.current_unlocked():continue
		var at=project(Vector2(entry.at[0],entry.at[1]));var color=Color("#f6d17f") if entry.id==selected else Color("#8ae4df")
		draw_circle(at,9,color);draw_arc(at,12,0,TAU,24,color,1.5,true)
	if game.worldrise.active() or game.worldrise.swamp.active():
		var at=project(Vector2(game.player.position.x,game.player.position.z))
		draw_colored_polygon(PackedVector2Array([at+Vector2(0,-8),at+Vector2(-6,6),at+Vector2(6,6)]),Color.WHITE)

func draw_floor_one() -> void:
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

func draw_swamp() -> void:
	if swamp_texture==null:
		var field=preload("res://scripts/swamp_shape.gd");var image=Image.create(241,241,false,Image.FORMAT_RGBA8)
		for z in range(241):
			for x in range(241):
				if Vector2(x-120,z-120).length()>120:image.set_pixel(x,z,Color.TRANSPARENT);continue
				var depth=maxf(0,-field.vertex(x,z));var color=Color("#687d50") if depth==0 else Color("#647d4b") if depth<1.3 else Color("#1b392a")
				image.set_pixel(x,z,color)
		swamp_texture=ImageTexture.create_from_image(image)
	draw_texture_rect(swamp_texture,Rect2(project(Vector2(-240,-240)),Vector2.ONE*480*scale_factor),false)
	draw_arc(project(Vector2.ZERO),240*scale_factor,0,TAU,128,Color("#b3c9bf"),2,true)
