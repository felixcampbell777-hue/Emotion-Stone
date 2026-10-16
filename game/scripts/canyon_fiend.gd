extends "res://scripts/slime.gd"
## Original four-armed Orchid Stalker. Body remains a normal damageable actor.
var game:Control
var art:Node3D
var joints:Dictionary={}
var rests:Dictionary={}
var tell:Node3D
var landing=Vector3.ZERO
var leap_start=Vector3.ZERO
var attacks=0
var exposed=0.0
var hit_once=false
var safe_drop=false
var pending_shots=0
var shot_clock=0.0

func configure(data:Dictionary,target:Node3D,saved:Dictionary={}) -> void:
	super.configure(data,target,saved)
	max_health=680;health=0 if int(saved.get("health",1))<=0 else max_health;size_class="giant"
	definition["display_name"]="Canyon Fiend · Orchid Stalker";definition["combat_height"]=3.9;definition["combat_radius"]=.9;definition["label_height"]=4.1
	set_meta("library_creature",true)
	for child in visual.get_children():child.free()
	art=load("res://assets/dreadmore/orchid-stalker.glb").instantiate();visual.add_child(art)
	for n in art.find_children("*","Node3D",true,false):
		if String(n.name).begins_with("Arm_") or String(n.name).begins_with("Fore_") or String(n.name).begins_with("Leg_") or n.name=="Head":joints[String(n.name)]=n;rests[String(n.name)]=n.transform
	body=MeshInstance3D.new();body.visible=false;visual.add_child(body)
	var shape=CapsuleShape3D.new();shape.radius=.75;shape.height=3.5;collision.shape=shape;collision.position.y=1.75
	state="perched";state_time=0;position=Vector3(30.8,8,-36);visual.rotation.y=PI/2
	collision.disabled=true;collision_layer=0;visible=health>0
	var ring=TorusMesh.new();ring.inner_radius=2.8;ring.outer_radius=3.0;ring.rings=48;ring.ring_segments=6
	tell=Props.mesh_node(self,ring,Vector3.ZERO,"#dba76d");tell.visible=false
	var material=StandardMaterial3D.new();material.albedo_color=Color("#e4b87d");material.emission_enabled=true;material.emission=Color("#b97a40");material.emission_energy_multiplier=1.2;tell.material_override=material
func aim() -> Vector3:
	var to=(player.position-position)*Vector3(1,0,1)
	return to.normalized() if to.length_squared()>.001 else Vector3.BACK
func face(heading:Vector3) -> void:visual.rotation.y=atan2(heading.x,heading.z)
func animate() -> void:
	var wall=state in ["perched","climb","wall_tell"]
	var strike=state in ["cleave","rush"]
	for key in joints:
		var n:Node3D=joints[key];n.transform=rests[key]
		var side=-1.0 if "L" in key else 1.0
		if key.begins_with("Arm_"):
			n.rotation.z=side*(.65 if wall else -.25 if strike else .10*sin(phase*3+side))
			n.rotation.x=-.75 if wall else -1.1*sin(clampf(1-state_time/.7,0,1)*PI) if strike else .1*sin(phase*2)
		elif key.begins_with("Fore_"):n.rotation.x=-.65 if wall else .2+sin(phase*3+side)*.16
		elif key.begins_with("Leg_"):n.rotation.x=-.45 if wall else sin(phase*6+side*PI/2)*.18 if velocity.length()>.1 else .04*sin(phase*2)
		elif key=="Head":n.rotation.z=.04*sin(phase*2);n.rotation.x=.15 if wall else -.08
	visual.position.y=.04*sin(phase*2)
func prepare_drop() -> void:
	landing=Vector3(clampf(player.position.x,10,26),0,clampf(player.position.z,-44,-28))
	leap_start=position;state="drop_tell";state_time=1.4;tell.visible=true;tell.global_position=landing+Vector3.UP*.06
func open_armor() -> void:
	exposed=4;pending_shots=0;hit_once=true;tell.visible=false
	if position.y>1:
		leap_start=position;landing=Vector3(22,0,-35);state="drop";state_time=.75;safe_drop=true
	else:state="recover";state_time=2.2
func sword_weakspot_open() -> bool:return exposed>0 or state=="recover"
func repel(_away:Vector3,_force:float,_stun:float) -> void:open_armor()
func take_damage(amount:int,away:Vector3) -> void:
	if state in ["perched","climb","wall_tell"] and exposed<=0:amount=maxi(1,roundi(amount*.6))
	var previous=state;var clock=state_time
	if health<=amount and position.y>1:position=home
	super.take_damage(amount,away);knockback=Vector3.ZERO
	if health>0:state=previous;state_time=clock
	else:tell.visible=false;pending_shots=0
func take_lance_damage(amount:int,away:Vector3) -> void:exposed=3;take_damage(amount,away)
func strike(damage:int,radius:float) -> void:
	if hit_once:return
	hit_once=true
	var to=(player.position-position)*Vector3(1,0,1)
	if to.length()<radius and not game.impact_blocked(position,player.position):
		if not player.try_parry(self):player.take_damage(damage,to.normalized())
func shoot() -> void:
	var shot=load("res://scripts/orchid_thorn.gd").new();game.current_world.add_child(shot);shot.configure(game,self);game.projectiles.append(shot)

func _physics_process(delta:float) -> void:
	if not simulation_enabled or health<=0:return
	phase+=delta;exposed=maxf(0,exposed-delta);velocity=Vector3.ZERO
	if not ai_enabled or player.health<=0:animate();return
	state_time-=delta
	var distance=Vector2(player.position.x-18,player.position.z+35).length()
	match state:
		"perched":
			if distance<14:prepare_drop()
		"drop_tell":
			face((landing-position)*Vector3(1,0,1))
			if state_time<=0:state="drop";state_time=.75
		"drop":
			var t=clampf(1-state_time/.75,0,1);position=leap_start.lerp(landing,t);position.y=lerpf(leap_start.y,0,t*t)
			if state_time<=0:
				position=landing;tell.visible=false;collision_layer=4;collision.set_deferred("disabled",false);hit_once=safe_drop;strike(32,3);safe_drop=false;state="recover";state_time=1.8;exposed=2
		"recover":
			if state_time<=0:state="hunt"
		"hunt":
			if distance>18:velocity=(home-position).normalized()*2
			else:
				direction=aim();face(direction)
				if position.distance_to(player.position)>4:velocity=direction*2.7
				else:attacks+=1;hit_once=false;state="cleave_tell" if attacks%3==1 else "rush_tell" if attacks%3==2 else "climb";state_time=1.15 if state!="climb" else 1.1;leap_start=position
		"cleave_tell","rush_tell":
			if state_time>.35:direction=aim();face(direction)
			if state_time<=0:state="cleave" if state=="cleave_tell" else "rush";state_time=.7;hit_once=false
		"cleave":
			if state_time<.4:strike(24,3.8)
			if state_time<=0:state="recover";state_time=1.2;exposed=1.4
		"rush":
			velocity=direction*8.5;strike(27,2.0)
			if state_time<=0:state="recover";state_time=1.5;exposed=1.7
		"climb":
			position=leap_start.lerp(Vector3(30.8,8,-36),clampf(1-state_time/1.1,0,1));collision_layer=0;collision.set_deferred("disabled",true)
			if state_time<=0:state="wall_tell";state_time=1.6;pending_shots=3;shot_clock=0
		"wall_tell":
			face(aim());shot_clock+=delta
			if state_time<.8 and pending_shots>0 and shot_clock>.28:shoot();pending_shots-=1;shot_clock=0
			if state_time<=0:prepare_drop()
	if velocity.length_squared()>0:
		move_and_slide();position.x=clampf(position.x,7,29);position.z=clampf(position.z,-47,-25)
	animate()
