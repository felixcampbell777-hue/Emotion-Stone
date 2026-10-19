extends Node3D
const Props=preload("res://scripts/props.gd")
var game:Node
var source:Node3D
var direction=Vector3.ZERO
var damage=8
var reflected=false
var life=4.0
var mesh:MeshInstance3D
func configure(owner:Node,thrower:Node3D,aim:Vector3,thorn:bool=false) -> void:
	game=owner
	if game.has_method("bind_effect"):game.bind_effect(self)
	source=thrower; direction=aim.normalized(); position=thrower.position+Vector3.UP*.75
	add_to_group("menagery_effect")
	mesh=Props.box(self,Vector3.ZERO,Vector3(.14,.14,.34) if thorn else Vector3(.28,.30,.28),"#92b67b" if thorn else "#be965e")
	damage=7 if thorn else 8
func repel(_away:Vector3,_force:float,_stun:float) -> void:
	reflected=true
	if is_instance_valid(source): direction=((source.position-position)*Vector3(1,0,1)).normalized()
	mesh.material_override=Props.mat("#9fe3ec")
func _physics_process(delta:float) -> void:
	if is_queued_for_deletion(): return
	if not is_instance_valid(game) or not game.simulation_active() or game.gallery_mode: return
	if not is_instance_valid(source) or source.health<=0: queue_free(); return
	life-=delta
	var next=position+direction*(9 if reflected else 5.5)*delta
	if life<=0 or not get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(position,next,1)).is_empty(): queue_free(); return
	var previous=position; position=next
	mesh.rotation+=Vector3(2,3,1)*delta
	if not reflected:
		var near=Geometry3D.get_closest_point_to_segment(game.player.position*Vector3(1,0,1),previous*Vector3(1,0,1),next*Vector3(1,0,1))
		if near.distance_to(game.player.position*Vector3(1,0,1))<=float(game.player.combat.parry.contact_range) and game.player.try_parry(self): return
	var target=source if reflected else game.player
	if ((target.position-position)*Vector3(1,0,1)).length()<.6:
		if reflected: source.take_damage(damage*2,direction)
		else: game.player.take_damage(damage,direction)
		queue_free()
