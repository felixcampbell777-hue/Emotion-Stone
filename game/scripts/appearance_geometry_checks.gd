extends SceneTree
const Profile=preload("res://scripts/appearance_profile.gd")
const Geometry=preload("res://scripts/appearance_geometry.gd")
var failures:Array[String]=[]
var checks=0

func check(condition:bool,message:String) -> void:
	checks+=1
	if not condition:failures.append(message)

func _initialize() -> void:
	var scene=load("res://assets/characters/heroine-beta.glb").instantiate()
	get_root().add_child(scene)
	var rig:Skeleton3D=scene.find_children("*","Skeleton3D",true,false)[0]
	var rests=[]
	for index in range(rig.get_bone_count()):rests.append(rig.get_bone_rest(index))
	check(rests.size()==16,"Original sixteen-bone rig retained")
	var original_meshes={}
	for part in scene.find_children("*","MeshInstance3D",true,false):original_meshes[String(part.name)]=part.mesh
	var combinations=0
	for face in ["default","soft_cheeks"]:
		for hair in ["chestnut_layers","short_layers"]:
			for body in ["default","subtle_shape"]:
				var profile=Profile.default_profile();profile.face_id=face;profile.hair_id=hair;profile.body_id=body
				check(Profile.valid(profile),"Approved combination validates "+Geometry.key(profile))
				Geometry.apply(scene,profile);combinations+=1
				var valid=true;var same_weights=true;var feet_fixed=true;var hands_fixed=true
				for part in scene.find_children("*","MeshInstance3D",true,false):
					var source:Mesh=original_meshes[String(part.name)]
					for surface in range(part.mesh.get_surface_count()):
						var arrays=part.mesh.surface_get_arrays(surface);var base=source.surface_get_arrays(surface)
						# Imported morph topology may retain vertices which the original importer merged.
						if arrays[Mesh.ARRAY_VERTEX].size()!=base[Mesh.ARRAY_VERTEX].size():continue
						same_weights=same_weights and arrays[Mesh.ARRAY_BONES]==base[Mesh.ARRAY_BONES] and arrays[Mesh.ARRAY_WEIGHTS]==base[Mesh.ARRAY_WEIGHTS]
						for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
							var point:Vector3=arrays[Mesh.ARRAY_VERTEX][i]
							var before:Vector3=base[Mesh.ARRAY_VERTEX][i]
							valid=valid and point.is_finite() and arrays[Mesh.ARRAY_NORMAL][i].is_finite()
							if before.y<.30:feet_fixed=feet_fixed and point.distance_to(before)<.00001
							if absf(before.x)>.24 and before.y<1.15:hands_fixed=hands_fixed and point.distance_to(before)<.00001
				check(valid,"Finite meshes "+Geometry.key(profile));check(same_weights,"Skin weights unchanged "+Geometry.key(profile))
				check(feet_fixed and hands_fixed,"Foot and hand anchors unchanged "+Geometry.key(profile))
				for option in [[face,"soft_cheeks","Static_Human_0",1.40,1.57],[hair,"short_layers","Static_Heroine_relaxed_layered_hair_0",0.0,2.0],[body,"subtle_shape","Static_Human_punkduck_black_cocktail_dress_0",.70,1.25]]:
					if option[0]!=option[1]:continue
					var maximum_delta=0.0
					for part in scene.find_children("*","MeshInstance3D",true,false):
						if String(part.name).replace(" ","_").replace(".","_")!=option[2]:continue
						for surface in range(part.mesh.get_surface_count()):
							var points=part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
							var previous=original_meshes[String(part.name)].surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
							for i in range(points.size()):
								if previous[i].y>=option[3] and previous[i].y<=option[4]:maximum_delta=maxf(maximum_delta,points[i].distance_to(previous[i]))
					check(maximum_delta>.0001,"Selected option changes visible vertices "+String(option[1]))
				for index in range(rig.get_bone_count()):check(rig.get_bone_rest(index)==rests[index],"Rig rest unchanged "+str(index))
	Geometry.apply(scene,Profile.default_profile())
	for part in scene.find_children("*","MeshInstance3D",true,false):check(part.mesh==original_meshes[String(part.name)],"Original mesh resource restored "+String(part.name))
	# Detach meshes before destroying override resources in the headless dummy renderer.
	for part in scene.find_children("*","MeshInstance3D",true,false):part.mesh=null
	scene.free()
	print("APPEARANCE_GEOMETRY_CHECKS ",JSON.stringify({"combinations":combinations,"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
