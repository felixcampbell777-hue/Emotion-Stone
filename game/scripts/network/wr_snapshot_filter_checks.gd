extends SceneTree
const Filter=preload("res://scripts/network/wr_snapshot_filter.gd")
class Authority extends RefCounted:
	func vec(value:Array) -> Vector3:return Vector3(value[0],value[1],value[2])
	func enemy_active(enemy:Dictionary) -> bool:return enemy.get("active",true)
var checks=0
var failures=[]
func check(value:bool,label:String) -> void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func legacy(snapshot:Dictionary,p:Dictionary,authority:RefCounted) -> Dictionary:
	var personal=snapshot.duplicate(true)
	if personal.players.has(p.id):
		personal.players[p.id].profile.erase("ancestors");personal.players[p.id].profile.erase("anchors")
	personal.claims=personal.claims.duplicate(true)
	for id in personal.claims.keys():
		var claim=personal.claims[id]
		if (claim.owner!=p.id and not claim.get("arrow",false)) or claim.floor!=p.floor or authority.vec(claim.position).distance_to(authority.vec(p.position))>110:personal.claims.erase(id)
	for id in personal.players.keys():
		if personal.players[id].floor!=p.floor:personal.players.erase(id);continue
		if id!=p.id:personal.players[id].erase("profile")
	for id in personal.enemies.keys():
		var enemy=personal.enemies[id]
		if enemy.floor!=p.floor or enemy.health<=0 or authority.vec(enemy.position).distance_to(authority.vec(p.position))>110 or not authority.enemy_active(enemy):personal.enemies.erase(id)
	for id in personal.projectiles.keys():
		if personal.projectiles[id].floor!=p.floor:personal.projectiles.erase(id)
	for id in personal.native_effects.keys():
		var effect=personal.native_effects[id]
		if effect.floor!=p.floor or authority.vec(effect.position).distance_to(authority.vec(p.position))>110:personal.native_effects.erase(id)
	return personal
func _initialize() -> void:
	var authority=Authority.new()
	var profile={"ancestors":["private"],"anchors":{"world":"private"},"resources":{"health":90}}
	var snapshot={"tick":100,"players":{},"claims":{},"enemies":{},"projectiles":{},"native_effects":{},"voice_roster":{"all":"unchanged"},"events":[{"kind":"test"}],"flags":["elder_defeated"]}
	for id in ["self","friend","other_floor"]:snapshot.players[id]={"id":id,"floor":"wr_floor_02" if id=="other_floor" else "wr_floor_01","position":[0,0,0],"profile":profile.duplicate(true),"pose_state":{"native_bones":[1,2,3]}}
	for id in ["own","foreign","arrow","far","other_floor"]:snapshot.claims[id]={"owner":"self" if id!="foreign" else "friend","floor":"wr_floor_02" if id=="other_floor" else "wr_floor_01","position":[111 if id=="far" else 1,0,0],"arrow":id=="arrow"}
	for id in ["near","far","dead","inactive","other_floor"]:snapshot.enemies[id]={"floor":"wr_floor_02" if id=="other_floor" else "wr_floor_01","position":[111 if id=="far" else 1,0,0],"health":0 if id=="dead" else 10,"active":id!="inactive"}
	for id in ["near","far","other_floor"]:
		var record={"floor":"wr_floor_02" if id=="other_floor" else "wr_floor_01","position":[111 if id=="far" else 1,0,0]}
		snapshot.projectiles[id]=record;snapshot.native_effects[id]=record
	var before=var_to_bytes(snapshot)
	for id in snapshot.players:
		var result=Filter.personal(snapshot,snapshot.players[id],authority)
		check(result==legacy(snapshot,snapshot.players[id],authority),"Exact legacy selection parity for "+id)
		check(var_to_bytes(snapshot)==before,"Filtering preserves immutable source for "+id)
		for visible_id in result.players:
			check((visible_id==id)==result.players[visible_id].has("profile"),"Only recipient owns private profile "+visible_id)
		result.players[id].profile.resources.health=1
		check(var_to_bytes(snapshot)==before,"Recipient private nested fields remain independent")
	for index in range(100):
		snapshot.claims["item_%03d"%index]={"owner":"self","floor":"wr_floor_01","position":[index,0,0],"arrow":false}
		snapshot.claims["arrow_%03d"%index]={"owner":"foreign","floor":"wr_floor_01","position":[index,0,0],"arrow":true}
	before=var_to_bytes(snapshot)
	var bounded=Filter.personal(snapshot,snapshot.players.self,authority)
	check(bounded.claims.size()==96,"Client claim visibility is bounded to 64 item claims and 32 arrows")
	check(bounded.claims.has("item_000") and not bounded.claims.has("item_099"),"Nearest owned earned claims are selected")
	check(bounded.claims.has("arrow_000") and not bounded.claims.has("arrow_099"),"Nearest shared arrows are selected")
	check(var_to_bytes(snapshot)==before and snapshot.claims.size()==205,"Unselected earned claims remain intact in server state")
	for id in snapshot.claims.keys():
		if id.begins_with("item_") or id.begins_with("arrow_"):
			if snapshot.claims[id].position[0]<99:snapshot.claims.erase(id)
	var revealed=Filter.personal(snapshot,snapshot.players.self,authority)
	check(revealed.claims.has("item_099") and revealed.claims.has("arrow_099"),"Later claims become accessible after nearer pickups")
	print("SNAPSHOT_FILTER_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
