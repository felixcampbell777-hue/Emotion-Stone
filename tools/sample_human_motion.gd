extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var state=GLTFState.new(); var doc=GLTFDocument.new()
	var path="C:/Games/CoastalFoundation/art/library/source/quaternius-human-motion/UAL1_Standard.glb"
	assert(doc.append_from_file(path,state)==OK)
	var scene=doc.generate_scene(state);root.add_child(scene)
	var rig:Skeleton3D=scene.find_children("*","Skeleton3D",true,false)[0]
	var player:AnimationPlayer=scene.find_children("*","AnimationPlayer",true,false)[0]
	var output={"provider":"Quaternius / Gonzalo Furnier","source":"Universal Animation Library Standard, creator upload 17958403","license":"CC0-1.0 (supplied License.txt); user-authorized Quaternius intake","samples_per_cycle":120,"clips":{}}
	for clip in ["Walk_Loop","Jog_Fwd_Loop","Sprint_Loop"]:
		player.play(clip);player.seek(0,true);rig.force_update_all_bone_transforms()
		var samples=[]
		for frame in range(121):
			player.seek(frame/120.0*player.get_animation(clip).length,true);rig.force_update_all_bone_transforms()
			var sample={}
			for name in ["pelvis","spine_03","Head"]:
				var index=rig.find_bone(name);var pose=rig.get_bone_global_pose(index);var rest=rig.get_bone_global_rest(index)
				sample[name+"_rotation"]=quat((pose.basis*rest.basis.inverse()).get_rotation_quaternion())
				if name=="pelvis":sample.hip=vec(pose.origin-rest.origin)
			for side in ["l","r"]:
				var foot=rig.get_bone_global_pose(rig.find_bone("foot_"+side));var rest=rig.get_bone_global_rest(rig.find_bone("foot_"+side))
				sample["foot_"+side]=vec(foot.origin-rest.origin)
				for pair in [["upperarm","lowerarm"],["lowerarm","hand"]]:
					sample[pair[0]+"_"+side]=vec((rig.get_bone_global_pose(rig.find_bone(pair[1]+"_"+side)).origin-rig.get_bone_global_pose(rig.find_bone(pair[0]+"_"+side)).origin).normalized())
				sample["foot_rotation_"+side]=quat((foot.basis*rest.basis.inverse()).get_rotation_quaternion())
			samples.append(sample)
		output.clips[clip]={"duration":player.get_animation(clip).length,"samples":samples}
	var file=FileAccess.open("C:/Games/CoastalFoundation/game/content/beta_locomotion_samples.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output));file.close()
	print("SAMPLED walk / jog / sprint to data only; no donor script executed")
	quit()
func vec(v:Vector3) -> Array: return [v.x,v.y,v.z]
func quat(q:Quaternion) -> Array: return [q.x,q.y,q.z,q.w]
