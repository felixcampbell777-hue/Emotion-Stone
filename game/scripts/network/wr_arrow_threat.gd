extends Node3D
## A transient physical arrow contact for the existing Actor parry predicate.
## Health zero deliberately grants no new ranged counter target or reflected damage.
var health=0
var entity_id=""
static func blocked_by(actor:Node3D,parent:Node3D,at:Vector3,arrow_id:String) -> bool:
 var threat=load("res://scripts/network/wr_arrow_threat.gd").new()
 threat.entity_id=arrow_id;parent.add_child(threat);threat.position=at
 var accepted=actor.try_parry(threat,at)
 threat.free()
 return accepted
