extends SceneTree
## Standalone focused checks; no imports, player Actor, personal userdata or saves.
const Profile=preload("res://scripts/appearance_profile.gd")
const Renderer=preload("res://scripts/character_appearance.gd")
var failures:Array[String]=[]
var checks=0

func check(condition:bool,message:String) -> void:
	checks+=1
	if not condition:failures.append(message)

func _initialize() -> void:
	var defaults=Profile.default_profile()
	check(Profile.valid(defaults),"Default profile validates")
	var roundtrip=JSON.parse_string(JSON.stringify(defaults))
	check(Profile.normalized(roundtrip)==defaults,"JSON float version roundtrip remains canonical")
	var prior=defaults.duplicate(true);prior.catalog_version=1
	check(Profile.valid(prior) and Profile.normalized(prior)==defaults,"Original catalog migrates without cosmetic changes")
	var approved=defaults.duplicate(true);approved.face_id="soft_cheeks";approved.hair_id="short_layers";approved.body_id="subtle_shape"
	check(Profile.valid(approved),"Reviewed face hair and body IDs validate together")
	var invalid=defaults.duplicate(true);invalid.face_id="../../untrusted.glb"
	check(not Profile.valid(invalid),"Untrusted asset paths rejected")
	invalid=defaults.duplicate(true);invalid.appearance_version=1.5
	check(not Profile.valid(invalid),"Fractional version rejected")
	invalid=defaults.duplicate(true);invalid.colors.skin="#FFFFFFFF"
	check(not Profile.valid(invalid),"Alpha/HDR color input rejected")
	invalid=defaults.duplicate(true);invalid.morphs={"height":NAN}
	check(not Profile.valid(invalid),"Unapproved morph and NaN rejected")
	invalid=defaults.duplicate(true);invalid.extra=true
	check(not Profile.valid(invalid),"Unknown keys rejected")
	invalid=defaults.duplicate(true);invalid.colors.erase("skin")
	check(not Profile.valid(invalid),"Missing required channel rejected")
	var material=StandardMaterial3D.new();material.resource_name="Human.body";material.albedo_color=Color(.8,.7,.6)
	var mesh=BoxMesh.new();mesh.material=material
	var first=Node3D.new();first.set_meta("appearance_preview",true)
	var second=Node3D.new();second.set_meta("appearance_preview",true)
	get_root().add_child(first);get_root().add_child(second)
	var a=MeshInstance3D.new();a.mesh=mesh;first.add_child(a)
	var b=MeshInstance3D.new();b.mesh=mesh;second.add_child(b)
	var draft=defaults.duplicate(true);draft.colors.skin="#806040"
	check(Renderer.apply(first,draft),"Valid draft applies")
	check(material.albedo_color==Color(.8,.7,.6),"Shared imported material stays immutable")
	check(b.get_surface_override_material(0)==null,"Separate actor stays unchanged")
	var color=a.get_surface_override_material(0).albedo_color
	Renderer.apply(first,draft)
	check(a.get_surface_override_material(0).albedo_color==color,"Repeated application never compounds tint")
	Renderer.apply(first,defaults)
	check(a.get_surface_override_material(0).albedo_color==material.albedo_color,"Default restores exact original color")
	Renderer.apply(first,draft);Renderer.clear(first)
	check(a.get_surface_override_material(0).albedo_color==material.albedo_color,"Leaving World Rise restores original material")
	check(not first.has_meta("appearance_profile") and not first.has_meta("appearance_revision"),"Leaving World Rise clears cached cosmetic revision")
	check(defaults.colors.skin=="#FFFFFF","Draft mutation cannot modify default")
	var iris_tint=Color("#82A8BF")
	check(Renderer.iris_pixel(Color(.95,.95,.95),iris_tint)==Color(.95,.95,.95),"Iris tint preserves white sclera")
	check(Renderer.iris_pixel(Color(.015,.015,.015),iris_tint)==Color(.015,.015,.015),"Iris tint preserves dark pupil")
	check(Renderer.iris_pixel(Color(.25,.13,.06),iris_tint)!=Color(.25,.13,.06),"Iris tint changes colored iris pixels")
	# Detach geometry before freeing its override materials (dummy renderer cleanup).
	a.mesh=null;b.mesh=null
	first.free();second.free()
	print(JSON.stringify({"suite":"appearance","checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
