extends SceneTree
class Harness extends RefCounted:
	var game:Node
	var tree:SceneTree
	var checks=0
	var failures=[]
	func check(ok:bool,label:String) -> void:
		checks+=1
		if not ok:failures.append(label);push_error(label)
	func frames(count:int) -> void:
		for i in range(count):await tree.process_frame
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;await process_frame
	game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide();game._refresh_simulation()
	for enemy in game.enemies:enemy.set_physics_process(false)
	var test=Harness.new();test.game=game;test.tree=self
	game.player.set_meta("body_wrist_inspection",true)
	game.camera_driver.set_mode("first_person")
	game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
	# Actual Main cold stowed R input must add visual wrists before carry capture.
	var cold=game.player;var cold_hero=cold.get_node("BetaHero")
	cold.set_sword_drawn(false)
	var draw=InputEventAction.new();draw.action="draw_sword";draw.pressed=true;game._unhandled_key_input(draw)
	test.check(cold.state=="draw","Actual Main R starts cold stowed draw")
	for i in range(200):
		cold._physics_process(1.0/60);cold_hero.synchronize()
		if cold.state=="draw":test.check(cold_hero.carry_transition.size()==cold_hero.rig.get_bone_count(),"Cold draw transition contains every visual wrist "+str(i))
		if cold.state=="free":break
	test.check(cold.state=="free" and cold.sword_drawn,"Cold native draw finishes without missing transition bones")
	# Restored authority transitions contain original bones only; presentation
	# deterministically pads just its two appended wrists before using the array.
	cold.state="draw";cold.state_time=.1;cold.state_duration=1;cold_hero.previous_state="draw"
	cold_hero.carry_transition.resize(cold.skeleton.get_bone_count());cold_hero.synchronize()
	test.check(cold_hero.carry_transition.size()==cold_hero.rig.get_bone_count(),"Authority carry restore pads only added presentation wrists")
	cold.state="free"
	load("res://scripts/grip_checks.gd").new().run(test)
	game.player.set_physics_process(false);game.player.state="free";game.player.set_sword_drawn(true)
	var actor=game.player;var hero=actor.get_node("BetaHero");var driver=game.camera_driver
	var count=hero.rig.get_bone_count();var authority=actor.skeleton.get_bone_count()
	for i in range(8):
		var profile=game.AppearanceProfile.default_profile()
		if i%2==1:profile.face_id="soft_cheeks";profile.body_id="subtle_shape";profile.colors.skin="#A87862"
		game.commit_appearance(profile);driver.set_mode("third_person");actor._pose_sword("drag",0);driver.update_third_person(0)
		var frame=driver.sample_first_person(0,false);var steel=actor.equipment.global_transform
		driver.set_mode("first_person");driver.visuals.rig_id=0;driver.visuals.prepare(actor);driver.update_first_person(0)
		test.check(frame.is_equal_approx(driver.sample_first_person(0,false)) and steel.is_equal_approx(actor.equipment.global_transform),"Appearance/perspective preserves canonical head and steel "+str(i))
		test.check(hero.rig.get_bone_count()==count and actor.skeleton.get_bone_count()==authority,"Appearance/toggle never adds duplicate presentation or authoritative bones "+str(i))
		test.check(hero.hands.body_wrist.prepared.size()==hero.dragon_grips.size(),"Body grip cache remains bounded across approved appearance revisions "+str(i))
		for item in hero.dragon_grips:
			var part=item[0]
			test.check(part.skin.get_bind_count()==part.get_meta("body_grip_original_skin").get_bind_count()+2,"Appearance wrist skin adds exactly two binds "+str(i))
			test.check(part.get_meta("body_grip_original_mesh")==hero.hands.body_wrist.prepared[part.get_instance_id()].source,"Grip refresh preserves current appearance source "+str(i))
		var view=driver.visuals
		for item in hero.dragon_grips:
			var source=item[0]
			if ["hair","crown","eyebrow","eyelash","teeth","tongue","high-poly","denim"].any(func(word):return word in String(source.name).to_lower()):continue
			var original=source.duplicate();original.mesh=source.get_meta("body_grip_original_mesh");original.skin=source.get_meta("body_grip_original_skin")
			var expected=view.arms_mesh(original,hero.rig);original.free()
			var arm=view.rig.get_node_or_null(String(source.name)+"FirstPersonArms")
			if expected.get_surface_count()==0:continue
			test.check(arm!=null,"Preserved source keeps accepted first-person arm surface "+str(i))
			if arm==null:continue
			var extracted=arm.mesh.get_meta("source_mesh")
			var exact=expected.get_surface_count()==extracted.get_surface_count()
			for surface in range(mini(expected.get_surface_count(),extracted.get_surface_count())):
				var a=expected.surface_get_arrays(surface);var b=extracted.surface_get_arrays(surface)
				for field in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS,Mesh.ARRAY_INDEX]:exact=exact and a[field]==b[field]
			test.check(exact,"First-person extraction exactly equals current untouched appearance source "+str(i))
			var bases=source.get_meta("appearance_base_materials",[])
			for surface in range(mini(bases.size(),source.mesh.get_surface_count())):
				var material=source.get_surface_override_material(surface)
				if material is StandardMaterial3D and bases[surface] is StandardMaterial3D and load("res://scripts/character_appearance.gd").material_channel(String(bases[surface].resource_name),String(source.name))=="skin":
					test.check(material.albedo_color.is_equal_approx(bases[surface].albedo_color*Color(profile.colors.skin)),"Approved source skin tint remains independent of grip cache "+str(i))
		test.check(view.rig.get_bone_count()==hero.rig.get_bone_count(),"First-person extraction reuses each wrist once "+str(i))
		for side in ["L","R"]:
			var hand=view.rig.get_bone_global_pose(view.rig.find_bone("view_hand."+side))
			var center=view.palms[side]+Vector3(.009 if side=="R" else -.009,-.018,.012)
			test.check((view.rig.global_transform*(hand*(center-Vector3(0,-.26,0)))).distance_to(view.hand_targets[side])<.003,"Accepted first-person wrist reaches independent live hilt after appearance "+side+str(i))
	# One accepted actor pose must have identical combat anatomy whether its
	# optional visible wrist presentation is enabled or headless/invisible.
	var Hurt=load("res://scripts/player_hurt.gd")
	for weapon in ["standard_greatsword","field_spear","duelist_rapier","hunting_bow"]:
		actor.state="free"
		if weapon not in game.magic_items.owned:game.magic_items.owned.append(weapon)
		test.check(game.magic_items.equip_weapon(weapon),"Actual accepted equipment selected "+weapon);actor.set_sword_equipped(true);actor.set_sword_drawn(true)
		for phase in [0.0,.15,.3,.5,.75,.95]:
			actor.state="light" if weapon=="standard_greatsword" else "weapon_attack";actor.combo_stage=1;actor.state_duration=1;actor.state_time=phase
			actor.play_clip("attack_light" if weapon=="standard_greatsword" else "idle_loop",0)
			actor.animator.seek(phase,true);actor._pose_sword("light" if weapon=="standard_greatsword" else "attack",phase)
			actor.visible=true;actor.set_meta("body_wrist_inspection",true)
			var shown=Hurt.volumes(actor);var accepted=driver.sample_first_person(0,false);var steel=actor.equipment.global_transform
			actor.visible=false;actor.set_meta("body_wrist_inspection",false)
			var hidden=Hurt.volumes(actor)
			var same=shown.size()==hidden.size()
			for j in range(mini(shown.size(),hidden.size())):same=same and shown[j].from.is_equal_approx(hidden[j].from) and shown[j].to.is_equal_approx(hidden[j].to) and shown[j].radius==hidden[j].radius
			test.check(same,"Visible/headless canonical hurt geometry identical "+weapon+" "+str(phase))
			test.check(accepted.is_equal_approx(driver.sample_first_person(0,false)) and steel.is_equal_approx(actor.equipment.global_transform),"Visible/headless preserves canonical head/steel "+weapon+" "+str(phase))
			actor.visible=true;actor.set_meta("body_wrist_inspection",true)
	# Presentation carry history must not become combat anatomy during sheathe,
	# draw reversal or an authority snapshot restoring only original bones.
	actor.state="free";game.magic_items.equip_weapon("standard_greatsword");actor.set_sword_drawn(true)
	for action in ["sheathe","draw"]:
		for phase in [.015,.06,.15,.5]:
			actor.state=action;actor.state_time=phase;actor.state_duration=1;actor.play_clip("sheathe_sword" if action=="sheathe" else "draw_sword",0);actor.animator.seek(phase,true)
			hero.previous_state=action;hero.carry_transition.clear()
			for j in range(hero.rig.get_bone_count()):hero.carry_transition.append(hero.rig.get_bone_pose(j))
			actor.visible=true;actor.set_meta("body_wrist_inspection",true);var native=Hurt.volumes(actor)
			var before=driver.sample_first_person(0,false);var steel=actor.equipment.global_transform
			# Restore different prior shoulder translations, as an invisible server
			# carry snapshot does, with the same authoritative head/body action.
			for side in ["L","R"]:
				var upper=hero.gait.bone(hero,"upper_arm",side);var prior=hero.carry_transition[upper];prior.origin+=Vector3(.2,-.1,.15);hero.carry_transition[upper]=prior
			hero.carry_transition.resize(actor.skeleton.get_bone_count())
			actor.visible=false;actor.set_meta("body_wrist_inspection",false);var authority_volumes=Hurt.volumes(actor)
			var same=native.size()==authority_volumes.size()
			for j in range(mini(native.size(),authority_volumes.size())):same=same and native[j].from.is_equal_approx(authority_volumes[j].from) and native[j].to.is_equal_approx(authority_volumes[j].to) and native[j].radius==authority_volumes[j].radius
			test.check(same,"Carry/reversal/restored short-array hurt anchors ignore presentation translations "+action+str(phase))
			test.check(before.is_equal_approx(driver.sample_first_person(0,false)) and steel.is_equal_approx(actor.equipment.global_transform),"Carry source head/steel unchanged "+action+str(phase))
			actor.visible=true;actor.set_meta("body_wrist_inspection",true)
	game.set_process(false);actor.set_physics_process(false)
	print("VERIFICATION_WRIST_REGRESSION ",JSON.stringify({"checks":test.checks,"failures":test.failures}))
	if game.audio!=null:await game.audio.shutdown_and_drain()
	if game.voice!=null:game.voice.configure_session(false)
	await create_timer(.15).timeout;game.queue_free();await process_frame;await process_frame;quit(0 if test.failures.is_empty() else 1)
