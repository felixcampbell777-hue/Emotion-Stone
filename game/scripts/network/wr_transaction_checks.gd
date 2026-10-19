extends SceneTree
## Focused fault injection at the authority's real settlement boundary. Native
## combat/physics and real filesystem durability are covered by separate fixtures.
const Authority=preload("res://scripts/network/wr_authority.gd")
const Profile=preload("res://scripts/network/wr_profile.gd")
class Storage extends RefCounted:
 var data={"schema":1,"world_id":"0123456789abcdef0123456789abcdef","characters":{},"visitors":{},"encounters":{},"claims":{},"flags":[],"transactions":{},"day_clock":0.0}
 var read_only=false
 var last_error=""
 var attempts=0
 func commit(proposed:Dictionary) -> bool:
  attempts+=1
  if read_only:last_error="Injected disk full";return false
  data=proposed.duplicate(true);last_error="";return true
var checks=0
var failures=[]
func verify(condition:bool,label:String) -> void:
 checks+=1
 if not condition:failures.append(label);push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var key=Crypto.new().generate_rsa(2048)
 var store=Storage.new();var authority=Authority.new();authority.configure(store)
 var profile=Profile.new_profile(key.save_to_string(true));var id=String(profile.character_id)
 store.data.characters[id]=profile.duplicate(true);var p=authority.add_player(profile)
 var e=authority.enemies["wr_boss_chamber/vault_elder"]
 p.floor=e.floor;p.position=e.position.duplicate();p.health=100;p.weapon="standard_greatsword"
 e.contributors[id]=0.0;e.health=0;e.last_attacker=id;e.last_weapon="greatsword"
 # Positive accepted weapon damage is separate from targeting/XP participation.
 e.practice_contributors={id:["greatsword"]}
 store.read_only=true;authority.settle_kill(e,id)
 verify(authority.persistence_failed and authority.pending_settlements.size()==1,"Failed reward is staged for retry")
 verify(store.data.characters[id].progression.xp==0 and store.data.transactions.is_empty(),"Failed commit cannot acknowledge or persist unpaid death")
 verify(authority.save_departure(id).is_empty(),"Export cannot bypass a pending reward")
 var staged=authority.pending_settlements.values()[0].next.characters[id].duplicate(true)
 store.read_only=false;authority.step(.016)
 verify(not authority.persistence_failed and authority.pending_settlements.is_empty(),"Storage recovery retries staged settlement")
 verify(store.data.characters[id].progression.xp==1500,"Elder settlement preserves repeatable plus first bonus")
 verify(store.data.characters[id].progression.greatsword_kills==1,"Accepted greatsword contribution earns exactly one practice credit")
 verify(Profile.digest(store.data.characters[id])==Profile.digest(staged),"Retry installs identical rolled/profile proposal")
 authority.settle_kill(e,id)
 verify(store.data.characters[id].progression.xp==1500,"Replayed settlement cannot pay twice")
 p.last_combat=1079.0;authority.elapsed=1081.0;authority.clock=1.0;p.pvp=true
 verify(not authority.action(id,"pvp",{"enabled":false}).ok,"Day rollover cannot erase combat timeout")
 authority.elapsed=1090.0
 verify(authority.action(id,"pvp",{"enabled":false}).ok,"PvP delay ends by monotonic gameplay time")
 var invalid=p.profile.duplicate(true);invalid.appearance={"resource":"res://scripts/main.gd"}
 verify(not Profile.valid(invalid),"Network appearance uses canonical allowlist")
 p.profile.magic_items.owned.append("wooden_arrows");p.profile.magic_items.quantities["wooden_arrows"]=99
 store.data.characters[id]=p.profile.duplicate(true)
 store.data.claims["miss"]={"owner":id,"floor":p.floor,"position":p.position.duplicate(),"arrow":true,"items":{}}
 verify(not authority.economy(p,"loot",{"claim":"miss"}).ok and store.data.claims.has("miss"),"Full arrow stack retains recoverable world claim")
 p.profile.magic_items.owned.append("guild_healing_potion");p.profile.magic_items.quantities["guild_healing_potion"]=2
 store.data.characters[id]=p.profile.duplicate(true);p.health=40
 var potion_before=Profile.digest(p.profile);store.read_only=true
 verify(not authority.economy(p,"drink",{"item":"guild_healing_potion"}).ok and p.health==40 and Profile.digest(p.profile)==potion_before,"Failed burst-potion write preserves bottle profile and wounded runtime")
 store.read_only=false
 verify(authority.economy(p,"drink",{"item":"guild_healing_potion"}).ok and p.health==65 and p.profile.resources.health==65 and store.data.characters[id].resources.health==65 and p.profile.magic_items.quantities.guild_healing_potion==1,"Consumed instant potion and burst heal commit together without double healing")
 p.health=p.max_health-5
 verify(authority.economy(p,"drink",{"item":"guild_healing_potion"}).ok and p.health==p.max_health and p.profile.resources.health==p.max_health and "guild_healing_potion" not in p.profile.magic_items.owned,"Final burst potion caps durable health and removes exhausted stack together")
 print("WR_TRANSACTION_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
