extends RefCounted
# Always run through platform capture with disposable userdata. Grants are fixture-only.
var failures:Array[String]=[]
var checks=0
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func picture(game:Control,directory:String,name:String)->void:
	await game.get_tree().create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(directory)
	check(game.get_viewport().get_texture().get_image().save_png(directory+"/world-rise-"+name+".png")==OK,"Saved menu capture "+name)
func bounds(game:Control)->void:
	var screen=game.get_viewport_rect()
	for box in [game.inventory.box,game.inventory.detail_box]:
		check(screen.encloses(box.get_global_rect()),"Inventory panels fit "+str(screen.size))
	for category in game.inventory.category_box.get_children():
		check(category.get_global_rect().end.y<game.inventory.preview.position.y,"Categories remain above equipment preview")
func key(game:Control,code:Key)->void:
	var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event)
	await game.get_tree().process_frame
	event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=false;Input.parse_input_event(event)
	await game.get_tree().process_frame
func escape(game:Control)->void:await key(game,KEY_ESCAPE)
func run(game:Control,directory:String)->void:
	game.game_mode="world_rise";game.start_new_game(false);game.set_resolution(640)
	for id in ["field_spear","duelist_rapier","hunting_bow","wooden_arrows"]:
		if id not in game.magic_items.owned:game.magic_items.owned.append(id)
	game.magic_items.quantities.wooden_arrows=24
	for size in [Vector2i(960,540),Vector2i(1366,768)]:
		DisplayServer.window_set_size(size)
		var suffix="-%dx%d" % [size.x,size.y]
		game.title_screen.show_menu();await picture(game,directory,"title"+suffix)
		game.settings_menu.open();await picture(game,directory,"sound"+suffix)
		var scroll=game.settings_menu.content_scroll;scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value);await picture(game,directory,"voice"+suffix)
		await escape(game);check(not game.settings_menu.visible and game.title_screen.visible,"Escape restores title after settings")
		game.connection_menu.open();await picture(game,directory,"connection"+suffix);await escape(game)
		check(not game.connection_menu.visible and game.title_screen.visible,"Escape restores title after connection")
		game.title_screen.visible=false;game._refresh_simulation();game.toggle_inventory()
		for id in ["standard_greatsword","field_spear","duelist_rapier","hunting_bow"]:
			game.inventory.selected_category="weapons";game.inventory.selected_item={"kind":"weapon","id":id};game.inventory.show_page("equipment")
			await picture(game,directory,id+suffix);bounds(game)
		game.inventory.selected_category="ammunition";game.inventory.selected_item={};game.inventory.refresh();await picture(game,directory,"arrows"+suffix)
		game.inventory.selected_category="apparel";game.inventory.selected_item={};game.inventory.refresh();await picture(game,directory,"equipment"+suffix);bounds(game)
		check(game.inventory.tabs.get_child(4).text=="Map" and game.inventory.tabs.get_child(2).text=="Level Up","Five inventory pages retain existing ordering")
		if game.appearance_menu!=null:
			game.inventory.tabs.get_child(5).pressed.emit();check(game.appearance_menu.visible,"Appearance opens from inventory")
			check(not game.player.input_enabled,"Appearance suppresses player controls")
			await escape(game);check(not game.appearance_menu.visible and game.inventory.visible,"Escape closes appearance before inventory")
		game.inventory.close()
		await key(game,KEY_P);check(game.inventory.visible and game.inventory.page=="level","P opens Level Up")
		await escape(game);check(not game.inventory.visible and not game.pause_menu.visible,"Escape closes Level Up before pause")
		await key(game,KEY_I);check(game.inventory.visible,"I opens Inventory");await escape(game)
		game.pause_menu.open();await picture(game,directory,"pause"+suffix);game.pause_menu.close()
	if "--online-menu-smoke" in OS.get_cmdline_user_args():await online_smoke(game,directory)
	check(failures.is_empty(),"Menu layout and overlay contracts")
	var report=FileAccess.open(directory+"/ui-current-result.json",FileAccess.WRITE)
	if report!=null:
		report.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"platform":OS.get_name(),"engine":Engine.get_version_info().string,"window_sizes":[[960,540],[1366,768]],"online_mouse_smoke":"--online-menu-smoke" in OS.get_cmdline_user_args(),"failures":failures},"\t")); report.close()
	print("WORLD_RISE_MENU_CAPTURE "+("PASS %d checks" % checks if failures.is_empty() else "FAIL "+str(failures)))
	print("CAPTURE_OK "+directory)
	# Stop looping streams and let the audio mixer release playback before teardown.
	if game.audio!=null:game.audio.shutdown()
	await game.get_tree().create_timer(.15).timeout
	game.get_tree().call_deferred("quit",0 if failures.is_empty() else 1)

func click(game:Control,button:BaseButton)->void:
	button.grab_focus()
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	var point=button.get_global_rect().get_center()
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;Input.parse_input_event(motion)
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;Input.parse_input_event(event)
		await game.get_tree().process_frame
	await game.get_tree().create_timer(.2).timeout

func online_smoke(game:Control,directory:String)->void:
	# Disposable fixture host only; regular UI and input propagation exercise the real service.
	var seeded=game.wr_session.ensure_character()
	check(seeded,"Disposable portable profile can be created")
	if not seeded:return
	var profile=game.wr_session.local_profile.duplicate(true)
	for id in ["hunting_bow","wooden_arrows"]:
		if id not in profile.magic_items.owned:profile.magic_items.owned.append(id)
	profile.magic_items.weapon_id="hunting_bow";profile.magic_items.quantities.wooden_arrows=24
	check(preload("res://scripts/network/wr_profile.gd").valid(profile),"Seeded bow profile validates")
	check(game.wr_session.install_checkpoint(profile),"Seeded bow fixture checkpoint is durable")
	game.connection_menu.open();game.connection_menu.port.value=28000+Time.get_ticks_msec()%10000
	await click(game,game.connection_menu.host_button)
	check(game.online_session_active(),"Actual Host button establishes a session")
	if not game.online_session_active():return
	check(not game.connection_menu.visible and not game.title_screen.visible,"Host enters the shared world")
	check(game.player.state=="free" and not game.mouse_attack_pending,"Host menu click does not enqueue an attack")
	check(game.magic_items.weapon_id=="hunting_bow","Host installs seeded portable bow profile")
	await key(game,KEY_R);await game.get_tree().create_timer(.7).timeout
	# Aim down at the arrival floor so the real online trajectory has a surface circle.
	game.camera_driver.first_pitch=.32
	var point=game.get_viewport_rect().get_center()
	var down=InputEventMouseButton.new();down.position=point;down.global_position=point;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;Input.parse_input_event(down)
	await game.get_tree().create_timer(.4).timeout
	var preview=game.player.weapon_runtime.preview
	check(game.player.state=="bow_draw","Actual online mouse press starts bow draw")
	check(is_instance_valid(preview) and preview.visible and preview.lines.mesh.get_surface_count()>0,"Online visible bow path is rendered")
	check(is_instance_valid(preview) and preview.circle.visible,"Online bow landing circle is visible")
	await picture(game,directory,"online-bow-preview-1366x768")
	var up=InputEventMouseButton.new();up.position=point;up.global_position=point;up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;Input.parse_input_event(up)
	await game.get_tree().create_timer(.8).timeout

	await escape(game);check(game.pause_menu.visible and not game.player.input_enabled,"Online Escape opens menu and gates local input")
	check(game.player.simulation_active(),"Online menu keeps simulation active")
	check(game.pause_menu.save_button.disabled and game.pause_menu.load_button.disabled and game.pause_menu.adventure_button.disabled,"Online menu protects offline saves and export flow")
	await picture(game,directory,"online-pause-1366x768")
	game.connection_menu.open();await game.get_tree().process_frame
	check(game.connection_menu.pvp.visible,"Online PvP control is available")
	await click(game,game.connection_menu.pvp)
	await game.get_tree().create_timer(.2).timeout
	check(game.get("online_pvp")==true,"Actual PvP control reaches server authority")
	check(game.player.state=="free" and not game.mouse_attack_pending,"Online menu click does not enqueue an attack")
	check(int(game.magic_items.quantities.get("wooden_arrows",0))==23,"PvP menu click does not spend another arrow")
	await picture(game,directory,"online-connection-1366x768")
	await click(game,game.connection_menu.disconnect_button)
	await game.get_tree().create_timer(.2).timeout
	check(not game.online_session_active(),"Actual Disconnect button completes checkpoint export")
	check(game.title_screen.visible,"Disconnect restores offline title")
