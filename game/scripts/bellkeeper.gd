extends "res://scripts/slime.gd"
## New guardian: reflected stones, readable ring slams, aimed rush and a double-ring second phase.
const Guardian=preload("res://scripts/library_model.gd")
const Rock=preload("res://scripts/bell_seed.gd")
var game:Control
var art:Node3D
var armor_open=0.0
var attacks=0
var ring_radius=-1.0
var ring_previous=0.0
var ring_hit=false
var ring_second=false
var ring_delay=0.0
var ring_mesh:MeshInstance3D
var tell:MeshInstance3D
var spec:Dictionary
var seed:Node3D
var heart:MeshInstance3D
var hazards:Array=[]
var melee_step=0

func configure(data:Dictionary,target:Node3D,saved:Dictionary={}) -> void:
	super.configure(data,target,saved)
	spec=JSON.parse_string(FileAccess.get_file_as_string("res://content/alpha2.json")).boss_tuning
	max_health=int(spec.health);health=0 if int(saved.get("health",1))<=0 else max_health
	definition["display_name"]="Aurek, the Rootbound Bellkeeper";definition["combat_height"]=3.2;definition["combat_radius"]=1.05;definition["label_height"]=3.5
	size_class="giant"
	set_meta("library_creature",true)
	for child in visual.get_children(): child.free()
	art=Guardian.new();visual.add_child(art);art.configure("res://assets/alpha2/forest_guardian.glb",3.4)
	for entry in art.surfaces:
		entry[0].roughness=.94;entry[0].normal_scale=.95;entry[1]*=Color("#d0dfbd")
	seed=Rock.pod(self);seed.visible=false
	var gem=SphereMesh.new();gem.radius=.13;gem.height=.28;heart=Props.mesh_node(visual,gem,Vector3(0,1.8,.43),"#7cdedb")
	var glow=StandardMaterial3D.new();glow.albedo_color=Color("#85e7de");glow.emission_enabled=true;glow.emission=Color("#47c5ca");glow.emission_energy_multiplier=2;heart.material_override=glow
	body=MeshInstance3D.new();body.mesh=SphereMesh.new();body.visible=false;visual.add_child(body)
	var shape=CapsuleShape3D.new();shape.radius=.85;shape.height=3.0;collision.shape=shape;collision.position.y=1.5
	var torus=TorusMesh.new();torus.inner_radius=.94;torus.outer_radius=1.06;torus.rings=64;torus.ring_segments=8
	ring_mesh=Props.mesh_node(self,torus,Vector3(0,.12,0),"#9bddd3");ring_mesh.visible=false
	var material=StandardMaterial3D.new();material.albedo_color=Color("#9fe6df");material.emission_enabled=true;material.emission=Color("#5dabad");material.emission_energy_multiplier=1.2;ring_mesh.material_override=material
	var disc=CylinderMesh.new();disc.top_radius=6;disc.bottom_radius=6;disc.height=.018;disc.radial_segments=64
	tell=Props.mesh_node(self,disc,Vector3(0,.14,0),"#d6a35d");tell.visible=false
	var warning=StandardMaterial3D.new();warning.albedo_color=Color(.95,.58,.14,.36);warning.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;warning.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;warning.no_depth_test=true;tell.material_override=warning
	visible=health>0;collision.disabled=health<=0;collision_layer=4 if health>0 else 0

func sword_weakspot_open() -> bool: return armor_open>0
func open_armor() -> void:
	armor_open=5;state="recover";state_time=2.8;clear_roots();seed.visible=false;game.notify("The returned thornseed parts Aurek's bark. Strike the blue heart!")
func repel(_away:Vector3,_force:float,_stun:float) -> void: open_armor()
func take_damage(amount:int,away:Vector3) -> void:
	var old_state=state;var remaining=state_time
	super.take_damage(amount if armor_open>0 else maxi(1,roundi(amount*.22)),away)
	knockback=Vector3.ZERO
	if health>0: state=old_state;state_time=remaining
func take_lance_damage(amount:int,away:Vector3) -> void:
	armor_open=maxf(armor_open,2.6);take_damage(amount,away)
func breaker_expose(seconds:float) -> void: armor_open=maxf(armor_open,seconds);parry_flash=seconds

func begin_ring() -> void:
	ring_radius=.2;ring_previous=0;ring_hit=false;ring_mesh.visible=true
func update_ring(delta:float) -> void:
	if ring_delay>0:
		ring_delay-=delta
		if ring_delay<=0: begin_ring()
	if ring_radius<0: return
	ring_previous=ring_radius;ring_radius+=delta*7.5;ring_mesh.scale=Vector3(ring_radius,1,ring_radius)
	var planar=(player.position-position)*Vector3(1,0,1);var distance=planar.length()
	if not ring_hit and distance>=ring_previous-.48 and distance<=ring_radius+.48 and player.position.y-position.y<.8:
		var hit=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(position+Vector3.UP*.4,player.position+Vector3.UP*.4,1))
		if hit.is_empty(): player.take_damage(int(spec.ring_damage),planar.normalized());ring_hit=true
	if ring_radius>12:
		ring_radius=-1;ring_mesh.visible=false
		if ring_second: ring_second=false;ring_delay=.25

func clear_roots() -> void:
	for hazard in hazards:
		if is_instance_valid(hazard.node):hazard.node.queue_free()
	hazards.clear()
func prepare_roots() -> void:
	clear_roots()
	for i in range(4 if health<max_health*.5 else 3):
		var point=player.position+Vector3((i-1)*1.8,0,-i*1.2);point.y=game.current_world.ground_height(point)
		var node=Node3D.new();add_child(node);node.global_position=point
		var circle=TorusMesh.new();circle.inner_radius=1.03;circle.outer_radius=1.12;circle.rings=32;circle.ring_segments=6
		var marker=Props.mesh_node(node,circle,Vector3(0,.04,0),"#d4c476")
		var spike=Props.cone(node,Vector3(0,.0075,0),.4,1.5,"#6e7246",0);spike.material_override=load("res://scripts/environment_art.gd").texture_material("pine_bark",1.6,Color("#a0b775"));spike.scale.y=.01;spike.visible=false
		hazards.append({"node":node,"spike":spike,"marker":marker,"hit":false,"at":point,"delay":.15+i*.35})
func update_roots(elapsed:float) -> void:
	for hazard in hazards:
		var t=elapsed-float(hazard.delay)
		hazard.spike.scale.y=maxf(.01,sin(clampf(t/.65,0,1)*PI));hazard.marker.visible=t<.65
		hazard.spike.position.y=.75*hazard.spike.scale.y;hazard.spike.visible=t>=0 and t<.65
		if t>=0 and not hazard.hit:
			hazard.hit=true
			if (player.position-hazard.at).length()<1.35 and not game.impact_blocked(position,hazard.at):player.take_damage(18,(player.position-position).normalized())

func _physics_process(delta:float) -> void:
	if not simulation_enabled or health<=0: return
	phase+=delta;armor_open=maxf(0,armor_open-delta);hit_flash=maxf(0,hit_flash-delta)
	var telling=state.ends_with("tell")
	var purpose="brace" if telling else "attack" if state in ["lunge","cleave","roots"] else "walk" if velocity.length()>.1 else "idle"
	art.pose(purpose,(1-state_time/float(spec.windup))*.6 if telling else (1-state_time/.85) if state in ["lunge","cleave"] else -1,delta);art.flash(hit_flash,armor_open);heart.visible=armor_open>0
	seed.visible=state=="rock_tell"
	if seed.visible:
		var t=clampf(1-state_time/float(spec.windup),0,1);seed.position=direction*1.5+Vector3.UP*lerpf(.05,1.3,t);seed.scale=Vector3.ONE*lerpf(.05,1.2,t);seed.rotation.y=phase*2
	tell.visible=state=="slam_tell";update_ring(delta);velocity=Vector3.ZERO
	if ai_enabled and player.health>0:
		var toward=(player.position-position)*Vector3(1,0,1);var distance=toward.length()
		if state=="idle":
			visual.rotation.y=lerp_angle(visual.rotation.y,atan2(toward.x,toward.z),delta*3)
			if distance<16:
				attacks+=1;direction=toward.normalized();lunge_hit=false
				state=["cleave_tell","rock_tell","roots_tell","slam_tell","rush_tell"][(attacks-1)%5];state_time=float(spec.windup)*( .88 if health<max_health*.5 else 1.0)
				if state=="roots_tell":prepare_roots()
				game.notify({"rock_tell":"A thornseed grows from the earth · parry it back.","roots_tell":"Roots mark your footing · leave the circles before they erupt.","cleave_tell":"Aurek coils for two sweeping claws · back away or parry.","slam_tell":"The bell tolls · leave the amber circle. Jump the low ring.","rush_tell":"Aurek lowers his crown · sidestep or parry the charge."}[state])
			else: velocity=toward.normalized()*1.25
		elif state.ends_with("tell"):
			state_time-=delta
			if state_time<=0:
				if state=="rock_tell":
					var shot=Rock.new();game.world_root.add_child(shot);shot.configure(game,self,direction);shot.position=seed.global_position;game.projectiles.append(shot);seed.visible=false;state="recover";state_time=2.0
				elif state=="cleave_tell":state="cleave";state_time=.85;melee_step=0
				elif state=="roots_tell":state="roots";state_time=1.8
				elif state=="slam_tell":
					if distance<5.5 and player.position.y-position.y<.8: player.take_damage(int(spec.damage),toward.normalized())
					begin_ring();ring_second=health<max_health*float(spec.phase_threshold);armor_open=3.4;state="recover";state_time=3.0
				else: state="lunge";state_time=.85
		elif state=="cleave":
			state_time-=delta;velocity=direction*.6
			var elapsed=.85-state_time
			if (melee_step==0 and elapsed>=.24) or (melee_step==1 and elapsed>=.62):
				melee_step+=1
				if distance<3.3 and direction.dot(toward.normalized())>-.15 and not game.impact_blocked(position,player.position):
					if not player.try_parry(self):player.take_damage(21,direction)
			if state=="cleave" and state_time<=0:state="recover";state_time=2;armor_open=2
		elif state=="roots":
			state_time-=delta;update_roots(1.8-state_time)
			if state_time<=0:clear_roots();state="recover";state_time=2.2;armor_open=2
		elif state=="lunge":
			state_time-=delta;velocity=direction*8.0
			if not lunge_hit and distance<float(player.combat.parry.contact_range)+.5 and player.try_parry(self): lunge_hit=true
			elif not lunge_hit and distance<1.4: player.take_damage(int(spec.damage),direction);lunge_hit=true
			if state_time<=0: state="recover";state_time=float(spec.recovery);armor_open=maxf(armor_open,2)
		elif state=="recover":
			state_time-=delta
			if state_time<=0: state="idle"
	game.current_world.move_grounded(self,delta)
