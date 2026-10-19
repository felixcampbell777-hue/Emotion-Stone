extends RefCounted
## Canonical swept steel versus a vertical combat capsule, shared by all dispatchers.
static func capsule(current:Array,previous:Array,at:Vector3,radius:float,height:float,margin:float,clearance:Callable=Callable()) -> Dictionary:
 if current.size()!=2:return {"hit":false,"point":Vector3.ZERO}
 if previous.size()!=2:previous=current
 var bottom=at+Vector3.UP*minf(radius,height*.5)
 var top=at+Vector3.UP*maxf(radius,height-radius)
 for index in range(9):
  var fraction=float(index)/8
  var base:Vector3=previous[0].lerp(current[0],fraction)
  var tip:Vector3=previous[1].lerp(current[1],fraction)
  var nearest=Geometry3D.get_closest_points_between_segments(base,tip,bottom,top)
  if nearest[0].distance_to(nearest[1])<=radius+margin:
   if not clearance.is_valid() or clearance.call(nearest[0]):return {"hit":true,"point":nearest[0],"fraction":fraction}
 return {"hit":false,"point":Vector3.ZERO}
