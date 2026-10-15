extends Node3D
## Imported donor skeleton and textures stay together. Only its own authored clips are sampled.
var model:Node3D
var animator:AnimationPlayer
var clips:Dictionary={}
var current=""
var surfaces:Array=[]
func configure(path:String,height:float) -> void:
	# Fit a parent wrapper: imported clips may animate the donor's own root scale.
	model=Node3D.new();add_child(model);model.add_child(load(path).instantiate())
	var players=model.find_children("*","AnimationPlayer",true,false)
	if not players.is_empty():
		animator=players[0];animator.stop();animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var bounds=rest_bounds(model)
	var factor=height/maxf(bounds.size.y,.01);model.scale=Vector3.ONE*factor
	model.position=-Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*factor
	if animator!=null:
		for name in animator.get_animation_list():
			var key=String(name).get_file().to_lower()
			for purpose in ["idle","walk","attack","brace","death","burrow","rise"]:
				if key==purpose or key.ends_with("_"+purpose): clips[purpose]=name
			if "idle" in key and not clips.has("idle"): clips.idle=name
			if "walk" in key and not clips.has("walk"): clips.walk=name
			if "attack" in key and not clips.has("attack"): clips.attack=name
		for purpose in ["idle","walk"]:
			if clips.has(purpose):animator.get_animation(clips[purpose]).loop_mode=Animation.LOOP_LINEAR
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var material=mesh.get_active_material(surface)
			if material is StandardMaterial3D:
				material=material.duplicate();material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				mesh.set_surface_override_material(surface,material);surfaces.append([material,material.albedo_color])

static func rest_bounds(node:Node3D,parent:Transform3D=Transform3D.IDENTITY) -> AABB:
	var transform=parent*node.transform;var box=AABB();var first=true
	if node is MeshInstance3D:
		var fitted=transform
		# FBX centimeter armatures can bind meter-sized vertices. Include the skin's
		# rest correction rather than measuring the unskinned vertices at 1/100 size.
		if node.skin!=null and node.skin.get_bind_count()>0:
			var skeleton=node.get_node_or_null(node.skeleton)
			if skeleton is Skeleton3D:
				var bone=node.skin.get_bind_bone(0)
				if bone<0:bone=skeleton.find_bone(node.skin.get_bind_name(0))
				if bone>=0:fitted=transform*skeleton.get_bone_global_rest(bone)*node.skin.get_bind_pose(0)
		box=fitted*node.get_aabb();first=false
	for child in node.get_children():
		if not child is Node3D:continue
		var part=rest_bounds(child,transform)
		if part.size.length_squared()<.000001:continue
		box=part if first else box.merge(part);first=false
	return box
func pose(purpose:String,phase:float,delta:float=0) -> void:
	if animator==null:return
	var clip=String(clips.get(purpose,clips.get("idle","")))
	if clip.is_empty():return
	if clip!=current:animator.play(clip,.12 if delta>0 else 0);current=clip
	if phase>=0:
		# Seeking a sampled attack alone never advances the blend clock.
		# Advance it explicitly so transitions cannot freeze on the old idle pose.
		if delta>0:animator.advance(delta)
		animator.seek(clampf(phase,0,1)*animator.get_animation(clip).length,true)
	else:animator.advance(delta)
func flash(hit:float,exposed:float) -> void:
	for entry in surfaces:
		entry[0].albedo_color=entry[1].lerp(Color("#c2eeee"),.3) if exposed>0 else entry[1].lerp(Color("#ffe0be"),.35) if hit>0 else entry[1]
