extends RefCounted
const Fen=preload("res://scripts/swamp_shape.gd")
func run(g:Node,review:RefCounted) -> void:
	var campaign=g.worldrise.swamp;var guild=g.worldrise.guild
	var giants=Fen.spec.enemies.filter(func(e):return e.style=="giant_green_slime");var sticky=Fen.spec.enemies.filter(func(e):return e.style=="resin_slime")
	review.check(giants.size()==7 and sticky.size()==1 and sticky[0].id=="sticky_d10","Seven giant slimes and one sticky D10 support slime populate Floor Two")
	var placement=giants[0];g.player.position=Vector3(placement.at[0]+5,.85,placement.at[1]);campaign.spawn(placement)
	var giant=campaign.live[placement.id];giant.set_physics_process(false);giant.ai_enabled=true;giant.simulation_enabled=true
	review.check(giant.max_health==128 and giant.specimen.damage==36 and is_equal_approx(giant.body.mesh.radius,1.45) and giant.collision.shape.radius==1.25,"Giant has 1.6 wolf HP, doubled damage and mother-slime dimensions")
	giant._physics_process(.01);review.check(giant.state=="giant_warn" and is_instance_valid(giant.warning),"Giant warns before its extended jump")
	var target=giant.jump_target;review.check(target.distance_to(giant.position)>4 and target.distance_to(giant.position)<=9.1,"Jump reaches beyond the original short hop")
	giant.take_damage(1,Vector3.ZERO);review.check(giant.state=="recover","Damage can interrupt the giant's jump tell")
	giant.state="idle";giant.knockback=Vector3.ZERO;giant._physics_process(.01);var jump_start=giant.position
	giant._physics_process(1.01);g.player.position+=Vector3(0,0,5)
	await g.get_tree().physics_frame
	for i in range(20):giant._physics_process(.05)
	review.check(giant.position.distance_to(jump_start)>3.5 and giant.state=="recover","Giant actually travels through its long jump and lands in recovery")
	var xp=g.progression.xp;var cores=g.monster_cores.pending.size();giant.take_damage(9999,Vector3.ZERO)
	for child in campaign.all_entries().filter(func(e):return e.get("parent_id","")==placement.id):campaign.spawn(child)
	var children=campaign.live.values().filter(func(e):return is_instance_valid(e) and String(e.definition.id).begins_with(placement.id+"_split_") and e.health>0)
	review.check(children.size()==4 and g.progression.xp==xp,"Giant splits once into four children, with no extra parent XP")
	review.check(children.all(func(e):return e.max_health==45 and e.specimen.damage==8 and e.specimen.attack_speed==7.0),"Split children keep their original stats but jump farther and faster")
	var split_save=g.save_data();g.Save.write(split_save,"user://swamp-live-split.json")
	review.check(g.apply_save(g.Save.read("user://swamp-live-split.json")),"Reload accepts an encounter between parent defeat and child defeats")
	for child in campaign.all_entries().filter(func(e):return e.get("parent_id","")==placement.id):campaign.spawn(child)
	children=campaign.live.values().filter(func(e):return is_instance_valid(e) and String(e.definition.id).begins_with(placement.id+"_split_") and e.health>0)
	review.check(children.size()==4 and not campaign.live.has(placement.id),"Reload restores four children without resurrecting or splitting the parent twice")
	var coins=guild.copper
	for child in children:child.set_physics_process(false);child.take_damage(9999,Vector3.ZERO)
	review.check(g.progression.xp==xp+72 and guild.copper-coins>=20 and guild.copper-coins<=24,"Four children give 72 XP and 20–24 copper")
	review.check(g.monster_cores.pending.size()==cores,"No Floor Two slime cores drop")
	var samples=4000;var residues=0;var potions=0;var valid_coins=true
	for i in range(samples):
		var loot=guild.roll("green_slime");residues+=int(loot.items.has("green_slime_residue"));potions+=int(loot.items.has("minor_healing_potion"));valid_coins=valid_coins and loot.copper in [5,6]
	review.check(valid_coins and residues>1000 and residues<1400 and potions>280 and potions<520,"Loot uses 5–6 coins and independent 30% residue / 10% potion rolls")
	var child_id=placement.id+"_split_0";var key="wr_floor_02/"+child_id;var raft=load("res://scripts/swamp_raft.gd").center()
	guild.drops[key]={"at":[raft.x,raft.z],"copper":0,"items":{"green_slime_residue":1,"minor_healing_potion":1}};guild.build_drop(key);g.player.position=raft;g.player.input_enabled=true
	var potion_before=int(g.magic_items.quantities.get("minor_healing_potion",0));var material_before=int(guild.materials.get("green_slime_residue",0))
	review.check(guild.collect(key) and int(g.magic_items.quantities.get("minor_healing_potion",0))==potion_before+1 and int(guild.materials.get("green_slime_residue",0))==material_before+1,"Residue and minor potions are collected as inventory stacks")
	g.player.state="free";g.player.restore_health(g.player.max_health)
	var save=g.save_data();review.check(g.Save.write(save,"user://swamp-split-review.json")==OK and not g.Save.read("user://swamp-split-review.json").is_empty(),"Split defeat IDs, materials and consumables survive strict save validation")
	var site=Fen.spec.sites.filter(func(e):return e.id=="swamp_rest_d11")[0];g.player.position=Vector3(site.at[0],.85,site.at[1]);g.worldrise.checkpoints.discover()
	review.check(site.id in campaign.unlocked,"D11 crystal is discovered on approach")
	review.check(g.current_world.interactions.any(func(e):return e.get("role","")=="wr_clerk") and g.current_world.interactions.any(func(e):return e.get("role","")=="wr_swords"),"Raft has a functional guild clerk and equipment vendor")
	var vendor=g.current_world.interactions.filter(func(e):return e.get("role","")=="wr_swords")[0];g.player.position=vendor.position;g.conversation.visible=true;g.conversation.target=vendor;guild.copper=450;guild.materials.green_slime_residue=15;g.progression.xp=int(g.progression.definition.level_thresholds[9]);g.apply_skill_stats()
	review.check(guild.craft("water_walkers") and "water_walkers" in g.magic_items.owned and int(guild.materials.get("green_slime_residue",0))==0 and guild.copper==0,"Fen vendor sells Water Walkers for level 10, fifteen residues and 450 copper")
	g.magic_items.equip("boots","water_walkers");review.check(is_equal_approx(g.magic_items.bonus("water_speed"),1.2),"Water Walkers provide their water-only 20% gait bonus without sticky resistance")
	g.conversation.close();g._refresh_simulation()
	var clerk=g.current_world.interactions.filter(func(e):return e.get("role","")=="wr_clerk")[0];g.player.position=clerk.position;g.conversation.visible=true;g.conversation.target=clerk;guild.copper=100
	review.check(guild.buy_potion() and guild.copper==75,"Raft clerk sells the existing 25-copper healing potion")
	g.conversation.close();g._refresh_simulation()
	var start=Vector3(Fen.spec.raft.anchor[0]+4.9,.858,Fen.spec.raft.anchor[1]);g.player.position=start
	await g.get_tree().physics_frame
	for i in range(240):g.player.velocity=Vector3(3.4,0,0);g.current_world.move_grounded(g.player,1.0/60)
	review.check(g.player.position.x>raft.x-2 and absf(g.player.position.y-.858)<.15,"Player walks the level gangplank onto the floating raft without drowning")
	campaign.respawn_reset();review.check(not g.defeated_enemies.any(func(id):return String(id).begins_with("wr_floor_02/")) and campaign.states.is_empty(),"Rest/death reset restores giants and removes split-child progress")
