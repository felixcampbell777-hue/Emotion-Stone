extends "res://scripts/slime.gd"
const Model=preload("res://scripts/library_model.gd")
const Rock=preload("res://scripts/rock_projectile.gd")
var game:Node
var art:Node3D
var spec:Dictionary
var armor_open=0.0
var count=0
var warning:MeshInstance3D
var encounter_owned=false
var encounter_hidden=false
var encounter_emerge=0.0
var encounter_goal=Vector3.ZERO
var encounter_speed=1.0
var encounter_engaged=false
var encounter_attack_allowed=false
func configure(data:Dictionary,target:Node3D,saved:Dictionary={}) -> void:
	super.configure(data,target,saved);set_meta("library_creature",true)
	spec=JSON.parse_string(FileAccess.get_file_as_string("res://content/alpha2_creatures.json"))[data.kind]
	max_health=int(spec.health);health=clampi(int(saved.get("health",max_health)),0,max_health);size_class=spec.size
	definition["display_name"]=spec.name;definition["combat_height"]=spec.height;definition["combat_radius"]=spec.radius;definition["label_height"]=spec.height+.35
	if data.kind=="library_rat":definition.combat_height=1.0
	for child in visual.get_children():child.free()
	art=Model.new();visual.add_child(art);art.configure(spec.model,float(spec.height));art.rotation.y=float(spec.get("yaw",0))
	body=MeshInstance3D.new();body.mesh=SphereMesh.new();body.visible=false;visual.add_child(body)
	var shape=CapsuleShape3D.new();shape.radius=float(spec.radius)*.72;shape.height=maxf(float(spec.height),shape.radius*2);collision.shape=shape;collision.position.y=shape.height*.5
	var ring=TorusMesh.new();ring.inner_radius=1.25;ring.outer_radius=1.36;ring.rings=40;ring.ring_segments=6
	warning=Props.mesh_node(self,ring,Vector3(0,.14,0),"#edbc68");warning.visible=false
	var mat=StandardMaterial3D.new();mat.albedo_color=Color("#eabc6a");mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;warning.material_override=mat
	visible=health>0;collision.disabled=health<=0;collision_layer=4 if health>0 else 0
	if has_node("Shadow"):get_node("Shadow").visible=false
func sword_weakspot_open() -> bool:return armor_open>0
func open_armor() -> void:armor_open=4;repel(Vector3.ZERO,0,2.0)
func take_damage(amount:int,away:Vector3) -> void:
	if encounter_hidden and health>0:
		encounter_hidden=false;visible=true;collision_layer=4;encounter_emerge=0
	if definition.kind=="library_sentinel" and armor_open<=0 and state not in ["recover"]:amount=maxi(1,roundi(amount*.35))
	super.take_damage(amount,away)
func take_lance_damage(amount:int,away:Vector3) -> void:armor_open=3;take_damage(amount,away)
func _physics_process(delta:float) -> void:
	if not simulation_enabled or health<=0:return
	if is_instance_valid(game) and game.game_mode=="world_rise" and state=="idle" and not encounter_engaged and knockback.length_squared()<.01 and player.position.distance_squared_to(position)>3600:
		velocity=Vector3.ZERO;return
	if encounter_hidden:return
	if encounter_emerge>0:
		encounter_emerge=maxf(0,encounter_emerge-delta);visual.position.y=-float(spec.height)*encounter_emerge/.75;art.pose("idle",-1,delta);return
	phase+=delta;hit_flash=maxf(0,hit_flash-delta);parry_flash=maxf(0,parry_flash-delta);armor_open=maxf(0,armor_open-delta)
	velocity=Vector3.ZERO;warning.visible=state=="burrow";visual.position.y=0
	var toward=(player.position-position)*Vector3(1,0,1);var distance=toward.length();var style=String(spec.style)
	if ai_enabled and player.health>0:
		if state=="idle":
			if encounter_owned:
				var goal=(encounter_goal-position)*Vector3(1,0,1)
				if goal.length()>.35:
					velocity=goal.normalized()*minf(float(spec.speed)*encounter_speed,goal.length()/maxf(delta,.001));visual.rotation.y=lerp_angle(visual.rotation.y,atan2(goal.x,goal.z),minf(1,delta*6))
				if encounter_engaged and encounter_attack_allowed and distance<float(spec.range) and not game.impact_blocked(position+Vector3.UP*.6,player.position+Vector3.UP*.6):
					count+=1;direction=toward.normalized();state="windup";state_time=float(spec.windup);lunge_hit=false;visual.rotation.y=atan2(direction.x,direction.z);velocity=Vector3.ZERO
			elif distance<12:
				visual.rotation.y=lerp_angle(visual.rotation.y,atan2(toward.x,toward.z),minf(1,delta*6))
				if distance<float(spec.range):
					count+=1;direction=toward.normalized();state="windup";state_time=float(spec.windup);lunge_hit=false
					visual.rotation.y=atan2(direction.x,direction.z)
				else:
					velocity=toward.normalized()*float(spec.speed)
					if style=="spider":velocity+=Vector3(toward.z,0,-toward.x).normalized()*sin(phase*3)*.8
		elif state=="windup":
			# Follow the target during preparation, then commit before the strike.
			if state_time>.18 and distance>.001:direction=toward.normalized()
			visual.rotation.y=atan2(direction.x,direction.z)
			state_time-=delta
			if state_time<=0:
				if style=="sentinel" and count%2==0:
					var rock=Rock.new();game.world_root.add_child(rock);rock.configure(game,self,direction);game.projectiles.append(rock);state="recover";state_time=2
				else:state="burrow" if style in ["crab","sentinel"] else "lunge";state_time=.9 if state=="burrow" else float(spec.lunge_seconds)
		elif state=="burrow":
			visual.rotation.y=atan2(direction.x,direction.z)
			state_time-=delta;visual.position.y=-.45*sin((1-state_time/.9)*PI);velocity=direction*float(spec.attack_speed)*.5
			if state_time<=0:state="lunge";state_time=float(spec.lunge_seconds);armor_open=2.4
		elif state=="lunge":
			visual.rotation.y=atan2(direction.x,direction.z)
			state_time-=delta;velocity=direction*float(spec.attack_speed)
			if style=="spider":visual.position.y=sin(clampf(1-state_time/float(spec.lunge_seconds),0,1)*PI)*.4
			if not lunge_hit and not game.impact_blocked(position+Vector3.UP*.6,player.position+Vector3.UP*.6):
				if distance<=float(player.combat.parry.contact_range) and player.try_parry(self):lunge_hit=true
				elif distance<float(spec.radius)+.6:player.take_damage(int(spec.damage),direction);lunge_hit=true
			if state_time<=0:state="recover";state_time=float(spec.recovery)
		elif state=="recover":
			state_time-=delta
			if state_time<=0:state="idle"
	var purpose="burrow" if state=="burrow" else "attack" if state in ["windup","lunge"] else "walk" if velocity.length()>.1 else "idle"
	var clip_phase=-1.0
	if state=="windup":clip_phase=clampf(1-state_time/float(spec.windup),0,1)*.35
	elif state=="lunge":clip_phase=.35+clampf(1-state_time/float(spec.lunge_seconds),0,1)*.65
	elif state=="burrow":clip_phase=clampf(1-state_time/.9,0,1)
	var animation_delta=game.worldrise.animation_step(self,delta) if game.game_mode=="world_rise" else delta
	if animation_delta>0:art.pose(purpose,clip_phase,animation_delta);art.flash(hit_flash,maxf(parry_flash,armor_open))
	velocity+=knockback;knockback=knockback.move_toward(Vector3.ZERO,delta*float(recoil_policy.deceleration));game.current_world.move_grounded(self,delta)
