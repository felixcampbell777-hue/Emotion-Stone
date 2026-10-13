extends RefCounted
func segment_box(a:Vector3,b:Vector3,box:AABB) -> bool:
	var lo=0.0; var hi=1.0; var d=b-a
	for axis in range(3):
		if absf(d[axis])<.000001:
			if a[axis]<box.position[axis] or a[axis]>box.end[axis]: return false
		else:
			var first=(box.position[axis]-a[axis])/d[axis]; var last=(box.end[axis]-a[axis])/d[axis]
			lo=maxf(lo,minf(first,last)); hi=minf(hi,maxf(first,last))
			if lo>hi: return false
	return true
func run(test:RefCounted) -> void:
	var game=test.game; var actor=game.player; var gear=game.magic_items
	game.load_map("menagery",Vector2(10,0),true)
	for entry in gear.catalog.items: gear.claim(entry.id)
	actor.set_physics_process(false); actor.position=Vector3.ZERO; actor.visual.rotation.y=0
	var actions=[["drag_walk_loop","drag"],["attack_light","light"],["attack_light2","light2"],["attack_light3","light3"],["attack_heavy","heavy"],["attack_water","water"],["attack_lance","lance"],["parry_guard","parry"],["draw_sword","draw"],["sheathe_sword","draw"],["attack_thrust","thrust"],["dodge_roll","roll"],["stand_up","stand"]]
	for variant in range(5):
		for type in ["torso","leggings","boots","headwear","necklace"]:
			var choices=gear.catalog.items.filter(func(e): return e.category==type)
			gear.equip(type,choices[mini(variant,choices.size()-1)].id)
		var meshes=[]
		for socket in actor.skeleton.get_children():
			if String(socket.name).begins_with("MagicGear_") and not String(socket.name).contains("forearm"):
				meshes.append_array(socket.find_children("*","MeshInstance3D",true,false))
		var contacts=[]
		var sockets=actor.skeleton.get_children().filter(func(node): return String(node.name).begins_with("MagicGear_"))
		test.check(sockets.all(func(node): return actor.skeleton.find_bone(node.bone_name)>=0),"Equipment set %d binds every accessory to an existing animated bone" % (variant+1))
		for action in actions:
			actor.set_sword_drawn(true); actor.play_clip(action[0],0)
			for sample in range(121):
				var phase=sample/120.0
				actor.animator.seek(phase*actor.animator.get_animation(actor.clips[action[0]]).length,true)
				actor._pose_sword(action[1],1-phase if action[0]=="sheathe_sword" else phase)
				actor.skeleton.force_update_all_bone_transforms()
				var steel=actor.blade_segment()
				for mesh in meshes:
					var inverse=mesh.global_transform.affine_inverse()
					for sign in [-1,0,1]:
						var offset=actor.equipment.global_basis.x*.075*sign
						if segment_box(inverse*(steel[0]+offset),inverse*(steel[1]+offset),mesh.mesh.get_aabb()) and contacts.size()<6:
							contacts.append(action[0]+"@"+str(snappedf(phase,.001))+"/"+String(mesh.get_parent().get_parent().name))
		test.check(contacts.is_empty(),"Equipment set %d clears the blade across 1,573 sampled gait/combat/draw/roll poses: %s" % [variant+1,str(contacts)])
	actor.set_physics_process(true)
	game.start_new_game(false); game.load_map("coastal_path",Vector2(0,3),true)
