extends RefCounted
static var spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://content/world_rise/floor_02.json"))
const RADIUS=240.0
const WATER=0.0
const DROWN=1.35
static func vertex(x:int,z:int) -> float:return float(spec.heights[clampi(z,0,240)*241+clampi(x,0,240)])
static func height(at:Vector3) -> float:
	var p=(Vector2(at.x,at.z)+Vector2.ONE*240)/2;var x=floori(p.x);var z=floori(p.y);var u=p.x-x;var v=p.y-z
	var a=vertex(x,z);var b=vertex(x+1,z);var c=vertex(x,z+1);var d=vertex(x+1,z+1)
	return a+(b-a)*u+(c-a)*v if u+v<=1 else d+(c-d)*(1-u)+(b-d)*(1-v)
static func depth(at:Vector3) -> float:return maxf(0,WATER-height(at))
static func safe(at:Vector3) -> bool:return Vector2(at.x,at.z).length()<235 and depth(at)<1.1
static func dry(at:Vector3) -> bool:return safe(at) and height(at)>.12
static func arrival() -> Vector2:return Vector2(spec.arrival[0],spec.arrival[1])
static func movement_factor(at:Vector3) -> float:
	var d=depth(at)
	return lerpf(1,.85,smoothstep(0,.18,d)) if d<=.25 else lerpf(.85,.28,smoothstep(.25,.95,d))
