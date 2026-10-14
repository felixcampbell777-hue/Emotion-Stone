extends RefCounted
const Rock=preload("res://scripts/rock_projectile.gd")
const Shot=preload("res://scripts/menagery_projectile.gd")
## Hit-confirmed skill effects; all clocks use the existing gameplay simulation gate.
var game:Control
var pressure:Dictionary={}
var exposed:Dictionary={}
func reset() -> void:
	pressure.clear()
	exposed.clear()
	if game!=null:
		game.player.counter_remaining=0;game.player.counter_target=null
		game.player.measured_remaining=0;game.player.counter_active=false
func tick(delta:float) -> void:
	if not game.player.input_enabled: return
	for id in exposed.keys():
		exposed[id]-=delta
		if exposed[id]<=0: exposed.erase(id)
	for id in pressure.keys():
		var item=pressure[id];var enemy=item.enemy.get_ref()
		if not is_instance_valid(enemy) or enemy.health<=0: pressure.erase(id);continue
		item.delay=maxf(0,item.delay-delta)
		if item.delay<=0: item.value=maxf(0,item.value-delta)
		if item.value<=0: pressure.erase(id)
func parried(enemy:Node3D) -> void:
	if not game.player.counter_equipped or not game.player.counter_unlocked: return
	if enemy is Rock: enemy=enemy.thrower
	elif enemy is Shot: enemy=enemy.source
	if is_instance_valid(enemy) and enemy.health>0:
		game.player.counter_target=weakref(enemy)
		game.player.counter_remaining=1.1+game.progression.bonus("counter_window")
func sword_hit(enemy:Node3D,previous:int,weakspot:bool,strong:bool) -> void:
	if enemy.health>=previous: return
	var actor=game.player
	if actor.state=="light" and actor.combo_stage==3 and not actor.measured_triggered and actor.measured_bonus>0:
		actor.measured_triggered=true;actor.measured_remaining=3.0
	if enemy.health<=0 or game.progression.bonus("breaker")<=0: return
	if enemy.size_class=="giant" and not weakspot: return
	var id=enemy.get_instance_id()
	if not pressure.has(id): pressure[id]={"enemy":weakref(enemy),"value":0.0,"delay":4.0}
	var item=pressure[id];item.value+=(1.5 if strong else 1.0)*(1+game.progression.bonus("breaker"));item.delay=4.0
	var threshold={"small":3.0,"medium":4.0,"large":6.0,"giant":8.0}[enemy.size_class]
	if item.value>=threshold:
		pressure.erase(id)
		exposed[id]=1.8
		enemy.repel(Vector3.ZERO,0,1.1)
		enemy.breaker_expose(1.8)
		game.notify("Guard broken")
