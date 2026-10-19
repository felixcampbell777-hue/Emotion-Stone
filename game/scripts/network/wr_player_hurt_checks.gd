extends SceneTree
const Bridge=preload("res://scripts/network/wr_actor_bridge.gd")
const Hurt=preload("res://scripts/player_hurt.gd")
class FloorContext extends Node:
 var map_id="wr_floor_01"
 var enemies:Array=[]
 var players={}
 var current_world:Node3D
 var world_root:Node3D
var failures=[]
var checks=0
var poses={}
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;await process_frame
 game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide();game._refresh_simulation();game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 for enemy in game.enemies:enemy.ai_enabled=false;enemy.set_physics_process(false)
 var context=FloorContext.new();context.current_world=game.current_world;context.world_root=game.world_root;root.add_child(context)
 var profile={"progression":game.progression.snapshot(),"magic_items":game.magic_items.snapshot(),"heavy_attack":"overhead"}
 var bridge=Bridge.new();root.add_child(bridge);bridge.setup(context,profile,"hurt")
 var collision:CollisionShape3D=bridge.actor.get_child(0)
 var shape=collision.shape;var collision_before=[shape.radius,shape.height,collision.position,bridge.actor.collision_layer,bridge.actor.collision_mask]
 var start=Vector3(0,game.current_world.ground_height(Vector3.ZERO),0);bridge.set_pose(start,0,0)
 var command={"movement":[0,0],"yaw":0,"pitch":0,"buttons":{}}
 for pose in ["standing","draw","attack","roll","jump"]:
  if pose=="draw":bridge.action("draw")
  elif pose=="attack":bridge.actor.set_sword_drawn(true);bridge.action("primary_down");bridge.action("primary_up")
  elif pose=="roll":bridge.actor.state="free";bridge.actor.restore_stamina(bridge.actor.max_stamina);bridge.actor.roll_unlocked=true;check(bridge.action("dodge").ok,"Native unlocked roll accepted")
  elif pose=="jump":bridge.actor.state="free";bridge.action("jump")
  for frame in range(10):bridge.step(1.0/60,command,false)
  var volumes=Hurt.volumes(bridge.actor);var head=volumes[2];var torso=volumes[1];var lower=volumes[0]
  poses[pose]={"state":bridge.actor.state,"head":head.from.y-bridge.actor.global_position.y,"torso_top":torso.to.y+torso.radius-bridge.actor.global_position.y,"movement_top":1.12}
  for volume in volumes:
   var center:Vector3=(volume.from+volume.to)*.5
   var from=center+Vector3.LEFT;var to=center+Vector3.RIGHT
   var contact=Hurt.segment_contact(bridge.actor,from,to)
   check(contact.hit and contact.fraction>=0 and contact.fraction<=1,pose+" "+volume.region+" accepts exact native-pose arrow segment")
   check(contact.normal.length()>.99 and contact.normal.dot(Vector3.LEFT)>0,pose+" "+volume.region+" reports outward entry surface normal")
   check(Hurt.steel_contact(bridge.actor,[from,to],[from,to],.05).hit,pose+" "+volume.region+" accepts actual swept steel rails")
   check(not Hurt.steel_contact(bridge.actor,[from,to],[from,to],.05,func(_point):return false).hit,pose+" "+volume.region+" scenery clearance blocks steel")
  var high:Vector3=head.from+Vector3.UP*(head.radius+.15)
  check(not Hurt.segment_contact(bridge.actor,high+Vector3.LEFT,high+Vector3.RIGHT).hit,pose+" above-head arrow remains a miss")
  check(not Hurt.steel_contact(bridge.actor,[high+Vector3.LEFT,high+Vector3.RIGHT],[],.05).hit,pose+" outside steel remains a miss")
  check(lower.from==bridge.actor.global_position+Vector3.UP*.23 and lower.to==bridge.actor.global_position+Vector3.UP*.89 and lower.radius==.23,pose+" retains full original lower-body damage coverage")
  check(collision_before==[shape.radius,shape.height,collision.position,bridge.actor.collision_layer,bridge.actor.collision_mask],pose+" movement collision unchanged")
  var native_rig=preload("res://scripts/network/wr_view_frame.gd").actor_rig(bridge.actor)
  var native_head=(native_rig.global_transform*native_rig.get_bone_global_pose(native_rig.find_bone("head"))).origin
  check(absf(head.from.distance_to(native_head)-Hurt.HEAD_CENTER)<.000001,pose+" combat skull follows actual visible native head pivot")
 var sphere=Hurt.segment_capsule(Vector3(-1,0,0),Vector3(1,0,0),Vector3.ZERO,Vector3.ZERO,.115)
 check(absf(sphere-.4425)<.000001,"Ray sphere entry fraction is analytical")
 check(Hurt.segment_capsule(Vector3.ZERO,Vector3.RIGHT,Vector3.ZERO,Vector3.UP,.23)==0,"Ray beginning inside body resolves immediately")
 var target=Bridge.new();root.add_child(target);target.setup(context,profile,"remote")
 target.set_pose(start+Vector3.RIGHT*2,0,0);target.step(1.0/60,command,false)
 game.player.entity_id=bridge.actor.entity_id;game.wr_session.connected=true
 game.online_view.remotes["remote"]=target.actor
 bridge.runtime=game
 var candidates=bridge.combat_player_targets(bridge.actor)
 var excluded=bridge.combat_player_exclusions(bridge.actor)
 check(candidates==[target.actor],"Actual main provider excludes visible logical-self duplicate from shadow targets")
 check(bridge.actor.get_rid() in excluded and game.player.get_rid() in excluded,"Actual main provider excludes shadow and visible-self movement RIDs")
 var target_head=Hurt.volumes(target.actor)[2].from
 var ray_from:Vector3=target_head+Vector3.LEFT;var ray_to:Vector3=target_head+Vector3.RIGHT
 var space=target.actor.get_world_3d().direct_space_state
 var native_hit=preload("res://scripts/arrow_ballistics.gd").sweep(space,ray_from,ray_to,excluded,candidates)
 check(not native_hit.is_empty() and native_hit.collider==target.actor and native_hit.player_region=="head","Combined physical query hits actual remote upper head rather than logical self")
 var wall=StaticBody3D.new();wall.collision_layer=1;var wall_shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(.05,.5,.5);wall_shape.shape=box;wall.add_child(wall_shape);context.world_root.add_child(wall);wall.global_position=target_head+Vector3.LEFT*.5
 await physics_frame
 var blocked=preload("res://scripts/arrow_ballistics.gd").sweep(space,ray_from,ray_to,excluded,candidates)
 check(not blocked.is_empty() and blocked.collider==wall,"Scenery before native upper body remains the nearest arrow hit")
 wall.free()
 target.actor.set_sword_drawn(true);target.actor.state="free";target.actor.restore_stamina(target.actor.max_stamina)
 check(target.actor.begin_parry(),"Native remote upper-body parry starts")
 target.actor.state_time=(float(target.actor.combat.parry.active_start)+float(target.actor.combat.parry.active_end))*.5
 var outside=Hurt.segment_contact(target.actor,target_head+Vector3.FORWARD,target_head+Vector3.BACK)
 check(outside.hit and target.actor.try_parry(bridge.actor,outside.point),"Actual outside-body skull contact routes through native parry")
 game.online_view.remotes.clear();game.wr_session.connected=false;target.free();bridge.runtime=context
 if game.audio!=null:check(await game.audio.shutdown_and_drain(),"Audio drain")
 print("PLAYER_HURT_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"poses":poses}))
 bridge.free();game.free();context.free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
