extends RefCounted
class Slope extends Node3D:
	func ground_height(point:Vector3) -> float: return 1.5+point.x*.06+point.z*.12
func run(test:RefCounted) -> void:
	var game=test.game;var actor=game.player
	game.game_mode="beta";game.start_new_game();game.camera_driver.set_mode("first_person")
	game.progression.restore({"tree_version":3,"xp":957383,"learned":["mana","mana_lance","sea_dragon"],"passives":[]});game.apply_skill_stats()
	for enemy in game.enemies: enemy.ai_enabled=false
	actor.set_sword_drawn(true);actor.restore_stamina(100);actor.invulnerability=0;actor.knockback=Vector3.ZERO;actor.set_physics_process(false)
	game.camera_driver.update_first_person(0);game.begin_sea_dragon();var dragon=game.sea_dragon;dragon.set_physics_process(false)
	var hero=actor.get_node("BetaHero");var rig=hero.rig;var max_hand_gap=0.0;var clearance=true;var previous=actor.equipment.global_transform;var max_jump=0.0;var gap_phase=0.0
	for sample in range(49):
		await test.frames(1);actor.state_time=.8*sample/48;actor._physics_process(0);hero.synchronize()
		var weight=smoothstep(0,1,actor.dragon_pose.phase(actor));var grip=lerpf(actor.BetaSwordMotion.GRIP,float(actor.dragon_pose.tuning.right_grip),weight)
		var palm=rig.global_transform*(rig.get_bone_global_pose(rig.find_bone("forearm.R"))*hero.hands.PALM)
		var gap=palm.distance_to(actor.equipment.global_transform*Vector3(0,grip,0))
		# Initial first-person carry uses its previously verified separate view arms.
		# Once the viewpoint transfers (.24s), the observer sees the full body rig.
		if sample/48.0>=.30 and gap>max_hand_gap: max_hand_gap=gap;gap_phase=sample/48.0
		max_jump=maxf(max_jump,previous.origin.distance_to(actor.equipment.global_position));previous=actor.equipment.global_transform
		var rails=actor.blade_segment();var chest=rig.global_transform*(rig.get_bone_global_pose(rig.find_bone("spine")).origin+Vector3(0,.18,0));var head=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("head")).origin
		clearance=clearance and Geometry3D.get_closest_point_to_segment(chest,rails[0],rails[1]).distance_to(chest)>.23 and Geometry3D.get_closest_point_to_segment(head,rails[0],rails[1]).distance_to(head)>.18
	test.check(max_jump<.16,"Sea Dragon planting travels continuously around the right side without a weapon teleport")
	test.check(max_hand_gap<.035,"Actual body palm contact after viewpoint transfer (max %.3f m at phase %.2f)"%[max_hand_gap,gap_phase])
	test.check(clearance,"Sampled planted-sword entry keeps steel clear of the torso and head")
	var grip_closed=not hero.dragon_grips.is_empty()
	for item in hero.dragon_grips: grip_closed=grip_closed and item[0].mesh==item[2] and item[2].blend_shape_mode==Mesh.BLEND_SHAPE_MODE_NORMALIZED and is_equal_approx(item[0].get_blend_shape_value(0),1.0)
	test.check(grip_closed,"Channel closes the supporting hand with a local morph that preserves body proportions")
	var tip=actor.sword_tip();test.check(absf(tip.y-game.current_world.ground_height(tip)-.018)<.005,"The actual steel tip plants on the terrain instead of floating")
	var right_knee=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("shin.R")).origin;var left_knee=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("shin.L")).origin
	test.check(right_knee.y<.23 and left_knee.y>right_knee.y+.16,"Caster lowers one knee and keeps the other raised like the reference")
	var left_palm=rig.global_transform*(rig.get_bone_global_pose(rig.find_bone("forearm.L"))*Vector3(.017,-.30,.012))
	test.check(left_palm.distance_to(left_knee+Vector3(.015,.075,.025).rotated(Vector3.UP,actor.visual.rotation.y))<.04,"Free hand rests on the raised knee")
	var clock=actor.state_time;var held=actor.equipment.global_transform
	game.toggle_pause();actor._physics_process(.3);hero.synchronize()
	test.check(actor.state_time==clock and held.is_equal_approx(actor.equipment.global_transform),"Pause freezes the kneeling pose and planted blade")
	game.pause_menu.close();game._refresh_simulation()
	test.check(actor.take_damage(5,Vector3.ZERO) and actor.state=="dragon_channel" and dragon.active,"Kneeling caster remains vulnerable without stopping nonfatal dragon control")
	var slope=Slope.new();game.world_root.add_child(slope);var old_ground=actor.ground_world;actor.ground_world=slope
	var planted=actor.dragon_pose.plant(actor);var slope_tip=planted*Vector3(0,actor.BetaSwordMotion.TIP,0)
	test.check(absf(slope_tip.y-slope.ground_height(slope_tip)-.018)<.005,"Planted tip follows a sloped ground sample")
	actor.ground_world=old_ground;slope.queue_free()
	dragon.finish(false);test.check(actor.state=="dragon_recover","Dragon exit starts a dedicated stand-and-extract recovery")
	actor.state_time=.325;actor._physics_process(0);hero.synchronize()
	game.camera_driver.update_first_person(0)
	var recovery_clear=not game.camera_driver.visuals.root.visible
	var middle=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("pelvis")).origin
	actor.state_time=.65;actor._physics_process(0);hero.synchronize()
	game.camera_driver.update_first_person(0)
	var grip_restored=true
	for item in hero.dragon_grips: grip_restored=grip_restored and item[0].mesh==item[1]
	test.check(actor.state=="free" and middle.y>.5 and middle.y<.8 and actor.sword_energy_materials.is_empty() and grip_restored and recovery_clear and game.camera_driver.visuals.root.visible,"Recovery raises the body smoothly, keeps view clear and restores controls, hands and steel unlit")
	actor.set_physics_process(true)
