extends SceneTree
## Production authority/store/runtime integration, using disposable absolute storage.
const Authority=preload("res://scripts/network/wr_authority.gd")
const Store=preload("res://scripts/network/wr_store.gd")
const Profile=preload("res://scripts/network/wr_profile.gd")
var failures=[]
var checks=0
var owner_node:Node
var temporary=""
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:
		failures.append(message);push_error(message)
		var diagnostic=preload("res://scripts/network/wr_storage_codec.gd").last_encode_error
		if not diagnostic.is_empty():print("NATIVE_STORAGE_DIAGNOSTIC ",diagnostic)
func _initialize() -> void:call_deferred("run")
func place(authority:RefCounted,p:Dictionary,at:Vector3) -> void:
	p.position=authority.arr(at);p.velocity=[0,0,0];p.input={};p.action="free";p.health=p.max_health
	if p.has("bridge"):
		p.bridge.set_pose(at,p.yaw,p.pitch);p.bridge.actor.health=p.bridge.actor.max_health;p.bridge.actor.state="free";p.bridge.actor.state_time=0;p.bridge.actor.knockback=Vector3.ZERO;p.bridge.actor.finish_jump()
func run() -> void:
	temporary=OS.get_environment("TMPDIR").path_join("world-rise-native-"+Profile.random_id()) if not OS.get_environment("TMPDIR").is_empty() else "/tmp/world-rise-native-"+Profile.random_id()
	var storage=Store.new();check(storage.open(temporary),"Disposable durable world opens")
	var authority=Authority.new();owner_node=Node.new();root.add_child(owner_node);authority.attach(owner_node);authority.configure(storage)
	var key=Crypto.new().generate_rsa(2048);var a=Profile.new_profile(key.save_to_string(true),"Floor One");var b=Profile.new_profile(key.save_to_string(true),"Floor Two")
	check(storage.import_character(a).ok and storage.import_character(b).ok,"Two portable characters imported")
	var p1=authority.add_player(a);var p2=authority.add_player(b)
	await physics_frame
	check(p1.has("bridge") and p2.has("bridge"),"Production authority uses canonical Actor bridges")
	if not p1.has("bridge") or not p2.has("bridge"):finish();return
	var next=storage.data.duplicate(true);next.flags.append("elder_defeated");check(storage.commit(next),"Fixture floor access established durably")
	check(authority.action(p2.id,"travel",{"floor":"wr_floor_02"}).ok,"One player travels through production action")
	await physics_frame
	check(p1.floor=="wr_floor_01" and p2.floor=="wr_floor_02","Distinct connected floors coexist")
	var fen=authority.runtimes.wr_floor_02;var rise=authority.runtimes.wr_floor_01
	var giant=authority.world.encounter_entries("wr_floor_02").filter(func(entry):return entry.kind=="giant_green_slime")[0]
	var pos=authority.vec(giant.position);place(authority,p2,pos)
	var ordinary=authority.world.encounter_entries("wr_floor_01")[0];place(authority,p1,authority.vec(ordinary.position))
	for i in range(3):authority.step(1.0/60)
	check(fen.enemies.size()>0 and rise.enemies.size()>0,"Production session streams native enemies on both floors")
	var parent=fen.enemy_node(giant.id)
	if parent==null:check(false,"Native giant exists");finish();return
	fen.apply_enemy_damage(giant.id,10,Vector3.ZERO,{"damage_kind":"melee","actor_id":p2.id,"weapon_type":"greatsword","action_id":"fixture-damage"})
	authority.step(1.0/60)
	check(authority.enemies["wr_floor_02/"+giant.id].health==118,"Actual controller health synchronized into authority")
	var native_commit=authority.checkpoint_all()
	check(native_commit,"Partial native encounter checkpoint: "+storage.last_error)
	if not native_commit:finish();return
	place(authority,p1,authority.world.floor_arrival("wr_floor_01"));check(authority.action(p1.id,"rest").ok,"Other-floor participant rests normally")
	check(parent.health==118,"Another player's rest preserves live damaged encounter")
	var parent_record=authority.enemies["wr_floor_02/"+giant.id];parent_record.contributors[p2.id]=authority.clock;parent_record.last_attacker=p2.id;parent_record.last_weapon="greatsword"
	fen.apply_enemy_damage(giant.id,9999,Vector3.ZERO,{"damage_kind":"melee","actor_id":p2.id,"weapon_type":"greatsword"})
	for i in range(35):authority.step(1.0/60)
	var children=fen.enemies.filter(func(enemy):return enemy.health>0 and String(enemy.definition.id).begins_with(giant.id+"_split_"))
	check(children.size()==4,"Production giant splits into four native children exactly once")
	if not children.is_empty():
		var child=children[0];var record=authority.enemies["wr_floor_02/"+child.definition.id];record.contributors[p2.id]=authority.clock;record.last_attacker=p2.id;record.last_weapon="greatsword"
		var before=int(p2.profile.progression.xp);var copper=int(p2.profile.copper)
		# Exercise a real personal loot claim without depending on a random no-drop.
		var reward_probe=RandomNumberGenerator.new()
		for seed_value in range(128):
			reward_probe.seed=seed_value
			if not authority.world.roll_rewards(record,reward_probe).items.is_empty():authority.rng.seed=seed_value;break
		fen.apply_enemy_damage(child.definition.id,9999,Vector3.ZERO,{"damage_kind":"melee","actor_id":p2.id,"weapon_type":"greatsword"})
		check(int(p2.profile.progression.xp)-before==18,"Production personal split XP pays exactly once")
		check(int(p2.profile.copper)-copper in [5,6],"Production personal split copper remains exact")
		var after=int(p2.profile.progression.xp);authority.settle_kill(record,p2.id);check(int(p2.profile.progression.xp)==after,"Repeated settlement cannot duplicate XP")
	# Canonical authority may reset only after every participant leaves the area.
	place(authority,p1,authority.world.floor_arrival("wr_floor_01"))
	check(authority.action(p1.id,"travel",{"floor":"wr_floor_02"}).ok,"Friend enters occupied Floor Two")
	var remote=authority.world.encounter_entries("wr_floor_02").filter(func(entry):return entry.kind=="giant_green_slime")[-1]
	place(authority,p2,authority.vec(remote.position));place(authority,p1,authority.vec(remote.position))
	for i in range(40):authority.step(1.0/60)
	check(fen.enemy_node(remote.id)!=null,"Remote encounter streamed by shared player interest")
	fen.apply_enemy_damage(remote.id,10,Vector3.ZERO)
	place(authority,p2,authority.world.floor_arrival("wr_floor_02"))
	authority.action(p2.id,"rest")
	for i in range(310):authority.step(.1)
	check(int(authority.enemies["wr_floor_02/"+remote.id].generation)==0,"Friend remaining in area prevents automatic reset")
	place(authority,p1,authority.world.floor_arrival("wr_floor_02"))
	for i in range(310):authority.step(.1)
	check(int(authority.enemies["wr_floor_02/"+remote.id].generation)==1,"Production authority resets empty encounter generation after delay")
	check(int(authority.enemies["wr_floor_02/"+remote.id].health)==128,"Empty reset canonical HP persists even without active actor")
	check(not authority.save_departure(p2.id).is_empty(),"Live encounter and character checkpoint persists")
	storage.stop_worker()
	var reopened=Store.new();var reopen_ok=reopened.open(temporary);check(reopen_ok,"Actual durable checkpoint reopens: "+reopened.last_error)
	if not reopen_ok:finish();return
	reopened.stop_worker()
	var restarted=Authority.new();restarted.configure(reopened)
	check(restarted.enemies["wr_floor_02/"+giant.id].health==authority.enemies["wr_floor_02/"+giant.id].health and restarted.enemies["wr_floor_02/"+giant.id].generation==authority.enemies["wr_floor_02/"+giant.id].generation,"Current giant reset/defeat state survives production restart")
	check(int(reopened.data.characters[p2.id].progression.xp)==int(p2.profile.progression.xp),"Portable personal XP survives production restart")
	check(not reopened.data.claims.is_empty(),"Personal loot identities survive production restart")
	# The shared Vault is a single runtime; entry does not start its battle until
	# somebody actually steps onto the arena, matching the authored bridge rule.
	check(authority.action(p1.id,"travel",{"floor":"wr_floor_01"}).ok,"First participant returns from Floor Two")
	place(authority,p1,Vector3(-168,authority.world.ground_height("wr_floor_01",Vector3(-168,0,-125)),-125))
	check(authority.action(p1.id,"travel",{"floor":"wr_boss_chamber"}).ok,"Production Vault entry")
	await physics_frame
	place(authority,p2,authority.world.floor_arrival("wr_floor_02"))
	check(authority.action(p2.id,"travel",{"floor":"wr_floor_01"}).ok,"Second participant returns through production floor portal")
	place(authority,p2,Vector3(-168,authority.world.ground_height("wr_floor_01",Vector3(-168,0,-125)),-125))
	check(authority.action(p2.id,"travel",{"floor":"wr_boss_chamber"}).ok,"Second participant joins existing Vault")
	var vault=authority.runtimes.wr_boss_chamber;authority.step(1.0/60)
	check(vault.players.size()==2,"Both canonical bodies share one Vault runtime")
	check(vault.enemy_node("vault_elder")==null,"Vault waits while visitor remains on arrival bridge")
	place(authority,p1,Vector3(0,0,10));place(authority,p2,Vector3(1,0,11));authority.step(1.0/60)
	check(vault.enemy_node("vault_elder")!=null,"Entering actual arena starts native Elder")
	for i in range(190):authority.step(1.0/60)
	var elder_record=authority.enemies["wr_boss_chamber/vault_elder"]
	elder_record.contributors[p1.id]=authority.clock;elder_record.contributors[p2.id]=authority.clock;elder_record.last_attacker=p1.id;elder_record.last_weapon="greatsword"
	var first_xp=int(p1.profile.progression.xp)
	vault.apply_enemy_damage("vault_elder",99999,Vector3.ZERO,{"damage_kind":"melee","actor_id":p1.id,"weapon_type":"greatsword"})
	check(elder_record.health==0 and is_equal_approx(float(elder_record.cooldown_remaining),1080),"Native Elder defeat schedules exact repeat cooldown")
	check(int(p1.profile.progression.xp)-first_xp==1500,"Native Elder grants repeat XP and personal first bonus")
	check("elder_first_kill_bonus" in p1.profile.bonus_claims and "elder_first_kill_bonus" in p2.profile.bonus_claims,"Both participating personal bonus claims settle")
	check(not authority.save_departure(p1.id).is_empty(),"Boss cooldown checkpoint persists")
	storage.stop_worker()
	var boss_reload=Store.new();check(boss_reload.open(temporary),"Boss save reopens")
	boss_reload.stop_worker()
	check(float(boss_reload.data.encounters["wr_boss_chamber/vault_elder"].cooldown_remaining)>1079,"Boss cooldown survives durable restart")
	elder_record.cooldown_remaining=.03
	authority.step(.02);authority.step(.02)
	check(int(elder_record.generation)==1 and vault.enemy_node("vault_elder")!=null and vault.enemy_node("vault_elder").health==1100,"Native cooldown expires into one fresh boss generation")
	finish()
func finish() -> void:
	print("NATIVE_SESSION_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
	if is_instance_valid(owner_node):owner_node.free()
	var dir=DirAccess.open(temporary)
	if dir!=null:
		for file in dir.get_files():dir.remove(file)
		DirAccess.remove_absolute(temporary)
	quit(0 if failures.is_empty() else 1)
