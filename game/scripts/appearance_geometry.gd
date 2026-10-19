extends RefCounted
## Reviewed surface changes are baked once per combination, including headless.
## No imported GPU morph lookup, skeleton, action or collision change is needed.
static var baked:Dictionary={}

static func key(profile:Dictionary) -> String:
	return profile.face_id+":"+profile.hair_id+":"+profile.body_id

static func original(profile:Dictionary) -> bool:
	return profile.face_id=="default" and profile.hair_id=="chestnut_layers" and profile.body_id=="default"

static func apply(root:Node,profile:Dictionary) -> bool:
	var changed=false;var signature=key(profile)
	for part in root.find_children("*","MeshInstance3D",true,false):
		if part.mesh==null:continue
		if not part.has_meta("appearance_original_mesh"):part.set_meta("appearance_original_mesh",part.mesh)
		if part.get_meta("appearance_geometry_key","")==signature:continue
		var original_mesh:Mesh=part.get_meta("appearance_original_mesh")
		var replacement:Mesh=original_mesh
		if not original(profile):
			var cache_key=String(part.name)+":"+signature
			if not baked.has(cache_key):baked[cache_key]=bake(original_mesh,profile,String(part.name))
			if baked[cache_key]!=null:replacement=baked[cache_key]
		part.mesh=replacement;part.set_meta("appearance_geometry_key",signature);changed=true
	return changed

static func bell(value:float,center:float,radius:float) -> float:
	return pow(maxf(0.0,1.0-absf(value-center)/radius),2.0)

static func active_mask(profile:Dictionary,name:String) -> int:
	var mask=0
	if profile.face_id=="soft_cheeks" and name=="Static_Human_0":mask|=1
	if profile.hair_id=="short_layers" and name=="Static_Heroine_relaxed_layered_hair_0":mask|=2
	if profile.body_id=="subtle_shape" and not ["hair","crown","high-poly","teeth","tongue","eyebrow","eyelash"].any(func(word):return word in name.to_lower()):mask|=4
	return mask

static func deform(vertex:Vector3,mask:int) -> Vector3:
	# Raw approved Blender mesh Z equals exported Godot mesh Y; front is -Y.
	var x=vertex.x;var height=vertex.y
	if mask&1:
		var weight=bell(height,1.515,.075)*bell(absf(x),.055,.045)
		if -vertex.z<.05 and height<1.548:x*=1+.10*weight
	if mask&2 and height<1.48:
		var weight=minf(1.0,(1.48-height)/.18);x*=1-.32*weight
		var limit=.13+.025*clampf((height-1.4)/.18,0,1);x=clampf(x,-limit,limit)
		height=1.48+(height-1.48)*.45
	elif mask&4:
		if absf(x)<.22:x*=1-.055*bell(height,1.03,.17)+.025*bell(height,.82,.16)
	return Vector3(x,height,vertex.z)

static func corrected_normal(vertex:Vector3,normal:Vector3,mask:int) -> Vector3:
	var epsilon=.00001
	var a=(deform(vertex+Vector3(epsilon,0,0),mask)-deform(vertex-Vector3(epsilon,0,0),mask))/(2*epsilon)
	var b=(deform(vertex+Vector3(0,epsilon,0),mask)-deform(vertex-Vector3(0,epsilon,0),mask))/(2*epsilon)
	var c=(deform(vertex+Vector3(0,0,epsilon),mask)-deform(vertex-Vector3(0,0,epsilon),mask))/(2*epsilon)
	var determinant=a.dot(b.cross(c))
	if absf(determinant)<.0000001:return normal
	return ((b.cross(c)*normal.x+c.cross(a)*normal.y+a.cross(b)*normal.z)/determinant).normalized()

static func bake(source:ArrayMesh,profile:Dictionary,name:String) -> ArrayMesh:
	var result=ArrayMesh.new();var any_change=false
	# Imported node names replace spaces with underscores, while authored IDs stay stable.
	name=name.replace(" ","_")
	var mask=active_mask(profile,name)
	if mask==0:return null
	if mask==4 and (source.get_aabb().end.y<.64 or source.get_aabb().position.y>1.21):return null
	for surface in range(source.get_surface_count()):
		var arrays=source.surface_get_arrays(surface).duplicate(true)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX].duplicate()
		var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL].duplicate()
		for i in range(vertices.size()):
			var before=vertices[i];var after=deform(before,mask)
			if after.distance_squared_to(before)>.00000000000001:
				vertices[i]=after;normals[i]=corrected_normal(before,normals[i],mask);any_change=true
		arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
		var tangents:PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT]!=null else PackedFloat32Array()
		if tangents.size()==vertices.size()*4:
			for i in range(vertices.size()):
				var tangent=Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
				tangent=(tangent-normals[i]*tangent.dot(normals[i])).normalized()
				tangents[i*4]=tangent.x;tangents[i*4+1]=tangent.y;tangents[i*4+2]=tangent.z
			arrays[Mesh.ARRAY_TANGENT]=tangents
		result.add_surface_from_arrays(source.surface_get_primitive_type(surface),arrays)
		result.surface_set_material(surface,source.surface_get_material(surface))
	return result if any_change else null
