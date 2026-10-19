extends SceneTree
const Adapter=preload("res://scripts/network/wr_world_adapter.gd")
var failures=0
func check(ok:bool,message:String) -> void:
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:
	var adapter=Adapter.new();var seen={}
	for floor_id in adapter.FLOORS:
		var arrival=adapter.floor_arrival(floor_id)
		check(adapter.safe_position(floor_id,arrival),"Arrival must be supported on "+floor_id)
		check(is_finite(adapter.ground_height(floor_id,arrival)),"Finite terrain on "+floor_id)
		for entry in adapter.encounter_entries(floor_id):
			var key=floor_id+"/"+entry.id
			check(not seen.has(key),"Stable unique encounter "+key);seen[key]=true
			check(entry.max_health>0 and entry.damage>=0 and entry.xp>=0,"Authored stats "+key)
	var fen=adapter.encounter_entries("wr_floor_02")
	check(fen.filter(func(e):return e.kind=="giant_green_slime").size()==7,"Seven permanent Floor Two giants")
	check(fen.filter(func(e):return e.has("parent_id")).size()==28,"Four distinct split IDs per giant")
	for child in fen.filter(func(e):return e.has("parent_id")):
		check(child.max_health==45 and child.damage==8 and child.xp==18,"Exact split reward/stats")
	var rng=RandomNumberGenerator.new();rng.seed=91
	for child in fen.filter(func(e):return e.has("parent_id")):
		var reward=adapter.roll_rewards(child,rng)
		check(reward.copper>=5 and reward.copper<=6,"Split copper remains 5-6")
		check(not reward.items.has("green_slime_core"),"No Floor Two cores")
	var tree=adapter.Rise.spec.trees[0];var center=Vector3(tree[0],adapter.Rise.height(Vector3(tree[0],0,tree[1]))+.7,tree[1])
	if Vector2(tree[0]+168,tree[1]+125).length()>=10:
		check(adapter.impact_blocked("wr_floor_01",center-Vector3(3,0,0),center+Vector3(3,0,0)),"Server rays preserve tree collision")
	var elder=adapter.encounter_entries("wr_boss_chamber")[0]
	check(elder.max_health==1100 and elder.xp==500 and elder.first_bonus==1000 and elder.cooldown==1080,"Elder exact reward/cooldown")
	var ash=adapter.encounter_entries("wr_floor_01").filter(func(e):return e.id=="ashfang")[0]
	check(ash.night_only and ash.max_health==360 and ash.first_bonus==200 and ash.cooldown==1080,"Ashfang night/cooldown/bonus")
	print("World adapter checks: ",seen.size()," authored identities; failures=",failures)
	quit(1 if failures else 0)
