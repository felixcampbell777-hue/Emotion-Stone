extends CharacterBody3D
const Props=preload("res://scripts/props.gd")
signal damaged(amount: int)
signal defeated
var definition: Dictionary
var tuning: Dictionary
var player: Node3D
var home=Vector3.ZERO
var visual: Node3D
var body: MeshInstance3D
var collision: CollisionShape3D
var health=60
var max_health=60
var dead_remaining=0.0
var state="idle"
var state_time=0.0
var direction=Vector3.ZERO
var knockback=Vector3.ZERO
var size_class="medium"
var recoil_policy:Dictionary
var hit_flash=0.0
var phase=0.0
var ai_enabled=true
var simulation_enabled=true
var lunge_hit=false
var parry_flash=0.0

func configure(data: Dictionary, target: Node3D, saved: Dictionary={}) -> void:
	definition=data
	size_class=data.get("size","giant" if data.kind=="warden" else "medium")
	recoil_policy=JSON.parse_string(FileAccess.get_file_as_string("res://content/knockback.json"))
	player=target
	tuning=JSON.parse_string(FileAccess.get_file_as_string("res://content/combat.json")).slime
	max_health=int(tuning.max_health)
	health=int(saved.get("health",max_health))
	dead_remaining=float(saved.get("dead_remaining",0))
	home=Vector3(data.at[0],0,data.at[1])
	position=home
	collision_layer=4 if health>0 else 0
	collision_mask=1 | 2 | 4
	motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
	collision=CollisionShape3D.new()
	var shape=SphereShape3D.new()
	shape.radius=.46
	collision.shape=shape
	collision.position.y=.46
	add_child(collision)
	visual=Node3D.new()
	add_child(visual)
	body=MeshInstance3D.new()
	var mesh=SphereMesh.new()
	mesh.height=1.0
	mesh.radius=.56
	mesh.radial_segments=12
	mesh.rings=6
	body.mesh=mesh
	body.material_override=Props.mat("#70b560")
	body.position.y=.47
	visual.add_child(body)
	Props.box(visual,Vector3(-.17,.56,.47),Vector3(.08,.14,.06),"#1b3429")
	Props.box(visual,Vector3(.17,.56,.47),Vector3(.08,.14,.06),"#1b3429")
	Props.box(visual,Vector3(0,.37,.515),Vector3(.15,.025,.04),"#36512d")
	Props.box(visual,Vector3(-.20,.75,.34),Vector3(.15,.045,.055),"#bed690")
	var shadow=Props.box(self,Vector3(0,.008,0),Vector3(.78,.008,.67),"#536c42")
	shadow.name="Shadow"
	visible=health>0
	collision.disabled=health<=0

func snapshot() -> Dictionary:
	return {"health":health,"dead_remaining":dead_remaining}

func set_body_color(color:Color) -> void:
	if has_meta("advanced_body_material"):
		body.material_override=get_meta("advanced_body_material")
		if body.material_override is ShaderMaterial:
			body.material_override.set_shader_parameter("tint",color)
			body.material_override.set_shader_parameter("clock",phase)
		else: body.material_override.albedo_color=color
	else:
		body.material_override=Props.mat(color.to_html(false))

func take_damage(amount: int, from_direction: Vector3) -> void:
	if health<=0:
		return
	health=maxi(0,health-amount)
	knockback=from_direction*3.2
	hit_flash=.18
	state="recover"
	state_time=.45
	damaged.emit(amount)
	if health==0:
		dead_remaining=0
		visible=false
		collision_layer=0
		collision.set_deferred("disabled",true)
		defeated.emit()

func sword_weakspot_open() -> bool:
	return false

func sword_recoil_force(strong:bool,weakspot:bool=false) -> float:
	var profile:Dictionary=recoil_policy[size_class]
	if size_class=="giant":
		return float(profile.weakspot_strong) if strong and weakspot else 0.0
	return float(profile.strong if strong else profile.light)

func take_sword_damage(amount:int,from_direction:Vector3,strong:bool=false,recoil_multiplier:float=1.0) -> void:
	var previous=health
	var weakspot=sword_weakspot_open()
	take_damage(amount,from_direction)
	if health>=previous: return
	var force=sword_recoil_force(strong,weakspot)*recoil_multiplier
	knockback=Vector3(from_direction.x,0,from_direction.z).normalized()*force
	if health>0 and force>0:
		state="recover"
		state_time=float(recoil_policy[size_class].stun)
		lunge_hit=true

func take_thrust_gust(away:Vector3, multiplier:float, stun:float) -> void:
	if health<=0: return
	var force=sword_recoil_force(true,sword_weakspot_open())*multiplier
	if force<=0: return
	if force>knockback.length():
		knockback=Vector3(away.x,0,away.z).normalized()*force
	state_time=maxf(state_time if state=="recover" else 0.0,stun)
	state="recover"
	lunge_hit=true
	velocity=Vector3.ZERO
	hit_flash=.18

func take_slam_shockwave(away:Vector3, strength:float, stun:float) -> void:
	# Ground pressure interrupts mobile enemies; giant stone armor remains planted.
	if health<=0 or size_class=="giant": return
	var force=sword_recoil_force(false)*strength
	if force>knockback.length():
		knockback=Vector3(away.x,0,away.z).normalized()*force
	state_time=maxf(state_time if state=="recover" else 0.0,stun)
	state="recover"
	lunge_hit=true
	velocity=Vector3.ZERO
	hit_flash=.18

func breaker_expose(seconds:float) -> void:
	parry_flash=seconds
func take_undertow(toward:Vector3,strength:float) -> void:
	if health<=0 or size_class=="giant": return
	var force={"small":5.0,"medium":3.8,"large":1.8}[size_class]*strength
	knockback=toward*force;state_time=maxf(state_time if state=="recover" else 0.0,.2);state="recover";lunge_hit=true;velocity=Vector3.ZERO
func take_lance_damage(amount: int, from_direction: Vector3) -> void:
	take_damage(amount,from_direction)

func respawn() -> void:
	health=max_health
	dead_remaining=0
	position=home
	# Keep the returning slime clear of a player standing directly on its spawn.
	if is_instance_valid(player) and player.position.distance_to(home)<.9:
		position+=Vector3(1.15,0,0)
	state="idle"
	state_time=0
	knockback=Vector3.ZERO
	collision_layer=4
	collision.set_deferred("disabled",false)
	visible=true

func repel(away: Vector3, force: float, stun: float) -> void:
	if health<=0:
		return
	state="recover"
	state_time=stun
	lunge_hit=true
	velocity=Vector3.ZERO
	knockback=away.normalized()*force
	parry_flash=.3

func _physics_process(delta: float) -> void:
	if not simulation_enabled:
		return
	if health<=0:
		return
	phase+=delta
	hit_flash=maxf(0,hit_flash-delta)
	parry_flash=maxf(0,parry_flash-delta)
	set_body_color(Color("#9ddfea") if parry_flash>0 else Color("#efe5b8") if hit_flash>0 else Color("#d8ad54") if state=="windup" else Color("#70b560"))
	visual.scale=Vector3(1+.06*sin(phase*5),1-.09*sin(phase*5),1+.06*sin(phase*5))
	velocity=Vector3.ZERO
	if ai_enabled and is_instance_valid(player) and player.health>0:
		var toward=player.position-position
		toward.y=0
		var distance=toward.length()
		if state=="idle":
			if distance<float(tuning.notice_range):
				visual.rotation.y=atan2(toward.x,toward.z)
				if distance<2.35:
					state="windup"
					state_time=float(tuning.windup)
					direction=toward.normalized()
				else:
					velocity=toward.normalized()*float(tuning.walk_speed)
			elif position.distance_to(home)>.3:
				velocity=(home-position).normalized()*float(tuning.walk_speed)
		elif state=="windup":
			visual.scale=Vector3(1.28,.67,1.28)
			state_time-=delta
			if state_time<=0:
				state="lunge"
				state_time=float(tuning.lunge_seconds)
				lunge_hit=false
		elif state=="lunge":
			velocity=direction*float(tuning.lunge_speed)
			state_time-=delta
			if not lunge_hit:
				if distance<=float(player.combat.parry.contact_range) and player.try_parry(self):
					lunge_hit=true
				elif distance<.9:
					player.take_damage(int(tuning.damage),direction)
					lunge_hit=true
			if state_time<=0:
				state="recover"
				state_time=float(tuning.recovery)
		elif state=="recover":
			state_time-=delta
			if state_time<=0:
				state="idle"
	velocity+=knockback
	knockback=knockback.move_toward(Vector3.ZERO,delta*float(recoil_policy.deceleration))
	if is_instance_valid(player) and is_instance_valid(player.ground_world): player.ground_world.move_grounded(self,delta)
	else:
		move_and_slide()
		position.y=0
