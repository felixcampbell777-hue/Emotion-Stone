extends RefCounted
## Original compact back pad and spring clips, authored in character space.
static func build(actor:Node3D) -> void:
	var tuning=JSON.parse_string(FileAccess.get_file_as_string("res://content/beta.json")).back_anchor
	var mount=actor.back_mount_pose()
	var pivot=actor.BetaSwordMotion.GRIP*float(actor.combat.sword_scale)
	var center=mount*Vector3(0,pivot-float(tuning.blade_distance),0)
	var backing=Vector3(float(tuning.pad_x),center.y,float(tuning.back_z))
	actor.back_harness.set_meta("compact_beta_anchor",true)
	actor.harness_material.roughness=.88;actor.harness_material.metallic=0.0
	var grain=FastNoiseLite.new();grain.seed=7352;grain.frequency=.36
	var texture=NoiseTexture2D.new();texture.width=128;texture.height=128;texture.noise=grain
	var ramp=Gradient.new();ramp.colors=PackedColorArray([Color(.65,.65,.65),Color(1,1,1)]);texture.color_ramp=ramp
	actor.harness_material.albedo_texture=texture
	var pad=MeshInstance3D.new();pad.name="CompactLeatherBackPad"
	pad.mesh=plate(float(tuning.width),float(tuning.height),float(tuning.depth))
	pad.position=backing;pad.material_override=actor.harness_material;actor.back_harness.add_child(pad)
	var trim=StandardMaterial3D.new();trim.albedo_color=Color("#3b3937");trim.metallic=.78;trim.roughness=.44
	var bronze=StandardMaterial3D.new();bronze.albedo_color=Color("#7c6548");bronze.metallic=.75;bronze.roughness=.5
	for x in [-1,1]:
		for y in [-1,1]:
			var rivet=MeshInstance3D.new();rivet.name="AnchorRivet"
			var sphere=SphereMesh.new();sphere.radius=.005;sphere.height=.006;sphere.radial_segments=12;sphere.rings=6
			rivet.mesh=sphere;rivet.material_override=bronze
			rivet.position=backing+Vector3(x*float(tuning.width)*.32,y*float(tuning.height)*.32,-float(tuning.depth)*.5-.002)
			actor.back_harness.add_child(rivet)
	var holder=Node3D.new();holder.name="CompactBladeClips";holder.position=center
	actor.back_harness.add_child(holder);actor.sword_holders.append(holder)
	actor.holder_rest.append(holder.transform);actor.holder_anchors.append(backing)
	var normal=mount.basis.z.normalized();var right=mount.basis.x.normalized()
	var half_width=actor.BetaSwordMotion.WIDTH/(2*.92)+.009
	for offset in [-.045,.045]:
		var point=center+mount.basis.y*offset
		var base=Vector3(clampf(point.x,backing.x-float(tuning.width)*.3,backing.x+float(tuning.width)*.3),point.y,backing.z-float(tuning.depth)*.5)
		bar(holder,base,point-normal*.016,.009,trim)
		bar(holder,point-normal*.016-right*half_width,point-normal*.016+right*half_width,.007,trim)
		for sign in [-1,1]:
			var edge=point+right*half_width*sign
			bar(holder,edge-normal*.016,edge+normal*.012,.006,trim)
			bar(holder,edge+normal*.012,edge-right*.012*sign+normal*.012,.006,trim)

static func bar(parent:Node3D,a:Vector3,b:Vector3,radius:float,material:Material) -> void:
	var part=MeshInstance3D.new();part.name="RoundedAnchorHardware"
	var mesh=CapsuleMesh.new();mesh.radius=radius;mesh.height=a.distance_to(b)+radius*2;mesh.radial_segments=12;mesh.rings=4
	part.mesh=mesh;part.material_override=material
	var up=(b-a).normalized();var right=Vector3.RIGHT-up*up.x
	if right.length_squared()<.001:right=Vector3.UP-up*up.y
	right=right.normalized()
	part.transform=Transform3D(Basis(right,up,right.cross(up)),(a+b)*.5-parent.position)
	parent.add_child(part)

static func plate(width:float,height:float,depth:float) -> ArrayMesh:
	var vertices=PackedVector3Array();var normals=PackedVector3Array();var uv=PackedVector2Array();var indices=PackedInt32Array()
	# Rounded rectangle, with a bevel rather than the old square-edged strips.
	for ring in range(4):
		var inset=.93 if ring in [0,3] else 1.0
		var z=[depth*.5,depth*.30,-depth*.30,-depth*.5][ring]
		for i in range(48):
			var angle=TAU*i/48.0;var c=cos(angle);var s=sin(angle)
			var x=signf(c)*sqrt(absf(c))*width*.5*inset
			var y=signf(s)*sqrt(absf(s))*height*.5*inset
			vertices.append(Vector3(x,y,z));uv.append(Vector2(x/width+.5,y/height+.5))
			var n=Vector3(c,s,1.0 if ring==0 else -1.0 if ring==3 else 0.0).normalized()
			normals.append(n)
	for ring in range(3):
		for i in range(48):
			var a=ring*48+i;var b=ring*48+(i+1)%48;var c=a+48;var d=b+48
			indices.append_array(PackedInt32Array([a,c,b,b,c,d]))
	for side in [0,3]:
		var center=vertices.size();vertices.append(Vector3(0,0,depth*.5 if side==0 else -depth*.5))
		normals.append(Vector3.BACK if side==0 else Vector3.FORWARD);uv.append(Vector2(.5,.5))
		for i in range(48):
			var a=side*48+i;var b=side*48+(i+1)%48
			indices.append_array(PackedInt32Array([center,b,a] if side==0 else [center,a,b]))
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
	var result=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return result
