extends Node3D
var game:Node
var thrower:Node3D
var direction=Vector3.ZERO
var reflected=false
var life=4.0
func configure(owner:Node,source:Node3D) -> void:
	game=owner;thrower=source;global_position=source.joints.get("Fore_R_0",source.visual).global_position
	direction=(game.player.position+Vector3.UP*.9-global_position).normalized()
	var shape=CylinderMesh.new();shape.top_radius=0;shape.bottom_radius=.10;shape.height=.65;shape.radial_segments=12
	var mesh=MeshInstance3D.new();mesh.mesh=shape;mesh.material_override=load("res://scripts/props.gd").mat("#986286");add_child(mesh)
	mesh.quaternion=Quaternion(Vector3.UP,direction)
func repel(_away:Vector3,_force:float,_stun:float) -> void:
	reflected=true
	direction=(thrower.global_position+Vector3.UP*1.7-global_position).normalized()
func _physics_process(delta:float) -> void:
	if not is_instance_valid(game) or not game.simulation_active():return
	if not is_instance_valid(thrower) or thrower.health<=0:queue_free();return
	life-=delta;var next=global_position+direction*(17 if reflected else 12)*delta
	var target=thrower.global_position+Vector3.UP*1.7 if reflected else game.player.position+Vector3.UP*.9
	var near=Geometry3D.get_closest_point_to_segment(target,global_position,next)
	if near.distance_to(target)<(.95 if reflected else 1.0):
		if reflected:thrower.open_armor();thrower.take_lance_damage(38,direction);queue_free();return
		if game.player.try_parry(self):return
		game.player.take_damage(18,direction);queue_free();return
	var query=PhysicsRayQueryParameters3D.create(global_position,next,1)
	if life<=0 or not get_world_3d().direct_space_state.intersect_ray(query).is_empty():queue_free();return
	global_position=next
