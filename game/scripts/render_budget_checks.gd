extends RefCounted
func run(test:RefCounted) -> void:
	var g=test.game;var b=g.render_budget
	g.title_screen.hide();g.game_mode="world_rise";g.start_new_game(false);g.set_process(false);g.player.set_physics_process(false)
	var world=g.current_world;var position=g.player.position;var ground=world.ground_height(position)
	b.focused=true;b.select_fps(60,false)
	test.check(Engine.max_fps==60,"Rendering defaults to a real 60 FPS cap")
	b.select_fps(0,false);test.check(Engine.max_fps==60,"Uncapped FPS requests are rejected")
	b.focused=false;b.apply_frame_cap();test.check(Engine.max_fps==15,"Unfocused rendering is limited to 15 FPS")
	b.focused=true;b.select_fps(90,false);test.check(Engine.max_fps==90,"Selectable higher frame cap remains bounded")
	b.select_fps(60,false);b.select_quality("balanced",false);g.set_resolution(0)
	test.check(g.world_view.msaa_3d==Viewport.MSAA_2X and g.world_view.mesh_lod_threshold==2.5,"Balanced native rendering uses 2x AA and earlier mesh LOD")
	for i in range(80):world.update_details(position)
	b.update_scenery()
	var chunk_count=world.loaded_chunks.size();var scene_meshes=g.get_tree().get_nodes_in_group("budget_scenery")
	test.check(not scene_meshes.is_empty(),"Actual environment scenery participates in render distance tiers")
	var valid=true
	for mesh in scene_meshes:
		if mesh.get_meta("budget_kind","")=="skyline":valid=valid and mesh.visibility_range_end==250
	test.check(valid,"Distant simplified tree crowns have a finite 250m range")
	var near=MeshInstance3D.new();near.mesh=BoxMesh.new();g.world_root.add_child(near);near.add_to_group("budget_scenery");near.global_position=g.player.global_position+Vector3.RIGHT*10
	var far=MeshInstance3D.new();far.mesh=BoxMesh.new();g.world_root.add_child(far);far.add_to_group("budget_scenery");far.global_position=g.player.global_position+Vector3.RIGHT*65
	b.update_scenery()
	test.check(near.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON and far.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and far.lod_bias<near.lod_bias,"Near scenery keeps shadows; far scenery uses lower detail without shadow passes")
	b.select_quality("low",false);for i in range(80):world.update_details(position)
	test.check(world.loaded_chunks.size()<=chunk_count and world.render_profile.load==76,"Low detail reduces loaded scenery radius without reducing actor activation")
	test.check(is_equal_approx(g.world_view.scaling_3d_scale,.77) and g.world_view.msaa_3d==Viewport.MSAA_DISABLED,"Low offers upscaled 3D without shrinking menu text")
	test.check(world.ground_height(position)==ground and world.safe_position(position) and g.player.position==position,"Graphics changes preserve terrain support, collision safety and player location")
	b.select_quality("high",false);test.check(g.world_view.msaa_3d==Viewport.MSAA_4X and world.render_profile.detail==110,"High restores longer scenery range with bounded 4x AA")
	b.select_quality("balanced",false);g.pause_menu.open()
	test.check(g.pause_menu.performance_quality.selected==1 and g.pause_menu.frame_limit.selected==1 and not g.player.input_enabled,"Pause exposes budget/FPS settings while preserving simulation gating")
	g.pause_menu.close();near.free();far.free();b.select_quality("balanced",false);b.select_fps(60,false)
