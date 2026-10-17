extends RefCounted
static var spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://content/world_rise/floor_01.json"))
static var samples:Dictionary={}
static func raw(x:float,z:float) -> float:
	var key=Vector2(x,z)
	if samples.has(key):return samples[key]
	var r=Vector2(x,z).length();var h=5.0
	for hill in spec.hills:h+=hill[2]*exp(-((x-hill[0])*(x-hill[0])+(z-hill[1])*(z-hill[1]))/(2*hill[3]*hill[3]))
	for pack in spec.packs:
		if pack.kind=="library_boar":h-=5*exp(-Vector2(x-pack.at[0],z-pack.at[1]).length_squared()/450.0)
	h=maxf(2,h+1.1*sin(x*.043)*sin(z*.037));h=lerpf(26,h,smoothstep(18,48,r));h+=4*smoothstep(218,240,r);samples[key]=h;return h
static func height(at:Vector3) -> float:
	var x=floor(at.x/4)*4;var z=floor(at.z/4)*4;var u=(at.x-x)/4;var v=(at.z-z)/4
	var a=raw(x,z);var b=raw(x+4,z);var c=raw(x,z+4);var d=raw(x+4,z+4)
	return a+(b-a)*u+(c-a)*v if u+v<=1 else d+(c-d)*(1-u)+(b-d)*(1-v)
static func safe(at:Vector3) -> bool:
	if Vector2(at.x,at.z).length()>239:return false
	for tree in spec.trees:
		if Vector2(at.x-tree[0],at.z-tree[1]).length()<tree[3]+.3:return false
	return true
static func normal(x:float,z:float) -> Vector3:return Vector3(raw(x-1,z)-raw(x+1,z),2,raw(x,z-1)-raw(x,z+1)).normalized()
