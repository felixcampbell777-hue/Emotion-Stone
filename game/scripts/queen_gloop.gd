extends Node3D
const Props=preload("res://scripts/props.gd")
var game:Node
var queen:Node3D
var entry:Dictionary
var origin=Vector3.ZERO
var landing=Vector3.ZERO
var age=0.0
var duration=.95
var blob:MeshInstance3D
var health=1
var reflected=false
func configure(owner:Node,source:Node3D,variant:Dictionary,target:Vector3) -> void:
	game=owner; queen=source; entry=variant; origin=queen.position+Vector3.UP*1.8; landing=target; position=origin
	duration=float(game.menagery.catalog.queen_attack.lob_seconds); add_to_group("queen_brood"); add_to_group("menagery_effect")
	var sphere=SphereMesh.new(); sphere.radius=.34; sphere.height=.55; sphere.radial_segments=8; sphere.rings=4
	blob=Props.mesh_node(self,sphere,Vector3.ZERO,entry.color)
func repel(_away:Vector3,_force:float,_stun:float) -> void:
	if not is_instance_valid(queen) or queen.health<=0: queue_free(); return
	reflected=true; origin=position; landing=queen.position+Vector3.UP*.8; age=0; duration=.4
	blob.material_override=Props.mat("#9fe3ec")
func _physics_process(delta:float) -> void:
	if is_queued_for_deletion() or not game.simulation_active() or game.gallery_mode: return
	if not is_instance_valid(queen) or queen.health<=0: queue_free(); return
	age+=delta; var t=clampf(age/duration,0,1); var next=origin.lerp(landing,t)+Vector3.UP*(8*t*(1-t))
	var wall=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(position,next,1))
	if reflected and not wall.is_empty(): queue_free(); return
	if not wall.is_empty(): landing=game.current_world.safe_landing(wall.position); next=landing; t=1
	position=next; blob.scale=Vector3(1,.85+.2*sin(t*PI),1)
	if not reflected and position.distance_to(game.player.position+Vector3.UP*.8)<float(game.player.combat.parry.contact_range) and game.player.try_parry(self): return
	if t>=1:
		if reflected:
			if queen.position.distance_to(landing)<2: queen.take_damage(18,(queen.position-origin).normalized())
		else:
			var core=load("res://scripts/slime_core.gd").new(); game.world_root.add_child(core); core.setup_core(game,queen,entry,landing); game.enemies.append(core); game.add_enemy_bar(core)
		queue_free()
