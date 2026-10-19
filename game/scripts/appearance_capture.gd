extends RefCounted
const Profile=preload("res://scripts/appearance_profile.gd")
const Renderer=preload("res://scripts/character_appearance.gd")
var failures:Array[String]=[]
var checks=0

func check(condition:bool,message:String) -> void:
	checks+=1
	if not condition:failures.append(message)

func picture(game:Control,path:String) -> void:
	await game.get_tree().create_timer(.35).timeout
	await RenderingServer.frame_post_draw
	check(game.get_viewport().get_texture().get_image().save_png(path)==OK,"Capture "+path.get_file())

func skin_matches(root:Node,tint:Color) -> bool:
	if root==null:return false
	var found=false
	for part in root.find_children("*","MeshInstance3D",true,false):
		if not part.has_meta(Renderer.BASE_META):continue
		var bases:Array=part.get_meta(Renderer.BASE_META)
		for surface in range(bases.size()):
			var base=bases[surface]
			if base is StandardMaterial3D and Renderer.material_channel(String(base.resource_name),String(part.name))=="skin":
				found=true
				var material=part.get_surface_override_material(surface)
				if not material is StandardMaterial3D or not material.albedo_color.is_equal_approx(base.albedo_color*tint):return false
	return found

func run(game:Control,directory:String) -> bool:
	game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide()
	game.get_window().size=Vector2i(1280,720)
	await game.get_tree().process_frame
	var original=game.appearance.duplicate(true)
	var growth=game.progression.snapshot().duplicate(true)
	var equipment=game.magic_items.snapshot().duplicate(true)
	game.appearance_menu.open()
	check(game.appearance_menu.visible and not game.player.input_enabled,"Editor gates local commands")
	game.appearance_menu.show_section("hair")
	await picture(game,directory+"/appearance-native-original.png")
	game.appearance_menu.draft.colors.hair="#503C32"
	game.appearance_menu.draft.colors.cloth="#798FBC"
	game.appearance_menu.draft.face_id="soft_cheeks";game.appearance_menu.draft.hair_id="short_layers";game.appearance_menu.draft.body_id="subtle_shape"
	game.appearance_menu.refresh_preview()
	check(game.appearance==original,"Preview edits remain local")
	game.appearance_menu.close()
	check(game.appearance==original,"Cancel leaves accepted profile untouched")
	game.appearance_menu.open();game.appearance_menu.show_section("colors")
	game.appearance_menu.draft.colors.hair="#503C32";game.appearance_menu.draft.colors.cloth="#798FBC"
	game.appearance_menu.draft.colors.eyes="#82A8BF"
	game.appearance_menu.draft.colors.skin="#C49A80"
	game.appearance_menu.draft.face_id="soft_cheeks";game.appearance_menu.draft.hair_id="short_layers";game.appearance_menu.draft.body_id="subtle_shape"
	game.appearance_menu.refresh_preview()
	game.appearance_menu.show_section("body")
	await picture(game,directory+"/appearance-native-approved-options.png")
	game.appearance_menu.show_section("hair");game.appearance_menu.preview.turn(0.0)
	game.appearance_menu.preview.camera.position=Vector3(0,1.53,.75)
	game.appearance_menu.preview.camera.look_at(Vector3(0,1.53,0))
	await picture(game,directory+"/appearance-native-approved-face-hair.png")
	game.appearance_menu.show_section("colors")
	game.get_window().size=Vector2i(960,540)
	await picture(game,directory+"/appearance-960-colors.png")
	game.appearance_menu.show_section("face")
	await picture(game,directory+"/appearance-960-eye-tint.png")
	var pending_draft=game.appearance_menu.draft.duplicate(true)
	game.appearance_menu.set_pending(true);game.appearance_menu.close()
	check(game.appearance_menu.visible and game.appearance_menu.draft==pending_draft,"Pending request keeps preview and cannot silently discard it")
	game.appearance_menu.resolve_online(false,"Fixture rejection")
	check(game.appearance_menu.visible and not game.appearance_menu.pending and game.appearance_menu.draft==pending_draft,"Rejected request retains editable draft")
	game.appearance_menu.apply_draft()
	check(game.appearance.colors.hair=="#503C32","Apply commits accepted colors")
	check(game.appearance.face_id=="soft_cheeks" and game.appearance.hair_id=="short_layers" and game.appearance.body_id=="subtle_shape","Apply commits reviewed geometry IDs")
	check(skin_matches(game.player.get_node("BetaHero").get_child(0),Color("#C49A80")),"Accepted body uses selected skin tone")
	check(skin_matches(game.player.get_node_or_null("FirstPersonHands"),Color("#C49A80")),"First-person hands use the same skin tone without compounding")
	game.player.set_sword_drawn(true)
	await picture(game,directory+"/appearance-first-person-skin.png")
	check(game.progression.snapshot()==growth and game.magic_items.snapshot()==equipment,"Cosmetics preserve progression and equipment")
	var saved=game.save_data()
	var path="user://appearance-fixture.json"
	check(game.Save.write(saved,path)==OK,"Cosmetics save to disposable fixture")
	var loaded=game.Save.read(path)
	check(not loaded.is_empty() and Profile.normalized(loaded.get("appearance",{}))==Profile.normalized(game.appearance),"Cosmetics survive validated save read")
	check(game.apply_save(loaded),"Cosmetics restore through normal loader")
	check(game.appearance.colors.hair=="#503C32","Reload keeps accepted profile")
	check(game.appearance.face_id=="soft_cheeks" and game.appearance.hair_id=="short_layers" and game.appearance.body_id=="subtle_shape","Reload keeps all reviewed geometry IDs")
	var legacy=loaded.duplicate(true);legacy.erase("appearance")
	check(game.apply_save(legacy) and game.appearance==Profile.default_profile(),"Legacy saves restore exact original default")
	game.appearance_menu.open();game.appearance_menu.show_section("skin")
	await picture(game,directory+"/appearance-960-skin.png")
	game.appearance_menu.close()
	DirAccess.remove_absolute(path)
	print("APPEARANCE_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
	return failures.is_empty()
