extends SceneTree
## Synthetic disposable profiles exercise production codec/store and lineage gates.
const Profile=preload("res://scripts/network/wr_profile.gd")
const Store=preload("res://scripts/network/wr_store.gd")
const Codec=preload("res://scripts/network/wr_storage_codec.gd")
const Authority=preload("res://scripts/network/wr_authority.gd")
const Session=preload("res://scripts/network/wr_session.gd")
const OfflineSave=preload("res://scripts/save_store.gd")
const Growth=preload("res://scripts/progression.gd")
const Checkpoint=preload("res://scripts/network/wr_world_checkpoint.gd")
var failures=[]
var checks=0
var temporary=""
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 temporary=OS.get_environment("TMPDIR").path_join("wr-tree6-"+Profile.random_id()) if not OS.get_environment("TMPDIR").is_empty() else "/tmp/wr-tree6-"+Profile.random_id()
 var key=Crypto.new().generate_rsa(2048)
 var legacy=Profile.new_profile(key.save_to_string(true),"Synthetic legacy")
 legacy.progression={"tree_version":4,"profile":"world_rise","xp":600,"learned":["iron_body","swiftfoot"],"passives":[],"greatsword_kills":31}
 legacy.copper=77;legacy.resources={"health":43,"stamina":67.125}
 check(Profile.valid(legacy),"strict legitimate original profile accepted")
 for field in ["progression","magic_items","materials","appearance","copper","revision","name","public_key","character_id","schema"]:
  var absent=legacy.duplicate(true);absent.erase(field)
  check(not Profile.valid(absent),"missing portable field fails closed without a runtime error: "+field)
 var overfull=legacy.duplicate(true);overfull.resources.health=100000
 check(not Profile.valid(overfull),"legacy resources above legitimate original maxima rejected")
 var defeated4=legacy.duplicate(true);defeated4.resources={"health":0,"stamina":0.0}
 var defeated4_upgrade=Profile.upgraded(defeated4)
 check(not defeated4_upgrade.is_empty() and defeated4_upgrade.resources.health==0,"original4 defeated health stays zero during direct migration")
 var original_hash=Profile.digest(legacy)
 var client_path=temporary.path_join("client/character.json")
 DirAccess.make_dir_recursive_absolute(client_path.get_base_dir())
 key.save(client_path.get_base_dir().path_join("owner.private.pem"))
 var original_file=Codec.encode(legacy,"character")
 var client_file=FileAccess.open(client_path,FileAccess.WRITE);client_file.store_string(original_file);client_file.close()
 var client=Session.new();client.checkpoint_path=client_path
 check(client.ensure_character() and Profile.digest(client.local_profile)==original_hash,"installed client loads original tree4 without eager migration")
 check(FileAccess.get_file_as_string(client_path)==original_file,"opening old client file leaves disk bytes unchanged")
 client.free()
 var a=Store.new();check(a.open(temporary.path_join("a")),"A opens")
 var old_world=a.data.duplicate(true);old_world.content=Profile.LEGACY_CONTENT_F3111C1;old_world.characters[legacy.character_id]=legacy.duplicate(true)
 var sibling=legacy.duplicate(true);sibling.character_id=Profile.random_id();old_world.characters[sibling.character_id]=sibling
 check(a.commit(old_world),"exact original fingerprint saved through lossless envelope")
 a.stop_worker()
 var reopened=Store.new();check(reopened.open(temporary.path_join("a")),"exact baseline world reopens compatibly")
 check(reopened.data.content==Profile.content_digest(),"world content upgraded durably")
 check(Profile.digest(reopened.data.characters[legacy.character_id])==original_hash,"dormant original character hash unchanged")
 check(Profile.digest(reopened.data.characters[sibling.character_id])==Profile.digest(sibling),"other dormant character hash unchanged")
 var signature=Crypto.new().sign(HashingContext.HASH_SHA256,original_hash.sha256_buffer(),key)
 check(Crypto.new().verify(HashingContext.HASH_SHA256,Profile.digest(legacy).sha256_buffer(),signature,key),"original signed identity survives until import")
 var result=reopened.import_character(legacy)
 check(result.ok,"authenticated original import upgrades")
 if not result.ok:finish([reopened]);return
 var upgraded=result.profile
 check(upgraded.progression.tree_version==6 and upgraded.parent==original_hash and original_hash in upgraded.ancestors,"one migrated checkpoint descends from original raw hash")
 check(upgraded.revision==legacy.revision+1,"migration creates exactly one revision")
 check(upgraded.copper==77 and upgraded.resources==legacy.resources and upgraded.magic_items==legacy.magic_items,"migration preserves economy/resources/equipment")
 check(upgraded.progression.xp==legacy.progression.xp,"migration preserves earned XP")
 check(upgraded.progression.migration_v4.learned==legacy.progression.learned,"original allocation receipt retained exactly")
 var refunded=Growth.new();refunded.restore(upgraded.progression)
 check(refunded.points()==refunded.level()-1,"retired passive ranks refund into earned perk budget")
 client=Session.new();client.checkpoint_path=client_path
 check(client.install_checkpoint(upgraded),"installed client accepts durable upgraded checkpoint")
 check(Profile.digest(Codec.read_file(client_path+".previous","character").data)==original_hash,"client backup preserves exact original accepted profile")
 client.free()
 client=Session.new();client.checkpoint_path=client_path
 check(client.ensure_character() and Profile.digest(client.local_profile)==Profile.digest(upgraded),"installed client reopens exact tree6 checkpoint")
 client.free()
 var revision=upgraded.revision
 result=reopened.import_character(upgraded)
 check(result.ok and result.profile.revision==revision,"repeat current import does not re-migrate")
 var b=Store.new();check(b.open(temporary.path_join("b")),"B opens")
 check(b.import_character(upgraded).ok,"B accepts upgraded A checkpoint")
 var proposed=upgraded.duplicate(true);proposed.copper+=3
 var back=b.checkpoint_character(upgraded.character_id,proposed)
 for index in range(130):back=Profile.checkpoint(back,b.data.world_id,back)
 check(Profile.digest(upgraded) not in back.ancestors and back.anchors.get(reopened.data.world_id)==Profile.digest(upgraded),"bounded ancestry retains original A handoff anchor")
 back=b.checkpoint_character(upgraded.character_id,back)
 check(not back.is_empty(),"long B visit commits durably")
 check(not back.is_empty() and reopened.import_character(back).ok,"upgraded A to B to A preserves lineage")
 var head=Profile.digest(reopened.data.characters[legacy.character_id])
 check(not reopened.import_character(legacy).ok,"stale original cannot fork upgraded lineage")
 check(Profile.digest(reopened.data.characters[legacy.character_id])==head,"rejected stale fork leaves head unchanged")
 var recovered=reopened.import_character(legacy,true)
 check(recovered.ok and recovered.profile.progression.tree_version==6 and Profile.digest(recovered.profile)==head,"explicit recovery selects accepted tree6 without migration")
 var wrong_owner=legacy.duplicate(true);wrong_owner.public_key=Crypto.new().generate_rsa(2048).save_to_string(true)
 check(not reopened.import_character(wrong_owner,true).ok,"recovery cannot change original owner")
 var malformed=legacy.duplicate(true);malformed.progression.learned=["not_a_skill"]
 check(not Profile.valid(malformed) and not reopened.import_character(malformed).ok,"malformed legacy progression rejected before mutation")
 var wrong_content=reopened.data.duplicate(true);wrong_content.content="a".repeat(64)
 check(not Checkpoint.valid(wrong_content),"arbitrary content mismatch rejected")
 var authority=Authority.new();authority.configure(reopened)
 var player=authority.add_player(reopened.data.characters[legacy.character_id])
 check(not player.is_empty(),"production authority admits upgraded character")
 player.health=40;player.stamina=23.5
 var before_action=Profile.digest(player.profile);player.action="attack"
 check(not authority.action(player.id,"attribute",{"attribute":"strength"}).ok and Profile.digest(player.profile)==before_action and player.health==40 and player.stamina==23.5,"direct mid-action progression request preserves profile and resources")
 player.action="free"
 check(authority.action(player.id,"attribute",{"attribute":"strength"}).ok and player.profile.progression.attributes.strength==4,"attribute allocation commits through authority")
 check(player.profile.resources=={"health":40,"stamina":23.5},"progression commit snapshots current wounded resources without healing")
 check(authority.action(player.id,"learn",{"skill":"iron_body"}).ok,"eligible perk commits through authority")
 check(authority.action(player.id,"refund",{"skill":"iron_body"}).ok and "iron_body" not in player.profile.progression.learned,"perk refund commits through authority")
 check(authority.action(player.id,"attribute",{"attribute":"agility"}).ok and authority.action(player.id,"learn",{"skill":"dash"}).ok and authority.action(player.id,"skill_loadout",{"skill":"dash","enabled":true}).ok,"Dash allocated learned and enabled")
 check(authority.action(player.id,"refund",{"skill":"dash"}).ok and not player.profile.skill_loadout.dash,"equipped Dash refund clears loadout atomically")
 check(authority.action(player.id,"learn",{"skill":"dash"}).ok and authority.action(player.id,"skill_loadout",{"skill":"dash","enabled":true}).ok,"Dash re-enabled before reset")
 check(authority.action(player.id,"attribute",{"attribute":"greatsword"}).ok and authority.action(player.id,"learn",{"skill":"charge_thrust"}).ok and authority.action(player.id,"heavy_attack",{"style":"charge_thrust"}).ok,"Charged Thrust allocated learned and equipped")
 player.health=player.max_health;player.stamina=player.max_stamina
 var old_health=player.health
 check(authority.action(player.id,"reset_attributes").ok and player.profile.progression.attribute_reset_used,"one-time attribute reset commits")
 check(not player.profile.skill_loadout.dash and player.profile.heavy_attack=="overhead","reset clears equipped active dependencies in durable profile")
 check(player.profile.resources.health==player.health and player.health==player.max_health and player.health<old_health and player.profile.resources.stamina==player.stamina,"stat reduction clamps durable and runtime resources without healing")
 var stable=Profile.digest(player.profile)
 check(not authority.action(player.id,"reset_attributes").ok and Profile.digest(player.profile)==stable,"repeated reset rejected without mutation")
 reopened.read_only=true
 check(not authority.action(player.id,"attribute",{"attribute":"strength"}).ok and Profile.digest(player.profile)==stable,"failed authoritative spend does not alter accepted character")
 var fresh=legacy.duplicate(true);fresh.character_id=Profile.random_id()
 check(not reopened.import_character(fresh).ok and not reopened.data.characters.has(fresh.character_id),"failed durable upgrade leaves accepted memory unchanged")
 exercise_draft5(key)
 finish([reopened,b])
func exercise_draft5(key:CryptoKey) -> void:
 var old=Profile.new_profile(key.save_to_string(true),"Synthetic five-category draft")
 old.progression={"tree_version":5,"profile":"world_rise","xp":1900,"learned":["dash","belly_roll","charge_thrust","iron_body","deep_reserve"],"passives":[],"greatsword_kills":31,"attributes":{"body":9,"reflexes":4,"precision":3,"endurance":4,"mastery":4},"weapon_kills":{"greatsword":31,"spear":19,"rapier":7,"bow":54},"attribute_reset_used":true,"migration_v4":{"learned":["iron_body","swiftfoot","dash","belly_roll","great_greatsword","charge_thrust"]}}
 old.skill_loadout.dash=true;old.heavy_attack="charge_thrust"
 old.copper=91;old.materials={"green_slime_residue":3};old.magic_items.owned.append("minor_healing_potion");old.magic_items.quantities["minor_healing_potion"]=2
 old.revision=3;old.issuer=Profile.random_id();old.anchors[Profile.random_id()]="c".repeat(64)
 old.resources=Profile.resource_maxima(old)
 check(Profile.valid(old),"strict frozen five-category draft validates independently of current catalog")
 var raw_hash=Profile.digest(old);var original=old.duplicate(true)
 var offline={"version":1,"game_mode":"world_rise","map":"wr_floor_01","position":[0,0],"progression":old.progression.duplicate(true),"magic_items":old.magic_items.duplicate(true),"health":old.resources.health,"stamina":old.resources.stamina,"world_rise":{},"skill_loadout":old.skill_loadout.duplicate(),"heavy_attack":old.heavy_attack}
 var offline_path=temporary.path_join("draft5-offline.json")
 check(OfflineSave.write(offline,offline_path)==OK and not OfflineSave.read(offline_path).is_empty(),"ordinary draft5 save accepts original stat maxima before current runtime conversion")
 var offline_bad=offline.duplicate(true);offline_bad.health+=1;OfflineSave.write(offline_bad,offline_path)
 check(OfflineSave.read(offline_path).is_empty(),"ordinary draft5 save rejects health above its frozen original maximum")
 offline_bad=offline.duplicate(true);offline_bad.stamina+=1;OfflineSave.write(offline_bad,offline_path)
 check(OfflineSave.read(offline_path).is_empty(),"ordinary draft5 save rejects stamina above its frozen original maximum")
 offline.health=43;offline.stamina=23.5;OfflineSave.write(offline,offline_path)
 var offline_wounded=OfflineSave.read(offline_path)
 check(not offline_wounded.is_empty() and offline_wounded.health==43 and offline_wounded.stamina==23.5 and offline_wounded.progression.tree_version==5,"ordinary draft5 reader preserves raw progression and wounds until actual runtime restore")
 var overfull=old.duplicate(true);overfull.resources.health+=1
 check(not Profile.valid(overfull),"draft5 resources validate original five-category maxima before conversion")
 var wounded=old.duplicate(true);wounded.resources={"health":43,"stamina":23.5}
 var wounded_upgrade=Profile.upgraded(wounded)
 check(not wounded_upgrade.is_empty() and wounded_upgrade.resources==wounded.resources,"draft5 wounded resource migration never heals")
 var defeated=old.duplicate(true);defeated.resources={"health":0,"stamina":0.0}
 var dead_upgrade=Profile.upgraded(defeated)
 check(not dead_upgrade.is_empty() and dead_upgrade.resources.health==0 and dead_upgrade.resources.stamina==0,"draft5 defeated character remains at zero resources during migration")
 var malformed=old.duplicate(true);malformed.progression.attributes.erase("body")
 check(not Profile.valid(malformed),"malformed draft5 attribute schema rejected without normalization")
 var client_path=temporary.path_join("draft5-client/character.json")
 DirAccess.make_dir_recursive_absolute(client_path.get_base_dir());key.save(client_path.get_base_dir().path_join("owner.private.pem"))
 var encoded=Codec.encode(old,"character");var client_file=FileAccess.open(client_path,FileAccess.WRITE);client_file.store_string(encoded);client_file.close()
 var client=Session.new();client.checkpoint_path=client_path
 check(client.ensure_character() and Profile.digest(client.local_profile)==raw_hash and FileAccess.get_file_as_string(client_path)==encoded,"draft5 installed client preserves original profile and file bytes before authentication")
 client.free()
 var a=Store.new();check(a.open(temporary.path_join("draft5-a")),"draft5 world A opens")
 var prior=a.data.duplicate(true);prior.content=Profile.LEGACY_CONTENT_4177E44;prior.characters[old.character_id]=old.duplicate(true)
 var dormant=old.duplicate(true);dormant.character_id=Profile.random_id();prior.characters[dormant.character_id]=dormant
 check(a.commit(prior),"exact prior draft5 world fingerprint and original records commit")
 check(not a.import_character(overfull).ok and Profile.digest(a.data.characters[old.character_id])==raw_hash,"malformed old resources rejected before migration without changing raw registry")
 a.stop_worker();a=Store.new();check(a.open(temporary.path_join("draft5-a")),"exact prior draft5 world reopens through narrow content allowlist")
 check(a.data.content==Profile.content_digest() and Profile.digest(a.data.characters[old.character_id])==raw_hash and Profile.digest(a.data.characters[dormant.character_id])==Profile.digest(dormant),"draft world fingerprint upgrade preserves all dormant original hashes")
 var result=a.import_character(old)
 check(result.ok,"draft5 accepted original lineage upgrades")
 if not result.ok:a.stop_worker();return
 var upgraded=result.profile
 check(upgraded.progression.tree_version==6 and upgraded.revision==4 and upgraded.parent==raw_hash and raw_hash in upgraded.ancestors,"draft5 creates exactly one tree6 checkpoint parented to original raw head")
 check(upgraded.progression.migration_v5==original.progression and upgraded.progression.migration_v4==original.progression.migration_v4,"bounded draft5 allocation receipt preserves exact original and nested tree4 receipt")
 check(upgraded.progression.xp==old.progression.xp and upgraded.progression.weapon_kills==old.progression.weapon_kills and upgraded.progression.attribute_reset_used,"draft5 migration preserves XP every weapon practice and used reset")
 check(upgraded.progression.learned==["dash","belly_roll","charge_thrust"] and upgraded.skill_loadout==old.skill_loadout and upgraded.heavy_attack==old.heavy_attack,"draft5 migration retains all active abilities and loadout")
 check(upgraded.copper==old.copper and upgraded.materials==old.materials and upgraded.magic_items==old.magic_items,"draft5 migration preserves economy gear and item stacks")
 var maximum=Profile.resource_maxima(upgraded)
 check(upgraded.resources.health==maximum.health and upgraded.resources.stamina==maximum.stamina and upgraded.resources.health<old.resources.health and upgraded.resources.stamina<old.resources.stamina,"draft5 original full resources clamp to reduced three-category maxima without healing")
 for world_id in old.anchors:check(upgraded.anchors.get(world_id)==old.anchors[world_id],"draft5 migration retains original handoff anchor")
 check(Profile.digest(old)==raw_hash,"draft5 migration leaves caller raw accepted profile unchanged")
 var growth=Growth.new();growth.restore(upgraded.progression)
 check(growth.attribute_points()==7+growth.level()-1-2 and growth.points()==growth.level()-1-3,"draft5 attributes and retired passive ranks refund within earned budgets")
 check(not growth.reset_attributes(),"draft5 migration cannot restore spent one-time reset")
 var repeated=a.import_character(upgraded)
 check(repeated.ok and repeated.profile.revision==upgraded.revision,"current tree6 does not repeatedly migrate draft5 receipt")
 var b=Store.new();check(b.open(temporary.path_join("draft5-b")),"fresh B opens after draft5 upgrade")
 check(b.import_character(upgraded).ok,"fresh B imports legitimate upgraded draft5 descendant")
 var proposal=upgraded.duplicate(true);proposal.copper+=4
 var returning=b.checkpoint_character(old.character_id,proposal)
 check(not returning.is_empty() and a.import_character(returning).ok,"draft5 to tree6 A to B to A preserves cross-world lineage")
 var head=Profile.digest(a.data.characters[old.character_id])
 check(not a.import_character(old).ok and Profile.digest(a.data.characters[old.character_id])==head,"stale raw draft5 cannot overwrite upgraded current branch")
 var recovered=a.import_character(old,true)
 check(recovered.ok and recovered.profile.progression.tree_version==6 and Profile.digest(recovered.profile)==head,"draft5 explicit recovery resolves durable tree6 before considering migration")
 var client2=Session.new();client2.checkpoint_path=client_path
 check(client2.install_checkpoint(recovered.profile),"draft5 client installs accepted current checkpoint")
 client2.free();client2=Session.new();client2.checkpoint_path=client_path
 check(client2.ensure_character() and Profile.digest(client2.local_profile)==head,"draft5 installed file reopens exact upgraded tree6 after cross-world return")
 client2.free();a.stop_worker();b.stop_worker()
func finish(stores:Array) -> void:
 for storage in stores:storage.stop_worker()
 remove_tree(temporary)
 print("WR_PROGRESSION_MIGRATION_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
func remove_tree(path:String) -> void:
 var directory=DirAccess.open(path)
 if directory==null:return
 for name in directory.get_files():DirAccess.remove_absolute(path.path_join(name))
 for name in directory.get_directories():remove_tree(path.path_join(name))
 DirAccess.remove_absolute(path)
