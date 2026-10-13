extends RefCounted
const Art=preload("res://scripts/environment_art.gd")

func collision_contract(world:Node3D) -> Array:
	var result:Array=[]
	for body in world.find_children("*","StaticBody3D",true,false):
		if body.collision_layer==8: continue
		for shape in body.get_children():
			if not shape is CollisionShape3D: continue
			result.append([body.collision_layer,body.transform,shape.transform,shape.shape.get_class(),shape.shape.get_rid()])
	return result

func run(test:RefCounted) -> void:
	var game=test.game
	game.start_new_game(false)
	game.environment_profile="original"
	var progress=game.progression.snapshot(); var quest=game.quest_stage
	for file in DirAccess.get_files_at("res://content/maps"):
		if not file.ends_with(".json"): continue
		var id=file.get_basename()
		game.environment_profile="original"; game.load_map(id,Vector2(INF,INF),true)
		for enemy in game.enemies: enemy.ai_enabled=false
		var map_data=JSON.stringify(game.current_world.definition)
		var native=collision_contract(game.current_world)
		var heights:Array=[]
		for point in [Vector3.ZERO,Vector3(2,0,2),game.player.position]: heights.append(game.current_world.ground_height(point))
		test.check(not game.current_world.has_node("DarkwoodEnvironment"),id+": original scenery remains available")
		game.environment_profile="darkwood"; game.load_map(id,Vector2(INF,INF),true)
		for enemy in game.enemies: enemy.ai_enabled=false
		var upgraded=collision_contract(game.current_world)
		# Shape RIDs are freshly allocated on rebuild; compare authored shape type/transform/mask.
		var same=native.size()==upgraded.size()
		for index in range(mini(native.size(),upgraded.size())):
			for column in range(4): same=same and native[index][column]==upgraded[index][column]
		test.check(same,id+": actor/sword collision count, masks and transforms remain intact")
		test.check(game.current_world.has_node("DarkwoodEnvironment") and JSON.stringify(game.current_world.definition)==map_data,id+": upgraded art preserves encounters, exits and map data")
		var index=0
		for point in [Vector3.ZERO,Vector3(2,0,2),game.player.position]:
			same=same and is_equal_approx(heights[index],game.current_world.ground_height(point)); index+=1
		test.check(same,id+": visual reskin preserves walkable terrain heights")
		for enemy in game.enemies:
			if String(enemy.definition.kind).begins_with("beta_"):
				test.check(not enemy.has_meta("advanced_art") and enemy.health==enemy.max_health and enemy.animal.find_children("*","Skeleton3D",true,false).size()==1 and enemy.animation_names.has("attack"),id+": authored animal keeps its supplied skin, attack clips and health across scenery profiles")
			else:
				test.check(enemy.has_meta("advanced_art") and enemy.health==enemy.max_health,id+": creature receives new materials with original health/AI")
		for data in game.current_world.definition.props:
			if data.kind=="tree" or data.kind=="rock":
				var node=game.current_world.get_node(NodePath(data.id))
				test.check(node.has_node("ScannedArt"),id+": "+data.id+" uses a downloaded scanned mesh")
	test.check(game.progression.snapshot()==progress and game.quest_stage==quest,"World art changes preserve XP and story")
	var detailed=game.player.visual.find_child("module_body",true,false)
	var native_mesh=detailed.get_meta("original_mesh")
	var head_index=game.player.skeleton.find_bone("head")
	var original_rests=game.player.get_meta("original_rests")
	var personal=game.player.get_node("BetaHero")
	test.check(not game.player.visual.visible and personal.rig.get_bone_count()==16,"Advanced Alpha renders the personal heroine with its fitted sixteen-bone skin")
	test.check(game.player.skeleton.get_bone_rest(head_index).is_equal_approx(original_rests[head_index]) and game.player.animator.get_animation_list().size()>=19,"Personal skin follows canonical combat clocks without replacing the gameplay rig")
	var textured=0
	for mesh in personal.find_children("*","MeshInstance3D",true,false):
		if mesh.skin==null:continue
		for index in range(mesh.mesh.get_surface_count()):
			var material=mesh.mesh.surface_get_material(index)
			if material is StandardMaterial3D and material.albedo_texture!=null:textured+=1
	test.check(textured>=4,"Personal heroine retains baked skin, hair, denim and leather textures")
	test.check(game.player.equipment.get_meta("beta_sword",false) and game.player.equipment.find_child("SwordBlade",true,false)!=null,"Advanced Alpha uses the selected broad war sword and its actual steel contacts")
	game.inventory.preview.signature="!";game.inventory.preview.refresh(game)
	test.check(game.inventory.preview.actor.has_node("BetaHero") and not game.inventory.preview.actor.visual.visible,"Inventory uses the same personal heroine as Advanced Alpha gameplay")
	game.load_map("slime_forest",Vector2(0,5),true)
	for enemy in game.enemies: enemy.ai_enabled=false
	await test.frames(3)
	var slime=game.enemies[0]
	var material=slime.body.material_override
	slime.set_body_color(Color("#eedd99"))
	test.check(slime.body.material_override==material and material is ShaderMaterial and material.shader.resource_path.ends_with("slime_surface.gdshader"),"Slime combat flashes retain the wet advanced material")
	game.player.set_sword_drawn(false)
	var health=game.player.health; var stamina=game.player.stamina
	var path="user://environment-verification.json"
	game.Save.write(game.save_data(),path)
	var saved=game.Save.read(path)
	game.set_environment_profile("original")
	test.check(game.apply_save(saved) and game.environment_profile=="darkwood" and game.player.health==health and game.player.stamina==stamina,"Private save round trip restores upgraded art and resources")
	game.set_environment_profile("original")
	test.check(not game.current_world.has_node("DarkwoodEnvironment") and game.player.skeleton.get_bone_count()==16,"Original profile restores preserved art and canonical rig")
	test.check(game.player.skeleton.get_bone_rest(head_index).is_equal_approx(original_rests[head_index]) and detailed.mesh==native_mesh,"Switching to Original restores its skeleton and mesh together")
	var old=saved.duplicate(true); old.erase("environment_revision"); old.erase("environment_profile")
	test.check(game.apply_save(old) and game.environment_profile=="darkwood" and game.graphics_preset==0,"Legacy player saves adopt upgraded full-resolution art without losing progress")
	game.environment_profile="original"; game.load_map("coastal_path",Vector2(0,3),true); game.set_resolution(320)
	DirAccess.remove_absolute(path)
