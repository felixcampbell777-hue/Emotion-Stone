extends Node3D
const Props=preload("res://scripts/props.gd")
const Hazard=preload("res://scripts/menagery_hazard.gd")
var game:Node
var source:Node3D
var origin=Vector3.ZERO
var landing=Vector3.ZERO
var age=0.0
var duration=.9
var height=1.8
var reflected=false
var blob:MeshInstance3D
func configure(owner:Node,thrower:Node3D,target:Vector3,presentation_only:bool=false) -> void:
 game=owner;
 if game.has_method("bind_effect"):game.bind_effect(self)
 source=thrower; origin=thrower.position+Vector3.UP*.8
 if not presentation_only:preload("res://scripts/world_sound.gd").play(game,"enemy.resin.launch",thrower.position)
 var bounds=game.current_world.bounds.grow(-.5)
 landing=Vector3(clampf(target.x,bounds.position.x,bounds.end.x),0,clampf(target.z,bounds.position.y,bounds.end.y)); landing.y=game.current_world.ground_height(landing)+.035
 if game.map_id=="wr_floor_02":landing.y=maxf(landing.y,.035)
 position=origin; duration=float(game.menagery.catalog.resin_attack.flight_seconds); height=float(game.menagery.catalog.resin_attack.arc_height)
 add_to_group("menagery_effect"); add_to_group("resin_gloop")
 var mesh=SphereMesh.new(); mesh.radius=.23; mesh.height=.46; mesh.radial_segments=8; mesh.rings=4
 blob=Props.mesh_node(self,mesh,Vector3.ZERO,"#e1b550")
 for i in range(3): Props.box(self,Vector3(0,-.08-i*.10,0),Vector3(.10,.12,.10),"#bc9442")
func repel(_away:Vector3,_force:float,_stun:float) -> void:
 if not is_instance_valid(source) or source.health<=0: return
 reflected=true; origin=position; landing=source.position+Vector3.UP*.04; age=0; duration=.4; height=.35; blob.material_override=Props.mat("#9fe3ec")
func _physics_process(delta:float) -> void:
 if is_queued_for_deletion() or not is_instance_valid(game) or not game.simulation_active() or game.gallery_mode: return
 age+=delta; var t=clampf(age/duration,0,1)
 var next=origin.lerp(landing,t)+Vector3.UP*(4*height*t*(1-t))
 var hit=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(position,next,1))
 if not hit.is_empty(): landing=hit.position+hit.normal*.25; landing.y=game.current_world.ground_height(landing)+.035; next=landing; t=1
 if t>=1 and game.map_id=="wr_floor_02":landing.y=maxf(landing.y,.035);next=landing
 position=next; blob.rotation+=Vector3(1,2,3)*delta
 if not reflected and position.distance_to(game.player.position+Vector3.UP*.8)<float(game.player.combat.parry.contact_range) and game.player.try_parry(self): return
 if t>=1:
  preload("res://scripts/world_sound.gd").play(game,"enemy.resin.impact",landing)
  if reflected:
   if is_instance_valid(source) and source.health>0 and source.position.distance_to(landing)<.9:
    source.set_meta("pending_damage_context",{"damage_kind":"reflection","actor_id":String(get_meta("reflected_by",get_meta("target_character","")))})
    source.take_damage(int(source.specimen.damage)*2,(source.position-origin).normalized())
  else:
   var puddle=Hazard.new(); game.current_world.add_child(puddle); puddle.configure(game,landing,true,source)
  queue_free()
