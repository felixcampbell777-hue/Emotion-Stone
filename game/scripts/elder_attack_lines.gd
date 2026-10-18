extends Node3D
## Temporary Elder-only visualization. All dimensions come from its damage checks.
var boss:Node3D
var warning:MeshInstance3D
var impact:MeshInstance3D
var flash_left=0.0
var hit_kind=""
func configure(owner_boss:Node3D) -> void:
	boss=owner_boss
	warning=make_line(Color("#ffd05c"));impact=make_line(Color("#ff493f"))
func make_line(color:Color) -> MeshInstance3D:
	var node=MeshInstance3D.new();add_child(node)
	var material=StandardMaterial3D.new();material.albedo_color=color;material.emission_enabled=true;material.emission=color;material.emission_energy_multiplier=1.5;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.cull_mode=BaseMaterial3D.CULL_DISABLED
	node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.visible=false
	return node
func hit(kind:String) -> void:
	hit_kind=kind;flash_left=.14
func sector(radius:float,cone:float) -> PackedVector2Array:
	var points=PackedVector2Array([Vector2.ZERO]);var half=acos(cone)
	for i in range(49):
		var angle=lerpf(-half,half,i/48.0);points.append(Vector2(sin(angle),cos(angle))*radius)
	return points
func circle(radius:float) -> PackedVector2Array:
	var points=PackedVector2Array()
	for i in range(96):points.append(Vector2(sin(i*TAU/96),cos(i*TAU/96))*radius)
	return points
func outline(kind:String,preview:bool) -> PackedVector2Array:
	if kind=="sweep":return sector(boss.SWEEP_REACH,boss.SWEEP_CONE)
	if kind=="slam":return circle(boss.SLAM_REACH)
	var points=sector(boss.RUSH_REACH,boss.RUSH_CONE)
	if preview:
		# Swept union of the forward contact sector and the committed rush travel.
		var heading=boss.direction;var finish=boss.position+heading*boss.RUSH_SPEED*boss.RUSH_SECONDS
		var radial=Vector2(finish.x/20.5,finish.z/22.5)
		if radial.length()>1:radial=radial.normalized();finish=Vector3(radial.x*20.5,0,radial.y*22.5)
		var travel=maxf(0,(finish-boss.position).dot(heading))
		for point in points.duplicate():points.append(point+Vector2(0,travel))
		points=Geometry2D.convex_hull(points)
	return points
func draw_line(node:MeshInstance3D,kind:String,preview:bool) -> void:
	node.rotation.y=atan2(boss.direction.x,boss.direction.z)
	var signature=kind+str(preview)+(str(boss.position)+str(boss.direction) if kind=="rush" and preview else "")
	node.visible=true
	if node.get_meta("shape","")==signature:return
	node.set_meta("shape",signature)
	var points=outline(kind,preview);var mesh=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var world_points=PackedVector3Array()
	for point in points:
		world_points.append(Vector3(point.x,.055,point.y))
	for i in range(world_points.size()):
		var a=world_points[i];var b=world_points[(i+1)%world_points.size()]
		if a.distance_squared_to(b)<.000001:continue
		var cross=Vector3.UP.cross((b-a).normalized())*.055
		for vertex in [a-cross,a+cross,b+cross,a-cross,b+cross,b-cross]:mesh.surface_add_vertex(vertex)
	mesh.surface_end();node.mesh=mesh;node.visible=true
func update(delta:float) -> void:
	flash_left=maxf(0,flash_left-delta)
	warning.visible=false;impact.visible=false
	if boss.health<=0 or boss.state=="forming":return
	var pending=boss.strikes<(2 if boss.attack_kind=="sweep" else 1)
	if boss.attack_kind=="rush":pending=not boss.lunge_hit
	if (boss.state=="windup" or (boss.state=="strike" and pending)) and boss.attack_kind in ["sweep","slam","rush"]:draw_line(warning,boss.attack_kind,true)
	if boss.state=="strike" and boss.attack_kind=="rush" and not boss.lunge_hit:draw_line(impact,"rush",false)
	elif flash_left>0 and hit_kind in ["sweep","slam","rush"]:draw_line(impact,hit_kind,false)
