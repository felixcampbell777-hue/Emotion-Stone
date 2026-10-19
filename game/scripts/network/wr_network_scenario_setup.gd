extends SceneTree
## Disposable production load-test setup. Never reads or writes an offline save.
const Profile=preload("res://scripts/network/wr_profile.gd")
const Store=preload("res://scripts/network/wr_store.gd")
const Adapter=preload("res://scripts/network/wr_world_adapter.gd")
const Economy=preload("res://scripts/network/wr_economy.gd")
const Storage=preload("res://scripts/network/wr_storage_codec.gd")
func _initialize() -> void:
	var destination=""
	var scenario_kind="authored-eight"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario-root="):destination=arg.trim_prefix("--scenario-root=")
		if arg.begins_with("--scenario-kind="):scenario_kind=arg.trim_prefix("--scenario-kind=")
	if scenario_kind not in ["authored-eight","pvp-arrow","pvp-arrow-wall"]:push_error("Unknown fixture scenario kind");quit(1);return
	var pvp_scenario=scenario_kind in ["pvp-arrow","pvp-arrow-wall"]
	if not destination.is_absolute_path() or destination.begins_with(ProjectSettings.globalize_path("res://")):
		push_error("Use an absolute disposable --scenario-root outside the checkout");quit(1);return
	if DirAccess.dir_exists_absolute(destination):
		push_error("Scenario directory must be new to avoid replacing a checkpoint");quit(1);return
	DirAccess.make_dir_recursive_absolute(destination)
	var world=Adapter.new();var store=Store.new()
	if not store.open(destination.path_join("server")):push_error(store.last_error);quit(1);return
	var next=store.data.duplicate(true);next.day_clock=0.0 if pvp_scenario else 700.0;next.flags=["elder_defeated"]
	var registry=[]
	var giant=world.encounter_entries("wr_floor_02").filter(func(entry):return entry.kind=="giant_green_slime")[0]
	for i in range(2 if pvp_scenario else 8):
		var key=Crypto.new().generate_rsa(2048);var profile=Profile.new_profile(key.save_to_string(true),"Load participant %d"%(i+1));profile.copper=1000;profile.progression.xp=1000
		if pvp_scenario:
			profile.magic_items.owned=["standard_greatsword","field_spear","duelist_rapier","hunting_bow","wooden_arrows","guild_healing_potion"];profile.magic_items.quantities={"wooden_arrows":20,"guild_healing_potion":20}
		if not Profile.valid(profile) or int(profile.progression.get("tree_version",0))!=6:push_error("Invalid current tree6 disposable profile "+str(i));quit(1);return
		var directory=destination.path_join("client-%d"%i);DirAccess.make_dir_recursive_absolute(directory)
		if key.save(directory.path_join("owner.private.pem"))!=OK:push_error("Cannot save disposable client credential");quit(1);return
		var file=FileAccess.open(directory.path_join("portable.json"),FileAccess.WRITE);file.store_string(Storage.encode(profile,"character"));file.close()
		var floor_id="wr_floor_01";var front=Vector3(0,0,-1.7).rotated(Vector3.UP,float(preload("res://scripts/rise_shape.gd").spec.guild.rotation))
		var at=Economy.vendor_position(floor_id,"wr_swords")+front+Vector3((i%2)*.6-.3,0,(i/2)*.5-.25)
		var role="vendor";var weapon=["field_spear","duelist_rapier","hunting_bow","improved_standard_greatsword"][i%4]
		if pvp_scenario:
			at=guild_point(8.0 if i==0 else 6.8,-.2) if scenario_kind=="pvp-arrow-wall" else Vector3(0,0,.6 if i==0 else -.6);role="pvp_arrow";weapon=""
		elif i in [4,5]:
			floor_id="wr_floor_02";at=Vector3(giant.at[0]+(-.7 if i==4 else .7),0,giant.at[1]+2.0);role="fen_combat";weapon="standard_greatsword"
		elif i>=6:
			floor_id="wr_boss_chamber";at=Vector3(-1 if i==6 else 1,0,-2);role="vault_combat";weapon="standard_greatsword"
		at.y=world.ground_height(floor_id,at)
		if not world.safe_position(floor_id,at):push_error("Fixture position is not safe: participant "+str(i));quit(1);return
		next.characters[profile.character_id]=profile
		next.visitors[profile.character_id]={"floor":floor_id,"position":[at.x,at.y,at.z],"discoveries":{floor_id:["arrival"]},"checkpoint":{floor_id:[at.x,at.y,at.z]},"contracts":{}}
		registry.append({"index":i,"id":profile.character_id,"checkpoint":directory.path_join("portable.json"),"floor":floor_id,"role":role,"purchase_item":weapon,"position":[at.x,at.y,at.z],"yaw":(PI*.75 if i==0 else -PI*.25) if scenario_kind=="pvp-arrow-wall" else PI if pvp_scenario and i==1 else 0.0,"pitch":0.0})
	if not store.commit(next):push_error(store.last_error);quit(1);return
	var occlusion_route=[]
	for point in [Vector2(3.5,-.2),Vector2(3.5,-7.5),Vector2(0,-7.5),Vector2(0,-10.5),Vector2(12,-10.5),Vector2(12,-.2),Vector2(12,2.8)]:occlusion_route.append(vector_array(guild_point(point.x,point.y)))
	var occlusion_hint={"inside_position":vector_array(guild_point(10,2.8)),"inside_walk_route":[vector_array(guild_point(10,-.2)),vector_array(guild_point(10,2.8))],"inside_yaw":-PI*.25,"outside_position":vector_array(guild_point(12,2.8)),"outside_yaw":PI*.75,"outside_walk_route":occlusion_route,"inside_return_position":vector_array(guild_point(8,-.2)),"outside_return_position":vector_array(guild_point(6.8,-.2)),"wall":"authored guild east plaster bay local x=11,z=2.8; use reverse routes to return"}
	var file=FileAccess.open(destination.path_join("scenario.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"progression_tree_version":6,"content_digest":Profile.content_digest(),"server":destination.path_join("server"),"night_clock":next.day_clock,"scenario_kind":scenario_kind,"clients":registry,"missed_arrow_hint":{"origin":"same arrival platform","pitch_down":0.9,"yaw_sideways":PI*.5,"recover_distance":3.0},"occlusion_hint":occlusion_hint,"near_wall_hint":{"position":vector_array(guild_point(10.5,-.2)),"yaw":-PI*.25,"return_position":vector_array(guild_point(8,-.2)),"return_yaw":PI*.75}},"\t"));file.close()
	print("NETWORK_SCENARIO_READY ",destination.path_join("scenario.json"));quit()

func guild_point(x:float,z:float) -> Vector3:
	var spec=preload("res://scripts/rise_shape.gd").spec.guild
	return Vector3(spec.at[0],spec.height,spec.at[1])+Vector3(x,0,z).rotated(Vector3.UP,float(spec.rotation))
func vector_array(at:Vector3) -> Array:return [at.x,at.y,at.z]
