extends RefCounted
static func tier(rank:int,values:Array) -> float:return float(values[clampi(rank,0,values.size()-1)])
static func reduction(g:Node) -> float:return clampf(.02*g.progression.rank("iron_body")+.10*g.progression.rank("stonewall"),0,1)
static func damage_multiplier(g:Node) -> float:
	var p=g.progression
	return (1+.02*p.rank("iron_body")+.05*p.rank("great_greatsword")+.15*p.rank("basher"))*(2 if p.has("devastating_blade") else 1)
static func apply(g:Node) -> void:
	var p=g.player;var s=g.progression;var c=p.combat;var gain=1+.01*(s.level()-1)
	c.dodge.stand_seconds=.08
	c.parry.active_start=0.0;c.parry.active_end+=.03
	p.max_health=roundi(p.max_health*gain);p.max_stamina*=gain
	var strength=damage_multiplier(g);c.thrust.damage=c.light.damage
	for key in ["light","heavy","thrust"]:c[key].damage=roundi(c[key].damage*strength)
	for attack in c.combo:attack.damage=roundi(attack.damage*strength)
	var universal=maxf(.01,1-.02*s.rank("iron_body"))
	p.jump_stamina_multiplier=universal
	var swing=maxf(.01,1-.15*s.rank("honed_arms")-.07*s.rank("great_greatsword"))
	for key in ["light","heavy","thrust"]:c[key].stamina_cost*=universal*swing
	for attack in c.combo:attack.stamina_cost*=universal*swing
	for key in ["parry","dodge"]:c[key].stamina_cost*=universal
	c.thrust_charge.stamina_per_second*=universal*swing
	var speed=(1+.02*s.rank("swiftfoot"))*(1+.25*s.rank("speed_freak"))
	p.walk_speed*=speed
	for key in ["drawn_walk_speed","sprint_speed","drawn_sprint_speed"]:c[key]*=speed
	for key in ["sprint_drain","drawn_sprint_drain"]:c[key]*=universal*maxf(.01,1-.05*s.rank("swiftfoot"))
	p.dash_distance_multiplier=1+tier(s.rank("streaming_dash"),[0,1,2,5])
	var saving=1-tier(s.rank("lightstep"),[0,.5,.75,.95])
	p.dash_stamina_multiplier=universal*saving
	var roll_speed=1+tier(s.rank("roly_poly"),[0,.25,.40,.75]);var roll_distance=1+tier(s.rank("roly_poly"),[0,.25,.50,.80])
	c.dodge.speed*=roll_speed*roll_distance;c.dodge.duration/=roll_speed
	p.thrust_charge_rate=2.0 if s.has("fast_thrust") else 1.0;c.thrust_charge.max_seconds=5.0;c.thrust_charge.damage_per_second=.15
	p.water_unlocked=false;p.dash_water_unlocked=false;p.lance_unlocked=false;p.dragon_unlocked=false;p.undertow_unlocked=false
	g.selected_special_attack="water_sweep"
