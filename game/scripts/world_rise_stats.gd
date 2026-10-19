extends RefCounted
## Shared tree6 numeric policy; presentation, native authority and save bounds agree.
static func tier(rank:int,values:Array) -> float:return float(values[clampi(rank,0,values.size()-1)])
static func attribute_bonus(growth:RefCounted,id:String) -> int:
	return maxi(0,int(growth.attributes.get(id,3))-3)
static func max_health(base:float,growth:RefCounted) -> int:
	return roundi(base*(1+.01*(growth.level()-1)))+2*attribute_bonus(growth,"strength")+15*growth.rank("iron_resolve")
static func max_stamina(base:float,growth:RefCounted) -> float:
	return base*(1+.01*(growth.level()-1))+2*attribute_bonus(growth,"strength")+5*growth.rank("deep_reserve")+15*growth.rank("second_wind")
static func reduction(g:Node) -> float:
	return clampf(.02*g.progression.rank("iron_body")+.04*g.progression.rank("stonewall"),0,.5)
static func weapon_damage_multiplier(growth:RefCounted,kind:String) -> float:
	var bonus=.02*growth.practice_rank(kind)
	if kind in ["greatsword","spear"]:
		bonus+=.01*attribute_bonus(growth,"greatsword")+.03*growth.rank("great_greatsword")+.04*growth.rank("basher")
	if kind in ["bow","rapier"]:
		bonus+=.01*attribute_bonus(growth,"agility")+.03*growth.rank("finesse")+.10*growth.rank("deadeye")
	if kind=="greatsword":bonus+=.15*growth.rank("devastating_blade")
	return 1+bonus
static func weapon_stamina_multiplier(growth:RefCounted,kind:String) -> float:
	var saving=.05*growth.rank("measured_draw") if kind=="bow" else .05*growth.rank("honed_arms")
	if kind=="rapier":saving+=.05*growth.rank("point_control")
	return maxf(.5,1-saving)
static func damage_multiplier(g:Node) -> float:
	return weapon_damage_multiplier(g.progression,g.player.weapon_type)
static func apply(g:Node) -> void:
	var p=g.player;var s=g.progression;var c=p.combat
	c.dodge.stand_seconds=.08
	c.parry.active_start=0.0;c.parry.active_end+=.03
	p.max_health=max_health(p.max_health,s);p.max_stamina=max_stamina(p.max_stamina,s)
	var strength=weapon_damage_multiplier(s,p.weapon_type);c.thrust.damage=c.light.damage
	for key in ["light","heavy","thrust"]:c[key].damage=roundi(c[key].damage*strength)
	for attack in c.combo:attack.damage=roundi(attack.damage*strength)
	p.jump_stamina_multiplier=1.0
	var swing=weapon_stamina_multiplier(s,p.weapon_type)
	for key in ["light","heavy","thrust"]:c[key].stamina_cost*=swing
	for attack in c.combo:attack.stamina_cost*=swing
	c.thrust_charge.stamina_per_second*=swing
	var speed=minf(1.25,1+.005*attribute_bonus(s,"agility")+.02*s.rank("swiftfoot"))
	p.walk_speed*=speed
	for key in ["drawn_walk_speed","sprint_speed","drawn_sprint_speed"]:c[key]*=speed
	for key in ["sprint_drain","drawn_sprint_drain"]:c[key]*=maxf(.5,1-.05*s.rank("long_march"))
	p.dash_distance_multiplier=1+.15*s.rank("streaming_dash")
	p.dash_stamina_multiplier=maxf(.5,1-.10*s.rank("lightstep"))
	c.dodge.speed*=1+.10*s.rank("roly_poly")
	p.thrust_unlocked=s.has("charge_thrust") and p.weapon_type=="greatsword"
	p.thrust_charge_rate=2.0 if s.has("fast_thrust") else 1.0;c.thrust_charge.max_seconds=5.0;c.thrust_charge.damage_per_second=.15
	p.water_unlocked=false;p.dash_water_unlocked=false;p.lance_unlocked=false;p.dragon_unlocked=false;p.undertow_unlocked=false
	g.selected_special_attack="water_sweep"
