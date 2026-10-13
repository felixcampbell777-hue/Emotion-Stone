extends RefCounted
## Bone-following native accessories; original deforming dress/boot surfaces stay intact.
const Props=preload("res://scripts/props.gd")
static func socket(actor:Node,bone:String) -> BoneAttachment3D:
	var rig:Skeleton3D=actor.get_node("BetaHero").rig if actor.has_node("BetaHero") else actor.skeleton
	var node=BoneAttachment3D.new(); node.name="MagicGear_"+bone.replace(".","_"); node.bone_name=bone; rig.add_child(node)
	# Author in character bind coordinates, then convert through this bone's rest.
	var root=Node3D.new(); root.name="BindSpace"; node.add_child(root)
	root.transform=rig.get_bone_global_rest(rig.find_bone(bone)).affine_inverse()
	if actor.get_meta("fitted_hero_rig",false) and bone=="head":
		root.transform*=Transform3D(Basis.from_scale(Vector3(.55,.95,.60)),Vector3.ZERO)
	return node
static func box(root:Node3D,at:Vector3,size:Vector3,color:String) -> MeshInstance3D:
	return Props.box(root,at,size,color)
static func paint(actor:Node,prefix:String,color:String,material_slot:String="") -> void:
	for mesh in actor.visual.find_children("*","MeshInstance3D",true,false):
		if not String(mesh.name).begins_with(prefix): continue
		for i in range(mesh.mesh.get_surface_count()):
			var source=mesh.mesh.surface_get_material(i)
			if not source is StandardMaterial3D or (not material_slot.is_empty() and not String(source.resource_name).begins_with(material_slot+"_")): continue
			var material=source.duplicate()
			material.albedo_color=Color(color).darkened(.22) if String(source.resource_name).ends_with("dark") else Color(color).lightened(.15) if String(source.resource_name).ends_with("light") else Color(color)
			var current=mesh.get_surface_override_material(i)
			if current is ShaderMaterial and current.shader.resource_path in ["res://shaders/hero_surface.gdshader","res://shaders/hero_preview.gdshader","res://shaders/character_surface.gdshader"]:
				var detailed=current.duplicate()
				detailed.set_shader_parameter("tint",Color(color) if current.shader.resource_path.get_file() in ["hero_surface.gdshader","hero_preview.gdshader"] and material_slot=="dress" else material.albedo_color)
				mesh.set_surface_override_material(i,detailed)
				continue
			mesh.set_surface_override_material(i,material)
static func apply(actor:Node,gear:RefCounted) -> void:
	for child in actor.find_children("MagicGear_*","BoneAttachment3D",true,false):
		if String(child.name).begins_with("MagicGear_"):
			child.get_parent().remove_child(child); child.queue_free()
	# Restore the player's base palette before any item-specific recolor.
	for mesh in actor.visual.find_children("*","MeshInstance3D",true,false):
		if String(mesh.name).begins_with("outfit_") or String(mesh.name).begins_with("footwear_") or String(mesh.name).begins_with("body_leg_"):
			actor._apply_palette(mesh)
	for slot in gear.SLOTS:
		var entry=gear.item(gear.slots.get(slot,""))
		if entry.is_empty(): continue
		var color:String=entry.color; var accent:String=entry.accent
		var index=int(entry.variant)
		if slot.begins_with("ring"):
			var sign=1 if slot=="ring1" else -1
			var root=socket(actor,"forearm.L" if sign>0 else "forearm.R").get_child(0)
			# Finger-width band and jewel on the outside of the gripping hand.
			var band=TorusMesh.new(); band.inner_radius=.016; band.outer_radius=.026; band.rings=12; band.ring_segments=6
			Props.mesh_node(root,band,Vector3(sign*.415,.858,.055),color)
			box(root,Vector3(sign*.415,.872,.085),Vector3(.030,.027,.020),accent)
		elif slot=="torso":
			paint(actor,"outfit_dress",color,"dress")
			var root=socket(actor,"spine").get_child(0)
			if actor.get_meta("fitted_hero_rig",false): root.transform*=Transform3D(Basis.IDENTITY,Vector3(0,0,.065))
			box(root,Vector3(0,1.26,.151),Vector3(.35,.25,.035),color)
			for sign in [-1,1]:
				box(root,Vector3(sign*.11,1.28,.18),Vector3(.022,.27,.024),accent)
			box(root,Vector3(0,1.35,.187),Vector3(.08,.075,.025),accent)
			box(root,Vector3(0,1.12,.17),Vector3(.37,.07,.045),color)
			if index in [0,4]:
				for sign in [-1,1]: box(root,Vector3(sign*.17,1.36,.03),Vector3(.11,.07,.19),color)
			if index==2: box(root,Vector3(.13,1.32,.20),Vector3(.09,.045,.025),"#e2c578")
			if index==3: box(root,Vector3(0,1.23,.20),Vector3(.075,.12,.028),accent)
			if index==4:
				for y in [1.18,1.23,1.28]: box(root,Vector3(0,y,.198),Vector3(.22,.012,.018),accent)
		elif slot=="leggings":
			paint(actor,"body_leg_",color)
			for side in ["L","R"]:
				var sign=1 if side=="L" else -1
				var root=socket(actor,"shin."+side).get_child(0)
				box(root,Vector3(sign*.13,.40,.055),Vector3(.125,.14,.035),color)
				box(root,Vector3(sign*.13,.41,.080),Vector3(.055,.065,.018),accent)
				box(root,Vector3(sign*.13,.315,0),Vector3(.145,.027,.145),accent)
		elif slot=="boots":
			paint(actor,"footwear_boots",color,"leather")
			paint(actor,"footwear_boots",accent,"socks")
			for side in ["L","R"]:
				var sign=1 if side=="L" else -1
				var root=socket(actor,"shin."+side).get_child(0)
				box(root,Vector3(sign*.13,.225,.09),Vector3(.14,.10,.026),color)
				box(root,Vector3(sign*.13,.278,0),Vector3(.18,.028,.18),accent)
				var toe=socket(actor,"foot."+side).get_child(0)
				box(toe,Vector3(sign*.13,.13,.07),Vector3(.12,.026,.11),color)
				box(toe,Vector3(sign*.13,.15,.09),Vector3(.05,.022,.04),accent)
		elif slot=="headwear":
			var root=socket(actor,"head").get_child(0)
			box(root,Vector3(0,1.81,.23),Vector3(.38,.055,.045),color)
			for sign in [-1,1]: box(root,Vector3(sign*.25,1.81,0),Vector3(.035,.045,.31),color)
			if index==0:
				box(root,Vector3(0,1.79,.27),Vector3(.09,.10,.06),accent)
				var light=OmniLight3D.new(); light.position=Vector3(0,1.8,.3); light.light_color=Color("#ffe3a5"); light.light_energy=1.2; light.omni_range=6; root.add_child(light)
			elif index==2:
				for sign in [-1,1]:
					box(root,Vector3(sign*.08,1.72,.23),Vector3(.09,.025,.032),color)
					box(root,Vector3(sign*.14,1.76,.25),Vector3(.055,.08,.032),accent)
			else:
				for i in range(3): box(root,Vector3((i-1)*.11,1.855,.20),Vector3(.045,.085 if index in [3,4] else .045,.045),accent)
			if index==4: box(root,Vector3(0,1.85,-.17),Vector3(.28,.06,.035),accent)
		elif slot=="necklace":
			var root=socket(actor,"spine").get_child(0)
			if actor.get_meta("fitted_hero_rig",false): root.transform*=Transform3D(Basis.IDENTITY,Vector3(0,0,.015))
			for sign in [-1,1]:
				var cord=box(root,Vector3(sign*.045,1.38,.19),Vector3(.012,.14,.018),color)
				cord.rotation.z=sign*.55
			box(root,Vector3(0,1.31,.21),Vector3(.065,.08,.032),color)
			var jewel=box(root,Vector3(0,1.31,.235),Vector3(.043,.053,.020),accent)
			jewel.rotation.z=PI/4 if index in [0,2] else 0
