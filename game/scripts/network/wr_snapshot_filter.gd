extends RefCounted
## Select immutable published state without copying the entire world per peer.
## Records are borrowed read-only until synchronous serialization completes.
static func personal(snapshot:Dictionary,recipient:Dictionary,authority:RefCounted) -> Dictionary:
	var result=snapshot.duplicate(false)
	result.players={};result.claims={};result.enemies={};result.projectiles={};result.native_effects={}
	var origin=authority.vec(recipient.position)
	for id in snapshot.players:
		var source=snapshot.players[id]
		if source.floor!=recipient.floor:continue
		var record=source.duplicate(false)
		if id==recipient.id:
			record.profile=source.profile.duplicate(true)
			record.profile.erase("ancestors");record.profile.erase("anchors")
		else:record.erase("profile")
		result.players[id]=record
	var item_claims=[];var arrow_claims=[]
	for id in snapshot.claims:
		var claim=snapshot.claims[id]
		if (claim.owner!=recipient.id and not claim.get("arrow",false)) or claim.floor!=recipient.floor or authority.vec(claim.position).distance_to(origin)>110:continue
		var candidates=arrow_claims if claim.get("arrow",false) else item_claims
		candidates.append({"id":id,"distance":authority.vec(claim.position).distance_squared_to(origin)})
	for selection in [[item_claims,64],[arrow_claims,32]]:
		var candidates=selection[0]
		if candidates.size()>selection[1]:
			candidates.sort_custom(func(a,b):return a.distance<b.distance if a.distance!=b.distance else String(a.id)<String(b.id))
		for index in range(mini(candidates.size(),selection[1])):
			var id=candidates[index].id;result.claims[id]=snapshot.claims[id]
	for id in snapshot.enemies:
		var enemy=snapshot.enemies[id]
		if enemy.floor!=recipient.floor or enemy.health<=0 or authority.vec(enemy.position).distance_to(origin)>110 or not authority.enemy_active(enemy):continue
		result.enemies[id]=enemy
	for id in snapshot.projectiles:
		var projectile=snapshot.projectiles[id]
		if projectile.floor==recipient.floor:result.projectiles[id]=projectile
	for id in snapshot.get("native_effects",{}):
		var effect=snapshot.native_effects[id]
		if effect.floor==recipient.floor and authority.vec(effect.position).distance_to(origin)<=110:result.native_effects[id]=effect
	return result
