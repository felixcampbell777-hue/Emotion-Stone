extends "res://scripts/slime.gd"
const WardenVisual=preload("res://scripts/warden_visual.gd")
var guardian: Node3D
const Rock=preload("res://scripts/rock_projectile.gd")
var game: Control
var kind="boar"
var armor_open=0.0
var base_color="#795543"
var attacks=0

func configure(data: Dictionary, target: Node3D, saved: Dictionary={}) -> void:
	super.configure(data,target,saved)
	kind=data.kind
	tuning=JSON.parse_string(FileAccess.get_file_as_string("res://content/forest_enemies.json"))[kind]
	max_health=int(tuning.health)
	health=int(saved.get("health",max_health))
	for child in visual.get_children():
		visual.remove_child(child)
		child.queue_free()
	base_color=tuning.color
	body=Props.box(visual,Vector3(0,.6,0),Vector3(.95,.7,1.25) if kind=="boar" else Vector3(.72,1.1,.65),base_color)
	if kind=="boar":
		Props.box(visual,Vector3(0,.6,.7),Vector3(.55,.36,.3),"#c39a83")
		for x in [-.28,.28]:
			Props.box(visual,Vector3(x,.64,.85),Vector3(.09,.25,.1),"#efdfb3")
			Props.box(visual,Vector3(x,.19,-.35),Vector3(.16,.38,.2),"#382c29")
			Props.box(visual,Vector3(x,.19,.35),Vector3(.16,.38,.2),"#382c29")
		for z in [-.35,0,.35]:
			Props.box(visual,Vector3(0,1,z),Vector3(.2,.23,.13),"#6c804a")
	elif kind=="wisp":
		for x in [-.55,.55]:
			var wing=Props.box(visual,Vector3(x,1,0),Vector3(.6,.09,.65),"#b38ac0")
			wing.rotation.z=x*.5
		Props.box(visual,Vector3(0,1.28,0),Vector3(.2,.25,.2),"#dbc1df")
	else:
		visual.remove_child(body)
		body.queue_free()
		guardian=WardenVisual.new()
		visual.add_child(guardian)
		guardian.build()
		body=guardian.torso
	if kind!="warden":
		for x in [-.19,.19]:
			Props.box(visual,Vector3(x,.82,.39),Vector3(.09,.08,.07),"#ffe0a0")
	visible=health>0
	collision.disabled=health<=0

func open_armor() -> void:
	armor_open=5
	repel((position-player.position).normalized(),3,1.2)

func sword_weakspot_open() -> bool:
	return kind=="warden" and armor_open>0

func take_damage(amount: int, from_direction: Vector3) -> void:
	if kind=="warden" and armor_open<=0:
		hit_flash=.12
		if is_instance_valid(game):
			game.notify("Armored: parry a thrown rock back at the warden.")
		return
	super.take_damage(amount,from_direction)

func take_lance_damage(amount: int, from_direction: Vector3) -> void:
	if kind=="warden":
		armor_open=maxf(armor_open,2.6)
		if is_instance_valid(guardian):
			guardian.animate(state,state_time,armor_open,phase)
		if is_instance_valid(game):
			game.notify("The water lance breaches the warden's stone guard!")
	take_damage(amount,from_direction)

func _physics_process(delta: float) -> void:
	if not simulation_enabled or health<=0:
		return
	phase+=delta
	armor_open=maxf(0,armor_open-delta)
	hit_flash=maxf(0,hit_flash-delta)
	parry_flash=maxf(0,parry_flash-delta)
	if kind=="warden":
		guardian.animate(state,state_time,armor_open,phase)
	else:
		set_body_color(Color("#c8edef") if armor_open>0 or parry_flash>0 else Color("#ffe1a1") if state=="windup" or hit_flash>0 else Color(base_color))
	visual.position.y=.13*sin(phase*7)+.3 if kind=="wisp" else .035*sin(phase*9)
	velocity=Vector3.ZERO
	if ai_enabled and is_instance_valid(player) and player.health>0:
		var toward=(player.position-position)*Vector3(1,0,1)
		var distance=toward.length()
		if kind=="boar" and state=="idle" and distance<float(tuning.range):
			# A pack notices and winds up together; each boar aims from its own position.
			for partner in game.enemies:
				if partner.definition.kind=="boar" and partner.health>0 and partner.ai_enabled and partner.state=="idle":
					partner.state="windup"
					partner.state_time=float(tuning.windup)
					partner.direction=((player.position-partner.position)*Vector3(1,0,1)).normalized()
		visual.rotation.y=lerp_angle(visual.rotation.y,atan2(toward.x,toward.z),delta*6)
		if state=="idle" and distance<float(tuning.notice):
			if kind=="wisp":
				velocity=(toward.normalized()*.3+Vector3(toward.z,0,-toward.x).normalized())*1.5
			if distance<float(tuning.range):
				state="windup"
				state_time=float(tuning.windup)
				direction=toward.normalized()
			else:
				velocity=toward.normalized()*float(tuning.speed)
		elif state=="windup":
			state_time-=delta
			if kind!="warden":
				visual.scale=Vector3(1.1,.86,1.1)
			if state_time<=0:
				visual.scale=Vector3.ONE
				attacks+=1
				if kind=="warden":
					var rock=Rock.new()
					game.world_root.add_child(rock)
					rock.configure(game,self,direction)
					game.projectiles=game.projectiles.filter(func(item): return is_instance_valid(item))
					game.projectiles.append(rock)
					state="recover"
					state_time=2.3
				else:
					state="lunge"
					state_time=.65 if kind=="boar" else .45
					lunge_hit=false
		elif state=="lunge":
			velocity=direction*float(tuning.attack_speed)
			state_time-=delta
			if not lunge_hit:
				if distance<=float(player.combat.parry.contact_range) and player.try_parry(self):
					lunge_hit=true
				elif distance<1.05:
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
	if is_instance_valid(game) and is_instance_valid(game.current_world): game.current_world.move_grounded(self,delta)
	else:
		move_and_slide()
		position.y=0

func breaker_expose(seconds:float) -> void:
	super.breaker_expose(seconds)
	if kind=="warden": armor_open=maxf(armor_open,seconds)
