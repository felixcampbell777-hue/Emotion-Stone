extends RefCounted
## Deterministic faceted surfaces and the shared, no-jump ground-height sampler.
const Props=preload("res://scripts/props.gd")
const STEP=.5
static func is_terrain(code:String) -> bool:
	return code in ["1F","2F","3F","4F","5F"]
static func raw_height(code:String,p:Vector2) -> float:
	if code=="5F":
		var r=sqrt(pow(p.x/6,2)+pow(p.y/5,2))
		return .65*smoothstep(.12,.72,r)*(1-smoothstep(.78,1,r))
	if code=="1F":
		var r=sqrt(pow(p.x/6,2)+pow(p.y/5,2))
		return 1.8*pow(maxf(0,1-r*r),2)
	if code=="2F":
		return 2.2*maxf(pow(maxf(0,1-pow((p.x-2.4)/3.6,2)-pow(p.y/4.4,2)),2),pow(maxf(0,1-pow((p.x+2.4)/3.6,2)-pow(p.y/4.4,2)),2))
	if absf(p.x)>=3.5 or p.y< -4 or p.y>5: return 0
	if code=="3F": return 2.8*smoothstep(0,4,4-p.y)
	if p.y>1: return maxf(0,(4-p.y)*.45)
	if p.y>.3: return 1.35
	if p.y> -2: return 1.35+(.3-p.y)*(1.05/2.3)
	return 2.4
static func height(code:String,p:Vector2) -> float:
	if absf(p.x)>6 or absf(p.y)>5: return 0
	# Same triangles as the rendered mesh: no hovering above a curved approximation.
	var cell=(p/STEP).floor()*STEP
	var uv=(p-cell)/STEP
	var a=raw_height(code,cell); var b=raw_height(code,cell+Vector2(STEP,0))
	var c=raw_height(code,cell+Vector2(0,STEP)); var d=raw_height(code,cell+Vector2.ONE*STEP)
	return a+(b-a)*uv.x+(c-a)*uv.y if uv.x+uv.y<=1 else d+(c-d)*(1-uv.x)+(b-d)*(1-uv.y)
static func create(node:Node3D,code:String) -> void:
	var surface=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ix in range(-12,12):
		for iz in range(-10,10):
			var p=Vector2(ix,iz)*STEP
			var points=[p,p+Vector2(STEP,0),p+Vector2(0,STEP),p+Vector2.ONE*STEP]
			for index in [0,1,2,1,3,2]:
				var q=points[index]; var h=raw_height(code,q)
				surface.set_color(Color("#8aa36b") if h>1 else Color("#799665"))
				if code=="5F": surface.set_color(Color("#557e58") if h>.35 else Color("#688c60"))
				surface.add_vertex(Vector3(q.x,h+.006,q.y))
	surface.generate_normals()
	var mesh=surface.commit()
	var top=Props.mesh_node(node,mesh,Vector3.ZERO,"#ffffff")
	var material=Props.mat("#ffffff").duplicate(); material.vertex_color_use_as_albedo=true; top.material_override=material
	var camera_body=StaticBody3D.new(); camera_body.set_meta("terrain_surface",true); camera_body.collision_layer=8; camera_body.collision_mask=0
	var shape=CollisionShape3D.new(); shape.shape=mesh.create_trimesh_shape(); camera_body.add_child(shape); node.add_child(camera_body)
	if code in ["3F","4F"]:
		var h=2.8 if code=="3F" else 2.4
		Props.box(node,Vector3(0,h/2,-3.8),Vector3(7.3,h, .45),"#7c8178")
		Props.collider(node,Vector3(0,h/2,-3.8),Vector3(7.3,h,.45))
		for z in range(-3,5):
			var y=raw_height(code,Vector2(0,z+.35))
			if y<.02: continue
			for sign in [-1,1]:
				Props.box(node,Vector3(sign*3.5,y/2,z+.35),Vector3(.3,y,1.02),"#7e887d" if z%2 else "#90958a")
				Props.collider(node,Vector3(sign*3.5,y/2,z+.35),Vector3(.3,y,1.02))
		# Weathered path marks the traversable central ramp and its shelves.
		for i in range(19):
			var z=3.8-i*.38
			Props.cone(node,Vector3(sin(i*.6)*.25,height(code,Vector2(0,z))+.025,z),.22,.04,"#b1ac8b",.2)
