extends SceneTree
## Finds real native steel/body intersections for reproducible normal-input PvP fixtures.
const Bridge=preload("res://scripts/network/wr_actor_bridge.gd")
const Steel=preload("res://scripts/steel_contact.gd")
class FloorContext extends Node:
 var map_id="wr_floor_01"
 var enemies:Array=[]
 var current_world:Node3D
 var world_root:Node3D
func _initialize():call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;await process_frame
 game.game_mode="world_rise";game.start_new_game(false);game.title_screen.hide();game._refresh_simulation();game.set_process(false);game.set_physics_process(false)
 game.player.set_physics_process(false)
 for enemy in game.enemies:enemy.ai_enabled=false;enemy.set_physics_process(false)
 var context=FloorContext.new();context.current_world=game.current_world;context.world_root=game.world_root;root.add_child(context)
 var result={}
 for item in ["standard_greatsword","field_spear","duelist_rapier","hunting_bow"]:
  if item not in game.magic_items.owned:game.magic_items.owned.append(item)
  game.magic_items.weapon_id=item
  if "wooden_arrows" not in game.magic_items.owned:game.magic_items.owned.append("wooden_arrows")
  game.magic_items.quantities["wooden_arrows"]=99
  var profile={"progression":game.progression.snapshot(),"magic_items":game.magic_items.snapshot(),"heavy_attack":"overhead"}
  var hits=[]
  for pitch in [0.0,.3,.6,.9]:
   var bridge=Bridge.new();root.add_child(bridge);bridge.setup(context,profile,"geometry")
   bridge.actor.collision_mask=1|4
   var start=Vector3(0,game.current_world.ground_height(Vector3.ZERO),0);bridge.set_pose(start,0,pitch)
   var command={"movement":[0,0],"yaw":0,"pitch":pitch,"buttons":{}}
   bridge.action("draw")
   for frame in range(110):bridge.step(1.0/60,command,false)
   if pitch==0:
    var rig=preload("res://scripts/network/wr_view_frame.gd").actor_rig(bridge.actor)
    var heights={"physical_top":1.12,"eye":bridge.driver.sample_first_person(0,false).origin.y-start.y}
    for bone in ["head","chest","spine","spine_01","spine_02","pelvis"]:
     var index=rig.find_bone(bone)
     if index>=0:heights[bone]=(rig.global_transform*rig.get_bone_global_pose(index)).origin.y-start.y
    print("PVP_NATIVE_HEIGHT ",item," ",JSON.stringify(heights))
   bridge.action("primary_down")
   for frame in range(23 if item=="hunting_bow" else 3):bridge.step(1.0/60,command,false)
   var release=bridge.action("primary_up")
   if item=="hunting_bow" and release.get("ok",false):
    var shot=release.shot;var pos=shot.origin;var velocity=preload("res://scripts/arrow_ballistics.gd").velocity(shot.direction,shot.charge,shot.settings)
    for frame in range(60):
     var next=preload("res://scripts/arrow_ballistics.gd").advance(pos,velocity,1.0/60,float(shot.settings.gravity))
     sample(hits,[pos,next.position],[pos,next.position],start,pitch,frame/60.0,.0)
     pos=next.position;velocity=next.velocity
   else:
    for frame in range(110):
     bridge.step(1.0/60,command,false)
     if bridge.contact_active:
      var margin=float(bridge.actor.weapon_runtime.settings.radius) if bridge.actor.weapon_runtime.enabled() else .05
      sample(hits,bridge.accepted_steel,bridge.previous_steel,start,pitch,frame/60.0,margin)
   bridge.free()
  hits.sort_custom(func(a,b):return absf(a.lateral)+absf(a.distance-2.0)*.1+a.pitch*.01<absf(b.lateral)+absf(b.distance-2.0)*.1+b.pitch*.01)
  result[item]={"count":hits.size(),"best":hits.slice(0,8)}
 if game.audio!=null:await game.audio.shutdown_and_drain()
 print("PVP_GEOMETRY ",JSON.stringify(result))
 game.free();context.free();await process_frame;await process_frame;quit()
func sample(hits:Array,current:Array,previous:Array,start:Vector3,pitch:float,clock:float,margin:float):
 for distance_index in range(2,17):
  var distance=distance_index*.25
  for lateral_index in range(-4,5):
   var lateral=lateral_index*.25
   if Steel.capsule(current,previous,start+Vector3(lateral,0,-distance),.23,1.12,margin).hit:
    hits.append({"pitch":pitch,"distance":distance,"lateral":lateral,"clock":clock})
