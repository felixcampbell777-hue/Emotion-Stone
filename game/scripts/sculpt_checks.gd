extends RefCounted
const Packs=preload("res://scripts/world_pack.gd")
func run(test:RefCounted) -> void:
 var game=test.game; var old_directory=Packs.directory; Packs.directory="user://sculpt-verification"
 var pack=load("res://scripts/builder_document.gd").example(); pack.id="sculpt_test"
 pack.maps[0].props=[]; pack.maps[0].sculpted_terrain=[{"id":"hill","at":[-10,0],"height":2,"radius":4,"profile":"smooth","rotation":0},{"id":"bluff","at":[0,0],"height":3,"radius":4,"profile":"bluff","rotation":0},{"id":"ledge","at":[10,0],"height":3,"radius":4,"profile":"overhang","rotation":0}]
 test.check(Packs.validate(pack).is_empty(),"Smooth, bluff and overhang terrain validates as a portable world")
 Packs.install(pack); game.start_world(pack.id); await test.frames(2)
 var world=game.current_world
 test.check(is_equal_approx(world.ground_height(Vector3(-10,0,0)),2),"Sculpted smooth mound has authored height")
 test.check(world.ground_step_allowed(Vector3(-10,0,3),Vector3(-10,0,2.9)),"Smooth slope permits grounded walking")
 test.check(not world.ground_step_allowed(Vector3(4.3,3,-2),Vector3(3.8,3,-2)),"Bluff side blocks movement across a steep rise")
 test.check(world.ground_step_allowed(Vector3(0,0,3),Vector3(0,0,2.9)),"Bluff's south ramp remains walkable")
 test.check(is_zero_approx(world.ground_height(Vector3(10,0,-3))) and is_equal_approx(world.ground_height(Vector3(10,3,-3)),3),"Overhang supplies distinct ground below and walkable ledge above")
 game.player.position=Vector3(10,0,-4.8); Input.action_press("move_down"); game.camera_driver.set_mode("overhead")
 await test.frames(55); Input.action_release("move_down")
 test.check(game.player.position.z> -3.4 and is_zero_approx(game.player.position.y),"Character walks underneath the overhang without snapping onto its roof")
 game.player.position=Vector3(10,3,-2.5)
 var save="user://sculpt-private-save.json"; game.Save.write(game.save_data(),save); var data=game.Save.read(save)
 test.check(not data.is_empty() and game.apply_save(data) and is_equal_approx(game.player.position.y,3),"Private save restores the upper overhang walking layer")
 pack.maps[0].sculpted_terrain[0].height=-2; Packs.install(pack); game.load_map(Packs.runtime_id(pack.id,"meadow"),Vector2(0,8),true)
 test.check(is_equal_approx(game.current_world.ground_height(Vector3(-10,0,0)),-2) and is_equal_approx(game.current_world.ground_height(Vector3(0,0,0)),3),"Lowering creates a hollow without flattening a separate raised bluff")
 pack.maps[0].sculpted_terrain[1].plateau_width=12; pack.maps[0].sculpted_terrain[1].plateau_depth=8
 pack.maps[0].sculpted_terrain[2].plateau_width=10; pack.maps[0].sculpted_terrain[2].plateau_depth=8
 test.check(Packs.validate(pack).is_empty(),"Extended plateau dimensions validate without changing legacy default terrain")
 Packs.install(pack); game.load_map(Packs.runtime_id(pack.id,"meadow"),Vector2(0,8),true)
 test.check(is_equal_approx(game.current_world.ground_height(Vector3(5,0,-7)),3) and is_equal_approx(game.current_world.ground_height(Vector3(0,0,3)),.75),"Extended bluff adds a broad flat top while preserving its original walk-up slope")
 test.check(is_zero_approx(game.current_world.ground_height(Vector3(10,0,-7))) and is_equal_approx(game.current_world.ground_height(Vector3(10,3,-7)),3),"Extended overhang preserves ground below its enlarged ledge")
 game.Save.write(game.save_data(),save); data=game.Save.read(save)
 test.check(not data.is_empty() and game.apply_save(data) and game.current_world.definition.sculpted_terrain[1].plateau_depth==8,"Extended plateau world remains playable after private save/load")
 var bad=pack.duplicate(true); bad.maps[0].sculpted_terrain[0].height=INF
 test.check(not Packs.validate(bad).is_empty(),"Sculpt validator rejects nonfinite height")
 bad=pack.duplicate(true); bad.maps[0].sculpted_terrain[2].height=1
 test.check(not Packs.validate(bad).is_empty(),"Sculpt validator rejects a ledge without head clearance")
 DirAccess.remove_absolute(save); DirAccess.remove_absolute(Packs.file_path(pack.id)); DirAccess.remove_absolute(Packs.directory)
 Packs.directory=old_directory; game.start_new_game(false); game.load_map("coastal_path",Vector2(0,3),true)
