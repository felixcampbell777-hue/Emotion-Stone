extends RefCounted
## Gameplay support wins over water: standing on the raft must sound like timber.
static func surface(game:Node, at:Vector3) -> String:
	var map_id=String(game.get("map_id"))
	if map_id=="wr_boss_chamber":return "stone"
	if map_id=="wr_floor_02":
		var fen=load("res://scripts/swamp_shape.gd")
		if fen.raft_surface(at):return "wood"
		var arrival:Vector2=fen.arrival()
		if Vector2(at.x,at.z).distance_to(arrival)<7:return "metal"
		if fen.depth(at)>.07:return "water"
		return "mud"
	if map_id=="wr_floor_01":
		if Vector2(at.x,at.z).length()<20:return "metal"
		if Vector2(at.x,at.z).length()>232:
			var west=load("res://scripts/west_islands.gd")
			for link in west.links():
				var a=Vector2(link[0].x,link[0].z);var b=Vector2(link[1].x,link[1].z)
				if Vector2(at.x,at.z).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(at.x,at.z),a,b))<2.4:return "wood"
			if Vector2(at.x,at.z).length()<241:return "metal"
		var shape=load("res://scripts/rise_shape.gd")
		var guild=shape.spec.guild
		if Vector2(at.x-guild.at[0],at.z-guild.at[1]).length()<12:return "wood"
		if Vector2(at.x+168,at.z+125).length()<9:return "stone"
		if shape.trail_distance(at)<2.5:return "dirt"
	return "grass"
