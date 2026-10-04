extends RefCounted
## Integration checks exercise actual imported assets, physics, input, and save serialization.
var failures:Array=[]
var checks:Array=[]
var game:Node

func check(condition: bool, description: String) -> void:
	checks.append({"check":description,"passed":condition})
	if not condition:
		failures.append(description)
		push_error(description)

func frames(count: int) -> void:
	for i in range(count):
		await game.get_tree().physics_frame

func run(target: Node) -> void:
	game=target
	await frames(3)
	check(game.player.skeleton.get_bone_count()==14,"Canonical 14-bone rig imported")
	check(game.player.clips.size()==3,"Idle, walk, and interaction clips imported")
	check(game.player.animator.get_animation(game.player.clips.idle_loop)==game.npcs[0].animator.get_animation(game.npcs[0].clips.idle_loop),"Character variants share the same animation resource")
	check(game.player.visual.find_child("outfit_dress",true,false).visible and not game.player.visual.find_child("outfit_tunic",true,false).visible,"Hero uses the dress module")
	check(game.npcs[0].visual.find_child("hair_crop",true,false).visible and not game.npcs[0].visual.find_child("hair_bob",true,false).visible,"NPC uses the short hair module")
	var leg=game.player.skeleton.find_bone("thigh_L")
	if leg<0:
		leg=game.player.skeleton.find_bone("thigh.L")
	check(leg>=0,"Expected deforming thigh bone exists")
	game.player.animator.play(game.player.clips.walk_loop)
	game.player.animator.seek(.1,true)
	var pose_a=game.player.skeleton.get_bone_pose_rotation(leg)
	game.player.animator.seek(.5,true)
	var pose_b=game.player.skeleton.get_bone_pose_rotation(leg)
	check(not pose_a.is_equal_approx(pose_b),"Walk animation changes the actual skeleton pose")
	game.player.position=Vector3(0,0,3)
	Input.action_press("move_right")
	await frames(30)
	Input.action_release("move_right")
	check(game.player.position.x>1.05 and game.player.position.x<1.35,"Mapped movement advances at the configured speed")
	check(is_zero_approx(game.player.position.y),"Movement remains on the horizontal plane")
	game.player.position=Vector3(0,0,3)
	game.player.last_axis=0
	Input.action_press("move_right")
	Input.action_press("move_up")
	await frames(20)
	Input.action_release("move_right")
	Input.action_release("move_up")
	check(abs(game.player.position.z-3)<.01,"Simultaneous movement inputs remain cardinal")
	game.player.position=Vector3(-5.8,0,-2.75)
	Input.action_press("move_up")
	await frames(60)
	Input.action_release("move_up")
	check(game.player.position.z>-3.15 and game.player.position.z<-3.02,"House collision stops walking through the building")
	game.player.position=Vector3(8,0,4)
	Input.action_press("move_right")
	await frames(60)
	Input.action_release("move_right")
	check(game.player.position.x<8.79 and game.player.position.x>8.65,"Shoreline collision prevents walking onto water")
	game.player.position=Vector3(-1.9,0,6)
	await frames(2)
	game.open_nearest()
	check(game.dialog.visible and game.dialog_title.text=="Waymarker","Nearby interaction opens the correct sign dialogue")
	var before=game.player.position
	Input.action_press("move_down")
	await frames(15)
	Input.action_release("move_down")
	check(game.player.position.distance_to(before)<.01,"Dialogue suspends movement")
	game.advance_dialogue()
	game.advance_dialogue()
	check(not game.dialog.visible,"Dialogue closes after the last line")
	game.player.position=Vector3(0,0,-10.3)
	game.exit_cooldown=0
	await frames(3)
	check(game.map_id=="village_green","North exit loads the connected village")
	game.player.position=Vector3(0,0,9.2)
	game.exit_cooldown=0
	await frames(3)
	check(game.map_id=="coastal_path","South exit returns to the coastal path")
	game.player.position=Vector3(0,0,3.2)
	game.player.visual.rotation.y=1.2
	game.set_resolution(320)
	var saved=game.save_data()
	var save_path="user://verification-save.json"
	check(game.Save.write(saved,save_path)==OK,"Versioned save is written")
	game.load_map("village_green")
	check(game.apply_save(game.Save.read(save_path)),"Saved data is loaded")
	check(game.map_id=="coastal_path" and abs(game.player.position.z-3.2)<.01 and abs(game.player.visual.rotation.y-1.2)<.01 and game.world_view.size.x==320,"Save round trip restores map, position, facing, and pixel preset")
	check(game.Save.write(saved,save_path)==OK,"Atomic save replacement works for an existing save")
	var file=FileAccess.open(save_path,FileAccess.WRITE)
	file.store_string('{"version":1,"map":"missing_map","position":[0,0]}')
	file.close()
	check(game.Save.read(save_path).is_empty(),"Unknown-map save is rejected")
	file=FileAccess.open(save_path,FileAccess.WRITE)
	file.store_string('{"version":1,"map":"coastal_path","position":["bad",0]}')
	file.close()
	check(game.Save.read(save_path).is_empty(),"Malformed save coordinates are rejected")
	var water_save=saved.duplicate(true)
	water_save.position=[11,3]
	check(not game.apply_save(water_save),"Saved water position is rejected")
	var blocked_save=saved.duplicate(true)
	blocked_save.position=[-5.8,-4.6]
	check(not game.apply_save(blocked_save),"Saved position inside a building is rejected")
	DirAccess.remove_absolute(save_path)
	var recolor=game.player.definition.duplicate(true)
	recolor.palette.dress="#9B6884"
	recolor.modules.hair="crop"
	var animation_before=game.player.animator.get_animation(game.player.clips.walk_loop)
	game.player.configure(recolor)
	check(game.player.animator.get_animation(game.player.clips.walk_loop)==animation_before,"Palette and hair changes reuse the existing walk animation")
	check(game.player.visual.find_child("hair_crop",true,false).visible,"Hair change selects the existing alternate module")
	var palette_ok=false
	var outfit=game.player.visual.find_child("outfit_dress",true,false)
	for i in range(outfit.mesh.get_surface_count()):
		var material=outfit.get_surface_override_material(i)
		if material!=null and material.albedo_color.is_equal_approx(Color("#9B6884")):
			palette_ok=true
	check(palette_ok,"Recolor applies to the actual render material")
	var modified_map=game.read_data("res://content/maps/coastal_path.json").duplicate(true)
	modified_map.props.append({"id":"recipe_test_flowers","kind":"flowers","at":[3,3]})
	var map_test=game.World.new()
	game.world_root.add_child(map_test)
	map_test.build(modified_map)
	check(map_test.find_child("recipe_test_flowers",false,false)!=null,"A map definition change creates a new prop without gameplay edits")
	map_test.queue_free()
	game.set_resolution(640)
	game._layout()
	check(int(game.image_view.size.x)%640==0,"World presentation uses integer pixel scaling")
	var blade=game.player.equipment.find_child("SwordBlade",true,false)
	var gem=game.player.equipment.find_child("SwordBlueGem",true,false)
	var blade_center=blade.global_transform*blade.get_aabb().get_center()
	var gem_center=gem.global_transform*gem.get_aabb().get_center()
	check(gem_center.y>blade_center.y and blade_center.y>.35,"Sword carry has its pommel above the blade and clears the ground")
	var report={"passed":failures.is_empty(),"check_count":checks.size(),"checks":checks,"failures":failures,"godot":Engine.get_version_info().string}
	var report_path=ProjectSettings.globalize_path("res://../output/verification/integration-report.json")
	var arguments=OS.get_cmdline_user_args()
	if "--report" in arguments:
		report_path=arguments[arguments.find("--report")+1]
	DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
	file=FileAccess.open(report_path,FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	print("VERIFICATION_", "PASS" if failures.is_empty() else "FAIL", " ",checks.size()," checks")
	game.get_tree().quit(0 if failures.is_empty() else 1)
