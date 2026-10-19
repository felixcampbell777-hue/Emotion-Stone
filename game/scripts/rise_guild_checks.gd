extends RefCounted
const Shape=preload("res://scripts/rise_shape.gd")
func approach(g:Node,role:String) -> Dictionary:
	var target=g.current_world.interactions.filter(func(t):return t.get("role","")==role)[0]
	g.player.position=target.position+Vector3(0,0,-1).rotated(Vector3.UP,PI/4);g.conversation.show_character(target);g._refresh_simulation();return target
func run(test:RefCounted) -> void:
	var g=test.game;var guild=g.worldrise.guild;var house=g.current_world.get_node("AdventurersGuild")
	test.check(Shape.spec.arrival_radius==9 and house.position==Vector3(146,48,146),"Arrival platform diameter halves and guild occupies the southeast edge opposite Elderwood")
	test.check(g.npcs.size()==3 and g.current_world.interactions.filter(func(t):return String(t.get("role","")).begins_with("wr_")).size()==3,"Guild contains front desk, back armorer and sword merchant")
	# Walk through the actual doorway, across the hall and toward the armorer.
	var clear=true;g.player.position=house.to_global(Vector3(0,0,-16));await test.frames(2)
	for end in [Vector3(0,0,-6),Vector3(3,0,-6),Vector3(3,0,5),Vector3(-3,0,5)]:
		var target=house.to_global(end)
		for i in range(800):
			var toward=(target-g.player.position)*Vector3(1,0,1)
			if toward.length()<.2:break
			g.player.velocity=toward.normalized()*2.4;g.current_world.move_grounded(g.player,1.0/60)
		if Vector2(target.x-g.player.position.x,target.z-g.player.position.z).length()>.4:clear=false;break
	test.check(clear,"Player capsule can enter the real guild doorway and reach both sides of its hall")
	var roof_ray=PhysicsRayQueryParameters3D.create(house.to_global(Vector3(0,2,1)),house.to_global(Vector3(0,14,1)),1)
	test.check(not g.player.get_world_3d().direct_space_state.intersect_ray(roof_ray).is_empty(),"Guild roof blocks upward traversal and guided projectiles")
	var both=guild.roll("library_boar",2,.34999,.07999);var none=guild.roll("library_boar",4,.35,.08)
	test.check(both.copper==2 and both.items=={"boar_hide":1,"boar_tusk":1} and none.copper==4 and none.items.is_empty(),"Boars drop 2–4 copper; hide/tusk rolls are independent with exact 35%/8% boundaries")
	both=guild.roll("beta_wolf",1,.34999,.07999);none=guild.roll("beta_wolf",5,.35,.08)
	test.check(both.copper==1 and both.items=={"wolf_hide":1,"wolf_fang":1} and none.copper==5 and none.items.is_empty(),"Wolves drop 1–5 copper with independent 35% hide and 8% fang chances")
	var hides=0;var rare=0;var coins=true;guild.rng.seed=18481
	for i in range(5000):
		var loot=guild.roll("library_boar");hides+=int(loot.items.has("boar_hide"));rare+=int(loot.items.has("boar_tusk"));coins=coins and loot.copper>=2 and loot.copper<=4
	test.check(coins and absf(hides/5000.0-.35)<.025 and absf(rare/5000.0-.08)<.02,"Seeded bulk loot rolls preserve the requested common/rare rates and copper limits")
	test.check(guild.copper>=3 and guild.drops.values().all(func(d):return d.copper==0),"Real beast deaths immediately credit copper; sacks contain only items")
	# Guaranteed item fixture, independent of probabilistic earlier hide rolls.
	var loot_key="wr_floor_01/"+g.current_world.definition.enemies[0].id
	guild.drops[loot_key]={"at":[0,8],"copper":0,"items":{"boar_hide":1}};guild.build_drop(loot_key)
	var key=guild.drops.keys()[0];var drop=guild.drops[key];g.player.position=Vector3(drop.at[0],0,drop.at[1]);g.player.position.y=g.current_world.ground_height(g.player.position);var money=guild.copper;g.player.input_enabled=true
	test.check(guild.collect(key) and guild.copper==money and not guild.collect(key),"Nearby E-style collection grants only item stacks once; copper cannot pay twice")
	guild.materials={"boar_hide":6,"wolf_hide":9,"wolf_fang":2,"boar_tusk":1};guild.copper=1000
	test.check(not guild.sell("boar_hide") and not guild.craft("boar_hide_armor"),"Trade and crafting require the appropriate nearby NPC conversation")
	var clerk=approach(g,"wr_clerk");var clock=g.worldrise.elapsed;g.worldrise.tick(1)
	test.check(g.player.position.distance_to(clerk.position)<g.config.interaction_distance and Shape.safe(g.player.position),"Front-desk interaction is reachable from the customer side of its solid counter")
	test.check(not g.player.input_enabled and g.worldrise.elapsed==clock,"Guild conversations pause combat and territory simulation")
	money=guild.copper;test.check(guild.sell("boar_hide") and guild.materials.boar_hide==5 and guild.copper==money+5,"Front desk sells one stacked common hide for five copper")
	guild.materials.boar_tusk=2;money=guild.copper;test.check(guild.sell("boar_tusk") and guild.materials.boar_tusk==1 and guild.copper==money+22,"Rarer tusks sell for a proportionately higher 22 copper")
	test.check(guild.contract_action("boar") and guild.contract_action("wolf") and guild.contracts.boar.count==0 and guild.contracts.wolf.count==0,"Both one-time guild contracts can be accepted without retroactive kills")
	test.check(not guild.contract_action("boar"),"Incomplete hunts cannot pay out early")
	var definitions=g.current_world.definition.enemies;var boars=definitions.filter(func(e):return e.kind=="library_boar");var wolves=definitions.filter(func(e):return e.kind=="beta_wolf")
	for i in range(10):g._enemy_defeated("wr_floor_01/"+boars[i+2].id,"library_boar",g.enemies[0])
	for i in range(10):g._enemy_defeated("wr_floor_01/"+wolves[i+1].id,"beta_wolf",g.enemies[0])
	test.check(guild.contracts.boar.count==10 and guild.contracts.wolf.count==10,"Accepted contracts independently count ten actual defeat events")
	money=guild.copper;var xp=g.progression.xp;test.check(guild.contract_action("boar") and guild.contract_action("wolf") and guild.copper==money+200 and g.progression.xp==xp+240,"Clerk pays 75/125 copper plus 107/133 XP, one third of level-five/six advancement costs")
	money=guild.copper;xp=g.progression.xp;test.check(not guild.contract_action("boar") and guild.copper==money and g.progression.xp==xp and guild.contracts.boar.completed and guild.contracts.boar.count==10,"Completed one-time contracts cannot restart or duplicate copper/XP rewards")
	g.conversation.close();var armorer=approach(g,"wr_armorer");g.progression.xp=0;g.apply_skill_stats();var before=guild.snapshot()
	test.check(not guild.craft("boar_hide_armor") and guild.snapshot()==before,"Level-five boar recipe rejects low levels without charging resources")
	g.progression.xp=int(g.progression.definition.level_thresholds[4]);g.apply_skill_stats();money=guild.copper
	test.check(guild.craft("boar_hide_armor") and guild.copper==money-100 and not guild.materials.has("boar_hide"),"Level-five armor consumes exactly five boar hides and 100 copper")
	before=guild.snapshot();test.check(not guild.craft("boar_hide_armor") and guild.snapshot()==before,"Duplicate armor crafting cannot consume resources again")
	test.check(not guild.craft("wolf_hide_armor"),"Wolf armor remains locked below level ten")
	g.progression.xp=int(g.progression.definition.level_thresholds[9]);g.apply_skill_stats();money=guild.copper
	test.check(guild.craft("wolf_hide_armor") and guild.copper==money-200 and guild.materials.wolf_hide==1,"Level-ten armor consumes eight wolf hides and 200 copper")
	money=guild.copper;test.check(guild.craft("cruel_charm") and guild.copper==money-300 and not guild.materials.has("wolf_fang") and not guild.materials.has("boar_tusk"),"Cruel Charm consumes two fangs, one tusk and exactly 300 copper")
	g.magic_items.equip("torso","boar_hide_armor");test.check(is_equal_approx(g.magic_items.bonus("armor"),.02),"Boar torso armor contributes exactly two percent damage reduction")
	g.magic_items.equip("leggings","wolf_hide_armor");test.check(g.magic_items.slots.torso=="boar_hide_armor" and g.magic_items.slots.leggings=="wolf_hide_armor" and is_equal_approx(g.magic_items.bonus("armor"),.05),"Wolf leggings and boar torso equip together for five percent reduction")
	var current=g.magic_items.snapshot();var legacy_gear=current.duplicate(true);legacy_gear.slots={"torso":"wolf_hide_armor"}
	test.check(g.magic_items.valid_save(legacy_gear),"Legacy wolf torso equipment remains accepted by save validation")
	g.magic_items.restore(legacy_gear)
	test.check(g.magic_items.slots.get("leggings","")=="wolf_hide_armor" and not g.magic_items.slots.has("torso"),"Loading old wolf armor relocates it to the free leggings slot")
	legacy_gear.owned.append("kings_leggings");legacy_gear.slots.leggings="kings_leggings";g.magic_items.restore(legacy_gear)
	test.check(g.magic_items.slots.leggings=="kings_leggings" and "wolf_hide_armor" in g.magic_items.owned and not g.magic_items.slots.has("torso"),"Wolf migration preserves occupied leggings and retains the wolf item in inventory")
	g.magic_items.restore(current);g.apply_skill_stats()
	var base=g.player.combat.lance.damage;var dragon=g.player.combat.sea_dragon.damage;g.magic_items.equip("necklace","cruel_charm")
	test.check(is_equal_approx(g.magic_items.bonus("all_damage"),.02) and g.player.combat.lance.damage==roundi(base*1.02) and g.player.combat.sea_dragon.damage==roundi(dragon*1.02),"Equipped Cruel Charm applies two percent across normal and magic damage including Sea Dragon")
	var stable=g.player.combat.lance.damage;g.apply_skill_stats();test.check(g.player.combat.lance.damage==stable,"Rebuilding stats does not stack the charm's damage bonus")
	g.conversation.close();var merchant=approach(g,"wr_swords")
	var offers=g.conversation.choices.get_children().map(func(button):return button.text)
	for offer in [["improved_standard_greatsword",300],["field_spear",80],["duelist_rapier",100],["hunting_bow",75]]:
		var recipe=guild.catalog.recipes.get(offer[0],{})
		test.check(recipe.get("vendor","")=="wr_swords" and recipe.get("copper",-1)==offer[1] and offers.any(func(label):return label.contains(g.magic_items.item(offer[0]).name) and label.contains(str(offer[1])+" cp")),"Corin offers "+offer[0]+" at its authored copper price")
	test.check(offers.any(func(label):return label.contains("Buy 1 Wooden Arrows · 1 cp")) and offers.any(func(label):return label.contains("Buy 10 Wooden Arrows · 10 cp")) and not guild.craft("boar_hide_armor"),"Weapon vendor sells finite one-copper arrows and cannot craft armor")
	guild.copper=299;test.check(not guild.craft("improved_standard_greatsword") and guild.copper==299,"Sword purchase rejects insufficient copper without charging")
	guild.copper=500;test.check(guild.craft("improved_standard_greatsword") and guild.copper==200 and "improved_standard_greatsword" in g.magic_items.owned,"Corin sells the level-five sword for exactly 300 copper")
	money=guild.copper;test.check(not guild.craft("improved_standard_greatsword") and guild.copper==money,"Owned sword cannot charge the player a second time")
	g.conversation.close();approach(g,"wr_armorer")
	test.check(not guild.craft("improved_standard_greatsword") and not g.conversation.choices.get_child(0).text.contains("Greatsword"),"Armorer no longer lists or sells the sword")
	test.check(g.enemy_xp_reward("ashfang")==125 and g.enemy_xp_reward("vault_elder")==500,"World Rise keeps Ashfang normal XP and the explicit 500 repeatable Elder XP override")
	var checkpoint_xp=g.progression.xp;g.gain_xp(guild.contract_xp("boar"))
	test.check(g.progression.xp==checkpoint_xp+107 and guild.contract_xp("wolf")==133,"Quest XP passes through unchanged by the kill-only multiplier")
	g.progression.xp=checkpoint_xp;g.game_mode="alpha2"
	test.check(g.enemy_xp_reward("library_boar")==65 and g.enemy_xp_reward("beta_wolf")==30,"Other adventure modes retain their original kill rewards")
	g.game_mode="world_rise"
	g.conversation.close();g._refresh_simulation();g.inventory.selected_category="ingredients"
	test.check(g.inventory.listed_items().any(func(e):return e.kind=="material" and e.id=="wolf_hide" and e.count==1),"Materials use single counted stacks in inventory Ingredients")
	var invalid=guild.snapshot();invalid.copper=-1;test.check(not guild.valid(invalid),"Economy save validation rejects negative money")
	invalid=guild.snapshot();invalid.materials={"unapproved":1};test.check(not guild.valid(invalid),"Economy rejects unknown materials")
	invalid=guild.snapshot();invalid.contracts.boar.count=11;test.check(not guild.valid(invalid),"Contract save validation rejects out-of-range progress")
	var migrated=load("res://scripts/rise_guild.gd").new();var legacy=guild.snapshot();legacy.copper=11;legacy.drops={loot_key:{"at":[0,8],"copper":7,"items":{"boar_hide":1}}};migrated.restore(legacy)
	test.check(migrated.copper==18 and migrated.drops[loot_key].copper==0 and migrated.drops[loot_key].items.boar_hide==1,"Legacy uncollected sack coins migrate into the purse while item loot remains")
	var again=migrated.snapshot();migrated.restore(again);test.check(migrated.copper==18,"Loading migrated sacks cannot credit the same coins twice")
	test.check(guild.valid({}),"Old World Rise saves migrate to an empty purse and no active contracts")

