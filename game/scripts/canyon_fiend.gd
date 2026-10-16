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
var wall_index=0
var wall_target=Vector3(30.8,8,-36)
var wall_start=Vector3.ZERO
var wall_hops=0
var recovery_kind="slam"
var impact_count=0
var face_goal=PI/2
const PERCHES=[Vector3(30.8,8,-36),Vector3(22,9,-46.8),Vector3(5.2,7.5,-31),Vector3(25,8,-25.2)]
func begin_climb() -> void:
	wall_index=(wall_index+1)%PERCHES.size();wall_target=PERCHES[wall_index];leap_start=position;state="climb";state_time=1.1;wall_hops=0
func begin_wall_scramble() -> void:
	wall_start=position;wall_target=PERCHES[wall_index]+Vector3(0,1.0,0)
	if wall_index in [0,2]:wall_target.z+=3.0 if wall_index==0 else -3.0
	else:wall_target.x+=-3.0 if wall_index==1 else 3.0
	state="wall_scramble";state_time=.75
func slam_effect() -> void:
	impact_count+=1
	var effect=load("res://scripts/fiend_impact.gd").new();game.current_world.add_child(effect);effect.configure(game,landing)


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
	collision.disabled=true;collision_layer=0;visible=health>0;art.visible=false
	var ring=TorusMesh.new();ring.inner_radius=2.8;ring.outer_radius=3.0;ring.rings=48;ring.ring_segments=6
	tell=Props.mesh_node(self,ring,Vector3.ZERO,"#dba76d");tell.visible=false
	var material=StandardMaterial3D.new();material.albedo_color=Color("#e4b87d");material.emission_enabled=true;material.emission=Color("#b97a40");material.emission_energy_multiplier=1.2;tell.material_override=material
func aim() -> Vector3:
	var to=(player.position-position)*Vector3(1,0,1)
	return to.normalized() if to.length_squared()>.001 else Vector3.BACK
func face(heading:Vector3) -> void:face_goal=atan2(heading.x,heading.z)
func wall_facing() -> Vector3:return [Vector3.RIGHT,Vector3.FORWARD,Vector3.LEFT,Vector3.BACK][wall_index]
func animate(delta:float=1.0) -> void:
	var wall=state in ["perched","climb","wall_tell","wall_scramble","wall_jump"]
	var gait=phase*(17 if wall else 13)
	var moving=state in ["hunt","rush","climb","wall_scramble","wall_jump"]
	var crouch=0.0;var pitch=.12;var roll=0.0;var twist=0.0;var arm_lift=0.0;var spread=.18
	var fold=.3;var leg_fold=.1
	if moving:
		crouch=.38;pitch=.35;roll=sin(gait)*.10;fold=.65;spread=.55;leg_fold=.48
	if wall:
		pitch=.12;spread=.85;arm_lift=-.8;fold=-.65;crouch=0
	if state=="drop_tell":
		var t=clampf(1-state_time/1.4,0,1);arm_lift=-1.5*t;spread=.4+.5*t;fold=-.8;crouch=.25*t;pitch=-.2*t
	elif state=="drop":
		var t=clampf(1-state_time/.75,0,1);var open=smoothstep(.25,.85,t)
		arm_lift=lerpf(-1.5,.75,open);spread=lerpf(.85,-.35,open);fold=lerpf(-1.0,.1,open);leg_fold=.85*(1-open);pitch=lerpf(-.15,.65,open);crouch=.2
	elif state=="recover":
		var duration=1.8 if recovery_kind=="slam" else 1.5 if recovery_kind=="rush" else 1.2
		var t=clampf(1-state_time/duration,0,1);var release=smoothstep(.28,1,t)
		crouch=lerpf(.55,0,release);pitch=lerpf(.55,.12,release);arm_lift=lerpf(.85,0,release);spread=lerpf(-.35,.18,release);fold=lerpf(.1,.3,release);leg_fold=lerpf(.65,.1,release)
	elif state in ["cleave_tell","cleave"]:
		var t=clampf(1-state_time/(1.15 if state=="cleave_tell" else .7),0,1)
		var sweep=smoothstep(.05,.7,t)
		twist=.55*t if state=="cleave_tell" else lerpf(.55,-.75,sweep)
		spread=1.1 if state=="cleave_tell" else lerpf(1.1,.12,sweep);arm_lift=-.35 if state=="cleave_tell" else .55*sweep
		crouch=.25;pitch=.3;fold=-.3
	elif state in ["rush_tell","rush"]:
		crouch=.6;pitch=.62;arm_lift=.35;spread=.7;leg_fold=.7;fold=.8
	var blend=1-exp(-18*delta)
	for key in joints:
		var n:Node3D=joints[key];var side=-1.0 if "L" in key else 1.0;var lower=key.ends_with("_1")
		var beat=gait+(PI if side<0 else 0)+(PI if lower else 0);var stride=sin(beat) if moving else sin(phase*2+side)*.06
		var angles=Vector3.ZERO
		if key.begins_with("Arm_"):
			angles=Vector3(arm_lift+stride*.42,side*twist*.35,side*(spread+stride*.23))
			if lower:angles.x+=.28;angles.z*=.8
		elif key.begins_with("Fore_"):angles=Vector3(fold-stride*.5,side*twist*.4,side*.12)
		elif key.begins_with("Leg_"):angles=Vector3(leg_fold+stride*.55,side*.12,side*(.12+maxf(0,-stride)*.16))
		elif key=="Head":angles=Vector3(-pitch*.45,.12*sin(phase*2),-roll*.5)
		if state=="wall_tell" and key=="Arm_R_0":angles.x+=.55*maxf(0,1-shot_clock/.28)
		if wall and key=="Head":angles.y+=clampf(wrapf(atan2(aim().x,aim().z)-visual.rotation.y,-PI,PI),-.8,.8)
		var target=(rests[key].basis*Basis.from_euler(angles)).get_rotation_quaternion()
		n.quaternion=n.quaternion.slerp(target,blend)
	var bob=absf(sin(gait))*.075 if moving else .025*sin(phase*2)
	visual.position=visual.position.lerp(Vector3(0,-crouch+bob,0),blend)
	visual.rotation.y=lerp_angle(visual.rotation.y,face_goal,blend)
	visual.rotation.x=lerp_angle(visual.rotation.x,pitch,blend);visual.rotation.z=lerp_angle(visual.rotation.z,roll,blend)
	art.rotation.y=lerp_angle(art.rotation.y,twist,blend)
	if tell.visible:
		tell.scale=Vector3.ONE*(1+.035*sin(phase*14));tell.global_position=landing+Vector3.UP*.06
func prepare_drop() -> void:
	art.visible=true
	landing=Vector3(clampf(player.position.x,10,26),0,clampf(player.position.z,-44,-28))
	leap_start=position;state="drop_tell";state_time=1.4;tell.visible=true;tell.global_position=landing+Vector3.UP*.06
func open_armor() -> void:
	recovery_kind="slam";exposed=4;pending_shots=0;hit_once=true;tell.visible=false
	if position.y>1:
		leap_start=position;landing=Vector3(22,0,-35);state="drop";state_time=.75;safe_drop=true
	else:state="recover";state_time=2.2
func sword_weakspot_open() -> bool:return exposed>0 or state=="recover"
func repel(_away:Vector3,_force:float,_stun:float) -> void:open_armor()
func take_damage(amount:int,away:Vector3) -> void:
	if state in ["perched","climb","wall_tell","wall_scramble","wall_jump"] and exposed<=0:amount=maxi(1,roundi(amount*.6))
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
	if not ai_enabled or player.health<=0:animate(delta);return
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
				recovery_kind="slam";slam_effect()
				position=landing;tell.visible=false;collision_layer=4;collision.set_deferred("disabled",false);hit_once=safe_drop;strike(32,3);safe_drop=false;state="recover";state_time=1.8;exposed=2
		"recover":
			if state_time<=0:state="hunt"
		"hunt":
			if distance>18:velocity=(home-position).normalized()*2
			else:
				direction=aim();face(direction)
				if position.distance_to(player.position)>4:
					var side=direction.cross(Vector3.UP);var burst=2.4+2.0*maxf(0,sin(phase*9))
					velocity=(direction+side*sin(phase*4)*.65).normalized()*burst
				else:
					attacks+=1;hit_once=false;state="cleave_tell" if attacks%3==1 else "rush_tell" if attacks%3==2 else "climb";state_time=1.15;leap_start=position
					if state=="climb":begin_climb()
		"cleave_tell","rush_tell":
			if state_time>.35:direction=aim();face(direction)
			if state_time<=0:state="cleave" if state=="cleave_tell" else "rush";state_time=.7;hit_once=false
		"cleave":
			if state_time<.4:strike(24,3.8)
			if state_time<=0:recovery_kind="cleave";state="recover";state_time=1.2;exposed=1.4
		"rush":
			velocity=direction*8.5;strike(27,2.0)
			if state_time<=0:recovery_kind="rush";state="recover";state_time=1.5;exposed=1.7
		"climb":
			var t=clampf(1-state_time/1.1,0,1);position=leap_start.lerp(wall_target,t)+Vector3.UP*(sin(t*PI)*2.3);face(wall_target-leap_start)
			collision_layer=0;collision.set_deferred("disabled",true)
			if state_time<=0:begin_wall_scramble()
		"wall_scramble":
			var t=clampf(1-state_time/.75,0,1);position=wall_start.lerp(wall_target,t);face(wall_facing())
			if state_time<=0:state="wall_tell";state_time=1.6;pending_shots=3;shot_clock=0
		"wall_tell":
			face(wall_facing());shot_clock+=delta
			if state_time<.8 and pending_shots>0 and shot_clock>.28:shoot();pending_shots-=1;shot_clock=0
			if state_time<=0:
				if wall_hops==0:
					wall_hops=1;wall_index=(wall_index+1)%PERCHES.size();leap_start=position;wall_target=PERCHES[wall_index];state="wall_jump";state_time=.85
				else:prepare_drop()
		"wall_jump":
			var t=clampf(1-state_time/.85,0,1);position=leap_start.lerp(wall_target,t)+Vector3.UP*sin(t*PI)*2.0;face(wall_target-leap_start)
			if state_time<=0:begin_wall_scramble()
	if velocity.length_squared()>0:
		move_and_slide();position.x=clampf(position.x,7,29);position.z=clampf(position.z,-47,-25)
	animate(delta)
