extends SceneTree
const Runtime=preload("res://scripts/network/wr_floor_runtime.gd")
const Codec=preload("res://scripts/network/wr_storage_codec.gd")
const Adapter=preload("res://scripts/network/wr_world_adapter.gd")
var failures=0
var checks=0
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	check(Runtime.NATIVE_STATE_FIELDS.size()==Runtime.NATIVE_STATE_TYPES.size() and Runtime.NATIVE_STATE_FIELDS.all(func(field):return Runtime.NATIVE_STATE_TYPES.has(field)),"Every retained native state field has one explicit persistent type")
	var adapter=Adapter.new();var floors={}
	for floor_id in adapter.FLOORS:
		var runtime=Runtime.new();root.add_child(runtime);runtime.setup(floor_id,adapter);floors[floor_id]=runtime
	await physics_frame
	var fen=floors.wr_floor_02;var rise=floors.wr_floor_01
	var merchant=preload("res://scripts/network/wr_economy.gd").vendor_position("wr_floor_01","wr_swords")
	var stand=merchant+Vector3(0,0,-1.7).rotated(Vector3.UP,float(adapter.Rise.spec.guild.rotation))
	check(rise.valid_player_position(stand),"Actual capsule accepts walkable guild counter front")
	check(not rise.valid_player_position(merchant),"NPC interaction marker inside counter is not a player spawn")

	var child=adapter.encounter_entries("wr_floor_02")[0];var at=Vector3(child.at[0],0,child.at[1]);at.y=adapter.ground_height("wr_floor_02",at)
	fen.sync_players([{"id":"fen_player","position":[at.x,at.y,at.z],"health":100}])
	var pack=adapter.encounter_entries("wr_floor_01")[0];var p=Vector3(pack.at[0],0,pack.at[1]);p.y=adapter.ground_height("wr_floor_01",p)
	rise.sync_players([{"id":"rise_player","position":[p.x,p.y,p.z],"health":100}])
	fen.step(1.0/60);rise.step(1.0/60)
	check(fen.enemies.size()>0 and rise.enemies.size()>0,"Two distinct occupied floors retain actual enemies")
	check(fen.world_root.get_world_3d()!=rise.world_root.get_world_3d(),"Floor collision spaces isolated")
	var enemy=fen.enemies[0];var id=enemy.definition.id
	check(fen.apply_enemy_damage(id,1,Vector3.ZERO),"Actual controller accepts hit")
	check(enemy.health==enemy.max_health-1,"Controller owns live health")
	enemy.state="giant_warn";enemy.state_time=.42;enemy.jump_target=Vector3(4,2,8)
	var native_state=JSON.parse_string(JSON.stringify(fen.capture_enemy_state(enemy)))
	enemy.state="idle";enemy.state_time=0;enemy.jump_target=Vector3.ZERO
	fen.restore_enemy_state(enemy,native_state)
	check(enemy.state=="giant_warn" and is_equal_approx(enemy.state_time,.42) and enemy.jump_target==Vector3(4,2,8),"Native action clock and trajectory survive JSON roundtrip")
	check(enemy.state_time is float,"Native clock restores its declared floating type after an integer-zero reset")
	var clock=.420000000000031
	enemy.state="giant_warn";enemy.state_time=clock;enemy.jump_target=Vector3(4.125,2.5,8.75);enemy.jump_clock=.187500000000019
	var exact_state=fen.capture_enemy_state(enemy)
	var path="user://floor-runtime-native-state.json"
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(Codec.encode({"native_state":exact_state},"world"));file.close()
	var stored=Codec.read_file(path,"world");DirAccess.remove_absolute(path)
	check(stored.ok and var_to_bytes(stored.data.native_state)==var_to_bytes(exact_state),"Production lossless world-file envelope preserves exact native state bytes")
	enemy.state="idle";enemy.state_time=0;enemy.jump_clock=0;enemy.jump_target=Vector3.ZERO
	if stored.ok:fen.restore_enemy_state(enemy,stored.data.native_state)
	check(enemy.state=="giant_warn" and enemy.state_time==clock and enemy.jump_clock==.187500000000019 and enemy.jump_target==Vector3(4.125,2.5,8.75),"Production world-file restore preserves exact active clocks and trajectory after integer resets")
	var restored_clock=enemy.state_time;var restored_phase=enemy.phase
	enemy.bounce_count=0.0
	fen.restore_enemy_state(enemy,{"target":"fen_player","bounce_count":2})
	check(enemy.bounce_count is int and enemy.bounce_count==2,"Integer native counters restore by schema even when their temporary current Variant is float")
	fen.restore_enemy_state(enemy,{"target":"fen_player","state_time":INF,"jump_clock":"0.5","phase":100000001.0,"bounce_count":1.5})
	check(enemy.state_time==restored_clock and enemy.jump_clock==.187500000000019 and enemy.phase==restored_phase and enemy.bounce_count==2,"Native restore still rejects nonfinite out-of-range wrong-type clocks and fractional counters")
	enemy.bounce_count=0
	enemy.state="idle"

	check(rise.enemies[0].player.character_id=="rise_player" and enemy.player.character_id=="fen_player","Targets never cross floor")
	# Rest/death of one participant cannot reset a damaged encounter near another.
	fen.sync_players([{"id":"friend","position":[at.x,at.y,at.z],"health":100}])
	fen.process_empty_resets(61)
	check(enemy.health==enemy.max_health-1,"Present friend protects damaged encounter from reset")
	fen.sync_players([]);fen.process_empty_resets(29)
	check(enemy.health==enemy.max_health-1,"Empty-area grace preserves partial encounter")
	fen.process_empty_resets(2)
	check(int(fen.generation.get(id,0))==1,"Empty and unengaged encounter increments generation once after delay")
	var vault=floors.wr_boss_chamber
	vault.sync_players([{"id":"vault_a","position":[0,0,-3],"health":100},{"id":"vault_b","position":[1,0,-3],"health":100}])
	vault.spawn_entry(adapter.encounter_entries("wr_boss_chamber")[0])
	var damaged=[]
	vault.player_damaged.connect(func(character_id,_amount,_away):damaged.append(character_id))
	vault.enemies[0].strike(5.5,30,true)
	check("vault_a" in damaged and "vault_b" in damaged,"Native Elder slam tests every player body")
	print("FLOOR_RUNTIME_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
	for runtime in floors.values():runtime.queue_free()
	await process_frame
	quit(1 if failures else 0)
