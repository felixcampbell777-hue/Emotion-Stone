extends "res://scripts/slime.gd"
## New guardian: reflected stones, readable ring slams, aimed rush and a double-ring second phase.
const Guardian=preload("res://scripts/warden_visual.gd")
const Rock=preload("res://scripts/rock_projectile.gd")
var game:Control
var guardian:Node3D
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

func configure(data:Dictionary,target:Node3D,saved:Dictionary={}) -> void:
	super.configure(data,target,saved)
	spec=JSON.parse_string(FileAccess.get_file_as_string("res://content/alpha2.json")).boss_tuning
	max_health=int(spec.health);health=0 if int(saved.get("health",1))<=0 else max_health
	definition["display_name"]="Aurek, the Rootbound Bellkeeper";definition["combat_height"]=3.2;definition["combat_radius"]=1.05;definition["label_height"]=3.5
	size_class="giant"
	for child in visual.get_children(): child.free()
	guardian=Guardian.new();visual.add_child(guardian);guardian.build();guardian.scale=Vector3.ONE*1.12;body=guardian.torso
	# An open bronze bell crown and dangling root chimes distinguish him from a stone warden.
	for i in range(9):
		var angle=i*TAU/9
		var root=Props.cone(guardian,Vector3(sin(angle)*.46,3.0,cos(angle)*.35),.13,.85,"#8c7648",.035);root.rotation.z=-sin(angle)*.35
		var chime=Props.cone(guardian,Vector3(sin(angle)*.8,1.0,cos(angle)*.65),.11,.4,"#bda470",.17)
		chime.rotation.z=sin(angle)*.4
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
	armor_open=5;state="recover";state_time=2.8;game.notify("The reflected stone cracks Aurek's shell. Strike the blue heart!")
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

func _physics_process(delta:float) -> void:
	if not simulation_enabled or health<=0: return
	phase+=delta;armor_open=maxf(0,armor_open-delta);hit_flash=maxf(0,hit_flash-delta)
	guardian.animate("windup" if state in ["rock_tell","slam_tell","rush_tell"] else state,state_time,armor_open,phase)
	tell.visible=state=="slam_tell";update_ring(delta);velocity=Vector3.ZERO
	if ai_enabled and player.health>0:
		var toward=(player.position-position)*Vector3(1,0,1);var distance=toward.length()
		if state=="idle":
			visual.rotation.y=lerp_angle(visual.rotation.y,atan2(toward.x,toward.z),delta*3)
			if distance<16:
				attacks+=1;direction=toward.normalized();lunge_hit=false
				state=["rock_tell","slam_tell","rush_tell"][(attacks-1)%3];state_time=float(spec.windup)
				game.notify({"rock_tell":"Aurek lifts a stone · reflect it with a timed parry.","slam_tell":"The bell tolls · leave the amber circle. Jump the low ring.","rush_tell":"Aurek lowers his crown · sidestep or parry the charge."}[state])
			else: velocity=toward.normalized()*1.25
		elif state in ["rock_tell","slam_tell","rush_tell"]:
			state_time-=delta
			if state_time<=0:
				if state=="rock_tell":
					var shot=Rock.new();game.world_root.add_child(shot);shot.configure(game,self,direction);game.projectiles.append(shot);state="recover";state_time=2.0
				elif state=="slam_tell":
					if distance<5.5 and player.position.y-position.y<.8: player.take_damage(int(spec.damage),toward.normalized())
					begin_ring();ring_second=health<max_health*float(spec.phase_threshold);armor_open=3.4;state="recover";state_time=3.0
				else: state="lunge";state_time=.85
		elif state=="lunge":
			state_time-=delta;velocity=direction*8.0
			if not lunge_hit and distance<float(player.combat.parry.contact_range)+.5 and player.try_parry(self): lunge_hit=true
			elif not lunge_hit and distance<1.4: player.take_damage(int(spec.damage),direction);lunge_hit=true
			if state_time<=0: state="recover";state_time=float(spec.recovery);armor_open=maxf(armor_open,2)
		elif state=="recover":
			state_time-=delta
			if state_time<=0: state="idle"
	game.current_world.move_grounded(self,delta)
