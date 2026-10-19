extends RefCounted
## Applies reviewed geometry and isolated material copies; imported resources stay immutable.
const Profile=preload("res://scripts/appearance_profile.gd")
const Geometry=preload("res://scripts/appearance_geometry.gd")
const BASE_META="appearance_base_materials"
static var eye_textures:Dictionary={}
static var eye_source:Image

static func revision_key(profile:Variant) -> String:
	return Profile.revision_key(profile)

static func clear(actor:Node) -> void:
	if not actor.has_meta("appearance_profile"):return
	var personal=actor.get_node_or_null("BetaHero")
	if personal!=null and personal.get_child_count()>0:
		var scene=personal.get_child(0)
		if Geometry.apply(scene,Profile.default_profile()):
			personal.dragon_grips.clear();personal.prepare_dragon_grip(scene)
		clear_root(scene)
	var arms=actor.get_node_or_null("FirstPersonHands")
	if arms!=null:clear_root(arms)
	if actor.has_meta("appearance_preview"):
		Geometry.apply(actor,Profile.default_profile());clear_root(actor)
	actor.remove_meta("appearance_profile");actor.remove_meta("appearance_revision")

static func clear_root(root:Node) -> void:
	for part in root.find_children("*","MeshInstance3D",true,false):
		if not part.has_meta(BASE_META) or part.mesh==null:continue
		var bases:Array=part.get_meta(BASE_META)
		for surface in range(mini(bases.size(),part.mesh.get_surface_count())):part.set_surface_override_material(surface,bases[surface])

static func apply(actor:Node,profile:Variant) -> bool:
	var data=Profile.normalized(profile)
	if data.is_empty():return false
	actor.set_meta("appearance_profile",data.duplicate(true))
	actor.set_meta("appearance_revision",Profile.revision_key(data))
	var personal=actor.get_node_or_null("BetaHero")
	if personal!=null:
		# The first child is the authored GLB; sword/harness are separate actor copies.
		if personal.get_child_count()>0:
			var scene=personal.get_child(0)
			if Geometry.apply(scene,data):
				# Dragon support-grip meshes must use the newly accepted body surface.
				personal.dragon_grips.clear();personal.prepare_dragon_grip(scene)
			apply_root(scene,data)
		var arms=actor.get_node_or_null("FirstPersonHands")
		if arms!=null:apply_root(arms,data)
	elif actor.has_meta("appearance_preview"):
		Geometry.apply(actor,data)
		apply_root(actor,data)
	return true

static func apply_root(root:Node,profile:Dictionary) -> void:
	for part in root.find_children("*","MeshInstance3D",true,false):
		if part.mesh==null:continue
		if not part.has_meta(BASE_META):
			var bases=[]
			for surface in range(part.mesh.get_surface_count()):
				bases.append(part.get_surface_override_material(surface) if part.get_surface_override_material(surface)!=null else part.mesh.surface_get_material(surface))
			part.set_meta(BASE_META,bases)
		var bases:Array=part.get_meta(BASE_META)
		for surface in range(mini(bases.size(),part.mesh.get_surface_count())):
			var base=bases[surface]
			if not base is StandardMaterial3D:continue
			var channel=material_channel(String(base.resource_name),String(part.name))
			if channel.is_empty():continue
			var tint=Color(profile.colors[channel])
			if channel=="eyes" and tint!=Color.WHITE and base.albedo_texture!=null:
				var eyes:StandardMaterial3D=base.duplicate()
				eyes.albedo_texture=iris_texture(base.albedo_texture,tint)
				part.set_surface_override_material(surface,eyes)
				continue
			# A fresh instance from the immutable base prevents accumulated tint/bleed.
			var material:StandardMaterial3D=base.duplicate()
			# Approved material bug fix: sleeves sampled black outside a dress-only
			# atlas. Keep imported/source bytes intact and repair all live profiles.
			if "punkduck_black_cocktail_dress" in String(base.resource_name).to_lower():
				material.albedo_texture=load("res://assets/characters/heroine-appearance-denim-color.png")
				material.normal_texture=load("res://assets/characters/heroine-appearance-denim-normal.png")
				material.roughness_texture=load("res://assets/characters/heroine-appearance-denim-roughness.png")
			material.albedo_color=base.albedo_color*tint
			part.set_surface_override_material(surface,material)

static func material_channel(material_name:String,mesh_name:String) -> String:
	var label=(material_name+" "+mesh_name).to_lower()
	if "hair" in label or "eyebrow" in label:return "hair"
	if "teeth" in label or "tongue" in label or "eyelash" in label:return ""
	if "high-poly" in label or "eye" in label:return "eyes"
	if "human.body" in label or "human_body" in label:return "skin"
	if "dress" in label or "denim" in label or "shirt" in label:return "cloth"
	if "leather" in label or "boots" in label:return "leather"
	return ""

static func iris_texture(original:Texture2D,tint:Color) -> Texture2D:
	var key=str(original.get_rid())+tint.to_html(false)
	if eye_textures.has(key):return eye_textures[key]
	# Imported GPU texture readback/decompression is unavailable on some headless
	# and ASTC exports. This Image resource keeps the exact original PNG pixels.
	if eye_source==null:eye_source=load("res://assets/characters/heroine-appearance-eye-pixels.res")
	var image=eye_source.duplicate()
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			image.set_pixel(x,y,iris_pixel(image.get_pixel(x,y),tint))
	image.generate_mipmaps()
	var texture=ImageTexture.create_from_image(image)
	# Bound session memory while a player explores arbitrary colors.
	if eye_textures.size()>=16:eye_textures.clear()
	eye_textures[key]=texture
	return texture

static func iris_pixel(pixel:Color,tint:Color) -> Color:
	var maximum=maxf(pixel.r,maxf(pixel.g,pixel.b));var minimum=minf(pixel.r,minf(pixel.g,pixel.b))
	var saturation=(maximum-minimum)/maxf(maximum,.001)
	var luminance=pixel.r*.2126+pixel.g*.7152+pixel.b*.0722
	var weight=smoothstep(.12,.26,saturation)*(1-smoothstep(.45,.75,luminance))
	var colored=Color(tint.r*luminance*1.8,tint.g*luminance*1.8,tint.b*luminance*1.8,pixel.a)
	return pixel.lerp(colored,weight)
