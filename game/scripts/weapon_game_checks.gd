extends SceneTree
## End-to-end new-weapon checks: normal merchant, input, imported heroine, physics and save/floor flow.
const Motion=preload("res://scripts/weapon_motion.gd")
var game:Control
var failures:Array[String]=[]
var checks=0
var render=false
var directory=""
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func frames(count:int) -> void:
 for i in range(count):await physics_frame
func picture(label:String) -> void:
 if not render:return
 game.toast.hide();game.toast_time=0
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(directory.path_join(label+".png"))==OK,"Capture "+label)
func weapon_depth(label:String) -> void:
 var inverse=game.camera.global_transform.affine_inverse()
 var nearest=INF
 var pending:Array=[game.player.weapon_runtime.model]
 while not pending.is_empty():
  var node=pending.pop_back()
  pending.append_array(node.get_children())
  if node is MeshInstance3D and node.is_visible_in_tree():
   var bounds=node.get_aabb()
   for i in range(8):
    var corner=bounds.position+Vector3(bounds.size.x if i&1 else 0,bounds.size.y if i&2 else 0,bounds.size.z if i&4 else 0)
    nearest=minf(nearest,-(inverse*(node.global_transform*corner)).z)
 check(nearest>=.25,label+" active weapon geometry stays at least25cm ahead of eye ("+str(snappedf(nearest,.001))+"m)")
func palms(label:String) -> void:
 weapon_depth(label)
 var h=game.camera_driver.visuals;var targets=game.player.weapon_runtime.hand_targets()
 game.camera_driver.update_first_person()
 for side in ["R","L"]:
  var index=h.rig.find_bone("view_hand."+side)
  if index<0:continue
  var grasp=float(targets.get(side+"_grasp",1))
  var wrist=h.rig.get_bone_global_pose(index)
  var center:Vector3=h.palms[side]+Vector3(.009 if side=="R" else -.009,-.018,.012)*grasp
  var actual=h.rig.global_transform*(wrist*(center-Vector3(0,-.26,0)))
  var gap=actual.distance_to(targets[side])
  check(gap<.018,label+" actual skinned "+side+" palm stays at weapon socket ("+str(snappedf(gap,.001))+"m)")
 var hero=game.player.get_node("BetaHero");hero.synchronize()
 for side in ["R","L"]:
  var lower=hero.rig.find_bone("forearm."+side)
  var body_palm=Vector3(-.017 if side=="R" else .017,-.30,.012)
  var actual:Vector3=hero.rig.global_transform*(hero.rig.get_bone_global_pose(lower)*body_palm)
  var gap=actual.distance_to(targets[side])
  check(gap<.04,label+" observer "+side+" palm reaches real weapon socket ("+str(snappedf(gap,.001))+"m)")
func mouse(pressed:bool) -> void:
 var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=game.world_rect.get_center()
 if pressed:game._unhandled_input(event)
 else:game._input(event)
func equip(id:String) -> void:
 check(game.magic_items.equip_weapon(id),"Normally purchased "+id+" can equip")
 game.player.set_weapon_visual(id);game.player.set_sword_equipped(true);game.apply_skill_stats()
 check(game.player.toggle_sword(),"R draw action accepts "+id)
 await frames(ceili(game.player.state_duration*60)+4)
 check(game.player.sword_drawn and game.player.weapon_runtime.model.visible,"Drawn "+id+" is visible")
 palms(id+" ready")
func observer(label:String) -> void:
 if not render:return
 var actor=game.player;actor.set_physics_process(false)
 var camera=Camera3D.new();game.world_root.add_child(camera);camera.cull_mask=((1<<20)-1)&~(1<<18)
 camera.position=actor.position+Vector3(4.3,2.2,-2.7).rotated(Vector3.UP,game.camera_driver.yaw);camera.look_at(actor.position+Vector3(0,1.0,-1.0).rotated(Vector3.UP,game.camera_driver.yaw));camera.current=true
 await picture(label+"-observer")
 camera.queue_free();game.camera.make_current();actor.set_physics_process(true)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 render="--weapon-render" in OS.get_cmdline_user_args()
 directory=ProjectSettings.globalize_path("res://../output/weapon-review/native")
 if render:DirAccess.make_dir_recursive_absolute(directory)
 root.size=Vector2i(1280,720)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 await frames(3)
 # Fixture calls production input methods explicitly; desktop mouse movement must not steer captures.
 game.set_process_input(false);game.set_process_unhandled_input(false);game.set_process_unhandled_key_input(false)
 game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide();game._refresh_simulation()
 await frames(4)
 for enemy in game.enemies:enemy.ai_enabled=false
 var guild=game.worldrise.guild
 guild.copper=500 # Disposable fixture purse; all item acquisition still uses real merchant checks.
 var merchant=game.current_world.interactions.filter(func(t):return t.get("role","")=="wr_swords")[0]
 game.player.position=merchant.position+Vector3(0,0,1)
 game.conversation.show_character(merchant);game._refresh_simulation()
 for id in ["field_spear","duelist_rapier","hunting_bow"]:
  var before=guild.copper;var cost=int(guild.catalog.recipes.get(id,{}).get("copper",0))
  check(cost>0 and guild.craft(id),"Corin normally sells "+id)
  check(guild.copper==before-cost,"Corin charges authored cost for "+id)
 check(guild.buy_arrows(10) and game.magic_items.quantities.get("wooden_arrows",0)==10,"Corin sells finite arrows through normal purchase")
 await picture("merchant-purchased-weapons")
 game.conversation.close();game._refresh_simulation()
 game.player.position=Vector3.ZERO;game.player.position.y=game.current_world.ground_height(game.player.position)
 game.camera_driver.yaw=PI*.5;game.camera_driver.first_pitch=0;game.camera_driver.update_first_person()
 for id in ["field_spear","duelist_rapier"]:
  await equip(id)
  await picture(id+"-ready")
  var runtime=game.player.weapon_runtime
  var phase=.4;var sampled=Motion.sample(runtime.settings.kind,"attack",phase)
  var segment=Motion.contact_segments(Motion.weapon_transform(runtime.view_frame(),sampled),runtime.settings)
  var contact:Vector3=segment[1]
  var enemy=load("res://scripts/slime.gd").new();game.current_world.add_child(enemy)
  enemy.configure({"id":"weapon_fixture","kind":"slime","at":[contact.x,contact.z]},game.player)
  enemy.position.y=game.current_world.ground_height(enemy.position);enemy.health=500;enemy.max_health=500;enemy.ai_enabled=false
  game.enemies.append(enemy)
  var before=enemy.health;var kills=game.progression.greatsword_kills
  mouse(true);await frames(ceili(float(runtime.settings.duration)*.4*60))
  check(game.player.state=="weapon_attack","Mouse attacks use dedicated "+id+" action")
  palms(id+" thrust")
  await picture(id+"-thrust")
  await observer(id+"-thrust")
  await frames(ceili(float(runtime.settings.duration)*60)+3);mouse(false)
  check(enemy.health<before,"Real "+id+" steel damages low target through normal dispatch")
  check(game.progression.greatsword_kills==kills,"New melee does not award Greatsword kills")
  game.enemies.erase(enemy);enemy.queue_free();game.player.restore_stamina(game.player.max_stamina)
 await equip("hunting_bow")
 # Actual scenery wall creates a deterministic miss with recoverable arrow.
 var wall=StaticBody3D.new();wall.collision_layer=1;game.current_world.add_child(wall)
 wall.position=game.player.position+Vector3(0,1.4,-6).rotated(Vector3.UP,game.camera_driver.yaw);wall.rotation.y=game.camera_driver.yaw
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(5,4,.2);shape.shape=box;wall.add_child(shape)
 var wall_mesh=MeshInstance3D.new();var visible_box=BoxMesh.new();visible_box.size=box.size;wall_mesh.mesh=visible_box
 var stone=StandardMaterial3D.new();stone.albedo_color=Color("#59636b");stone.roughness=.9;wall_mesh.material_override=stone;wall.add_child(wall_mesh)
 await frames(3)
 var count=int(game.magic_items.quantities.wooden_arrows)
 mouse(true);await frames(48)
 check(game.player.state=="bow_draw","Mouse hold retains bow draw past greatsword heavy threshold")
 check(is_instance_valid(game.player.weapon_runtime.preview) and game.player.weapon_runtime.preview.visible,"Live bow displays trajectory preview")
 palms("Bow draw")
 await picture("hunting-bow-draw-trajectory")
 await observer("hunting-bow-draw")
 mouse(false);await frames(65)
 check(int(game.magic_items.quantities.wooden_arrows)==count-1,"Normal bow release consumes exactly one vendor arrow")
 check(game.player.state=="free","Normal bow recovers promptly")
 var arrows=get_nodes_in_group("world_rise_arrow").filter(func(a):return a.recoverable)
 check(not arrows.is_empty(),"Actual missed arrow remains recoverable at wall")
 if not arrows.is_empty():
  game.player.position=Vector3(arrows[0].position.x,0,arrows[0].position.z+1.0);game.player.position.y=game.current_world.ground_height(game.player.position)
  await frames(3)
  check(game.nearest.has("wr_arrow"),"Normal nearby interaction chooses missed arrow")
  var event=InputEventKey.new();event.physical_keycode=KEY_E;event.pressed=true;game._unhandled_key_input(event)
  await frames(2)
  check(int(game.magic_items.quantities.wooden_arrows)==count,"E recovers missed vendor arrow exactly once")
 wall.queue_free()
 game.player.position=Vector3.ZERO;game.player.position.y=game.current_world.ground_height(game.player.position)
 game.player.set_sword_drawn(false);game._refresh_simulation();await frames(3)
 var path="user://weapon-acceptance.json";var saved=game.save_data()
 check(game.Save.write(saved,path)==OK,"New equipped weapon saves through normal serializer")
 var restored=game.Save.read(path)
 check(not restored.is_empty() and restored.magic_items.weapon_id=="hunting_bow","Strict save read preserves equipped bow")
 var invalid=saved.duplicate(true);invalid.magic_items.weapon_id="not_a_catalog_weapon"
 game.Save.write(invalid,path)
 check(game.Save.read(path).is_empty(),"Strict save rejects unknown equipped weapon ID")
 var legacy=restored.magic_items.duplicate(true);legacy.erase("weapon_id")
 var migrated=load("res://scripts/magic_items.gd").new();migrated.restore(legacy)
 check(migrated.weapon_id=="standard_greatsword","Legacy save equipment defaults to unchanged starter greatsword")
 migrated=null
 check(game.apply_save(restored),"Normal loader restores new weapon equipment")
 game.worldrise.flags.append("elder_defeated") # Fixture unlock, without mutating any private character.
 game.player.position=Vector3.ZERO;game.player.position.y=game.current_world.ground_height(game.player.position)
 check(game.worldrise.swamp.travel_floor(2),"Normal arrival travel accepts unlocked Floor Two")
 check(game.magic_items.weapon_id=="hunting_bow" and game.magic_items.quantities.get("wooden_arrows",0)==count,"Floor travel shares weapon and finite ammo")
 check(game.worldrise.swamp.travel_floor(1),"Normal arrival travel returns to Floor One")
 for id in ["standard_greatsword","field_spear","duelist_rapier","hunting_bow"]:
  check(game.magic_items.equip_weapon(id),"Round-trip weapon is owned: "+id)
  game.player.set_weapon_visual(id);game.player.set_sword_equipped(true);game.apply_skill_stats();game.player.set_sword_drawn(true)
  check(game.Save.write(game.save_data(),path)==OK,"Actual "+id+" save writes")
  var round_trip=game.Save.read(path)
  check(not round_trip.is_empty() and game.apply_save(round_trip),"Actual "+id+" save loads through main")
  await frames(2)
  check(game.magic_items.weapon_id==id and game.player.weapon_runtime.item_id==id and game.player.weapon_type==load("res://scripts/weapon_profiles.gd").kind(id),"Loader updates reused Actor's actual "+id+" runtime")
 game.start_new_game(false);game.title_screen.hide();game._refresh_simulation();await frames(2)
 check(game.magic_items.weapon_id=="standard_greatsword" and game.player.weapon_runtime.item_id=="standard_greatsword","Fresh game after bow restores actual starter greatsword")
 check(not game.player.weapon_runtime.enabled(),"Fresh game after bow has no lingering new-weapon runtime")
 DirAccess.remove_absolute(path)
 if game.audio!=null:check(await game.audio.shutdown_and_drain(),"Audio mixer releases playback references before scene teardown")
 print("WEAPON_GAME_CHECKS "+JSON.stringify({"checks":checks,"failures":failures,"rendered":render}))
 game.queue_free()
 await process_frame
 call_deferred("finish",0 if failures.is_empty() else 1)
func finish(code:int) -> void:quit(code)
