extends RefCounted
const Sculpt=preload("res://scripts/sculpt_terrain.gd")
static func frame(item:Dictionary,kind:String) -> Dictionary:
	if kind in ["exits","terrain_regions"]:
		var r=item.rect
		return {"at":Vector2(r[0]+r[2]*.5,r[1]+r[3]*.5),"angle":0.0,"left":-r[2]*.5,"right":r[2]*.5,"back":-r[3]*.5,"front":r[3]*.5}
	if kind=="sculpted_terrain" and item.get("profile")!="smooth":
		var w=float(item.get("plateau_width",item.radius*2))
		return {"at":Vector2(item.at[0],item.at[1]),"angle":deg_to_rad(float(item.get("rotation",0))),"left":-w*.5,"right":w*.5,"back":-float(item.get("plateau_depth",item.radius)),"front":float(item.radius)}
	return {}
static func to_world(f:Dictionary,p:Vector2) -> Vector2:
	return f.at+p.rotated(-f.angle)
static func points(item:Dictionary,kind:String) -> Array:
	var f=frame(item,kind)
	if f.is_empty(): return []
	var cx=(f.left+f.right)*.5; var cz=(f.back+f.front)*.5
	var result=[]
	for point in [Vector2(f.left,f.back),Vector2(cx,f.back),Vector2(f.right,f.back),Vector2(f.right,cz),Vector2(f.right,f.front),Vector2(cx,f.front),Vector2(f.left,f.front),Vector2(f.left,cz)]: result.append(to_world(f,point))
	return result
static func fits(item:Dictionary,kind:String,bounds:Rect2) -> bool:
	if kind=="sculpted_terrain": return Sculpt.fits(item,bounds)
	if kind in ["exits","terrain_regions"]: return bounds.grow(.00001).encloses(Rect2(item.rect[0],item.rect[1],item.rect[2],item.rect[3]))
	return bounds.grow(.00001).has_point(Vector2(item.at[0],item.at[1]))
static func resized(original:Dictionary,kind:String,index:int,at:Vector2,snap:float=.5) -> Dictionary:
	var f=frame(original,kind); var p=(at-f.at).rotated(f.angle)
	p=Vector2(snappedf(p.x,snap),snappedf(p.y,snap))
	var minimum=1.0 if kind=="sculpted_terrain" else .5
	if index in [0,6,7]: f.left=minf(p.x,f.right-minimum)
	if index in [2,3,4]: f.right=maxf(p.x,f.left+minimum)
	if index in [0,1,2]: f.back=minf(p.y,-1.0 if kind=="sculpted_terrain" else f.front-minimum)
	if index in [4,5,6]: f.front=clampf(p.y,1,8) if kind=="sculpted_terrain" else maxf(p.y,f.back+minimum)
	var copy=original.duplicate(true)
	if kind=="sculpted_terrain":
		var centre=to_world(f,Vector2((f.left+f.right)*.5,0))
		copy.at=[centre.x,centre.y]; copy.plateau_width=f.right-f.left; copy.plateau_depth=-f.back; copy.radius=f.front
	else:
		copy.rect=[f.at.x+f.left,f.at.y+f.back,f.right-f.left,f.front-f.back]
	return copy
static func bounded_resize(original:Dictionary,kind:String,index:int,at:Vector2,bounds:Rect2,snap:float=.5) -> Dictionary:
	var candidate=resized(original,kind,index,at,snap)
	if fits(candidate,kind,bounds): return candidate
	var start=points(original,kind)[index]; var low=0.0; var high=1.0
	for step in range(28):
		var t=(low+high)*.5
		if fits(resized(original,kind,index,start.lerp(at,t),.00001),kind,bounds): low=t
		else: high=t
	return resized(original,kind,index,start.lerp(at,low),.00001)

static func moved(original:Dictionary,kind:String,at:Vector2,bounds:Rect2) -> Dictionary:
	var copy=original.duplicate(true)
	var old=Vector2(original.at[0],original.at[1]) if original.has("at") else Vector2(original.rect[0]+original.rect[2]*.5,original.rect[1]+original.rect[3]*.5)
	var delta=at-old; var corners=points(original,kind)
	if corners.is_empty() and kind=="sculpted_terrain": corners=[old-Vector2.ONE*original.radius,old+Vector2.ONE*original.radius]
	if not corners.is_empty():
		var low=corners[0]; var high=corners[0]
		for point in corners: low=low.min(point); high=high.max(point)
		if high.x-low.x>bounds.size.x+.001 or high.y-low.y>bounds.size.y+.001: return copy
		delta.x=clampf(delta.x,bounds.position.x-low.x,bounds.end.x-high.x); delta.y=clampf(delta.y,bounds.position.y-low.y,bounds.end.y-high.y)
	else: delta=(at.clamp(bounds.position,bounds.end))-old
	if copy.has("at"): copy.at=[old.x+delta.x,old.y+delta.y]
	else: copy.rect[0]+=delta.x; copy.rect[1]+=delta.y
	return copy
