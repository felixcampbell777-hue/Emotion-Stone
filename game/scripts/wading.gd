extends RefCounted
## Coast shelves deepen continuously; pools deepen from their nearest bank.
const SHOULDER=1.35
static func enabled(world:Node3D) -> bool:return world.definition.get("wading",false)
static func level(world:Node3D) -> float:return -.115 if world.definition.sea else -.035
static func depth(world:Node3D,at:Vector3) -> float:
	if world.definition.get("id","")=="wr_floor_02":return preload("res://scripts/swamp_shape.gd").depth(at)
	if not enabled(world):return 0
	if world.terrain_at(int(floor(at.x)),int(floor(at.z)))!="water":return 0
	var point=Vector2(at.x,at.z)
	for region in world.definition.terrain_regions:
		if region.kind!="water":continue
		var r=region.rect;var rect=Rect2(r[0],r[1],r[2],r[3])
		if not rect.has_point(point):continue
		if world.definition.sea:return maxf(0,point.x-rect.position.x)*.36
		return maxf(0,minf(minf(point.x-rect.position.x,rect.end.x-point.x),minf(point.y-rect.position.y,rect.end.y-point.y)))*.55
	return 0
static func speed(world:Node3D,at:Vector3) -> float:return lerpf(1,.25,clampf(depth(world,at)/SHOULDER,0,1))
static func tick(game:Control) -> void:
	if not enabled(game.current_world) or not game.player.input_enabled:return
	var d=depth(game.current_world,game.player.position)
	if game.map_id=="wr_floor_02":
		if d>SHOULDER and -game.player.position.y>SHOULDER:game.player.drown()
		return
	if d>0 and level(game.current_world)-game.player.position.y>SHOULDER:game.player.drown()
