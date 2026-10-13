extends "res://scripts/slime.gd"
## One shared creature rig; readable tells and fixed rewards live in campaign data.
const Shot=preload("res://scripts/menagery_projectile.gd")
var game:Node
var weapon:Node3D
var arms:Array=[]
var legs:Array=[]
var dormant=false
var attack_spec:Dictionary
var ground_tell:MeshInstance3D

func configure(data:Dictionary,target:Node3D,saved:Dictionary={}) -> void:
	super.configure(data,target,saved)
	attack_spec=JSON.parse_string(FileAccess.get_file_as_string("res://content/goblin_campaign.json")).enemies[data.kind]
	max_health=int(attack_spec.health)
	health=clampi(int(saved.get("health",max_health)),0,max_health)
	definition["combat_height"]=1.35
	definition["combat_radius"]=.38
	definition["display_name"]={"goblin_raider":"Goblin raider","goblin_guard":"Goblin shieldguard","goblin_slinger":"Goblin rock slinger","goblin_foreman":"Grub, the foreman"}[data.kind]
	if data.kind=="goblin_foreman": size_class="large"
	for child in visual.get_children(): child.free()
	var skin="#819655" if data.kind!="goblin_foreman" else "#677b49"
	body=Props.box(visual,Vector3(0,.77,0),Vector3(.48,.58,.32),"#705541")
	var head=SphereMesh.new(); head.radius=.25; head.height=.42; head.radial_segments=8; head.rings=4
	Props.mesh_node(visual,head,Vector3(0,1.2,.03),skin)
	Props.box(visual,Vector3(0,1.14,.28),Vector3(.12,.14,.27),skin)
	for sign in [-1,1]:
		var ear=Props.cone(visual,Vector3(sign*.30,1.25,.01),.13,.35,skin,0)
		ear.rotation.z=sign*-PI/2
		Props.box(visual,Vector3(sign*.11,1.24,.21),Vector3(.09,.065,.04),"#e3c473")
		Props.box(visual,Vector3(sign*.09,1.07,.22),Vector3(.04,.08,.055),"#dfd5ad")
		var leg=Node3D.new(); leg.position=Vector3(sign*.15,.5,0); visual.add_child(leg); legs.append(leg)
		Props.box(leg,Vector3(0,-.18,0),Vector3(.18,.38,.18),skin)
		Props.box(leg,Vector3(0,-.42,.08),Vector3(.22,.14,.30),"#463c30")
		var arm=Node3D.new(); arm.position=Vector3(sign*.3,.97,0); visual.add_child(arm); arms.append(arm)
		Props.box(arm,Vector3(0,-.19,.03),Vector3(.14,.42,.16),skin)
	Props.box(visual,Vector3(0,.65,.19),Vector3(.52,.09,.08),"#b59555")
	weapon=Node3D.new(); arms[1].add_child(weapon); weapon.position=Vector3(0,-.35,.14)
	if data.kind=="goblin_slinger":
		Props.box(weapon,Vector3(0,.1,.12),Vector3(.035,.42,.035),"#be9b71")
		Props.box(weapon,Vector3(0,.33,.14),Vector3(.14,.10,.10),"#a48f6c")
	else:
		Props.box(weapon,Vector3(0,.10,.25),Vector3(.06,.06,.66),"#66523d")
		Props.box(weapon,Vector3(0,.1,.65),Vector3(.16,.055,.38),"#bac0ac")
	if data.kind in ["goblin_guard","goblin_foreman"]:
		Props.box(arms[0],Vector3(0,-.15,.22),Vector3(.50,.65,.10),"#654936")
		Props.box(arms[0],Vector3(0,-.15,.29),Vector3(.12,.58,.04),"#a39268")
		Props.cone(visual,Vector3(0,1.46,.02),.29,.18,"#8e9688",.17)
	if data.kind=="goblin_foreman": visual.scale=Vector3.ONE*1.12
	ground_tell=Props.cone(self,Vector3(0,.025,0),1.6,.025,"#bd9049",1.6)
	ground_tell.visible=false
	var shape=CapsuleShape3D.new(); shape.radius=.30; shape.height=1.3
	collision.shape=shape; collision.position.y=.65
	visible=health>0; collision.disabled=health<=0; collision_layer=4 if health>0 else 0

func take_damage(amount:int,away:Vector3) -> void:
	# The shield reduces frontal damage, but its long recovery exposes the guard.
	if definition.kind in ["goblin_guard","goblin_foreman"] and state=="idle" and away.dot(Vector3(sin(visual.rotation.y),0,cos(visual.rotation.y)))<-.5:
		amount=maxi(1,roundi(amount*.55))
	super.take_damage(amount,away)

func take_lance_damage(amount:int,away:Vector3) -> void:
	super.take_damage(amount,away)

func _physics_process(delta:float) -> void:
	if not simulation_enabled or health<=0 or dormant: return
	phase+=delta
	ground_tell.visible=state=="cleave_windup"
	hit_flash=maxf(0,hit_flash-delta)
	velocity=Vector3.ZERO
	var toward=(player.position-position)*Vector3(1,0,1)
	var distance=toward.length()
	if ai_enabled and player.health>0:
		if state=="idle":
			if distance<8:
				visual.rotation.y=lerp_angle(visual.rotation.y,atan2(toward.x,toward.z),delta*8)
				var ranged=definition.kind=="goblin_slinger"
				if distance<(6.5 if ranged else 2.0):
					state="windup"; state_time=attack_spec.windup; direction=toward.normalized(); lunge_hit=false
				else: velocity=toward.normalized()*float(attack_spec.speed)
		elif state=="windup":
			state_time-=delta
			visual.rotation.x=-.18
			arms[1].rotation.x=-1.5
			if state_time<=0:
				state="lunge"; state_time=.45
				if definition.kind=="goblin_slinger":
					var shot=Shot.new(); game.world_root.add_child(shot); shot.configure(game,self,direction)
					shot.damage=int(attack_spec.damage); game.projectiles.append(shot); lunge_hit=true
		elif state=="lunge":
			state_time-=delta
			arms[1].rotation.x=lerpf(-1.5,.75,1-state_time/.45)
			if definition.kind!="goblin_slinger":
				velocity=direction*float(attack_spec.lunge_speed)
				if not lunge_hit and distance<=float(player.combat.parry.contact_range) and player.try_parry(self): lunge_hit=true
				elif not lunge_hit and distance<.85:
					player.take_damage(int(attack_spec.damage),direction); lunge_hit=true
			if state_time<=0:
				state="cleave_windup" if definition.kind=="goblin_foreman" else "recover"
				state_time=.85 if state=="cleave_windup" else attack_spec.recovery
		elif state=="cleave_windup":
			state_time-=delta; arms[1].rotation.z=-1.2; visual.rotation.x=-.3
			if state_time<=0:
				if distance<1.65:
					if not player.try_parry(self): player.take_damage(11,toward.normalized())
				arms[1].rotation.z=0; state="recover"; state_time=1.8
		elif state=="recover":
			state_time-=delta; visual.rotation.x=lerpf(visual.rotation.x,0,delta*6)
			arms[1].rotation.x=lerpf(arms[1].rotation.x,0,delta*5)
			arms[1].rotation.z=lerpf(arms[1].rotation.z,0,delta*6)
			if state_time<=0: state="idle"
	if state=="idle":
		for i in range(2):
			legs[i].rotation.x=sin(phase*9+i*PI)*.45 if velocity.length()>.1 else 0.0
			arms[i].rotation.x=-legs[i].rotation.x*.5
		visual.position.y=absf(sin(phase*9))*.035 if velocity.length()>.1 else 0.0
	velocity+=knockback
	knockback=knockback.move_toward(Vector3.ZERO,delta*float(recoil_policy.deceleration))
	player.ground_world.move_grounded(self,delta)
