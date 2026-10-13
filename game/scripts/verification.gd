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
	# Headless display defaults to 64px; exercise UI input in the real logical game size.
	game.get_window().size=Vector2i(1280,720)
	await frames(3)
	check(game.player.skeleton.get_bone_count()==16,"Canonical rig with hair and skirt bones imported")
	check(game.player.clips.size()==19,"Nineteen shared clips include drawn and sheathed somersault and stand-up variants")
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
	check(game.player.position.x>.4 and game.player.position.z<2.6 and game.player.position.distance_to(Vector3(0,0,3))>.76 and game.player.position.distance_to(Vector3(0,0,3))<.84,"Diagonal input moves on both axes without a speed boost")
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
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	check(game.map_id=="village_green","North exit loads the connected village")
	game.player.position=Vector3(0,0,9.2)
	game.exit_cooldown=0
	await frames(3)
	await game.get_tree().process_frame
	await game.get_tree().process_frame
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
	await stamina_checks()
	await combat_checks(save_path)
	await parry_checks()
	await graphics_combo_checks()
	game.player.water_unlocked=true
	game.player.lance_unlocked=true
	await flow_rush_water_checks()
	await story_checks()
	game.progression.restore({"tree_version":2,"xp":240,"learned":["mana","mana_lance"]})
	game.apply_skill_stats()
	await inventory_cast_checks()
	await load("res://scripts/progression_checks.gd").new().run(self)
	await load("res://scripts/graphics9_checks.gd").new().run(self)
	game.player.water_unlocked=true
	game.player.lance_unlocked=true
	await load("res://scripts/consolidation_checks.gd").new().run(self)
	await load("res://scripts/alchemy_checks.gd").new().run(self)
	await load("res://scripts/potion_checks.gd").new().run(self)
	await load("res://scripts/title_checks.gd").new().run(self)
	await load("res://scripts/parry_input_checks.gd").new().run(self)
	await load("res://scripts/parry_contact_checks.gd").new().run(self)
	# Gameplay is first-person only. Legacy overhead/follow camera QA is retired.
	await load("res://scripts/menu_checks.gd").new().run(self)
	await load("res://scripts/animation_checks.gd").new().run(self)
	await load("res://scripts/combo_motion_checks.gd").new().run(self)
	await load("res://scripts/thrust_checks.gd").new().run(self)
	await load("res://scripts/knockback_checks.gd").new().run(self)
	await load("res://scripts/home_checks.gd").new().run(self)
	await load("res://scripts/menagery_checks.gd").new().run(self)
	await load("res://scripts/terrain_checks.gd").new().run(self)
	await load("res://scripts/world_pack_checks.gd").new().run(self)
	await load("res://scripts/grind_resin_checks.gd").new().run(self)
	await load("res://scripts/queen_checks.gd").new().run(self)
	await load("res://scripts/sculpt_checks.gd").new().run(self)
	await load("res://scripts/goblin_checks.gd").new().run(self)
	await load("res://scripts/magic_item_checks.gd").new().run(self)
	await load("res://scripts/equipment_clearance_checks.gd").new().run(self)
	await load("res://scripts/hud_healing_checks.gd").new().run(self)
	await load("res://scripts/core_checks.gd").new().run(self)
	await load("res://scripts/environment_checks.gd").new().run(self)
	await load("res://scripts/standalone_checks.gd").new().run(self)
	await load("res://scripts/alpha_character_checks.gd").new().run(self)
	await load("res://scripts/beta_checks.gd").new().run(self)
	await load("res://scripts/skill_upgrade_checks.gd").new().run(self)
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

func graphics_combo_checks() -> void:
	game.load_map("coastal_path",Vector2(0,3))
	game.player.set_sword_drawn(false)
	game.player.play_clip("walk_loop",0)
	var hair=game.player.skeleton.find_bone("hair_sway")
	var skirt=game.player.skeleton.find_bone("skirt_sway")
	game.player.animator.seek(.1,true)
	var hair_a=game.player.skeleton.get_bone_pose_rotation(hair)
	var skirt_a=game.player.skeleton.get_bone_pose_rotation(skirt)
	game.player.animator.seek(.5,true)
	check(not hair_a.is_equal_approx(game.player.skeleton.get_bone_pose_rotation(hair)),"Walking animates the hair's actual deform bone")
	check(not skirt_a.is_equal_approx(game.player.skeleton.get_bone_pose_rotation(skirt)),"Walking animates the dress hem's actual deform bone")
	var dress=game.player.visual.find_child("outfit_dress",true,false)
	check(dress.mesh.get_surface_count()>=3,"Pleated dress retains reusable semantic shading materials")
	check(game.current_world.shoreline.size()==18,"Coastal path includes the small animated shoreline")
	var foam=game.current_world.shoreline[0]
	var foam_before=foam.position
	await frames(12)
	check(not foam.position.is_equal_approx(foam_before),"Coastal foam moves in the running world")
	var house=game.current_world.find_child("west_cottage",true,false)
	var door_height=0.0
	for child in house.get_children():
		if child is MeshInstance3D and child.material_override.albedo_color.is_equal_approx(Color("#685241")):
			door_height=maxf(door_height,child.mesh.get_aabb().size.y)
	check(door_height>=2.2,"House door is taller than the 1.97m character rig")
	game.set_resolution(960)
	var save_path="user://graphics-verification-save.json"
	game.Save.write(game.save_data(),save_path)
	check(game.Save.read(save_path).resolution==960,"Detailed pixel preset survives save validation")
	DirAccess.remove_absolute(save_path)
	for map_name in ["coastal_path","village_green","slime_forest"]:
		game.load_map(map_name)
		var b=game.current_world.bounds
		var contained=true
		for x in [b.position.x,b.end.x]:
			for z in [b.position.y,b.end.y]:
				var target=game.bounded_camera_target(Vector3(x,0,z))
				game.camera.position=target+game.camera_offset
				game.camera.look_at(target,Vector3.UP)
				for sx in [0,game.world_view.size.x]:
					for sy in [0,game.world_view.size.y]:
						var point=Vector2(sx,sy)
						var origin=game.camera.project_ray_origin(point)
						var ray=game.camera.project_ray_normal(point)
						var ground=origin-ray*(origin.y/ray.y)
						contained=contained and b.has_point(Vector2(ground.x,ground.z))
		check(contained,"All four camera corners remain over "+map_name+" at every map edge")
	game.load_map("coastal_path",Vector2(0,3))
	game.player.set_sword_drawn(true)
	game.player.combo_remaining=0
	game.player.restore_stamina(100)
	check(game.player.begin_attack("light") and game.player.combo_stage==1 and game.player.stamina==80,"Combo opens with a committed light swing costing 20 stamina")
	game.player.state_time=game.player.state_duration*.5
	check(game.player.begin_charge() and game.player.release_charge("light"),"Mouse tap during the first swing queues its return cut")
	check(game.player.stamina==80 and not game.player.queue_combo(),"Combo buffer neither spends early nor accepts duplicate requests")
	game.player.state_time=game.player.state_duration-.01
	await frames(2)
	check(game.player.state=="light" and game.player.combo_stage==2 and game.player.stamina==60 and game.player.current_clip=="attack_light2","Buffered return cut uses its own animation and costs 20 stamina")
	game.player.state_time=game.player.state_duration*.5
	check(game.player.begin_attack("light"),"A third light request queues the momentum spin")
	game.player.state_time=game.player.state_duration-.01
	await frames(2)
	check(game.player.combo_stage==3 and game.player.stamina==32 and game.player.current_clip=="attack_light3","Spin costs 28 stamina and uses its own blade and arm animation")
	game.player.state_time=game.player.state_duration*.55
	await frames(2)
	check(abs(game.player.visual.rotation.y-game.player.attack_yaw)>2 and game.player.attack_tuning().cone_dot==-1,"Third swing rotates the whole character and can hit around her")
	check(not game.player.queue_combo(),"Three-hit combo cannot loop into a fourth strike")
	game.player.set_sword_drawn(true)
	game.player.combo_remaining=0
	game.player.restore_stamina(39)
	game.player.begin_attack("light")
	game.player.state_time=game.player.state_duration*.6
	check(not game.player.queue_combo() and game.player.stamina==19,"Insufficient stamina rejects the return cut without spending")
	game.player.set_sword_drawn(true)
	game.player.combo_stage=1
	game.player.combo_remaining=.01
	game.player.restore_stamina(100)
	await frames(3)
	game.player.begin_attack("light")
	check(game.player.combo_stage==1,"Expired combo window starts a fresh opening swing")
	game.player.set_sword_drawn(false)
	game.player.restore_stamina(100)
	game.set_resolution(960)

func trial_wave(origin: Vector3, toward: Vector3) -> Node3D:
	var wave=game.WaterWave.new()
	game.world_root.add_child(wave)
	wave.configure(game,origin,toward,game.player.combat.water)
	wave.set_physics_process(false)
	game.water_waves.append(wave)
	return wave

func flow_rush_water_checks() -> void:
	game.load_map("coastal_path",Vector2(0,3))
	game.player.set_sword_drawn(true)
	game.player.restore_stamina(100)
	check(game.player.visual.find_child("SwordArc",true,false)==null and not "swing_arc" in game.player,"Sword and parry arc geometry has been removed")
	var gem_front=game.player.equipment.find_child("SwordBlueGem",true,false)
	var gem_back=game.player.equipment.find_child("SwordBlueGemBack",true,false)
	var mount=game.player.equipment.find_child("SwordGemMount",true,false)
	check(gem_front!=null and gem_back!=null and gem_front.get_aabb().size.x>mount.get_aabb().size.x*.65,"Smaller pommel crystal remains visible on both sides")
	game.player.visual.rotation.y=0
	Input.action_press("move_right")
	await frames(1)
	check(game.player.visual.rotation.y>0 and game.player.visual.rotation.y<PI/2,"Facing turns smoothly instead of snapping on direction changes")
	Input.action_release("move_right")
	Input.action_press("move_up")
	await frames(1)
	check(game.player.velocity.x>0 and game.player.velocity.z<0,"Movement curves through a diagonal when changing direction")
	Input.action_release("move_up")
	game.player.position=Vector3(0,0,3)
	game.player.visual.rotation.y=PI
	Input.action_press("move_up")
	Input.action_press("sprint")
	await frames(20)
	var rushed_start=game.player.position
	var before_hold=game.player.stamina
	check(game.player.sprinting and game.player.rush_credit>0,"A real drawn-sword sprint builds attack momentum")
	check(game.player.begin_charge(),"A rushing player can start the mouse hold wind-up")
	await frames(10)
	check(game.player.position.z<rushed_start.z-.3 and game.player.stamina<before_hold-4,"Forward mouse hold keeps the rush moving and draining stamina")
	check(game.player.release_charge("heavy") and game.player.attack_rushing,"Heavy release preserves the actual rushing bonus")
	Input.action_release("sprint")
	Input.action_release("move_up")
	var regular_windup=float(game.player.combat.heavy.duration)*float(game.player.combat.heavy.active_start)
	check(game.player.compressed_windup<regular_windup*.45 and game.player.state_duration<float(game.player.combat.heavy.duration),"Rushing reduces heavy wind-up by 58 percent without speeding recovery")
	await frames(39)
	check(game.player.attack_phase()>=float(game.player.combat.heavy.active_start),"Rushed heavy reaches its damage window in roughly 0.6 seconds")
	game.player.set_sword_drawn(true)
	game.player.restore_stamina(100)
	game.player.position=Vector3(0,0,3)
	game.player.visual.rotation.y=0
	Input.action_press("move_down")
	Input.action_press("sprint")
	await frames(14)
	game.player.begin_attack("light")
	Input.action_release("sprint")
	Input.action_release("move_down")
	check(game.player.attack_rushing and abs(game.player.compressed_windup-float(game.player.combat.light.duration)*float(game.player.combat.light.active_start)*.65)<.001,"Rushing also reduces the light opener's wind-up")
	game.player.set_sword_drawn(true)
	game.player.restore_stamina(100)
	game.player.combo_remaining=0
	game.player.position=Vector3(0,0,3)
	game.player.visual.rotation.y=0
	game.player.begin_attack("light")
	game.player.state_time=game.player.state_duration*.72
	game.player.animator.seek(game.player.state_time,true)
	game.player._pose_sword("light",.72)
	var blade_before=game.player.sword_tip()
	game.player.queue_combo()
	await frames(3)
	check(game.player.combo_stage==2 and game.player.chain_blend>0 and game.player.state_time<.08,"Return cut links during follow-through before the old attack resets")
	check(game.player.sword_tip().distance_to(blade_before)<.5,"The blade stays continuous across the combo join")
	check(game.player.velocity.length()>.3 and game.player.velocity.length()<=.75,"Combo transition keeps a small carry without repeating the opening surge")
	game.load_map("slime_forest",Vector2(0,3))
	var enemy=game.enemies[0]
	enemy.ai_enabled=false
	enemy.set_physics_process(false)
	game.player.set_sword_drawn(true)
	game.player.restore_stamina(100)
	game.player.visual.rotation.y=0
	enemy.position=Vector3(0,0,5)
	enemy.health=60
	var key=InputEventKey.new()
	key.physical_keycode=KEY_Q
	key.pressed=true
	Input.parse_input_event(key.duplicate())
	await frames(2)
	check(game.player.state=="water" and game.player.stamina==76,"Mapped Q commits a water cast and spends 24 stamina")
	key.pressed=false
	Input.parse_input_event(key.duplicate())
	check(not game.player.begin_water() and not game.player.begin_attack("heavy"),"Water cast commitment prevents repeated casts or melee overlap")
	await frames(28)
	var live_waves=game.water_waves.filter(func(wave): return is_instance_valid(wave))
	check(live_waves.size()==1 and live_waves[0].radius>0,"Water releases one traveling front at its authored animation phase")
	await frames(24)
	check(enemy.health<40 and enemy.health>=32,"Actual traveling water front damages the mob from the advancing caster")
	await frames(45)
	check(game.player.state=="free" and game.water_waves.filter(func(wave): return is_instance_valid(wave)).is_empty(),"Water cast recovers and its faded wave is cleaned up")
	game.player.set_sword_drawn(true)
	game.player.restore_stamina(23)
	check(not game.player.begin_water() and game.player.stamina==23,"Insufficient water stamina spends nothing")
	game.player.set_sword_drawn(false)
	game.player.restore_stamina(100)
	check(not game.player.begin_water(),"Water is channeled through the drawn sword crystal")
	game.player.set_sword_drawn(true)
	game.player.position=Vector3(0,0,0)
	var wave=trial_wave(Vector3.ZERO,Vector3(0,0,1))
	check(wave.damage_at(1)>wave.damage_at(4) and wave.damage_at(4)>wave.damage_at(7) and wave.damage_at(8)==0,"Water damage decreases monotonically to zero at maximum range")
	enemy.position=Vector3(0,0,2)
	enemy.health=60
	wave.advance(.3)
	var near_damage=60-enemy.health
	wave.advance(.1)
	check(near_damage==24 and enemy.health==36,"Swept water contact deals near damage once per enemy")
	wave.queue_free()
	wave=trial_wave(Vector3.ZERO,Vector3(0,0,1))
	enemy.position=Vector3(0,0,6)
	enemy.health=60
	wave.advance(.85)
	check(60-enemy.health==8 and near_damage>60-enemy.health,"Distant mob receives less damage even with a large physics step")
	check(wave.front.material_override.albedo_color.a<.2,"Traveling water also fades visibly with distance")
	wave.queue_free()
	wave=trial_wave(Vector3.ZERO,Vector3(0,0,1))
	enemy.position=Vector3(4,0,0)
	enemy.health=60
	wave.advance(.7)
	check(enemy.health==60,"Water sweeps forward and does not hit enemies beside the casting fan")
	wave.queue_free()
	var barrier=game.World.Props.collider(game.current_world,Vector3(0,.7,3),Vector3(3,1.4,.3))
	await frames(2)
	wave=trial_wave(Vector3.ZERO,Vector3(0,0,1))
	enemy.position=Vector3(0,0,5)
	enemy.health=60
	wave.advance(.8)
	check(enemy.health==60 and float(wave.blocked[12])<3.1,"Walls stop water damage and cut off the corresponding visible wave sector")
	barrier.queue_free()
	wave.queue_free()
	game.player.position=Vector3(0,0,3)
	game.player.restore_stamina(100)
	game.player.begin_water()
	game.toggle_help()
	await frames(2)
	var paused_time=game.player.state_time
	await frames(10)
	check(game.player.state_time==paused_time and game.player.stamina==76,"Help pauses water casting and its resource clocks")
	game.toggle_help()
	await frames(2)
	game.player.set_sword_drawn(true)
	wave=trial_wave(Vector3.ZERO,Vector3(0,0,1))
	wave.set_physics_process(true)
	game.toggle_help()
	await frames(2)
	var paused_radius=wave.radius
	await frames(8)
	check(wave.radius==paused_radius,"Help also freezes water that is already traveling")
	game.toggle_help()
	await frames(4)
	check(wave.radius>paused_radius,"Existing water resumes traveling after Help closes")
	game._water_cast(Vector3.ZERO,Vector3(0,0,1))
	var old_wave=game.water_waves[-1]
	game.load_map("coastal_path")
	await frames(2)
	check(not is_instance_valid(old_wave) and game.water_waves.is_empty(),"Area changes remove all old-map water attacks")
	game.player.set_sword_drawn(false)
	game.player.restore_stamina(100)

func combat_checks(save_path: String) -> void:
	# Keep this encounter independent of earlier movement/resource fixtures.
	game.defeated_enemies.clear()
	game.enemy_states.clear()
	game.player.configure(game.read_data("res://content/characters/hero.json"))
	game.load_map("coastal_path",Vector2(0,3))
	game.player.visual.rotation.y=0
	check(game.player.sword_tip().y>.02,"Oversized stowed sword clears the ground")
	check(not game.player.begin_attack("light"),"Sheathed sword cannot attack")
	var draw_event=InputEventKey.new()
	draw_event.physical_keycode=KEY_R
	draw_event.pressed=true
	Input.parse_input_event(draw_event)
	await frames(1)
	check(game.player.state=="draw","Mapped R key starts drawing the sword")
	draw_event.pressed=false
	Input.parse_input_event(draw_event)
	await frames(ceili(game.player.combat.draw_seconds*60)+4)
	check(game.player.sword_drawn and game.player.state=="free","Draw animation finishes in an equipped state")
	var tip=game.player.sword_tip()
	check(abs(tip.y)<.09 and (tip-game.player.position).dot(game.player.facing())<-1.8,"Drawn sword tip rests on the ground behind the girl")
	game.player.set_physics_process(false)
	var forearm=game.player.skeleton.find_bone("forearm_R")
	if forearm<0:
		forearm=game.player.skeleton.find_bone("forearm.R")
	var wrist=Vector3(-.385,.88,.015)
	var rest_offset=game.player.skeleton.get_bone_global_rest(forearm).affine_inverse()*wrist
	for pose in [{"key":"drag","clip":"drag_idle_loop","phase":0.0},{"key":"light","clip":"attack_light","phase":.7},{"key":"heavy","clip":"attack_heavy","phase":.68}]:
		game.player.play_clip(pose.clip,0)
		game.player.animator.seek(game.player.animator.get_animation(game.player.clips[pose.clip]).length*pose.phase,true)
		game.player._pose_sword(pose.key,pose.phase)
		await frames(2)
		var hand=game.player.skeleton.global_transform*(game.player.skeleton.get_bone_global_pose(forearm)*rest_offset)
		var grip=game.player.equipment.global_transform*Vector3(0,.16,0)
		check(hand.distance_to(grip)<.13,"Imported right hand stays on the sword grip in "+pose.key+" pose")
	game.player.current_clip=""
	game.player.set_sword_drawn(true)
	game.player.set_physics_process(true)
	var start=game.player.position
	Input.action_press("move_right")
	await frames(30)
	Input.action_release("move_right")
	check(game.player.position.x-start.x>.56 and game.player.position.x-start.x<.70,"Dragging the sword slows the actual walk speed")
	check(not game.player.scrape_nodes.is_empty(),"Dragging emits ground scrape marks")
	var click=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.position=game.world_rect.get_center()
	click.global_position=click.position
	click.pressed=true
	Input.parse_input_event(click.duplicate())
	await frames(2)
	await game.get_tree().process_frame
	check(game.player.state=="charge" and game.player.stamina==100,"Left press waits for tap or hold without spending stamina")
	click.pressed=false
	Input.parse_input_event(click.duplicate())
	await frames(1)
	check(game.player.state=="light" and game.player.stamina==80,"Quick left release starts one light attack and spends its stamina cost")
	await frames(96)
	game.player.restore_stamina(100)
	click.button_index=MOUSE_BUTTON_RIGHT
	click.pressed=true
	Input.parse_input_event(click.duplicate())
	await frames(2)
	# Flush queued GUI delivery as well as physics, including during frame catch-up.
	await game.get_tree().process_frame
	check(game.player.state=="parry" and game.player.stamina==90,"Right mouse click starts a parry through the UI")
	click.pressed=false
	Input.parse_input_event(click.duplicate())
	await frames(45)
	game.player.restore_stamina(100)
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	Input.parse_input_event(click.duplicate())
	await frames(30)
	check(game.player.state=="heavy" and game.player.stamina==64,"Holding left click commits one heavy attack at the threshold")
	await frames(160)
	check(game.player.state=="free" and not game.mouse_attack_pending,"Keeping left click held does not repeat the heavy attack")
	click.pressed=false
	Input.parse_input_event(click.duplicate())
	await frames(2)
	check(game.player.state=="free","Releasing after a heavy attack does not add a light attack")
	game.player.restore_stamina(100)
	click.pressed=true
	Input.parse_input_event(click.duplicate())
	await frames(2)
	click.position=game.world_rect.position-Vector2(10,10)
	click.global_position=click.position
	click.pressed=false
	Input.parse_input_event(click.duplicate())
	await frames(2)
	check(game.player.state=="free" and not game.mouse_attack_pending and game.player.stamina==100,"Releasing outside the game cancels the uncommitted charge")
	click.position=game.world_rect.get_center()
	click.global_position=click.position
	click.pressed=true
	Input.parse_input_event(click.duplicate())
	await frames(2)
	game.get_window().focus_exited.emit()
	check(game.player.state=="free" and not game.mouse_attack_pending,"Losing window focus cancels a pending mouse charge")
	click.pressed=false
	Input.parse_input_event(click.duplicate())
	await frames(1)
	# The headless window is only 64px; move the real panel into its input area.
	game.set_process(false)
	game.health_panel.position=Vector2.ZERO
	click.position=Vector2(10,10)
	click.global_position=click.position
	click.pressed=true
	Input.parse_input_event(click.duplicate())
	await frames(2)
	check(game.player.state=="free" and not game.mouse_attack_pending,"Clicking the health interface does not charge a sword attack")
	click.pressed=false
	Input.parse_input_event(click.duplicate())
	await frames(1)
	game.set_process(true)
	game._layout()
	game.player.position=Vector3(0,0,3)
	game.player.visual.rotation.y=PI
	game.player.restore_stamina(100)
	start=game.player.position
	check(game.player.begin_attack("heavy"),"Heavy attack starts with the sword drawn")
	check(not game.player.begin_attack("light") and not game.player.toggle_sword(),"Attack commitment rejects spam and sheathing during a swing")
	Input.action_press("move_right")
	await frames(35)
	Input.action_release("move_right")
	check(game.player.position.distance_to(start)<.02,"Heavy wind-up plants her feet and locks steering")
	await frames(115)
	check(game.player.position.z<start.z-2 and abs(game.player.position.x-start.x)<.02,"Heavy follow-through carries her forward without steering")
	check(game.player.combat.heavy.duration>game.player.combat.light.duration and game.player.combat.heavy.damage>game.player.combat.light.damage,"Heavy attack is slower and stronger than light attack")
	game.player.position=Vector3(-5.8,0,-2.75)
	game.player.visual.rotation.y=PI
	game.player.restore_stamina(100)
	game.player.begin_attack("heavy")
	await frames(150)
	check(game.player.position.z>-3.15,"Attack momentum respects solid building collision")
	game.player.set_sword_drawn(true)
	game.player.position=Vector3(0,0,10.3)
	game.exit_cooldown=0
	game._process(0)
	await frames(3)
	check(game.map_id=="slime_forest" and game.enemies.size()==1,"Southern coast exit enters Slime Forest with its mob")
	var enemy=game.enemies[0]
	enemy.ai_enabled=false
	game.player.position=Vector3(0,0,-.9)
	game.player.visual.rotation.y=0
	game.player.restore_stamina(100)
	game.player.begin_attack("heavy")
	await frames(150)
	check(enemy.health==15,"Heavy attack deals damage once per swing, including multiple active frames")
	check(game.enemy_bars[0].bar.value==15,"Floating mob health bar follows actual damage")
	game.player.position=Vector3(0,0,enemy.position.z-1.4)
	game.player.restore_stamina(100)
	game.player.begin_attack("light")
	await frames(96)
	check(enemy.health==0 and not enemy.visible and enemy.collision_layer==0,"Light attack can defeat the slime and remove its collision")
	await frames(600)
	check(enemy.health==0,"Slime remains permanently defeated after ten seconds")
	await frames(10)
	check(enemy.health==0 and not enemy.visible and enemy.collision_layer==0,"Defeated slime does not respawn or regain collision")
	game.player.position=enemy.position+Vector3(0,0,1.2)
	game.player.visual.rotation.y=0
	var health_before=enemy.health
	game._attack_contact("light",game.player.facing(),{})
	check(enemy.health==health_before,"Attacks cannot hit a mob behind the player")
	game.load_map("coastal_path")
	var occluded=game.Slime.new()
	occluded.configure({"id":"occluded_test","kind":"slime","at":[-5.8,-4.6]},game.player)
	game.world_root.add_child(occluded)
	occluded.ai_enabled=false
	game.enemies.append(occluded)
	game.player.position=Vector3(-5.8,0,-2.75)
	game.player.visual.rotation.y=PI
	game._attack_contact("light",game.player.facing(),{})
	check(occluded.health==occluded.max_health,"Sword attacks cannot damage a mob through a solid wall")
	game.load_map("coastal_path")
	game.player.position=Vector3(0,0,1)
	game.load_map("slime_forest")
	enemy=game.enemies[0]
	enemy.respawn()
	enemy.ai_enabled=true
	game.player.set_sword_drawn(false)
	game.player.restore_health(100)
	game.player.invulnerability=0
	game.player.position=enemy.position+Vector3(0,0,1)
	await frames(80)
	check(game.player.health==88,"Slime telegraph and lunge damage the player")
	check(game.health_bar.value==88 and game.health_label.text.contains("88"),"Screen health bar follows player damage")
	game.player.invulnerability=.9
	check(not game.player.take_damage(12,Vector3.ZERO),"Hurt invulnerability blocks repeated immediate damage")
	game.player.invulnerability=0
	game.player.take_damage(100,Vector3.ZERO)
	await frames(115)
	check(game.death_screen.visible and game.player.health==0 and game.recovering,"Player defeat opens a death screen and waits for respawn")
	game.respawn_player()
	check(game.map_id=="village_green" and game.player.health==100 and not game.recovering,"Respawn restores health in the village square")
	game.load_map("home_downstairs")
	game.player.position=Vector3(-.1,0,-2.8)
	await frames(3)
	game._process(0)
	game.open_nearest()
	check(game.conversation.visible,"Mother opens the illustrated conversation mode")
	check(game.conversation.choices.get_child_count()>=2,"Mother conversation offers dialogue options")
	var mother=game.dialogue_target.actor
	check(mother.visual.find_child("arm_wrapped",true,false).visible and not mother.visual.find_child("left_arm_human",true,false).visible,"Mother starts with her prosthetic wrapped and no human left forearm")
	game.conversation.reveal_arm()
	check(game.mother_unwrapped and not mother.visual.find_child("arm_wrapped",true,false).visible and mother.visual.find_child("arm_prototype",true,false).visible,"Reveal choice visibly removes the wrap and leaves the prototype arm")
	game.conversation.close()
	await frames(3)
	game.player.restore_health(63)
	game.player.restore_stamina(47.5)
	game.player.set_sword_drawn(true)
	var saved=game.save_data()
	check(game.Save.write(saved,save_path)==OK,"Extended save serializes health, stamina, weapon, and mother flags")
	game.load_map("village_green")
	check(game.apply_save(game.Save.read(save_path)),"Extended save can be applied")
	mother=game.npcs[0]
	check(game.player.health==63 and is_equal_approx(game.player.stamina,47.5) and game.player.sword_drawn and game.mother_unwrapped and not mother.arm_wrapped,"Save restores player health, fractional stamina, drawn weapon, and mother's revealed arm")
	var legacy=saved.duplicate(true)
	for key in ["health","stamina","sword_drawn","mother_unwrapped"]:
		legacy.erase(key)
	check(game.apply_save(legacy) and game.player.health==100 and game.player.stamina==100 and not game.player.sword_drawn and not game.mother_unwrapped,"Existing exploration saves remain compatible with full health and stamina")
	var bad=saved.duplicate(true)
	bad.health=-1
	game.Save.write(bad,save_path)
	check(game.Save.read(save_path).is_empty(),"Malformed saved health is rejected")
	bad=saved.duplicate(true)
	bad.mother_unwrapped="yes"
	game.Save.write(bad,save_path)
	check(game.Save.read(save_path).is_empty(),"Malformed saved story flags are rejected")
	for value in [-1,101,"tired"]:
		bad=saved.duplicate(true)
		bad.stamina=value
		game.Save.write(bad,save_path)
		check(game.Save.read(save_path).is_empty(),"Malformed saved stamina is rejected: "+str(value))
	bad=saved.duplicate(true)
	bad.stamina=0
	game.Save.write(bad,save_path)
	check(not game.Save.read(save_path).is_empty(),"Zero stamina is a valid saved state")
	DirAccess.remove_absolute(save_path)
	game.load_map("slime_forest")
	enemy=game.enemies[0]
	enemy.ai_enabled=false
	enemy.take_damage(60,Vector3.ZERO)
	game.load_map("coastal_path")
	game.load_map("slime_forest")
	check(game.enemies[0].health==0 and not game.enemies[0].visible,"Map travel preserves permanent slime defeat")
	game.player.position=Vector3(0,0,-9.3)
	game.exit_cooldown=0
	await frames(6)
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	check(game.map_id=="coastal_path","Northern forest exit returns to the coast")

func stamina_checks() -> void:
	game.player.configure(game.read_data("res://content/characters/hero.json"))
	game.load_map("coastal_path",Vector2(0,3))
	# Arm mesh setup must settle before counting sprint movement/resource ticks.
	await frames(4)
	game.player.set_sword_drawn(false)
	game.player.restore_stamina(100)
	var shift=InputEventKey.new()
	shift.physical_keycode=KEY_SHIFT
	shift.pressed=true
	Input.parse_input_event(shift)
	Input.flush_buffered_events()
	Input.action_press("move_right")
	await frames(30)
	Input.action_release("move_right")
	shift.pressed=false
	Input.parse_input_event(shift)
	Input.flush_buffered_events()
	check(game.player.position.x>2.15 and game.player.position.x<2.4,"Mapped Shift sprints faster with the sword sheathed")
	check(abs(game.player.stamina-89)<.8,"Sprinting drains stamina with elapsed movement time")
	check(abs(game.stamina_bar.value-game.player.stamina)<.01 and game.stamina_label.text.contains(str(ceili(game.player.stamina))),"Screen stamina bar and label follow the actual resource")
	game.player.set_sword_drawn(true)
	game.player.restore_stamina(100)
	game.player.position=Vector3(0,0,3)
	await frames(1)
	shift.pressed=true
	Input.parse_input_event(shift.duplicate())
	Input.flush_buffered_events()
	Input.action_press("move_right")
	await frames(30)
	Input.action_release("move_right")
	check(game.player.position.x>1.1 and game.player.position.x<1.3 and game.player.sprinting and abs(game.player.stamina-83)<.8,"Drawn sword sprint reaches walking pace and spends more stamina")
	game.player.set_sword_drawn(false)
	game.player.restore_stamina(100)
	await frames(20)
	check(game.player.stamina==100 and not game.player.sprinting,"Holding Shift while standing still does not drain stamina")
	game.player.position=Vector3(0,0,3)
	game.player.restore_stamina(20.2)
	Input.action_press("move_right")
	await frames(60)
	check(game.player.stamina<.001 and game.player.sprint_exhausted and not game.player.sprinting,"Empty stamina falls back to walking and latches sprint exhaustion")
	Input.action_release("move_right")
	game.player.restore_stamina(0)
	game.player.position=Vector3(0,0,3)
	Input.action_press("move_right")
	await frames(40)
	check(game.player.stamina>16 and game.player.stamina<19 and not game.player.sprinting,"Exhausted sprint waits for enough stamina instead of alternating every frame")
	await frames(12)
	check(game.player.sprinting,"Sprint becomes available after its recovery threshold")
	Input.action_release("move_right")
	shift.pressed=false
	Input.parse_input_event(shift.duplicate())
	game.player.restore_stamina(100)
	game.player.spend_stamina(20)
	await frames(30)
	check(game.player.stamina==80,"Stamina regeneration waits through the rest delay")
	await frames(30)
	check(game.player.stamina>83 and game.player.stamina<87,"Stamina regenerates after a short rest")
	await frames(60)
	check(game.player.stamina==100,"Stamina recovery stops at the maximum")
	game.player.set_sword_drawn(true)
	game.player.restore_stamina(19)
	check(not game.player.begin_attack("light") and game.player.state=="free" and game.player.stamina==19,"Unaffordable light swing leaves stamina and action state intact")
	game.player.restore_stamina(35)
	check(not game.player.begin_attack("heavy") and game.player.state=="free" and game.player.stamina==35,"Unaffordable heavy swing leaves stamina and action state intact")
	game.player.restore_stamina(9)
	check(not game.player.begin_parry() and game.player.state=="free","Parry cannot be spammed without enough stamina")
	game.player.restore_stamina(100)
	check(game.player.begin_attack("light") and game.player.stamina==80,"Accepted swing pays its stamina cost once")
	check(game.player.action_transition_remaining>.15,"A melee attack blends out of the current drawn-sword gait")
	check(not game.player.begin_attack("heavy") and game.player.stamina==80,"Rejected overlapping swing does not spend stamina")
	game.toggle_help()
	await frames(5)
	var before=game.player.state_time
	await frames(15)
	check(game.player.state_time==before and game.player.stamina==80,"Help pauses action and stamina clocks")
	game.toggle_help()
	await frames(100)
	game.player.set_sword_drawn(false)
	game.player.restore_stamina(100)
	game.player.position=Vector3(0,0,3)

func prepare_parry_trial(enemy: Node) -> void:
	game.player.set_sword_drawn(true)
	game.player.restore_health(100)
	game.player.restore_stamina(100)
	game.player.invulnerability=0
	game.player.knockback=Vector3.ZERO
	game.player.position=Vector3(0,0,3)
	game.player.visual.rotation.y=0
	enemy.position=Vector3(0,0,3.85)
	enemy.knockback=Vector3.ZERO
	enemy.ai_enabled=false
	enemy.state="idle"
	enemy.lunge_hit=false
	enemy.parry_flash=0

func start_trial_lunge(enemy: Node) -> void:
	enemy.state="lunge"
	enemy.state_time=.34
	enemy.direction=Vector3(0,0,-1)
	enemy.lunge_hit=false
	enemy.ai_enabled=true

func parry_checks() -> void:
	game.load_map("slime_forest")
	var enemy=game.enemies[0]
	enemy.respawn()
	prepare_parry_trial(enemy)
	game.toggle_help()
	await frames(3)
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	check(not game.enemy_bars[0].root.visible,"Enemy health UI hides beneath Help so controls remain readable")
	game.toggle_help()
	await frames(2)
	check(game.player.begin_parry() and game.player.stamina==90,"Parry spends its small fixed stamina cost")
	await frames(14)
	var enemy_start=enemy.position
	start_trial_lunge(enemy)
	await frames(2)
	check(game.player.parry_resolved and game.player.health==100,"Timed forward parry prevents actual slime lunge damage")
	check(enemy.state=="recover" and enemy.knockback.length()>7 and enemy.parry_flash>0,"Successful parry cancels the lunge and starts visible knockback and stun")
	check(enemy.health==enemy.max_health,"Parry repels without dealing sword damage")
	check(not game.player.try_parry(enemy),"A parry window can resolve only once")
	await frames(20)
	check(enemy.position.z>enemy_start.z+1.8 and enemy.state=="recover" and game.player.health==100,"Parried slime moves away and remains staggered without a follow-up hit")
	prepare_parry_trial(enemy)
	game.player.begin_parry()
	start_trial_lunge(enemy)
	await frames(2)
	check(game.player.health==88 and not game.player.parry_resolved,"Contact before the parry window still damages the player")
	prepare_parry_trial(enemy)
	game.player.begin_parry()
	await frames(35)
	start_trial_lunge(enemy)
	await frames(2)
	check(game.player.health==88 and not game.player.parry_resolved,"Contact after the parry window still damages the player")
	prepare_parry_trial(enemy)
	game.player.visual.rotation.y=PI
	game.player.begin_parry()
	await frames(14)
	start_trial_lunge(enemy)
	await frames(2)
	check(game.player.health==88 and not game.player.parry_resolved,"Parry cannot block an enemy behind the girl's facing")
	prepare_parry_trial(enemy)
	game.player.set_sword_drawn(false)
	check(not game.player.begin_parry(),"Sheathed sword cannot parry")
	game.player.set_sword_drawn(true)
	game.player.begin_attack("heavy")
	check(not game.player.begin_parry() and game.player.state=="heavy","Parry cannot cancel a committed heavy swing")
	game.player.set_sword_drawn(false)
	game.player.restore_stamina(100)
	game.player.restore_health(100)
	game.load_map("coastal_path")

func story_checks() -> void:
	game.conversation.close()
	game.dialog.visible=false
	game.help_panel.visible=false
	game.quest_stage="not_started"
	game.defeated_enemies=[]
	game.load_map("home_downstairs",Vector2(-.1,-2.8),true)
	game.player.restore_health(100)
	game.player.restore_stamina(100)
	game.player.set_sword_drawn(false)
	await frames(3)
	game._process(0)
	game.open_nearest()
	check(game.conversation.visible and game.conversation.portrait.texture!=null,"Conversation displays high-resolution Mother artwork")
	var at=game.player.position
	Input.action_press("move_down")
	await frames(12)
	Input.action_release("move_down")
	check(game.player.position.is_equal_approx(at),"Conversation mode pauses world movement")
	game.conversation.accept_quest()
	check(game.quest_stage=="active" and game.conversation.text.text.contains("aether core"),"Mother offers and starts the alchemical core quest")
	game.conversation.close()
	game.load_map("slime_forest",Vector2(0,11.2),true)
	game.exit_cooldown=0
	await frames(3)
	check(game.map_id=="slime_forest","Deeper trail requires defeating the slime")
	game.enemies[0].take_damage(100,Vector3.ZERO)
	game.exit_cooldown=0
	await frames(3)
	check(game.map_id=="herb_glade" and game.enemies.size()==3,"Slime defeat unlocks a pair of boars and the stone warden")
	for enemy in game.enemies:
		enemy.ai_enabled=false
	check(not game.loot_warden_core(),"Core cannot be looted before defeating the warden")
	var boar=game.enemies[0]
	game.player.position=boar.position+Vector3(0,0,-3)
	game.player.state="free"
	game.player.invulnerability=0
	boar.ai_enabled=true
	await frames(4)
	check(boar.state=="windup","Briar boar visibly telegraphs a committed charge")
	await frames(60)
	check(boar.attacks>0 and boar.state=="lunge" and boar.velocity.length()>5,"Briar boar charges rapidly along its committed direction")
	boar.ai_enabled=false
	var second_boar=game.enemies[1]
	check(second_boar.definition.kind=="boar" and not game.enemies.any(func(enemy): return enemy.definition.kind=="wisp"),"Second boar replaces the removed wisp")
	boar.state="idle"
	second_boar.state="idle"
	boar.position=Vector3(-1.2,0,-8)
	second_boar.position=Vector3(1.2,0,-8)
	game.player.position=Vector3(0,0,-11)
	boar.ai_enabled=true
	second_boar.ai_enabled=true
	await frames(4)
	check(boar.state=="windup" and second_boar.state=="windup" and abs(boar.state_time-second_boar.state_time)<.05,"Both boars wind up together when their pack is approached")
	await frames(58)
	check(boar.state=="lunge" and second_boar.state=="lunge","Both boars charge at the same time")
	boar.ai_enabled=false
	second_boar.ai_enabled=false
	var warden=game.enemies[2]
	game.player.position=warden.position+Vector3(0,0,-4)
	game.player.restore_health(100)
	game.player.state="free"
	warden.ai_enabled=true
	await frames(75)
	check(game.projectiles.any(func(item): return is_instance_valid(item)),"Stone warden throws an actual rock after its telegraph")
	warden.ai_enabled=false
	var thrown=game.projectiles.filter(func(item): return is_instance_valid(item))[0]
	var rock_at=thrown.position
	game.help_panel.visible=true
	await frames(12)
	check(thrown.position.is_equal_approx(rock_at),"Thrown rocks pause while menus are open")
	game.help_panel.visible=false
	for item in game.projectiles:
		if is_instance_valid(item):
			item.queue_free()
	game.projectiles.clear()
	await frames(2)
	warden.take_damage(45,Vector3.ZERO)
	check(warden.health==90,"Warden armor resists damage until a reflected rock opens it")
	game.player.position=warden.position+Vector3(0,0,-2)
	game.player.visual.rotation.y=0
	game.player.set_sword_drawn(true)
	game.player.restore_stamina(100)
	await frames(3)
	var rock=load("res://scripts/rock_projectile.gd").new()
	game.world_root.add_child(rock)
	rock.configure(game,warden,Vector3(0,0,-1))
	rock.position=game.player.position+Vector3(0,.7,2.55)
	game.projectiles.append(rock)
	game.player.begin_parry()
	await frames(25)
	check(game.player.parry_resolved and warden.armor_open>0 and game.player.health==100,"Timed parry reflects an actual thrown rock without player damage")
	await frames(20)
	check(warden.armor_open>0 and warden.health==72,"Reflected rock opens warden armor and damages it")
	warden.take_damage(100,Vector3.ZERO)
	for enemy in [game.enemies[0],game.enemies[1]]:
		enemy.take_damage(100,Vector3.ZERO)
	game.player.position=game.warden_remains.position+Vector3(0,0,1)
	check(game.loot_warden_core() and game.quest_stage=="component_ready","Defeating the warden allows looting its alchemical core")
	check(not game.loot_warden_core(),"Core collection is one-time")
	game.player.state="free"
	game.player.restore_health(100)
	var saved=game.save_data()
	var path="user://story-verification-save.json"
	game.Save.write(saved,path)
	game.defeated_enemies=[]
	game.quest_stage="not_started"
	check(game.apply_save(game.Save.read(path)) and game.quest_stage=="component_ready" and game.defeated_enemies.size()==4,"Quest and permanent encounter defeats survive save/load")
	check(game.enemies.all(func(enemy): return enemy.health==0),"Reloaded quest enemies remain defeated")
	game.player.invulnerability=0
	game.player.take_damage(100,Vector3.ZERO)
	await frames(3)
	check(game.death_screen.visible and not game.player.input_enabled,"Death pauses play behind the respawn screen")
	game.respawn_player()
	check(game.map_id=="village_green" and game.player.health==100 and game.player.stamina==100 and game.quest_stage=="component_ready" and game.defeated_enemies.size()==4,"Village respawn preserves the core and defeated enemies")
	game.load_map("home_downstairs",Vector2(-.1,-2.8))
	await frames(3)
	game.open_nearest()
	game.conversation.complete_quest()
	check(game.quest_stage=="completed" and game.player.health==100,"Returning the core to Mother completes the quest")
	for bad_value in ["broken",12]:
		var bad=saved.duplicate(true)
		bad.quest_stage=bad_value
		game.Save.write(bad,path)
		check(game.Save.read(path).is_empty(),"Malformed quest stage is rejected: "+str(bad_value))
	var bad=saved.duplicate(true)
	bad.defeated_enemies=["unknown/enemy"]
	game.Save.write(bad,path)
	check(game.Save.read(path).is_empty(),"Unknown saved enemy IDs are rejected")
	DirAccess.remove_absolute(path)
	game.conversation.close()

func inventory_cast_checks() -> void:
	game.conversation.close()
	game.dialog.visible=false
	game.help_panel.visible=false
	game.load_map("coastal_path",Vector2(0,3))
	game.player.set_sword_equipped(true)
	game.player.restore_stamina(100)
	game.player.set_sword_drawn(true)
	game.toggle_inventory()
	check(game.inventory.visible and not game.player.input_enabled,"Inventory opens and pauses world input")
	game.inventory.toggle_weapon()
	check(not game.player.sword_equipped and not game.player.sword_drawn and not game.player.equipment.visible,"Inventory unequip removes both drawn and stowed sword")
	game.inventory.close()
	await frames(3)
	check(not game.player.toggle_sword() and not game.player.begin_water() and not game.player.begin_parry(),"Unequipped sword cannot be drawn or used for casting/parry")
	var saved=game.save_data()
	var path="user://equipment-verification-save.json"
	game.Save.write(saved,path)
	game.player.set_sword_equipped(true)
	check(game.apply_save(game.Save.read(path)) and not game.player.sword_equipped and not game.player.equipment.visible,"Saved equipment restores an unequipped sword")
	game.toggle_inventory()
	game.inventory.toggle_weapon()
	check(game.player.sword_equipped and game.player.equipment.visible and not game.player.sword_drawn,"Inventory equips the bag's sword onto the back")
	game.inventory.close()
	await frames(3)
	game.player.set_sword_drawn(true)
	game.player.restore_stamina(100)
	game.player.visual.rotation.y=0
	var at=game.player.position
	game.player.begin_water()
	await frames(32)
	check(game.player.position.z>at.z+.3,"Water cast takes a visible sweeping step forward")
	check(game.player.current_clip=="attack_water","Water step uses the authored full-body sweep")
	game.player.set_sword_drawn(true)
	game.player.play_clip("drag_walk_loop",0)
	game.player.animator.seek(game.player.animator.get_animation(game.player.clips.drag_walk_loop).length*.23,true)
	var spine_index=game.player.skeleton.find_bone("spine")
	var lean=absf(game.player.skeleton.get_bone_pose(spine_index).basis.get_euler().x)
	check(lean>.22,"Greatsword walking animation leans her forward into the sword's weight")
	game.player.restore_stamina(100)
	game.player.begin_parry()
	check(game.player.action_transition_remaining>.15,"Parry blends from the current burdensome walking pose")
	await frames(17)
	check(game.player.current_clip=="parry_guard","Parry uses its own braced guard animation")
	var grip=game.player.equipment.global_transform*Vector3(0,.16,0)
	var tip=game.player.sword_tip()
	var blade=tip-grip
	check(tip.x<-.85 and abs(blade.x)>abs(blade.y)*1.1 and abs(blade.x)>abs(blade.z)*1.1,"Parry sweeps the blade around and holds it along her right side, outside her torso")
	game.player.set_sword_drawn(false)
	game.player.position=Vector3(2,0,1.55)
	await frames(3)
	game._process(0)
	game.open_nearest()
	check(game.conversation.visible and game.conversation.target.actor!=null and game.conversation.target.get("role","")!="mother","Friendly villager receives the illustrated conversation mode")
	game.conversation.villager_story()
	check(not game.conversation.text.text.is_empty(),"Villager dialogue choices show that NPC's lines")
	game.conversation.close()
	game.player.set_sword_drawn(true)
	game.player.restore_stamina(100)
	game.player.position=Vector3(0,0,3)
	game.player.visual.rotation.y=0
	Input.action_press("move_down")
	Input.action_press("sprint")
	await frames(14)
	game.player.begin_charge()
	await frames(12)
	check(game.player.current_clip=="attack_heavy" and game.player.sprinting,"Sprint-click immediately moves into heavy anticipation while continuing forward")
	var elapsed=game.player.state_time
	game.player.release_charge("heavy")
	check(game.player.state=="heavy" and game.player.state_time>=elapsed-.02,"Held sprint-click credits anticipation time toward heavy wind-up")
	Input.action_release("move_down")
	Input.action_release("sprint")
	var legacy=saved.duplicate(true)
	legacy.erase("sword_equipped")
	check(game.apply_save(legacy) and game.player.sword_equipped,"Legacy saves default to an equipped sword")
	var bad=saved.duplicate(true)
	bad.sword_equipped="yes"
	game.Save.write(bad,path)
	check(game.Save.read(path).is_empty(),"Malformed saved equipment flag is rejected")
	DirAccess.remove_absolute(path)
