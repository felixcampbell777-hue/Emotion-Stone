extends "res://scripts/rock_projectile.gd"
func configure(owner_game:Control,source:Node3D,aim:Vector3) -> void:
	super.configure(owner_game,source,aim);life=10;stone.scale=Vector3.ONE*2.5
func repel(_away:Vector3,_force:float,_stun:float) -> void:
	preload("res://scripts/world_sound.gd").play(game,"enemy.elder.reflect",position)
	reflected=true;direction=(thrower.position+Vector3.UP*1.8-position).normalized();life=10;stone.material_override=Props.mat("#9de4ff");game.notify("Stone returned! The Elder staggers.")
func _physics_process(delta:float) -> void:
	if not game.simulation_active():return
	if not is_instance_valid(thrower) or thrower.health<=0:queue_free();return
	life-=delta;var next=position+direction*(18 if reflected else 14)*delta
	var hit=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(position,next,1))
	if life<=0 or not hit.is_empty():
		if not hit.is_empty():preload("res://scripts/world_sound.gd").play(game,"enemy.elder.stone_hit",position)
		queue_free();return
	var previous=position;position=next;stone.rotation+=Vector3(3,5,2)*delta
	var target=thrower if reflected else game.player;var center=target.position+Vector3.UP*(1.8 if reflected else .9)
	var closest=Geometry3D.get_closest_point_to_segment(center,previous,position)
	if not reflected and closest.distance_to(center)<float(game.player.combat.parry.contact_range) and game.player.try_parry(self,closest):return
	if closest.distance_to(center)<(1.8 if reflected else .8):
		if reflected:
			thrower.set_meta("pending_damage_context",{"damage_kind":"reflection","actor_id":String(get_meta("reflected_by",get_meta("target_character","")))})
			thrower.open_armor();thrower.take_damage(55,direction)
		else:game.player.take_damage(22,direction)
		queue_free()
