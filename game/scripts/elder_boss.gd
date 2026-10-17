extends "res://scripts/slime.gd"
## Arena-wide pursuit: never uses an ordinary mob's notice range or home leash.
const Model=preload("res://scripts/library_model.gd")
var game:Node
var art:Node3D
var attacks=0
var attack_kind="sweep"
var duration=1.0
var exposed=0.0
var rock:MeshInstance3D
var marker:MeshInstance3D
var formation:Array=[]
var target_point=Vector3.ZERO
var strikes=0
var pursuit_time=0.0
func configure(data:Dictionary,target:Node3D,saved:Dictionary={}) -> void:
	super.configure(data,target,saved)
	mob_category="humanoid"
	max_health=1100;health=max_health;size_class="giant"
	definition.merge({"display_name":"The Elder · Keeper of the Veiled Vault","combat_height":3.9,"combat_radius":1.45,"label_height":5.6},true)
	set_meta("library_creature",true)
	for child in visual.get_children():child.free()
	art=Model.new();visual.add_child(art);art.configure("res://assets/alpha2/forest_guardian.glb",6.0)
	# Use the donor's real foliage alpha rather than the older dying-skin atlas.
	for mesh in art.model.find_children("*","MeshInstance3D",true,false):
		if "tree" in String(mesh.name).to_lower():
			var leaves=StandardMaterial3D.new();leaves.albedo_texture=load("res://assets/creatures/elder-tree.png");leaves.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;leaves.alpha_scissor_threshold=.4;leaves.cull_mode=BaseMaterial3D.CULL_DISABLED;leaves.roughness=1.0;mesh.material_override=leaves
	body=MeshInstance3D.new();body.mesh=SphereMesh.new();body.visible=false;visual.add_child(body)
	var capsule=CapsuleShape3D.new();capsule.radius=1.2;capsule.height=3.8;collision.shape=capsule;collision.position.y=1.9
	rock=Props.box(visual,Vector3(1.4,.3,1.3),Vector3(1.1,.9,1.0),"#82949f");rock.visible=false
	var ring=TorusMesh.new();ring.inner_radius=5.4;ring.outer_radius=5.6;ring.rings=64;ring.ring_segments=6
	marker=Props.mesh_node(self,ring,Vector3(0,.06,0),"#73d5ff");marker.visible=false
	var mat=Props.mat("#73d5ff");mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;marker.material_override=mat
	for i in range(18):
		var fragment=Props.box(self,Vector3.ZERO,Vector3(.35,.45,.35),"#728a96");fragment.material_override=preload("res://scripts/rise_chamber.gd").stone_material();formation.append(fragment)
	state="forming";state_time=3.0;collision_layer=0;collision.disabled=true;visual.position.y=-4
	if has_node("Shadow"):get_node("Shadow").visible=false
func sword_weakspot_open() -> bool:return exposed>0 or state=="recover"
func take_damage(amount:int,away:Vector3) -> void:
	if state=="forming" or health<=0:return
	var before=state;var remaining=state_time
	super.take_damage(amount,away);knockback=Vector3.ZERO
	if health>0:state=before;state_time=remaining
func repel(_away:Vector3,_force:float,stun:float) -> void:
	if state=="forming" or health<=0:return
	exposed=3;state="recover";state_time=maxf(1.4,stun);parry_flash=.4;marker.visible=false;rock.visible=false
func open_armor() -> void:repel(Vector3.ZERO,0,2.5)
func breaker_expose(seconds:float) -> void:exposed=maxf(exposed,seconds);state="recover";state_time=1.5
func take_lance_damage(amount:int,away:Vector3) -> void:exposed=2;take_damage(amount,away)
func begin_attack(kind:String) -> void:
	attack_kind=kind;attacks+=1;strikes=0;lunge_hit=false;pursuit_time=0;direction=((player.position-position)*Vector3(1,0,1)).normalized()
	target_point=player.position*Vector3(1,0,1)
	duration={"sweep":1.0,"slam":1.45,"rush":1.0,"stone":1.6}[kind];state="windup";state_time=duration;marker.visible=kind=="slam";rock.visible=kind=="stone"
func form(delta:float) -> void:
	state_time=maxf(0,state_time-delta);var t=1-state_time/3.0
	visual.position.y=-4*(1-smoothstep(0,1,t));art.pose("rise",t,delta)
	for mesh in art.model.find_children("*","MeshInstance3D",true,false):mesh.transparency=1-smoothstep(.15,.9,t)
	for i in range(formation.size()):
		var a=i*TAU/formation.size()+t*5;formation[i].position=Vector3(sin(a)*(4*(1-t)+.5),.2+(i%5)*.7+sin(t*PI)*2,cos(a)*(4*(1-t)+.5));formation[i].scale=Vector3.ONE*maxf(.01,1-smoothstep(.6,1,t))
	if state_time<=0:
		state="idle";collision_layer=4;collision.set_deferred("disabled",false);visual.position.y=0
		for fragment in formation:fragment.queue_free()
		formation.clear()
func strike(reach:float,damage:int,wide:bool=false) -> void:
	var offset=(player.position-position)*Vector3(1,0,1)
	if offset.length()>reach or (not wide and direction.dot(offset.normalized())<.15):return
	if game.impact_blocked(position+Vector3.UP,player.position+Vector3.UP):return
	if player.position.y>1.1 and attack_kind=="sweep":return
	if offset.length()<=float(player.combat.parry.contact_range)+1.5 and player.try_parry(self):return
	player.take_damage(damage,offset.normalized())
func _physics_process(delta:float) -> void:
	if not simulation_enabled or not is_instance_valid(game) or not player.input_enabled or player.health<=0:return
	if health<=0:
		marker.visible=false;rock.visible=false;return
	if state=="forming":form(delta);return
	if not ai_enabled:return
	phase+=delta;exposed=maxf(0,exposed-delta);hit_flash=maxf(0,hit_flash-delta);parry_flash=maxf(0,parry_flash-delta)
	var offset=(player.position-position)*Vector3(1,0,1);var distance=offset.length();velocity=Vector3.ZERO
	if state=="idle":
		visual.rotation.y=lerp_angle(visual.rotation.y,atan2(offset.x,offset.z),minf(1,delta*5))
		if distance>9:pursuit_time+=delta
		else:pursuit_time=0
		if distance>6 and (attacks%3==2 or pursuit_time>=1.4):begin_attack("stone" if attacks%2==0 else "rush")
		elif distance>10 and attacks%2==1:begin_attack("rush")
		elif distance>3.7:velocity=offset.normalized()*3.2
		else:begin_attack("slam" if attacks%3==1 else "sweep")
	elif state=="windup":
		state_time-=delta
		if state_time>.25 and distance>.01:direction=offset.normalized()
		visual.rotation.y=atan2(direction.x,direction.z)
		if attack_kind=="stone":rock.position.y=lerpf(.25,3.4,1-state_time/duration)
		if state_time<=0:
			state="strike";duration=.85 if attack_kind=="sweep" else .65;state_time=duration
			if attack_kind=="stone":
				var projectile=load("res://scripts/elder_stone.gd").new();game.world_root.add_child(projectile);projectile.configure(game,self,direction);projectile.position=rock.global_position;projectile.direction=(player.position+Vector3.UP*.9-projectile.position).normalized();game.projectiles.append(projectile);rock.visible=false
	elif state=="strike":
		state_time-=delta;var t=1-state_time/duration
		if attack_kind=="rush":velocity=direction*10
		if attack_kind=="slam" and strikes==0 and t>=.4:
			strikes=1;strike(5.5,30,true);marker.visible=false;game._ground_slam(position+direction*2.5,true)
		elif attack_kind=="sweep":
			if strikes==0 and t>=.18:strikes=1;strike(4.8,19,true)
			elif strikes==1 and t>=.72:strikes=2;strike(4.8,21,true)
		elif attack_kind=="rush" and not lunge_hit and distance<2.8:
			lunge_hit=true;strike(3.0,25)
		if state_time<=0 and state=="strike":state="recover";state_time=1.6 if attack_kind=="slam" else 1.0;exposed=state_time
	elif state=="recover":
		state_time-=delta
		if state_time<=0:state="idle"
	var purpose="walk" if velocity.length()>.1 else "idle";var sample=-1.0
	if state=="windup":purpose="brace" if attack_kind=="slam" else "attack";sample=clampf(1-state_time/duration,0,1)*.38
	elif state=="strike":purpose="attack";sample=.38+clampf(1-state_time/duration,0,1)*.62
	art.pose(purpose,sample,delta);art.flash(hit_flash,exposed)
	# Stop inside the rim without resetting or de-aggroing. Reach covers its edge.
	var goal=position+velocity*delta;var radial=Vector2(goal.x/20.5,goal.z/22.5)
	if radial.length()>1:
		radial=radial.normalized();goal=Vector3(radial.x*20.5,0,radial.y*22.5);velocity=(goal-position)/maxf(delta,.001)
	velocity.y=0;move_and_slide();position.y=0;knockback=Vector3.ZERO
