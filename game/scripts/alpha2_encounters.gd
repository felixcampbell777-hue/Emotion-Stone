extends RefCounted
## Bounded situations. Owns goals/attack turns, never damage, action clocks or rewards.
var game:Node
var world:Node3D
var groups:Array=[]
var navigation:AStarGrid2D
var clock=0.0
var routes:Dictionary={}
func build(owner:Node) -> void:
	game=owner;world=game.current_world;groups.clear();routes.clear();navigation=null;clock=0
	var plans=JSON.parse_string(FileAccess.get_file_as_string("res://content/alpha2_regions.json"))
	for source in plans.get(game.map_id,{}).get("groups",[]):
		var group=source.duplicate(true);group.actors=[];group.awake=false;group.triggered=false;group.turn=0;group.next_turn=0.0;group.last_health={}
		for member in group.members:
			for enemy in game.enemies:
				if enemy.definition.id!=member.id or enemy.health<=0:continue
				enemy.encounter_owned=true;enemy.encounter_goal=enemy.position;enemy.encounter_speed=.45
				group.actors.append(enemy);group.last_health[enemy.get_instance_id()]=enemy.health
				if group.behavior in ["ambush","scavenge"]:enemy.visible=false;enemy.collision_layer=0;enemy.encounter_hidden=true
		groups.append(group)
func point(pair:Array) -> Vector3:return Vector3(pair[0],0,pair[1])
func create_navigation() -> void:
	navigation=AStarGrid2D.new();var b=world.bounds
	navigation.region=Rect2i(int(b.position.x)+1,int(b.position.y)+1,int(b.size.x)-2,int(b.size.y)-2);navigation.cell_size=Vector2.ONE;navigation.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;navigation.update()
	var query=PhysicsShapeQueryParameters3D.new();var sphere=SphereShape3D.new();sphere.radius=.42;query.shape=sphere;query.collision_mask=1
	for x in range(navigation.region.position.x,navigation.region.end.x):
		for z in range(navigation.region.position.y,navigation.region.end.y):
			var at=Vector3(x,0,z);var blocked=false
			if world.terrain_at(x,z)=="water" and load("res://scripts/wading.gd").depth(world,at)>1.35:blocked=true
			var height=world.ground_height(at)
			for offset in [Vector3(.24,0,0),Vector3(-.24,0,0),Vector3(0,0,.24),Vector3(0,0,-.24)]:
				if absf(world.ground_height(at+offset)-height)>.45:blocked=true
			if not blocked:
				at.y=world.ground_height(at)+.7;query.transform.origin=at
				blocked=not world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
			navigation.set_point_solid(Vector2i(x,z),blocked)
func nearest(at:Vector3) -> Vector2i:
	var cell=Vector2i(roundi(at.x),roundi(at.z));var best=cell;var distance=INF
	for x in range(cell.x-2,cell.x+3):
		for z in range(cell.y-2,cell.y+3):
			var candidate=Vector2i(x,z)
			if navigation.region.has_point(candidate) and not navigation.is_point_solid(candidate) and Vector2(x,z).distance_to(Vector2(at.x,at.z))<distance:
				best=candidate;distance=Vector2(x,z).distance_to(Vector2(at.x,at.z))
	return best
func steer(enemy:Node3D,goal:Vector3) -> Vector3:
	if ((goal-enemy.position)*Vector3(1,0,1)).length()<.35:return enemy.position
	if navigation==null:create_navigation()
	var key=enemy.get_instance_id();var cache=routes.get(key,{})
	if cache.is_empty() or clock>cache.until or goal.distance_to(cache.goal)>2:
		var start=nearest(enemy.position);var finish=nearest(goal);var path=PackedVector2Array()
		if navigation.region.has_point(start) and navigation.region.has_point(finish) and not navigation.is_point_solid(start) and not navigation.is_point_solid(finish):path=navigation.get_point_path(start,finish)
		cache={"until":clock+.6,"goal":goal,"path":path};routes[key]=cache
	var path:PackedVector2Array=cache.path
	while path.size()>1 and Vector2(enemy.position.x,enemy.position.z).distance_to(path[0])<.65:path.remove_at(0)
	cache.path=path
	if path.is_empty():return enemy.position
	var target=Vector3(path[0].x,0,path[0].y)
	# The last short segment stays within its walkable cell.
	if path.size()==1 and target.distance_to(Vector3(goal.x,0,goal.z))<.6:target=goal
	return target
func tick(delta:float) -> void:
	if not is_instance_valid(world) or world!=game.current_world or not game.player.input_enabled:return
	clock+=delta
	for group in groups:
		var center=point(group.center);var player=game.player.position;player.y=0
		var actors=group.actors.filter(func(e):return is_instance_valid(e) and e.health>0)
		if actors.is_empty():continue
		var hurt=false
		for e in actors:
			var key=e.get_instance_id();hurt=hurt or e.health<int(group.last_health.get(key,e.health));group.last_health[key]=e.health
		var sight=group.behavior in ["ambush","scavenge"] or actors.any(func(e):return not game.impact_blocked(e.position,game.player.position))
		if not group.awake and (hurt or (sight and player.distance_to(center)<float(group.trigger_radius))):
			group.awake=true;group.triggered=true
			for e in actors:
				if e.encounter_hidden:e.encounter_hidden=false;e.encounter_emerge=.75;e.visible=true;e.collision_layer=4
		if group.awake and player.distance_to(center)>float(group.leash_radius)+3:group.awake=false
		if clock>=group.next_turn:group.turn=(int(group.turn)+1)%actors.size();group.next_turn=clock+2.1
		for i in range(actors.size()):
			var e=actors[i]
			if not e.ai_enabled:continue
			e.encounter_attack_allowed=false;e.encounter_engaged=group.awake
			var goal=e.home;var pace=.65
			if group.awake:
				var permitted=i==int(group.turn) or group.behavior=="ambush"
				var busy=actors.any(func(other):return other!=e and other.state in ["windup","lunge","burrow"])
				e.encounter_attack_allowed=permitted and (not busy or group.behavior=="ambush")
				goal=player;pace=1.0
				if group.behavior=="pack" and not e.encounter_attack_allowed:
					var angle=clock*.4+TAU*i/actors.size();goal=player+Vector3(sin(angle),0,cos(angle))*3.7;pace=.85
				elif group.behavior=="guard" and not e.encounter_attack_allowed:goal=e.home+Vector3(sin(clock*.5+i)*1.5,0,0);pace=.5
			elif group.behavior=="guard":goal=e.home+Vector3(sin(clock*.35+i)*1.2,0,cos(clock*.35+i)*.8);pace=.4
			if e.encounter_hidden:continue
			e.encounter_goal=steer(e,goal);e.encounter_speed=pace
