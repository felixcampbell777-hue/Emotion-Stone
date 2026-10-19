extends SceneTree
## Actual shared Menagerie/debug grants must remain readable by strict save validation.
var game:Control
var checks=0
var failures:Array=[]
const PATH="user://magic-claim-save-check.json"
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func button_named(node:Node,text:String) -> Button:
	if node is Button and node.text==text:return node
	for child in node.get_children():
		var found=button_named(child,text)
		if found!=null:return found
	return null
func round_trip(label:String) -> void:
	var saved=game.save_data()
	check(game.Save.write(saved,PATH)==OK,label+" writes through actual Save.write")
	var restored=game.Save.read(PATH)
	check(not restored.is_empty(),label+" passes strict Save.read")
	if not restored.is_empty():check(game.apply_save(restored),label+" applies to reused real Actor")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	for i in range(3):await physics_frame
	game.set_process_input(false);game.set_process_unhandled_input(false);game.set_process_unhandled_key_input(false)
	game.game_mode="alpha";game.start_new_game(false);game.title_screen.hide()
	game.load_map("menagery",Vector2(10,0),true)
	game.menagery.toggle()
	var gear=game.magic_items
	var codex=game.menagery.codex
	var arrow_index=gear.catalog.items.find(gear.item("wooden_arrows"))
	check(arrow_index>=0,"Shared codex contains arrow specimen")
	if arrow_index>=0:
		var card=codex.list.get_child(arrow_index).get_child(0).get_child(1)
		card.get_child(2).pressed.emit()
	check(gear.quantities.get("wooden_arrows",0)==1 and gear.owned.count("wooden_arrows")==1,"Actual individual codex button grants one counted arrow")
	for i in range(98):gear.claim("wooden_arrows")
	check(gear.quantities.get("wooden_arrows",0)==99 and gear.owned.count("wooden_arrows")==1 and not gear.claim("wooden_arrows"),"Arrow claims cap at 99 without duplicate ownership")
	var claim_all=button_named(codex,"Claim all test specimens")
	check(claim_all!=null,"Actual shared Claim all control exists")
	if claim_all!=null:claim_all.pressed.emit()
	check(gear.owned.size()==gear.catalog.items.size() and gear.quantities.get("wooden_arrows",0)==99,"Claim all preserves capped arrow quantity and unique catalog ownership")
	check(gear.valid_save(gear.snapshot()),"Claim all creates strict-valid equipment state")
	game.menagery.close()
	round_trip("Actual shared Claim all")
	gear=game.magic_items
	var missing=gear.snapshot();missing.quantities.erase("wooden_arrows")
	check(not gear.valid_save(missing),"Present quantity map missing owned ammunition remains rejected")
	var legacy=gear.snapshot();legacy.erase("quantities")
	check(gear.valid_save(legacy),"Legacy save without entire quantity map remains accepted")
	var migrated=load("res://scripts/magic_items.gd").new();migrated.restore(legacy)
	check(migrated.quantities.get("wooden_arrows",0)==1,"Legacy missing quantity map still migrates ammunition to one")
	game.start_new_game(false);game.title_screen.hide()
	gear=game.magic_items
	gear.owned.append("wooden_arrows");gear.quantities.wooden_arrows=7
	for code in game.ALLOOT_KEYS:
		var event=InputEventKey.new();event.keycode=code;event.pressed=true;game._allloot_input(event)
	check(gear.quantities.get("wooden_arrows",0)==7,"Actual ALLOOTNOW preserves existing stack value")
	for item in gear.catalog.items:
		if item.category in ["consumable","ammunition"]:check(gear.quantities.has(item.id),"ALLOOTNOW counts "+item.id)
	check(gear.valid_save(gear.snapshot()),"ALLOOTNOW creates strict-valid equipment state")
	if game.inventory.visible:game.inventory.close()
	round_trip("Actual ALLOOTNOW")
	# Use the production release path to verify empty ammunition is removed consistently.
	game.load_map("menagery",Vector2(10,0),true);game.title_screen.hide();game._refresh_simulation()
	gear=game.magic_items;gear.quantities.wooden_arrows=1
	check(gear.equip_weapon("hunting_bow"),"Claimed bow equips normally")
	game.player.set_sword_equipped(true);game.player.set_sword_drawn(true)
	game.camera_driver.set_mode("first_person");game.camera_driver.first_pitch=0;game.camera_driver.sample_first_person(1.0/60.0,true)
	game.player.restore_stamina(game.player.max_stamina)
	check(game.player.weapon_runtime.begin_primary(),"Last arrow starts a real bow draw")
	game.player.state_time=.2;game.player.weapon_runtime.pose("ready",0)
	check(game.player.weapon_runtime.release_primary(),"Last arrow fires through production release")
	check(not gear.owned.has("wooden_arrows") and not gear.quantities.has("wooden_arrows"),"Last arrow removes both ownership and quantity")
	check(gear.valid_save(gear.snapshot()),"Empty ammunition remains strict-valid")
	DirAccess.remove_absolute(PATH)
	if game.audio!=null:check(await game.audio.shutdown_and_drain(),"Audio playback drains before fixture exit")
	print("MAGIC_CLAIM_SAVE_CHECKS "+JSON.stringify({"checks":checks,"failures":failures}))
	game.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
