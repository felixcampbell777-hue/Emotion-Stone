extends RefCounted
const Packs=preload("res://scripts/world_pack.gd")
func run(test:RefCounted) -> void:
 var game=test.game; var old_directory=Packs.directory
 var main_bytes=FileAccess.get_file_as_bytes("user://save-v1.json") if FileAccess.file_exists("user://save-v1.json") else PackedByteArray()
 Packs.directory="user://world-pack-verification"
 var pack=load("res://scripts/builder_document.gd").example(); pack.id="verification_world"
 pack.maps[0].catalog_enemies=[{"id":"test_slime","code":"1E","at":[9,8]}]
 test.check(Packs.validate(pack).is_empty(),"Standalone world example validates with native scenery and creature")
 test.check(Packs.install(pack)==OK,"Custom world installs atomically outside release files")
 test.check(game.start_world(pack.id),"Installed world launches without code edits")
 await test.frames(2)
 test.check(game.map_id==Packs.runtime_id(pack.id,"meadow") and game.enemies.size()==1,"Runtime loads the custom area and its catalog creature")
 game.world_browser.open(); await test.frames(2)
 test.check(not game.player.input_enabled and not game.enemies[0].simulation_enabled,"Custom world browser freezes player and creature simulation")
 var screen=game.get_viewport_rect().size
 test.check(Rect2(Vector2.ZERO,screen).encloses(game.world_browser.box.get_global_rect()),"World browser panel is centered fully inside the game window")
 var old_size=game.get_window().size; game.get_window().size=Vector2i(960,540); await test.frames(2); game.world_browser._layout()
 test.check(Rect2(Vector2.ZERO,Vector2(960,540)).encloses(game.world_browser.box.get_global_rect()),"World browser remains inside a small window with scrollable controls")
 game.get_window().size=old_size; await test.frames(2); game.world_browser.close()
 var exit=game.current_world.definition.exits[0]
 game.player.position=Vector3(15,0,-11.8); game.exit_cooldown=0; await test.frames(2); game._process(0); game.open_nearest(); await test.frames(2)
 test.check(game.map_id==Packs.runtime_id(pack.id,"cave"),"Custom E doorway actually travels to its linked cave")
 game.load_map(Packs.runtime_id(pack.id,"meadow"),Vector2(15,-11.8),true)
 game.current_world.definition.exits[0].interact=false; game.exit_cooldown=0; game._process(0); await test.frames(2)
 test.check(game.map_id==Packs.runtime_id(pack.id,"cave"),"Custom automatic transition travels on entry without E")
 test.check(Packs.save_path(pack.id)!="user://save-v1.json","Custom world save routing stays separate from the main save")
 var save_path="user://world-pack-test-save.json"
 var wrote=game.Save.write(game.save_data(),save_path); var saved=game.Save.read(save_path)
 test.check(wrote==OK and not saved.is_empty() and game.apply_save(saved),"Private custom-world save roundtrips map and world identity")
 game.load_map(Packs.runtime_id(pack.id,"meadow"),Vector2(0,8),true)
 game.enemies[0].take_damage(99999,Vector3.ZERO)
 test.check(game.world_defeats.size()==1 and game.defeated_enemies.is_empty(),"Custom creature defeat persists without touching story encounter progress")
 game.Save.write(game.save_data(),save_path); saved=game.Save.read(save_path)
 test.check(not saved.is_empty() and game.apply_save(saved) and game.world_defeats.size()==1,"Custom creature defeat ledger restores from a private save")
 game.load_map(Packs.runtime_id(pack.id,"cave"),Vector2(0,5.5),true); game.load_map(Packs.runtime_id(pack.id,"meadow"),Vector2(0,8),true)
 test.check(game.enemies[0].health==0,"Defeated custom creature stays defeated after area travel")
 game.recovering=true; game.respawn_player(); await test.frames(2)
 test.check(game.world_id==pack.id and game.map_id==Packs.runtime_id(pack.id,"meadow"),"Custom-world death respawns at its own start rather than the village")
 var bad=pack.duplicate(true); bad.maps[0].exits[0].target="no_such_area"
 test.check(not Packs.validate(bad).is_empty(),"World validator rejects missing transition destination")
 bad=pack.duplicate(true); bad.maps[0].spawn=[5,0]
 test.check(not Packs.validate(bad).is_empty(),"World validator rejects scenery-blocked spawn")
 bad=pack.duplicate(true); bad.maps[0].exits[0].spawn=[0,6.6]; bad.maps[1].exits[0].interact=false
 test.check(not Packs.validate(bad).is_empty(),"World validator rejects automatic transition loops at landing")
 bad=pack.duplicate(true); bad.maps[0].bounds=[-2,-2,2,2]
 test.check(not Packs.validate(bad).is_empty(),"World validator rejects unusably small boundaries")
 test.check(not Packs.valid_id("../escape") and not Packs.valid_id("con"),"World IDs cannot escape storage or use reserved Windows filenames")
 var after=FileAccess.get_file_as_bytes("user://save-v1.json") if FileAccess.file_exists("user://save-v1.json") else PackedByteArray()
 test.check(main_bytes==after,"Custom installation and private fixture saves leave player main save intact")
 var tiny=load("res://scripts/builder_document.gd").area("tiny"); tiny.bounds=[-6,-6,6,6]; tiny.spawn=[0,0]
 var small_pack={"format":"coastal_world","version":1,"id":"verification_tiny","name":"Tiny","start_map":"tiny","maps":[tiny]}
 Packs.install(small_pack); game.start_world(small_pack.id); game.camera_driver.set_mode("overhead"); game._process(0)
 var inside=true
 for x in [0,game.world_view.size.x]:
  for y in [0,game.world_view.size.y]:
   var origin=game.camera.project_ray_origin(Vector2(x,y)); var ray=game.camera.project_ray_normal(Vector2(x,y)); var at=origin-ray*(origin.y/ray.y)
   inside=inside and game.current_world.bounds.has_point(Vector2(at.x,at.z))
 test.check(inside,"Overhead camera shrinks to fit the minimum editable area without seeing off map")
 DirAccess.remove_absolute(Packs.file_path(small_pack.id))
 pack.maps[0].catalog_enemies=[{"id":"repeat_slime","code":"9E","at":[9,8],"respawn_seconds":10}]
 Packs.install(pack); game.start_world(pack.id); await test.frames(2)
 var point=game.current_world.get_children().filter(func(node): return node.get_script()!=null and node.get_script().resource_path=="res://scripts/mob_respawn.gd")[0]
 point.set_process(false)
 test.check(not point is Node3D and point.get_child_count()==0,"Timed spawn point has no runtime visual, collider or label")
 point._process(12)
 test.check(game.enemies.size()==1 and point.remaining==0,"Respawn clock cannot start while its creature is alive")
 var xp=game.progression.xp
 point.creature.take_damage(99999,Vector3.ZERO)
 var timer_key=point.key
 test.check(point.remaining==10 and game.world_defeats.is_empty() and game.progression.xp>xp,"Death starts countdown and awards XP without marking permanent defeat")
 await test.frames(2)
 test.check(game.enemies.is_empty(),"Dead repeating creature and health bar retire before respawn")
 game.player.input_enabled=false; point._process(5)
 test.check(point.remaining==10,"Menus freeze respawn countdown")
 game.player.input_enabled=true; point._process(3)
 game.Save.write(game.save_data(),save_path); saved=game.Save.read(save_path)
 test.check(not saved.is_empty() and saved.respawn_timers[timer_key]==7,"Private save validates and retains remaining death timer")
 game.load_map(Packs.runtime_id(pack.id,"cave"),Vector2(0,5.5),true)
 game.load_map(Packs.runtime_id(pack.id,"meadow"),Vector2(0,8),true)
 point=game.current_world.get_children().filter(func(node): return node.get_script()!=null and node.get_script().resource_path=="res://scripts/mob_respawn.gd")[0]; point.set_process(false)
 test.check(game.enemies.is_empty() and point.remaining==7,"Area travel cannot bypass a pending respawn timer")
 point._process(6.9); test.check(game.enemies.is_empty(),"Creature stays absent until full death delay expires")
 point._process(.2); test.check(game.enemies.size()==1 and point.creature.health==point.creature.max_health and not game.respawn_timers.has(timer_key),"Timer creates exactly one fresh healthy creature at expiry")
 xp=game.progression.xp; point.creature.take_damage(99999,Vector3.ZERO)
 test.check(game.progression.xp>xp and point.remaining==10,"Each fresh kill grants fixed XP and restarts its timer")
 test.check(game.apply_save(saved) and game.enemies.is_empty() and game.respawn_timers[timer_key]==7,"Loading a pending death timer does not spawn early")
 bad=pack.duplicate(true); bad.maps[0].catalog_enemies[0].respawn_seconds=-1
 test.check(not Packs.validate(bad).is_empty(),"World validator rejects negative respawn delay")
 DirAccess.remove_absolute(save_path); DirAccess.remove_absolute(Packs.file_path(pack.id)); DirAccess.remove_absolute(Packs.directory)
 Packs.directory=old_directory; game.start_new_game(false); game.load_map("coastal_path",Vector2(0,3),true)
