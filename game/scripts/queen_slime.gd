extends "res://scripts/menagery_enemy.gd"
const Warning=preload("res://scripts/slime_warning.gd")
var attack_index=0
var warning:Node3D
var jump_origin=Vector3.ZERO
var jump_target=Vector3.ZERO
var action_clock=0.0
var brood_serial=0
func setup(owner:Node,entry:Dictionary,at:Vector3) -> void:
	super.setup(owner,entry,at)
	for child in visual.get_children(): child.free()
	var sphere=SphereMesh.new(); sphere.radius=1.45; sphere.height=2.35; sphere.radial_segments=16; sphere.rings=8
	body=Props.mesh_node(visual,sphere,Vector3(0,1.05,0),entry.color)
	for x in [-.42,.42]:
		Props.box(visual,Vector3(x,1.35,1.40),Vector3(.20,.28,.10),"#172f46")
		Props.box(visual,Vector3(x-.04,1.42,1.47),Vector3(.05,.06,.03),"#e8f0e7")
	Props.box(visual,Vector3(0,.91,1.46),Vector3(.40,.07,.08),"#1d415c")
	Props.cone(visual,Vector3(0,2.25,0),.66,.15,"#dcb461",.62)
	for i in range(7):
		var a=i*TAU/7
		Props.cone(visual,Vector3(sin(a)*.55,2.55,cos(a)*.55),.14,.55,"#e8bd65",.02)
		Props.box(visual,Vector3(sin(a)*.59,2.33,cos(a)*.59),Vector3(.13,.12,.13),["#70b560","#74a44e","#cb9e43","#779883"][i%4])
	collision.shape.radius=1.25; collision.position.y=.95
	get_node("Shadow").scale=Vector3(3,1,3)
	definition.combat_height=2.2; definition.combat_radius=1.3; definition.label_height=3.1
	state_time=1.0

func _brood_count() -> int:
	var total=0
	for node in game.get_tree().get_nodes_in_group("queen_brood"):
		if node.get("queen") == self and not node.is_queued_for_deletion() and (not node.get("health") is int or node.health>0): total+=1
	return total

func spawn_brood(entry:Dictionary,at:Vector3) -> Node3D:
	brood_serial+=1
	var child=game.spawn_catalog_creature(entry,at)
	child.definition.id="queen_brood_"+str(get_instance_id())+"_"+str(brood_serial); child.definition["transient"]=true
	child.set_meta("queen",get_instance_id()); child.defeated.connect(func(): game._catalog_enemy_defeated(entry.style,entry.name,child))
	child.defeated.connect(func(): game.call_deferred("retire_transient",child))
	# A small companion tracker keeps the cap tied to living slimes, not dead records.
	child.add_to_group("queen_child")
	return child

func living_brood() -> int:
	var total=_brood_count()
	for child in game.get_tree().get_nodes_in_group("queen_child"):
		if child.get_meta("queen",0)==get_instance_id() and child.health>0: total+=1
	return total

func _splash_brood() -> void:
	var available=maxi(0,int(game.menagery.catalog.queen_attack.max_brood)-living_brood())
	var codes=["9E","1E","2E","3E"]
	for i in range(mini(4,available)):
		var entry=game.menagery.catalog.monsters.filter(func(mob): return mob.code==codes[i])[0]
		var angle=i*TAU/4+.35
		var target=game.current_world.safe_landing(player.position+(Vector3.ZERO if i==0 else Vector3(sin(angle),0,cos(angle))*2.4))
		var gloop=load("res://scripts/queen_gloop.gd").new(); game.current_world.add_child(gloop); gloop.configure(game,self,entry,target); game.projectiles.append(gloop)

func _start_attack() -> void:
	var tune=game.menagery.catalog.queen_attack
	var choice=attack_index%3; attack_index+=1; action_clock=0
	if choice==0 and living_brood()<int(tune.max_brood):
		state="brood_windup"; state_time=1.1
	elif choice==1:
		state="jump_warn"; state_time=float(tune.jump_warning); jump_target=game.current_world.safe_landing(player.position+player.velocity*.2)
		warning=Warning.new(); game.current_world.add_child(warning); warning.configure(jump_target,float(tune.jump_radius),"QUEEN IMPACT")
	else:
		state="queen_charge_warn"; state_time=float(tune.charge_warning); direction=((player.position-position)*Vector3(1,0,1)).normalized()
		if dash_line==null: dash_line=Props.box(self,Vector3.ZERO,Vector3(.65,.03,1),"#eaa257")
		dash_line.visible=true; dash_line.scale.z=float(tune.charge_speed)*float(tune.charge_seconds); dash_line.position=direction*dash_line.scale.z*.5+Vector3.UP*.08; dash_line.rotation.y=atan2(direction.x,direction.z)

func _clear_warning() -> void:
	if is_instance_valid(warning): warning.queue_free()
	if dash_line!=null: dash_line.visible=false

func take_damage(amount:int,from_direction:Vector3) -> void:
	_clear_warning()
	if state=="queen_jump": position.y=game.current_world.ground_height(position); collision.set_deferred("disabled",false)
	get_node("Shadow").position.y=.008
	super.take_damage(amount,from_direction)
	knockback*=.4

func repel(away:Vector3,force:float,stun:float) -> void:
	_clear_warning(); super.repel(away,force*.5,stun)

func take_slam_shockwave(away:Vector3,strength:float,stun:float) -> void:
	if state=="queen_jump": return
	_clear_warning(); super.take_slam_shockwave(away,strength,stun)

func take_thrust_gust(away:Vector3,multiplier:float,stun:float) -> void:
	if state=="queen_jump": return
	_clear_warning(); super.take_thrust_gust(away,multiplier,stun)

func _physics_process(delta:float) -> void:
	if not simulation_enabled or health<=0: return
	phase+=delta; hit_flash=maxf(0,hit_flash-delta); parry_flash=maxf(0,parry_flash-delta)
	set_body_color(Color("#b8ecdf" if parry_flash>0 else "#d9e7ba" if hit_flash>0 else specimen.color))
	visual.scale=Vector3(1+.04*sin(phase*4),1-.06*sin(phase*4),1+.04*sin(phase*4)); velocity=Vector3.ZERO
	if not ai_enabled or player.health<=0: return
	var tune=game.menagery.catalog.queen_attack
	var toward=(player.position-position)*Vector3(1,0,1)
	visual.rotation.y=lerp_angle(visual.rotation.y,atan2(toward.x,toward.z),delta*3)
	state_time-=delta
	if state=="idle":
		if toward.length()<18:
			if state_time<=0: _start_attack()
			elif toward.length()>5: velocity=toward.normalized()*float(specimen.speed)
	elif state=="brood_windup":
		visual.scale=Vector3(1.2,.7,1.2)
		if state_time<=0: _splash_brood(); state="recover"; state_time=float(tune.recover_seconds)
	elif state=="jump_warn":
		visual.scale=Vector3(1.25,.58,1.25)
		if state_time<=0: state="queen_jump"; action_clock=0; jump_origin=position; collision.set_deferred("disabled",true)
	elif state=="queen_jump":
		action_clock+=delta; var t=clampf(action_clock/float(tune.jump_seconds),0,1)
		position=jump_origin.lerp(jump_target,t)+Vector3.UP*(4*float(tune.jump_height)*t*(1-t)); visual.scale=Vector3(.85,1.25,.85)
		get_node("Shadow").position.y=game.current_world.ground_height(position)-position.y+.008
		if t>=1:
			position=jump_target; collision.set_deferred("disabled",false); _clear_warning()
			get_node("Shadow").position.y=.008
			visual.scale=Vector3(1.5,.40,1.5); state="recover"; state_time=2.2
			var offset=(player.position-position)*Vector3(1,0,1)
			if offset.length()<float(tune.jump_radius) and not game.impact_blocked(position,player.position): player.take_damage(int(tune.jump_damage),offset.normalized())
			var splash=Warning.new(); game.current_world.add_child(splash); splash.configure(position,float(tune.jump_radius),"SLAM")
			splash.game=game; splash.lifetime=.4
		return
	elif state=="queen_charge_warn":
		visual.scale=Vector3(1.2,.7,1.2)
		if state_time<=0: state="queen_charge"; state_time=float(tune.charge_seconds); lunge_hit=false; dash_line.visible=false
	elif state=="queen_charge":
		velocity=direction*float(tune.charge_speed); visual.rotation.y=atan2(direction.x,direction.z); visual.scale=Vector3(.9,.75,1.4)
		if not lunge_hit and toward.length()<float(player.combat.parry.contact_range)+.75:
			if player.try_parry(self): lunge_hit=true
			elif toward.length()<1.8: player.take_damage(int(specimen.damage),direction); lunge_hit=true
		if state_time<=0 and state=="queen_charge": state="recover"; state_time=float(tune.recover_seconds)
	elif state=="recover":
		if state_time<=0: state="idle"; state_time=.65
	velocity+=knockback; knockback=knockback.move_toward(Vector3.ZERO,delta*float(recoil_policy.deceleration)); game.current_world.move_grounded(self,delta)
