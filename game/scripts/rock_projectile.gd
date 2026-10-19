extends Node3D
const Props=preload("res://scripts/props.gd")
var game: Control
var thrower: Node3D
var direction=Vector3.ZERO
var reflected=false
var life=3.5
var stone: MeshInstance3D

func configure(owner_game: Control, source: Node3D, aim: Vector3) -> void:
	game=owner_game
	if game.has_method("bind_effect"):game.bind_effect(self)
	thrower=source
	position=source.position+Vector3(0,.7,0)
	direction=aim.normalized()
	stone=Props.box(self,Vector3.ZERO,Vector3(.36,.32,.34),"#a8a392")

func repel(_away: Vector3, _force: float, _stun: float) -> void:
	reflected=true
	direction=(thrower.position-position)*Vector3(1,0,1)
	direction=direction.normalized()
	life=3
	stone.material_override=Props.mat("#b9e7ed")
	game.notify("Rock reflected! Strike the warden's glowing cracks.")

func _physics_process(delta: float) -> void:
	if not game.simulation_active():
		return
	if not is_instance_valid(thrower):
		queue_free()
		return
	life-=delta
	var next=position+direction*float(10 if reflected else 6)*delta
	var hit=game.player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(position,next,1))
	if life<=0 or not hit.is_empty():
		queue_free()
		return
	var previous=position
	position=next
	stone.rotation+=Vector3(3,5,2)*delta
	if not reflected:
		var closest=Geometry3D.get_closest_point_to_segment(game.player.position*Vector3(1,0,1),previous*Vector3(1,0,1),position*Vector3(1,0,1))
		if closest.distance_to(game.player.position*Vector3(1,0,1))<=float(game.player.combat.parry.contact_range) and game.player.try_parry(self):
			return
	var target=thrower if reflected else game.player
	var offset=(target.position-position)*Vector3(1,0,1)
	if offset.length()<.65:
		if reflected:
			thrower.open_armor()
			thrower.set_meta("pending_damage_context",{"damage_kind":"reflection","actor_id":String(get_meta("reflected_by",get_meta("target_character","")))})
			thrower.take_damage(18,direction)
			queue_free()
		elif not game.player.try_parry(self):
			game.player.take_damage(18,direction)
			queue_free()
