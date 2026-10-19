extends SceneTree
## Actual main/Actor regression fixture. Always run with disposable user data.
## Transport is replaced with a request recorder; real ENet/voice acceptance is separate.
class ShockTarget extends Node3D:
 var health=100
 var impacts=0
 func take_slam_shockwave(_away:Vector3,_strength:float,_duration:float) -> void:impacts+=1
class SessionFixture extends Node:
 var active=false
 var commands=[]
 func online_session_active() -> bool:return active
 func request_action(kind:String,payload:Dictionary={}) -> void:commands.append([kind,payload])
var failures=[]
var count=0
func check(ok:bool,label:String) -> void:
 count+=1
 print("REVIEW_CHECK ",label," ",ok)
 if not ok:failures.append(label)
func _initialize() -> void:
 create_timer(45).timeout.connect(func():push_error("Integration review watchdog");quit(2))
 call_deferred("run")
func key(action:String,pressed:bool) -> InputEventAction:
 var event=InputEventAction.new();event.action=action;event.pressed=pressed;return event
func hardware_key(game:Node,code:int,pressed:bool) -> void:
 var event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed;game._input(event)
func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 await process_frame;await process_frame
 game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide();game._refresh_simulation()
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 for enemy in game.enemies:enemy.simulation_enabled=false;enemy.set_physics_process(false)
 var actor=game.player
 game.magic_items.owned.append_array(["hunting_bow","field_spear","wooden_arrows"]);game.magic_items.quantities.wooden_arrows=5
 game.magic_items.equip_weapon("hunting_bow");actor.set_sword_equipped(true);actor.set_sword_drawn(true);actor.restore_stamina(actor.max_stamina)
 game._unhandled_key_input(key("heavy_attack",true));check(actor.state=="bow_draw","K starts actual bow draw")
 actor.state_time=.8;game._input(key("heavy_attack",false))
 check(actor.state=="weapon_recovery" and game.magic_items.quantities.wooden_arrows==4,"K release fires exactly one arrow")
 actor.weapon_runtime.cancel();actor.restore_stamina(actor.max_stamina)
 game._unhandled_key_input(key("light_attack",true));actor.state_time=.8;game._input(key("light_attack",false))
 check(actor.state=="weapon_recovery" and game.magic_items.quantities.wooden_arrows==3,"J release fires exactly one arrow")
 actor.weapon_runtime.cancel();actor.set_sword_equipped(false)
 check(not actor.weapon_runtime.model.visible,"Unequip hides actual runtime model")
 actor.set_sword_equipped(true);actor.set_sword_drawn(true);actor.set_sword_drawn(false)
 check(actor.weapon_runtime.model.global_transform.is_equal_approx(actor.weapon_runtime.carry_transform()),"Stow restores actual carry transform")
 actor.set_sword_drawn(true)
 var appearance=game.AppearanceProfile.default_profile();appearance.colors.skin="#C49A80";game.commit_appearance(appearance)
 var meshes=actor.weapon_runtime.model.find_children("*","MeshInstance3D",true,false)
 check(not meshes.is_empty() and meshes.all(func(mesh):return (mesh.layers & game.camera.cull_mask)!=0),"Appearance keeps runtime weapon on visible camera layers")
 var old_interactions=game.current_world.interactions;game.current_world.interactions=[]
 var arrow=load("res://scripts/physical_arrow.gd").new();game.current_world.add_child(arrow)
 arrow.configure(game,actor,actor.global_position+Vector3(.6,.2,0),Vector3.FORWARD,actor.weapon_runtime.settings,{})
 arrow.grounded=true;arrow.recoverable=true;arrow.set_physics_process(false);actor.set_sword_drawn(false)
 game._process(0)
 check(game.nearest.get("wr_arrow")==arrow,"Normal nearest interaction selects recoverable arrow")
 var ammo=int(game.magic_items.quantities.wooden_arrows);game.open_nearest()
 check(game.magic_items.quantities.wooden_arrows==ammo+1 and not arrow.recoverable,"Normal E interaction recovers one arrow")
 game.current_world.interactions=old_interactions;game.inventory.close();game.conversation.close();game.dialog.hide();game._refresh_simulation()
 for weapon in ["standard_greatsword","field_spear","duelist_rapier","hunting_bow"]:
  if weapon not in game.magic_items.owned:game.magic_items.owned.append(weapon)
  game.magic_items.equip_weapon(weapon);actor.set_sword_equipped(true);actor.set_sword_drawn(true)
  actor._pose_sword("drag",0);game.camera_driver.sample_first_person(0,false)
  if weapon=="standard_greatsword":check(not actor.weapon_runtime.enabled(),"Actual greatsword camera sample remains legacy")
  else:check(actor.weapon_runtime.model.visible and not actor.weapon_runtime.hand_targets().is_empty(),"Actual "+weapon+" camera and rig draw remains finite")
 var fixture=SessionFixture.new();root.add_child(fixture);game.network_session=fixture;game.wr_session=fixture
 var offline=game.save_data();check(game.Save.write(offline,game.current_save_path())==OK,"Disposable offline save written")
 var path=game.current_save_path();var saved_hash=FileAccess.get_file_as_string(path).sha256_text()
 fixture.active=true;game._refresh_simulation();actor.state="free";actor.position.x+=1.25
 var position=actor.position
 game._unhandled_key_input(key("load_game",true))
 check(actor.position.is_equal_approx(position),"Online F9 preserves live actor instead of loading offline save")
 game._unhandled_key_input(key("save_game",true))
 check(FileAccess.get_file_as_string(path).sha256_text()==saved_hash,"Online F5 never overwrites offline save")
 actor.set_sword_drawn(true);actor.restore_stamina(actor.max_stamina);check(actor.weapon_runtime.begin_primary(),"Online fixture begins actual bow draw")
 actor.state_time=.4;var runtime_model=actor.weapon_runtime.model
 actor.set_meta("online_weapon",game.magic_items.weapon_id)
 var profile={"progression":game.progression.snapshot(),"magic_items":game.magic_items.snapshot(),"copper":1,"materials":{},"appearance":game.appearance}
 game.apply_online_profile(profile)
 check(actor.state=="bow_draw" and actor.weapon_runtime.model==runtime_model,"Ammo/economy profile update preserves draw/model")
 var remote=game.Actor.new();remote.configure(game.read_data("res://content/characters/hero.json"));game.world_root.add_child(remote);remote.controllable=true;remote.set_physics_process(false);remote.set_process_input(false)
 remote.weapon_runtime=load("res://scripts/weapon_runtime.gd").new();remote.weapon_runtime.configure(game,remote);game.apply_character_art(remote)
 var public_appearance=game.AppearanceProfile.default_profile();public_appearance.colors.hair="#845A46"
 var state={"position":[10,0,10],"velocity":[0,0,0],"max_health":100,"max_stamina":100,"health":100,"stamina":100,"sword_equipped":true,"sword_drawn":true,"yaw":0.0,"action":"light","action_phase":.4,"action_clock":.4,"duration":1.0,"action_id":"review-action","combo":1,"appearance":public_appearance}
 for weapon in ["standard_greatsword","field_spear","duelist_rapier","hunting_bow"]:
  state.weapon=weapon;state.action_id="review-"+weapon;state.action="fire" if weapon=="hunting_bow" else "light";state.sword_drawn=true
  game.online_view.apply_actor(remote,state,false)
  check(remote.weapon_type==load("res://scripts/weapon_profiles.gd").kind(weapon) and (not remote.weapon_runtime.enabled() or remote.weapon_runtime.model.visible),"Authoritative observer renders "+weapon)
  if remote.weapon_runtime.enabled():
   state.sword_drawn=false;state.action="free";state.action_phase=0;state.action_clock=0;game.online_view.apply_actor(remote,state,false)
   check(remote.weapon_runtime.model.global_transform.is_equal_approx(remote.weapon_runtime.carry_transform()),"Authoritative observer stows "+weapon)
 check(remote.get_meta("appearance_profile")==public_appearance,"Observer uses remote public appearance")
 state.weapon="standard_greatsword";state.action="light";state.sword_drawn=true;state.action_id="review-local-accepted";state.action_phase=.3;state.action_clock=.3
 game.online_view.apply_actor(actor,state,true)
 check(actor.current_clip=="attack_light" and actor.state=="light","Local accepted greatsword action selects attacking body clip")
 state.weapon="field_spear";state.action="sheathe";state.sword_drawn=false;state.action_id="review-network-stow";game.online_view.apply_actor(remote,state,false)
 check(remote.state=="sheathe" and remote.current_clip=="sheathe_sword","Online R stow selects reverse authored transition")
 var health=actor.health;actor.drown();check(actor.health==health,"Online client immersion cannot independently kill actor")
 var shock_target=ShockTarget.new();game.current_world.add_child(shock_target);shock_target.global_position=actor.global_position+Vector3(.1,0,0)
 var old_enemies=game.enemies;game.enemies=[shock_target]
 var slam=load("res://scripts/ground_slam.gd").new();game.current_world.add_child(slam);slam.configure(game,actor.global_position,true);slam._physics_process(.1)
 check(shock_target.impacts==0,"Online cosmetic ground slam cannot stun client enemy mirrors")
 game.enemies=old_enemies
 actor.state="free";game._refresh_simulation();fixture.commands.clear()
 for code in [KEY_J,KEY_K]:
  hardware_key(game,code,true);hardware_key(game,code,false)
 check(fixture.commands.map(func(command):return command[0])==["primary_down","primary_up","primary_down","primary_up"],"Real J/K key edges route exactly once to authority")
 fixture.commands.clear();hardware_key(game,KEY_T,true);hardware_key(game,KEY_T,false)
 check(fixture.commands.map(func(command):return command[0])==["dash_charge","dash_release"],"Real T key edges preserve charge/release")
 fixture.commands.clear();hardware_key(game,KEY_SHIFT,true);hardware_key(game,KEY_SHIFT,false)
 check(fixture.commands.map(func(command):return command[0])==["shift_down","shift_up"],"Real Shift key edges preserve sprint/tap distinction")
 fixture.commands.clear()
 for code in [KEY_R,KEY_SPACE,KEY_CTRL]:hardware_key(game,code,true);hardware_key(game,code,false)
 check(fixture.commands.map(func(command):return command[0])==["draw","jump","dodge"],"Real R/Space/Ctrl route action requests once")
 fixture.commands.clear();actor.state="dash_charge";hardware_key(game,KEY_J,true);hardware_key(game,KEY_J,false)
 check(fixture.commands.map(func(command):return command[0])==["dash_attack","primary_up"],"Dash charge retains queued attack key semantics")
 actor.state="free";fixture.commands.clear();hardware_key(game,KEY_F,true)
 check(fixture.commands.map(func(command):return command[0])==["cancel","parry"],"Real defense key cancels pending input then parries")
 fixture.commands.clear();hardware_key(game,KEY_J,true);game.inventory.visible=true;game._refresh_simulation()
 check(fixture.commands.map(func(command):return command[0])==["primary_down","cancel"],"Opening online inventory cancels pending primary exactly once")
 for overlay in [game.inventory,game.pause_menu,game.appearance_menu,game.connection_menu,game.settings_menu]:
  game.inventory.visible=false;overlay.visible=true;game._refresh_simulation();fixture.commands.clear()
  for code in [KEY_J,KEY_K,KEY_T,KEY_SHIFT,KEY_R,KEY_SPACE,KEY_CTRL,KEY_F]:hardware_key(game,code,true);hardware_key(game,code,false)
  check(fixture.commands.is_empty(),"Online "+String(overlay.get_script().resource_path.get_file())+" blocks gameplay key requests")
  overlay.visible=false
 game._refresh_simulation();fixture.commands.clear();hardware_key(game,KEY_J,true);game._cancel_mouse_charge()
 check(fixture.commands.map(func(command):return command[0])==["primary_down","cancel"],"Focus cancellation sends authority cancel")
 print("WORLD_RISE_ONLINE_INPUT_CHECKS ",count," checks; failures=",failures)
 if game.audio!=null:game.audio.shutdown()
 if game.voice!=null:game.voice.configure_session(false)
 await create_timer(.15).timeout
 game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
