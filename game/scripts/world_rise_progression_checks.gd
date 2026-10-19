extends RefCounted
## Pure allocation/migration checks, also called by the native World Rise fixture.
const Growth=preload("res://scripts/progression.gd")
const Stats=preload("res://scripts/world_rise_stats.gd")
func state(amount:int=957383) -> RefCounted:
	var result=Growth.new();result.set_profile(true);result.xp=amount;return result
func run(test:Object) -> void:
	var s=state(0)
	test.check(s.level()==1 and s.points()==0 and s.attribute_points()==7,"Fresh tree5 has seven attribute points, no paid perks, and unchanged level one")
	test.check(s.definition.level_thresholds==JSON.parse_string(FileAccess.get_file_as_string(Growth.LEGACY_WORLD_RISE)).level_thresholds,"Every XP threshold matches frozen tree4")
	test.check(Growth.valid(s.snapshot()) and Growth.valid(JSON.parse_string(JSON.stringify(s.snapshot()))),"Fresh tree5 and JSON-number snapshots validate strictly")
	for id in Growth.ATTRIBUTE_IDS:
		s=state()
		for value in range(3,20):test.check(s.increase_attribute(id),"Attribute investment succeeds within earned budget and cap")
		test.check(not s.increase_attribute(id) and s.attributes[id]==20,"Attribute cannot exceed twenty")
		for item in s.definition.skills:
			if item.attribute!=id:continue
			var gate=int(item.gate);s.attributes[id]=gate-1
			test.check(not s.can_learn(item.id),"Perk is locked immediately below its attribute gate: "+item.id)
			s.attributes[id]=20
			for rank_index in range(int(item.max_rank)):
				test.check(s.learn(item.id),"Each supported perk rank is available after its prerequisites: "+item.id)
			test.check(not s.learn(item.id),"Perk rank cap rejects excess allocation: "+item.id)
			test.check(Growth.valid(s.snapshot()),"Every legal branch allocation survives strict validation")
		test.check(Stats.weapon_stamina_multiplier(s,"greatsword")>=.5 and Stats.weapon_stamina_multiplier(s,"rapier")>=.5 and Stats.weapon_stamina_multiplier(s,"bow")>=.5,"Action stamina savings remain bounded for each branch")
	s=state();s.increase_attribute("mastery");s.learn("charge_thrust")
	for i in range(5):s.increase_attribute("mastery")
	s.learn("fast_thrust")
	test.check(not s.refund("charge_thrust") and s.has("charge_thrust"),"Refund rejects removing a dependency still used by Fast Thrust")
	var before=s.points();test.check(s.refund("fast_thrust") and s.points()==before+1 and s.refund("charge_thrust"),"Refund returns exactly one point per removed rank, in dependency order")
	for kind in Growth.WEAPON_KINDS:
		for threshold in Growth.PRACTICE_MILESTONES:
			s=state();s.award_practice(kind,threshold-1);var rank=s.practice_rank(kind)
			s.award_practice(kind);test.check(s.practice_rank(kind)==rank+1,"Practice advances exactly at an accepted-kill milestone: "+kind)
			test.check(Growth.valid(s.snapshot()),"Practice counters and legacy greatsword mirror remain valid")
	s=state();s.award_practice("bow",400);s.award_practice("invalid",100);s.award_practice("bow",-1)
	test.check(s.practice_rank("bow")==5 and s.weapon_kills.bow==400 and is_equal_approx(Stats.weapon_damage_multiplier(s,"bow"),1.10),"Weapon practice caps its bonus at ten percent and rejects invalid awards")
	s.increase_attribute("body");s.learn("iron_body");var old_xp=s.xp;var old_kills=s.weapon_kills.duplicate()
	test.check(s.reset_attributes() and s.attributes==Growth.base_attributes() and s.learned.is_empty() and s.attribute_points()==56 and s.points()==49,"One free attribute reset atomically returns all attribute and perk allocations")
	test.check(s.xp==old_xp and s.weapon_kills==old_kills and not s.reset_attributes(),"Reset preserves XP/practice and cannot be used twice")
	var legacy={"tree_version":4,"profile":"world_rise","xp":957383,"learned":["iron_body","swiftfoot","dash","belly_roll","great_greatsword","charge_thrust","fast_thrust","basher","basher","basher","devastating_blade"],"passives":[],"greatsword_kills":400}
	var untouched=legacy.duplicate(true);var upgraded=Growth.migrate_world_rise(legacy)
	test.check(Growth.valid_world_rise4(legacy) and Growth.valid(upgraded) and legacy==untouched,"Legacy validator accepts the exact original gates, and migration never mutates its input")
	test.check(upgraded.learned==["dash","belly_roll","charge_thrust"] and upgraded.attributes.reflexes==4 and upgraded.attributes.mastery==4,"Migration retains paid active abilities and assigns only their minimum attribute gates")
	s.restore(upgraded)
	test.check(s.points()==46 and s.attribute_points()==54 and s.xp==957383 and s.greatsword_kills==400,"Migration returns every retired passive rank while preserving XP and lifetime kills")
	test.check(Growth.migrate_world_rise(upgraded)==upgraded and upgraded.migration_v4.learned==legacy.learned,"Migration is idempotent and keeps a bounded exact allocation receipt")
	legacy.learned=[]
	for i in range(49):legacy.learned.append("iron_body")
	upgraded=Growth.migrate_world_rise(legacy)
	test.check(Growth.valid_world_rise4(legacy) and upgraded.learned.is_empty() and upgraded.migration_v4.learned.size()==49,"Maximum legitimate uncapped legacy allocation is validated then fully refunded")
	var malformed=legacy.duplicate(true);malformed.learned=["basher"]
	test.check(not Growth.valid_world_rise4(malformed) and Growth.migrate_world_rise(malformed).is_empty(),"Migration refuses a legacy allocation missing original prerequisites")
	malformed=legacy.duplicate(true);malformed.greatsword_kills=0;malformed.learned=["great_greatsword","charge_thrust"]
	test.check(not Growth.valid_world_rise4(malformed),"Legacy validation keeps its original fifteen-kill Charged Thrust gate")
	s=state();var bad=s.snapshot();bad.attributes.body=20;bad.attributes.reflexes=20;bad.attributes.precision=20;bad.attributes.endurance=20
	test.check(not Growth.valid(bad),"Tree5 rejects attribute overspending")
	bad=s.snapshot();bad.attributes.body=3.5;test.check(not Growth.valid(bad),"Tree5 rejects fractional attribute ranks")
	bad=s.snapshot();bad.weapon_kills.greatsword=15;test.check(not Growth.valid(bad),"Tree5 rejects mismatched legacy and current greatsword counters")
	bad=s.snapshot();bad.learned=["devastating_blade"];test.check(not Growth.valid(bad),"Tree5 rejects perk gates and missing dependencies")
	bad=s.snapshot();bad["free_points"]=999;test.check(not Growth.valid(bad),"Tree5 rejects invented economy fields")
	var older=Growth.new();older.restore({"tree_version":3,"xp":8200,"learned":["strength","mana","mana_lance"],"passives":[]})
	test.check(not older.world_rise and older.has("mana_lance") and older.snapshot().tree_version==3,"Older game modes retain their independent Mana tree and save version")

	var notice=preload("res://scripts/world_rise_migration_notice.gd")
	var notice_path="user://tree5-notice-fixture.cfg"
	var receipt={"learned":["iron_body","swiftfoot"]}
	test.check(not notice.acknowledged("offline",receipt,notice_path),"Missing local notice preference safely shows migration explanation")
	test.check(notice.remember("offline",receipt,notice_path) and notice.acknowledged("offline",receipt,notice_path),"Offline acknowledgement persists and reopens through a fresh ConfigFile read")
	var character_key="online:"+"a".repeat(32)
	test.check(not notice.acknowledged(character_key,receipt,notice_path) and notice.remember(character_key,receipt,notice_path),"Portable character acknowledgement uses its own stable local identity")
	test.check(notice.acknowledged("offline",receipt,notice_path) and notice.acknowledged(character_key,receipt,notice_path),"Offline and portable preferences remain independent after reopen")
	test.check(not notice.acknowledged("offline",{"learned":["iron_body"]},notice_path),"A different migration receipt is never hidden by a previous acknowledgement")
	var successful_notices=0
	for index in range(130):
		var suffix=String.num_int64(index,16)
		if notice.remember("online:"+"0".repeat(32-suffix.length())+suffix,receipt,notice_path):successful_notices+=1
	if successful_notices!=130 or notice.entries(notice_path).size()!=129:print("NOTICE_HISTORY_DIAGNOSTIC ",JSON.stringify({"saved":successful_notices,"entries":notice.entries(notice_path).size(),"offline":notice.acknowledged("offline",receipt,notice_path)}))
	test.check(notice.entries(notice_path).size()==129 and notice.acknowledged("offline",receipt,notice_path),"Local notice history is bounded to 128 portable characters plus one offline slot")
	var broken=ConfigFile.new();broken.set_value("notices","acknowledged",["invalid preference shape"]);broken.save(notice_path)
	test.check(not notice.acknowledged("offline",receipt,notice_path),"Corrupt presentation preference cannot suppress a migration notice")
	DirAccess.remove_absolute(notice_path)
