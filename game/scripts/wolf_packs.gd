extends RefCounted
## Pack decisions share one physics clock. Animals own actual contact and recoil.
var game:Control
var tuning:Dictionary
var packs:Array=[]

func build(owner_game:Control) -> void:
	game=owner_game;var old=packs.duplicate();packs.clear()
	tuning=JSON.parse_string(FileAccess.get_file_as_string("res://content/beta.json")).wolf_packs
	if game.game_mode=="world_rise":
		tuning.first_attack_delay=.7;tuning.wave_interval=2.2;tuning.leash_radius=32.0;tuning.circle_radius=2.8;tuning.attack_distance=4.5
		tuning.territories={}
		for p in preload("res://scripts/rise_shape.gd").spec.packs:
			if p.kind=="beta_wolf":tuning.territories[p.id]={"center":p.at,"radius":14}
	for id in tuning.territories:
		var members=game.enemies.filter(func(e): return e.definition.kind=="beta_wolf" and e.definition.get("pack","")==id)
		if members.is_empty(): continue
		var previous=old.filter(func(p):return p.id==id and p.members.any(func(e):return is_instance_valid(e) and e in members))
		if not previous.is_empty():previous[0].members=members;packs.append(previous[0]);continue
		var territory=tuning.territories[id]
		packs.append({"id":id,"members":members,"home":Vector3(territory.center[0],0,territory.center[1]),"radius":float(territory.radius),"route":0,"route_clock":0.0,"hold":0.0,"engaged":false,"angle":0.0,"wave":0,"next_attack":float(tuning.first_attack_delay),"cursor":0,"lost_sight":0.0})

func live_members(pack:Dictionary) -> Array:
	return pack.members.filter(func(w): return is_instance_valid(w) and w.health>0)

func active_members(pack:Dictionary) -> Array:
	return live_members(pack).filter(func(w): return w.ai_enabled and w.simulation_enabled)

func alert(wolf:Node3D) -> void:
	if not is_instance_valid(game.player) or game.player.health<=0: return
	for pack in packs:
		if wolf in pack.members and horizontal(game.player.position-pack.home).length()<=float(tuning.leash_radius): engage(pack)

func engage(pack:Dictionary) -> void:
	if pack.engaged: return
	pack.engaged=true; pack.lost_sight=0.0
	pack.next_attack=float(tuning.first_attack_delay)
	pack.angle=atan2(pack.home.x-game.player.position.x,pack.home.z-game.player.position.z)
	for wolf in active_members(pack):
		if wolf.state not in ["recover","windup","lunge"]: wolf.state="circle"

func disengage(pack:Dictionary) -> void:
	pack.engaged=false; pack.lost_sight=0.0; pack.next_attack=float(tuning.first_attack_delay)
	for wolf in active_members(pack):
		if wolf.state in ["windup","lunge"]: wolf.state="recover"; wolf.state_time=.6; wolf.lunge_hit=true
		elif wolf.state!="recover": wolf.state="patrol"

static func horizontal(value:Vector3) -> Vector3:
	return value*Vector3(1,0,1)

func can_see(wolf:Node3D) -> bool:
	return not game.impact_blocked(wolf.position+Vector3.UP*.45,game.player.position+Vector3.UP*.45)

func tick(delta:float) -> void:
	if not is_instance_valid(game) or game.game_mode not in ["beta","world_rise"] or not game.player.input_enabled or game.gallery_mode: return
	for pack in packs:
		var members=active_members(pack)
		if members.is_empty(): continue
		if game.player.health<=0:
			disengage(pack); patrol(pack,members,delta); continue
		var inside=horizontal(game.player.position-pack.home).length()<=float(tuning.leash_radius)
		var visible_target=members.any(func(w): return horizontal(game.player.position-w.position).length()<(12.0 if game.game_mode=="world_rise" else float(w.tuning.notice_range)) and can_see(w))
		if not pack.engaged and inside and visible_target: engage(pack)
		if pack.engaged:
			var line_of_sight=members.any(func(w): return can_see(w))
			pack.lost_sight=0.0 if line_of_sight else pack.lost_sight+delta
			if not inside or pack.lost_sight>float(tuning.lost_sight_seconds): disengage(pack)
		if pack.engaged: surround(pack,members,delta)
		else: patrol(pack,members,delta)

func patrol(pack:Dictionary,members:Array,delta:float) -> void:
	pack.route_clock+=delta; pack.hold=maxf(0,pack.hold-delta)
	var offsets=[Vector3(-2.4,0,-1.8),Vector3(2.4,0,-1.8),Vector3(2.4,0,1.8),Vector3(-2.4,0,1.8)]
	var waypoint:Vector3=pack.home+offsets[pack.route]
	if pack.hold<=0 and (horizontal(members[0].position-waypoint).length()<.7 or pack.route_clock>9):
		pack.route=(pack.route+1)%offsets.size(); pack.route_clock=0.0; pack.hold=.7
		waypoint=pack.home+offsets[pack.route]
	var formation=[Vector3.ZERO,Vector3(-.9,0,-.8),Vector3(.9,0,-.8),Vector3(0,0,-1.7)]
	var heading=horizontal(waypoint-members[0].position).normalized()
	var yaw=atan2(heading.x,heading.z)
	for i in range(members.size()):
		var wolf=members[i]
		var target=waypoint+formation[i%formation.size()].rotated(Vector3.UP,yaw)
		var from_home=horizontal(target-pack.home)
		if from_home.length()>pack.radius: target=pack.home+from_home.normalized()*pack.radius
		wolf.pack_target=wolf.position if pack.hold>0 else target
		wolf.pack_speed=float(tuning.patrol_speed)
		wolf.pack_engaged=false
		if wolf.state not in ["recover","windup","lunge"]: wolf.state="patrol"

func surround(pack:Dictionary,members:Array,delta:float) -> void:
	pack.angle+=delta*float(tuning.circle_angular_speed)
	pack.next_attack=maxf(0,pack.next_attack-delta)
	for i in range(members.size()):
		var wolf=members[i]
		var angle=pack.angle+TAU*float(i)/members.size()
		var radius=float(tuning.circle_radius)+(.18 if i%2==1 else -.12)
		wolf.pack_target=game.player.position+Vector3(sin(angle),0,cos(angle))*radius
		wolf.pack_speed=float(tuning.circle_speed); wolf.pack_engaged=true
		if wolf.state not in ["recover","windup","lunge"]: wolf.state="circle"
	if pack.next_attack>0: return
	# Count every pack's committed windups/lunges: two is a map-wide limit.
	var occupied=game.enemies.filter(func(w): return w.definition.kind=="beta_wolf" and w.health>0 and w.state in ["windup","lunge"]).size()
	if occupied>0: return
	var candidates=[]
	for offset in range(members.size()):
		var index=(int(pack.cursor)+offset)%members.size()
		var wolf=members[index]
		var distance=horizontal(game.player.position-wolf.position).length()
		if wolf.state=="circle" and distance<=float(tuning.attack_distance) and can_see(wolf): candidates.append(wolf)
	if candidates.is_empty(): return
	var count=mini(1 if int(pack.wave)%2==0 else 2,candidates.size())
	for i in range(count):
		var wolf=candidates[i]
		wolf.state="windup"; wolf.state_time=float(wolf.tuning.windup)
		wolf.direction=horizontal(game.player.position-wolf.position).normalized()
		wolf.lunge_hit=false
	pack.cursor=(members.find(candidates[count-1])+1)%members.size()
	pack.wave+=1; pack.next_attack=float(tuning.wave_interval)
