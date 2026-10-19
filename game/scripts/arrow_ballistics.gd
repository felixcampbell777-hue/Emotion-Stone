extends RefCounted
const PlayerHurt=preload("res://scripts/player_hurt.gd")
## Preview and live flight share this exact fixed-step integrator and swept collision query.
static func velocity(direction:Vector3,charge:float,p:Dictionary) -> Vector3:
 return direction.normalized()*lerpf(float(p.minimum_speed),float(p.maximum_speed),clampf(charge,0,1))
static func advance(position:Vector3,current_velocity:Vector3,seconds:float,gravity:float) -> Dictionary:
 return {"position":position+current_velocity*seconds+Vector3.DOWN*gravity*seconds*seconds*.5,"velocity":current_velocity+Vector3.DOWN*gravity*seconds}
static func sweep(space:PhysicsDirectSpaceState3D,from:Vector3,to:Vector3,exclude:Array[RID]=[],player_candidates:Array=[],accepted_volumes:Dictionary={}) -> Dictionary:
 # Movement capsules are terrain solvers, not the visible player's combat anatomy.
 var physical_exclude:Array[RID]=exclude.duplicate()
 for candidate in player_candidates:
  if is_instance_valid(candidate) and candidate is CollisionObject3D:
   var rid:RID=candidate.get_rid()
   if rid not in physical_exclude:physical_exclude.append(rid)
 var nearest=space.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1|2|4,physical_exclude))
 var length=from.distance_to(to)
 var fraction=from.distance_to(nearest.position)/length if not nearest.is_empty() and length>.000001 else INF
 for candidate in player_candidates:
  if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():continue
  if candidate is CollisionObject3D and candidate.get_rid() in exclude:continue
  var cached=accepted_volumes.get(candidate.get_instance_id())
  var contact=PlayerHurt.segment_volumes(cached,from,to) if cached!=null else PlayerHurt.segment_contact(candidate,from,to)
  if contact.hit and float(contact.fraction)<fraction:
   fraction=float(contact.fraction)
   nearest={"position":contact.point,"normal":contact.get("normal",(from-to).normalized()),"collider":candidate,"rid":candidate.get_rid(),"shape":-1,"face_index":-1,"fraction":fraction,"player_region":contact.region}
 return nearest
static func predict(space:PhysicsDirectSpaceState3D,origin:Vector3,initial_velocity:Vector3,p:Dictionary,exclude:Array[RID]=[],player_candidates:Array=[]) -> Dictionary:
 var points:Array[Vector3]=[origin];var at=origin;var speed=initial_velocity;var elapsed=0.0
 # A prediction samples one accepted pose, rather than solving every rig at every substep.
 var accepted_volumes:Dictionary={}
 for candidate in player_candidates:
  if is_instance_valid(candidate) and not candidate.is_queued_for_deletion() and candidate.get_rid() not in exclude:accepted_volumes[candidate.get_instance_id()]=PlayerHurt.volumes(candidate)
 var step=float(p.step_seconds)
 while elapsed<float(p.lifetime):
  var next=advance(at,speed,step,float(p.gravity));var hit=sweep(space,at,next.position,exclude,player_candidates,accepted_volumes)
  if not hit.is_empty():points.append(hit.position);return {"points":points,"hit":hit}
  at=next.position;speed=next.velocity;elapsed+=step;points.append(at)
 return {"points":points,"hit":{}}
static func launch(space:PhysicsDirectSpaceState3D,eye:Vector3,muzzle:Vector3,direction:Vector3,p:Dictionary,exclude:Array[RID]=[],player_candidates:Array=[]) -> Dictionary:
 # Eye-to-muzzle obstruction prevents a visible camera from spawning steel beyond a wall.
 var blocked=sweep(space,eye,muzzle,exclude,player_candidates)
 if not blocked.is_empty():return {"valid":false,"hit":blocked}
 return {"valid":true,"origin":muzzle,"direction":direction.normalized()}
