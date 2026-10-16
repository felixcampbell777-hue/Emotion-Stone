extends RefCounted
## Equipped items keep their effects and slots. Visual fitting is deferred to Blender.
## Weapons and the character's authored clothing are owned by their existing systems.
static func apply(actor:Node,_gear:RefCounted) -> void:
	# Also clear already attached accessories when refreshing a live actor.
	for child in actor.find_children("MagicGear_*","BoneAttachment3D",true,false):
		child.get_parent().remove_child(child);child.queue_free()
	for child in actor.find_children("EquipmentLight","BoneAttachment3D",true,false):
		child.get_parent().remove_child(child);child.queue_free()
	# Remove legacy item recolors; retain the character's authored base palette.
	for mesh in actor.visual.find_children("*","MeshInstance3D",true,false):
		if String(mesh.name).begins_with("outfit_") or String(mesh.name).begins_with("footwear_") or String(mesh.name).begins_with("body_leg_"):
			actor._apply_palette(mesh)
	# The lantern's illumination remains useful even while its mesh is deferred.
	if _gear.slots.get("headwear","")=="lantern":
		var rig:Skeleton3D=actor.get_node("BetaHero").rig if actor.has_node("BetaHero") else actor.skeleton
		var socket=BoneAttachment3D.new();socket.name="EquipmentLight";socket.bone_name="head";rig.add_child(socket)
		var light=OmniLight3D.new();light.position=Vector3(0,.1,.3);light.light_color=Color("#ffe3a5");light.light_energy=1.2;light.omni_range=6;socket.add_child(light)
