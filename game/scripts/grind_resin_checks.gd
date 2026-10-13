extends RefCounted
func run(test:RefCounted) -> void:
 var game=test.game
 game.start_new_game(false); game.load_map("menagery",Vector2(10,0),true)
 game.player.set_physics_process(false); game.player.position=Vector3(10,0,0); game.player.state="free"; game.player.input_enabled=true
 var costs=[]; var thresholds=game.progression.definition.level_thresholds
 for i in range(1,thresholds.size()): costs.append(int(thresholds[i])-int(thresholds[i-1]))
 var rising=true
 for i in range(1,costs.size()): rising=rising and costs[i]>costs[i-1]
 test.check(thresholds.size()==50 and rising,"All 50 levels have strictly increasing XP requirements")
 game.progression.xp=int(thresholds[-1]); game.progression.learned=[]
 for skill in game.progression.definition.skills:
  for rank in range(int(skill.max_rank)): game.progression.learn(skill.id)
 test.check(game.progression.learned.size()==49 and game.progression.points()==0 and game.Progression.valid(game.progression.snapshot()),"Late-game XP supports 49 purchased ranks without overspending the expanded skill catalog")
 game.progression.restore({"tree_version":2,"xp":8200,"learned":["form","belly_roll"]}); game.apply_skill_stats()
 var resin=game.menagery.spawn("2E"); resin.set_physics_process(false); resin.position=Vector3(10,0,-6); resin.home=resin.position; resin.ai_enabled=true
 resin._release_ability(); var gloop=game.get_tree().get_nodes_in_group("resin_gloop")[-1]; gloop.set_physics_process(false)
 gloop._physics_process(gloop.duration*.5)
 test.check(gloop.position.y>1.8 and game.get_tree().get_nodes_in_group("menagery_effect").filter(func(node): return node.has_method("contains_player")).is_empty(),"Gloop visibly arcs through the air without creating a premature puddle")
 var age=gloop.age; game.toggle_inventory(); gloop._physics_process(.2)
 test.check(gloop.age==age,"Inventory freezes airborne resin gloop")
 game.inventory.close(); game._refresh_simulation(); gloop._physics_process(gloop.duration*.5)
 var patch=game.get_tree().get_nodes_in_group("menagery_effect").filter(func(node): return node.has_method("contains_player"))[-1]; patch.set_physics_process(false)
 test.check(patch.age==0 and patch.producer.get_ref()==resin,"Puddle appears at impact and retains its throwing slime")
 game.player.position=Vector3(patch.position.x,0,patch.position.z); patch._physics_process(.01)
 test.check(resin.state=="resin_charge" and patch.dash_triggered and game.player.terrain_speed_scale()<.5,"Entering resin puddle slows movement and begins the owner's charged dash")
 resin._physics_process(.7); var aim=resin.direction
 resin._physics_process(.2); game.player.position.x+=3; resin._physics_process(.1)
 test.check(resin.direction.is_equal_approx(aim),"Resin dash aim locks before release so a sideways escape works")
 var clock=resin.state_time; game.toggle_pause(); resin._physics_process(.5)
 test.check(resin.state_time==clock,"Pause freezes resin dash charge and its telegraph")
 game.pause_menu.close(); game._refresh_simulation(); resin._physics_process(.3)
 test.check(resin.state=="lunge" and resin.resin_dash_active and not resin.dash_line.visible,"Charged resin dash releases with its ground warning removed")
 var start=resin.position
 for i in range(30):
  await test.frames(1); resin._physics_process(1.0/60)
 test.check(resin.position.distance_to(start)>3.5,"Resin dash actually travels several metres at high speed")
 resin.state="idle"; resin.knockback=Vector3.ZERO; resin.notice_trapped_target(); resin.take_slam_shockwave(Vector3.RIGHT,1,.65)
 test.check(resin.state=="recover" and not resin.notice_trapped_target(),"Sword slam interrupts resin charge and sap cannot cancel its recoil stun")
 game.player.state="free"; game.player.set_sword_drawn(true); game.player.restore_stamina(100); game.player.visual.rotation.y=0; game.player.begin_parry(); game.player.state_time=.3
 resin.position=game.player.position+Vector3(0,0,1); resin.state="lunge"; resin.direction=Vector3.FORWARD; resin.lunge_hit=false; resin._physics_process(.01)
 test.check(resin.state=="recover" and resin.knockback.length()>0,"Timed right-click parry repels the resin dash")
 # Damage lands at early/middle/late roll phases; no roll-generated immunity.
 game.player.slow_sources.clear(); game.player.set_sword_drawn(true)
 for phase in [.1,.5,.9]:
  game.player.state="free"; game.player.restore_stamina(100); game.player.restore_health(100); game.player.invulnerability=0; game.player.begin_roll(); game.player.state_time=game.player.state_duration*phase
  var before=game.player.health; var hit=game.player.take_damage(7,Vector3.ZERO)
  test.check(hit and game.player.health==before-7,"Connecting hit damages the roll at phase "+str(phase))
 game.player.state="free"; game.player.invulnerability=0; game.player.restore_stamina(100); game.player.begin_roll(); game.player.state_time=game.player.state_duration*.5
 resin.position=game.player.position+Vector3(0,0,.6); resin.state="lunge"; resin.lunge_hit=false; resin.direction=Vector3.FORWARD; var actual_before=game.player.health; resin._physics_process(.01)
 test.check(game.player.health==actual_before-int(resin.specimen.damage),"A real enemy lunge damages the character during its roll")
 game.player.state="stand"; game.player.invulnerability=0; var before=game.player.health
 test.check(game.player.take_damage(7,Vector3.ZERO) and game.player.health==before-7,"Connecting hit also damages the stand-up")
 game.player.state="free"; game.player.invulnerability=0; resin.position=Vector3(10,0,-5); game.player.position=Vector3(10,0,1)
 var wall=load("res://scripts/props.gd").collider(game.current_world,Vector3(10,.8,-2),Vector3(4,3,.35)); await test.frames(2)
 var reflected=load("res://scripts/resin_gloop.gd").new(); game.current_world.add_child(reflected); reflected.configure(game,resin,game.player.position); reflected.set_physics_process(false); reflected.position=game.player.position+Vector3.UP*.8; reflected.repel(Vector3.ZERO,0,0)
 var source_health=resin.health; reflected._physics_process(reflected.duration)
 test.check(resin.health==source_health,"Reflected gloop blocked by scenery cannot damage its thrower through a wall")
 wall.queue_free(); game.menagery.clear(); game.player.set_physics_process(true); game.start_new_game(false); game.load_map("coastal_path",Vector2(0,3),true)
