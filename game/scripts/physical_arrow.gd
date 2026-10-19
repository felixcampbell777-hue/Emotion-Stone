extends Node3D
const Ballistics=preload("res://scripts/arrow_ballistics.gd")
const Models=preload("res://scripts/weapon_models.gd")
var game:Node
var owner_actor:Node3D
var settings:Dictionary
var context:Dictionary
var flight_velocity=Vector3.ZERO
var accumulator=0.0
var age=0.0
var grounded=false
var recoverable=false
var excluded:Array[RID]=[]
func configure(owner_game:Node,actor:Node3D,origin:Vector3,initial_velocity:Vector3,profile:Dictionary,source_context:Dictionary) -> void:
 game=owner_game;owner_actor=actor;settings=profile.duplicate(true);context=source_context.duplicate(true);global_position=origin;flight_velocity=initial_velocity
 excluded=[actor.get_rid()]
 var visible_arrow=Models.arrow();visible_arrow.position.z=.385;add_child(visible_arrow);add_to_group("world_rise_arrow")
 if flight_velocity.length_squared()>.001:look_at(global_position+flight_velocity)
func _physics_process(delta:float) -> void:
 if not is_instance_valid(game) or not is_instance_valid(owner_actor):queue_free();return
 var runs=owner_actor.get("simulation_enabled")
 if (runs!=null and not runs) or (runs==null and not owner_actor.input_enabled):return
 age+=delta
 if grounded:
  if age>float(settings.arrow_recovery_seconds):queue_free()
  return
 accumulator+=delta
 var step=float(settings.step_seconds)
 while accumulator>=step and not grounded:
  accumulator-=step
  var next=Ballistics.advance(global_position,flight_velocity,step,float(settings.gravity))
  var players=game.combat_player_targets(owner_actor) if game.has_method("combat_player_targets") else []
  var query_excluded:Array[RID]=excluded.duplicate()
  if game.has_method("combat_player_exclusions"):
   for rid in game.combat_player_exclusions(owner_actor):
    if rid not in query_excluded:query_excluded.append(rid)
  var hit=Ballistics.sweep(get_world_3d().direct_space_state,global_position,next.position,query_excluded,players)
  if not hit.is_empty():
   global_position=hit.position;grounded=true;age=0
   var target=hit.collider
   if target!=null and target.has_method("take_damage") and target!=owner_actor:
    if game.has_method("resolve_weapon_contact"):game.resolve_weapon_contact(context,target,int(context.get("damage",settings.damage)),flight_velocity.normalized(),false)
    else:target.take_damage(int(settings.damage),flight_velocity.normalized())
    queue_free();return
   recoverable=true;set_meta("recoverable_arrow",true)
   if owner_actor.has_method("emit_presentation"):owner_actor.emit_presentation("projectile.impact.stone",context)
  else:
   global_position=next.position;flight_velocity=next.velocity
   if flight_velocity.length_squared()>.001:look_at(global_position+flight_velocity)
  if age>=float(settings.lifetime):queue_free();return
func recover(actor:Node) -> bool:
 if not recoverable or not is_instance_valid(actor) or actor.global_position.distance_to(global_position)>2.5:return false
 var inventory=game.magic_items;var amount=int(inventory.quantities.get(settings.ammo_id,0))
 if amount>=99:return false
 if settings.ammo_id not in inventory.owned:inventory.owned.append(settings.ammo_id)
 inventory.quantities[settings.ammo_id]=amount+1;recoverable=false
 if actor.has_method("emit_presentation"):actor.emit_presentation("weapon.bow.pickup",context)
 queue_free();return true
