extends SceneTree
## Compare the complete real Actor restore with a supplied previous implementation.
## Invoke only with disposable userdata; legacy script is temporary fixture input.
const Pose=preload("res://scripts/network/wr_actor_pose.gd")
var failures:Array=[]
var checks=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func run() -> void:
 var legacy_path=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--legacy="):legacy_path=arg.trim_prefix("--legacy=")
 if legacy_path.is_empty():push_error("Supply temporary previous Actor pose script with --legacy=res://...");quit(2);return
 var legacy=load(legacy_path)
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;await process_frame
 game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide();game._refresh_simulation();game.set_process(false);game.set_physics_process(false)
 for enemy in game.enemies:enemy.set_physics_process(false)
 var actor=game.player;actor.set_physics_process(false);actor.get_node("BetaHero").set_process(false)
 var samples={};var native_bones=actor.skeleton.get_bone_count()
 for item in ["standard_greatsword","field_spear","duelist_rapier","hunting_bow"]:
  if item not in game.magic_items.owned:game.magic_items.owned.append(item)
  if "wooden_arrows" not in game.magic_items.owned:game.magic_items.owned.append("wooden_arrows")
  game.magic_items.quantities.wooden_arrows=30;game.magic_items.weapon_id=item;actor.set_weapon_visual(item);game.apply_skill_stats();actor.set_sword_drawn(true)
  var state=Pose.snapshot(actor)
  check(state==legacy.snapshot(actor),item+" serialized payload is identical")
  for frame in range(8):
   if frame==0:
    if item=="standard_greatsword":actor.begin_attack("light")
    else:actor.weapon_runtime.begin_primary()
   actor._physics_process(1.0/60);actor.get_node("BetaHero").synchronize(1.0/60)
   state=legacy.snapshot(actor)
   legacy.apply(actor,state);var expected=legacy.snapshot(actor)
   Pose.apply(actor,state);check(legacy.snapshot(actor)==expected,item+" complete native/action/weapon restore parity "+str(frame))
  var invalid=state.duplicate(true);invalid["health"]=-900;invalid["not_an_actor_field"]=true;invalid["shift_clock"]="invalid";invalid["attack_direction"]=[1,2];invalid["action_event_index"]=12.75
  legacy.apply(actor,invalid);var expected=legacy.snapshot(actor);var health=actor.health
  Pose.apply(actor,state);Pose.apply(actor,invalid)
  check(legacy.snapshot(actor)==expected and actor.health==health,item+" rejected unknown/wrong-type values and accepted numeric coercion retain parity")
  var timings={"legacy":[],"optimized":[]}
  for iteration in range(140):
   # Alternate first runner to reduce ordering/thermal bias.
   for mode in ["legacy","optimized"] if iteration%2==0 else ["optimized","legacy"]:
    var start=Time.get_ticks_usec()
    if mode=="legacy":legacy.apply(actor,state)
    else:Pose.apply(actor,state)
    timings[mode].append(Time.get_ticks_usec()-start)
  var mode_samples={}
  for mode in timings:
   timings[mode].sort();mode_samples[mode]={"median_usec":timings[mode][70],"p95_usec":timings[mode][133]}
  samples[item]=mode_samples
 if game.audio!=null:check(await game.audio.shutdown_and_drain(),"Audio refs drain before pose fixture exit")
 var report={"checks":checks,"failures":failures,"native_bones":native_bones,"samples":samples,"scope":"Godot4.5.1 headless real Main Actor complete pose restore; isolated CPU dispatch, not client FPS/server capacity"}
 var destination=ProjectSettings.globalize_path("res://").path_join("../output/verification/actor-pose-performance-current.json").simplify_path()
 DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
 var file=FileAccess.open(destination,FileAccess.WRITE)
 if file!=null:file.store_string(JSON.stringify(report,"\t"));file.close()
 print(JSON.stringify(report));game.free();await process_frame;quit(1 if not failures.is_empty() else 0)
