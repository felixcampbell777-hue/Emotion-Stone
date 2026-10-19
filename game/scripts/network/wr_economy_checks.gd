extends SceneTree
const Economy=preload("res://scripts/network/wr_economy.gd")
class Authority extends RefCounted:
	var store={"data":{"visitors":{},"flags":[]}}
	func fail(error:String) -> Dictionary:return {"ok":false,"error":error}
	func finish_economy(p:Dictionary,profile:Dictionary,next:Dictionary) -> Dictionary:
		p.profile=profile;store.data=next;return {"ok":true}
var failures=0
func check(ok:bool,message:String) -> void:
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:
	var authority=Authority.new();var at=Economy.vendor_position("wr_floor_01","wr_swords")
	var p={"id":"test","floor":"wr_floor_01","position":[at.x,at.y,at.z],"health":100,"profile":{"copper":100,"materials":{},"magic_items":{"owned":[],"quantities":{}},"progression":{"xp":0}}}
	check(Economy.transact(authority,p,"purchase",{"item":"wooden_arrows","count":10}).ok,"Normal finite arrow purchase")
	check(p.profile.copper==90 and p.profile.magic_items.quantities.wooden_arrows==10,"Cost/count atomic")
	check(not Economy.transact(authority,p,"purchase",{"item":"wooden_arrows","count":90}).ok,"Reject stack overflow")
	check(p.profile.copper==90 and p.profile.magic_items.quantities.wooden_arrows==10,"Denied transaction unchanged")
	p.position=[0,0,0]
	check(not Economy.transact(authority,p,"purchase",{"item":"wooden_arrows","count":1}).ok,"Vendor requires physical proximity")
	at=Economy.vendor_position("wr_floor_01","wr_clerk");p.position=[at.x,at.y,at.z]
	check(Economy.transact(authority,p,"contract",{"id":"boar"}).ok,"Accept normal hunt")
	for i in range(10):Economy.record_kill(authority.store.data,"test","library_boar")
	check(Economy.transact(authority,p,"contract",{"id":"boar"}).ok,"Turn in participating kill contract")
	var copper=p.profile.copper;var xp=p.profile.progression.xp
	check(not Economy.transact(authority,p,"contract",{"id":"boar"}).ok,"Contract cannot pay twice")
	check(p.profile.copper==copper and p.profile.progression.xp==xp,"Replay does not reward")
	print("Authoritative economy checks failures=",failures);quit(1 if failures else 0)
