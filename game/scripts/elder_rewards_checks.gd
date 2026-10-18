extends RefCounted
func run(test:RefCounted) -> void:
	var g=test.game;var r=g.worldrise;var guild=r.guild;var gear=g.magic_items;var id=r.ELDER_ID
	g.title_screen.hide();g._refresh_simulation();g.player.set_physics_process(false);g.set_process(false);g.set_physics_process(false)
	var both=guild.roll("vault_elder",45,.199999,.049999);var none=guild.roll("vault_elder",130,.2,.05)
	test.check(both.copper==45 and both.items=={"elder_leaves":1,"elder_heart_necklace":1} and none.copper==130 and none.items.is_empty(),"Elder has independent exact 20% leaf and 5% necklace rolls with 45–130 copper")
	var leaf=0;var heart=0;guild.rng.seed=19373;var limits=true
	for i in range(10000):
		var loot=guild.roll("vault_elder");leaf+=int(loot.items.has("elder_leaves"));heart+=int(loot.items.has("elder_heart_necklace"));limits=limits and loot.copper>=45 and loot.copper<=130
	test.check(limits and absf(leaf/10000.0-.2)<.02 and absf(heart/10000.0-.05)<.01,"Seeded Elder drop sampling respects both chances and copper bounds")
	g.load_map("wr_boss_chamber",Vector2(0,36),true);g.current_world.set_physics_process(false)
	r.flags.erase("elder_first_kill_bonus");g.defeated_enemies.erase(id);var elder_xp=g.progression.xp
	g._enemy_defeated(id,"vault_elder")
	test.check(g.progression.xp==elder_xp+1500 and "elder_first_kill_bonus" in r.flags,"The Elder awards 500 repeatable XP plus a one-time 1,000 XP first-victory bonus")
	r.elder_respawn=0;g.defeated_enemies.erase(id);elder_xp=g.progression.xp
	g._enemy_defeated(id,"vault_elder")
	test.check(g.progression.xp==elder_xp+500,"Later Elder victories award only the repeatable 500 XP")
	var before=guild.copper;guild.defeated(id,"vault_elder",Vector3(0,0,-5))
	test.check(guild.copper>=before+45 and guild.copper<=before+130,"Real Elder defeat directly credits copper in the boss chamber")
	guild.drops[id]={"at":[0,-5],"copper":0,"items":{"elder_leaves":1,"elder_heart_necklace":1}};guild.build_drop(id);g.player.position=Vector3(0,0,-5);g.player.input_enabled=true
	test.check(guild.collect(id) and "elder_heart_necklace" in gear.owned and guild.materials.get("elder_leaves",0)>=1 and not guild.collect(id),"Elder sack pickup grants a counted leaf and unique necklace exactly once")
	gear.equip("necklace","elder_heart_necklace");g.player.restore_health(50);gear.elder_clock=0;gear.tick(9.9)
	test.check(g.player.health==50,"Elder Heart does not heal before ten seconds")
	g.player.state="light";gear.tick(.11)
	test.check(g.player.health==51,"Elder Heart restores exactly one HP per ten seconds even during combat")
	var clock=gear.elder_clock;g.player.input_enabled=false;gear.tick(20)
	test.check(gear.elder_clock==clock and g.player.health==51,"Menus freeze Elder Heart regeneration")
	g.player.input_enabled=true;g.player.state="free";gear.equip("necklace","");gear.tick(11)
	test.check(g.player.health==51,"Unequipping Elder Heart stops its healing")
	r.elder_fell();g.hud_feedback.update(.5)
	test.check(g.hud_feedback.victory.visible and g.hud_feedback.victory_label.text=="Floor 1 Boss Defeated!" and g.hud_feedback.victory.size.x>=g.world_rect.size.x*.85,"Victory displays the large exact-text tombstone over the viewport")
	g.hud_feedback.update(5);test.check(not g.hud_feedback.victory.visible,"Boss victory tombstone clears after its brief display")
	r.day_clock=0;r.elder_respawn=1080
	if id not in g.defeated_enemies:g.defeated_enemies.append(id)
	r.tick(1079.9)
	test.check(id in g.defeated_enemies and r.elder_respawn>0,"Elder stays defeated until eighteen gameplay minutes after its kill")
	r.tick(.11)
	test.check(id not in g.defeated_enemies and r.elder_respawn==0 and guild.elder_unlocked(),"Elder becomes available after eighteen minutes without losing the first-kill recipe unlock")
	test.check(is_equal_approx(r.daylight(555),1) and is_equal_approx(r.daylight(600),.5) and is_equal_approx(r.daylight(645),0) and is_equal_approx(r.daylight(1035),0) and is_equal_approx(r.daylight(0),.5) and is_equal_approx(r.daylight(45),1),"Ninety-second dusk/dawn gradients straddle each day/night boundary by forty-five seconds")
	test.check(absf(r.daylight(1079.999)-r.daylight(.001))<.001,"Lighting is continuous across the eighteen-minute cycle wrap")
	r.day_clock=300;r.elder_respawn=500;g.player.input_enabled=false;r.tick(100)
	test.check(r.day_clock==300 and r.elder_respawn==500,"Menus freeze both day/night and Elder respawn timers")
	g.player.input_enabled=true;r.day_clock=700;r.elder_respawn=360
	var path="user://elder-rewards-verification.json";var data=g.save_data()
	test.check(g.Save.write(data,path)==OK and not g.Save.read(path).is_empty() and g.apply_save(g.Save.read(path)) and r.day_clock==700 and r.elder_respawn==360,"Day/night phase and remaining Elder cooldown survive strict private save/load")
	g.current_world.set_physics_process(false);g.load_map("wr_floor_01",Vector2(146,146),true)
	for e in g.enemies:e.set_physics_process(false);e.ai_enabled=false
	var armorer=load("res://scripts/rise_guild_checks.gd").new().approach(g,"wr_armorer")
	r.flags.erase("elder_defeated");g.defeated_enemies.erase(id);guild.materials.elder_leaves=5;guild.copper=1000
	test.check(not guild.craft("leaf_shield") and guild.materials.elder_leaves==5 and guild.copper==1000,"Leaf Shield cannot be crafted before the first Elder victory")
	r.flags.append("elder_defeated");guild.dialogue(g.conversation,armorer)
	test.check(guild.craft("leaf_shield") and guild.copper==0 and not guild.materials.has("elder_leaves") and "leaf_shield" in gear.owned,"Unlocked armorer recipe consumes exactly five leaves and one thousand copper")
	test.check(not gear.equip("torso","leaf_shield") and not gear.equip("necklace","leaf_shield"),"Leaf Shield is stored gear without premature equipment or blocking mechanics")
	g.conversation.close();g._refresh_simulation();g.inventory.selected_category="apparel"
	test.check(g.inventory.listed_items().any(func(e):return e.id=="leaf_shield"),"Crafted Leaf Shield appears in the existing inventory")
	if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
