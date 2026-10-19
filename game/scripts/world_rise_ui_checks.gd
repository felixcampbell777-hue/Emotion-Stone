extends SceneTree
# Isolated menu contract checks: no gameplay, assets, player saves or network sockets.
class Session extends Node:
	signal status_changed(text:String)
	var active=false
	var requested_address=""
	var requested_port=0
	var password=""
	var reconnect_requested=false
	var pending_export:Dictionary={}
	var last_action:Dictionary={}
	var last_error=""
	var hosting_allowed=true
	var host_calls=0
	func local_host_available()->bool:return hosting_allowed
	func request_action(kind:String,payload:Dictionary)->void:last_action={"kind":kind,"payload":payload}
	func retry_checkpoint_install()->bool:pending_export.clear();return true
	func online_session_active()->bool:return active
	func host(port:int)->void:host_calls+=1;requested_port=port;active=true;status_changed.emit("Hosting")
	func join(address:String,port:int)->void:requested_address=address;requested_port=port;active=true;status_changed.emit("Connected")
	func disconnect_session()->void:active=false;status_changed.emit("Disconnected")
class Settings extends Node:
	func settings_panel()->Control:
		var c=VBoxContainer.new()
		for name in ["Master volume","Music","Effects","Microphone","Voice playback"]:
			var label=Label.new();label.text=name;c.add_child(label)
			var slider=HSlider.new();slider.value=65;c.add_child(slider)
		return c
class Game extends Control:
	var world_view:SubViewport
	var world_rect:Control
	var wr_session:Node
	var audio:Node
	var voice:Node
	var cancel_count=0
	var online_pvp=false
	func initialize(use_real_session:bool=false)->void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		world_view=SubViewport.new();world_view.size=Vector2i(960,540);add_child(world_view)
		world_rect=Control.new();world_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(world_rect)
		wr_session=load("res://scripts/network/wr_session.gd").new() if use_real_session else Session.new();wr_session.name="WorldRiseSession";add_child(wr_session)
		audio=Settings.new();add_child(audio);voice=Settings.new();add_child(voice)
	func style(color:Color,border:Color=Color.TRANSPARENT)->StyleBoxFlat:
		var s=StyleBoxFlat.new();s.bg_color=color;s.border_color=border;s.content_margin_left=18;s.content_margin_right=18;s.content_margin_top=12;s.content_margin_bottom=12;return s
	func panel(parent:Node)->PanelContainer:
		var p=PanelContainer.new();var s=StyleBoxFlat.new();s.bg_color=Color("203630");s.content_margin_left=18;s.content_margin_right=18;s.content_margin_top=12;s.content_margin_bottom=12;p.add_theme_stylebox_override("panel",s);parent.add_child(p);return p
	func label(text:String,size:int=18,color:Color=Color.WHITE)->Label:
		var l=Label.new();l.text=text;l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color);return l
	func button(text:String,callback:Callable)->Button:
		var b=Button.new();b.text=text;b.pressed.connect(callback);b.custom_minimum_size.y=36;return b
	func _cancel_mouse_charge()->void:cancel_count+=1
	func _refresh_simulation()->void:pass
var failures:Array[String]=[]
func check(ok:bool,message:String)->void:
	if not ok:failures.append(message);push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	if "--exported-host-gate" in OS.get_cmdline_user_args():
		await run_exported_host_gate();return
	root.size=Vector2i(960,540)
	var game=Game.new();root.add_child(game);game.initialize()
	var connection=load("res://scripts/world_rise_connection_menu.gd").new();game.add_child(connection);connection.configure(game)
	var settings=load("res://scripts/world_rise_settings_menu.gd").new();game.add_child(settings);settings.configure(game)
	connection.open();await process_frame;await process_frame
	check(connection.box.get_global_rect().end.x<=960 and connection.box.get_global_rect().end.y<=540,"Connection panel fits 960x540")
	connection.address.text="bad / address";connection.join_server();check(not game.wr_session.active,"Invalid address does not connect")
	connection.password.text="fixture only";connection.recovery.button_pressed=true
	connection.address.text="127.0.0.1";connection.port.value=25001;connection.join_server()
	check(game.wr_session.password=="fixture only" and game.wr_session.reconnect_requested,"Password and recovery choice reach session")
	check(game.wr_session.requested_address=="127.0.0.1" and game.wr_session.requested_port==25001,"Join forwards address and port")
	check(connection.status.text=="Connected" and connection.join_button.disabled and not connection.disconnect_button.disabled,"Connected state is visible")
	connection.disconnect_session();check(not game.wr_session.active and not connection.join_button.disabled,"Disconnect permits reconnect")
	connection.update_status("Connecting over trusted LAN/private VPN")
	check(connection.join_button.disabled and connection.host_button.disabled and not connection.disconnect_button.disabled,"Pending connection can cancel and cannot duplicate")
	connection.disconnect_session()
	connection.host_session();check(game.wr_session.active and game.wr_session.requested_port==25001,"Host forwards selected port")
	game.online_pvp=true;connection.update_buttons();check(connection.pvp.visible and connection.pvp.button_pressed,"PvP reflects authoritative state")
	connection.pvp.toggled.emit(false);check(game.wr_session.last_action=={"kind":"pvp","payload":{"enabled":false}},"PvP changes request authority")
	game.wr_session.pending_export={"checkpoint":"fixture"};connection.update_buttons();check(connection.retry_button.visible,"Failed checkpoint offers retry")
	connection.retry_checkpoint();check(game.wr_session.pending_export.is_empty(),"Checkpoint retry invokes service")
	connection.disconnect_session()
	game.wr_session.hosting_allowed=false;connection.update_buttons()
	check(connection.host_button.disabled and not connection.join_button.disabled,"Packaged client Host gate leaves Join available")
	check(connection.hosting_notice.visible and "Docker" in connection.hosting_notice.text and "DEDICATED-SERVER.md" in connection.hosting_notice.text,"Packaged client explains Docker hosting and names the guide")
	var calls=game.wr_session.host_calls
	connection.host_session()
	check(game.wr_session.host_calls==calls and not game.wr_session.active,"Blocked Host handler never invokes session or helper")
	check("Docker" in connection.status.text,"Blocked Host reports actionable hosting guidance")
	connection.join_server();check(game.wr_session.active,"Packaged client can still join a dedicated server")
	connection.disconnect_session();game.wr_session.hosting_allowed=true;connection.update_buttons()
	check(not connection.host_button.disabled,"Developer Host remains available")
	var real_service=load("res://scripts/network/wr_session.gd").new()
	check(real_service.local_host_available()==OS.has_feature("editor"),"Actual session Host availability follows the engine export feature gate")
	if not OS.has_feature("editor"):
		check(real_service.host(25001)==ERR_UNAVAILABLE and real_service.owner_key==null and real_service.peer==null,"Exported session rejects Host before profile or socket setup")
	real_service.free()
	await capture("connection")
	connection.close();settings.open();await process_frame;await process_frame
	check(settings.box.get_global_rect().end.x<=960 and settings.box.get_global_rect().end.y<=540,"Settings panel fits 960x540")
	check(settings.sections.get_child_count()==2,"Audio and voice panels are present")
	await capture("settings")
	settings.close();check(game.cancel_count==2,"Opening menus cancels pending action input")
	print("WORLD_RISE_UI_CHECKS "+("PASS" if failures.is_empty() else "FAIL "+str(failures)))
	quit(0 if failures.is_empty() else 1)
func capture(name:String)->void:
	var output=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ui-output="):output=arg.trim_prefix("--ui-output=")
	if output.is_empty():return
	DirAccess.make_dir_recursive_absolute(output)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+"-960x540.png")

func run_exported_host_gate()->void:
	# Run this branch from the actual exported client, never with a simulated feature tag.
	check(not OS.has_feature("editor"),"Host gate smoke is running from an exported client")
	if OS.has_feature("editor"):
		print("WORLD_RISE_EXPORTED_UI_GATE FAIL: use the actual exported client");quit(1);return
	root.size=Vector2i(960,540)
	var game=Game.new();root.add_child(game);game.initialize(true)
	var connection=load("res://scripts/world_rise_connection_menu.gd").new();game.add_child(connection);connection.configure(game)
	connection.open();await process_frame;await process_frame
	check(not game.wr_session.local_host_available(),"Installed session reports local hosting unavailable")
	check(connection.host_button.disabled and not connection.join_button.disabled,"Actual exported menu disables Host and keeps Join available")
	check(connection.hosting_notice.visible and "Docker" in connection.hosting_notice.text and "DEDICATED-SERVER.md" in connection.hosting_notice.text,"Actual exported menu explains Docker hosting and the guide")
	connection.host_session()
	check("Docker" in connection.status.text,"Actual exported UI Host handler directs to Docker")
	check(game.wr_session.owner_key==null and game.wr_session.peer==null and game.wr_session.storage==null and game.wr_session.local_profile.is_empty(),"UI gate performs no credential, socket, storage or profile setup")
	check(game.wr_session.host(25001)==ERR_UNAVAILABLE,"Direct exported Host call is rejected")
	check("Docker" in game.wr_session.status,"Direct exported Host failure gives Docker guidance")
	check(game.wr_session.owner_key==null and game.wr_session.peer==null and game.wr_session.storage==null and game.wr_session.local_profile.is_empty(),"Direct session gate performs no credential, socket, storage or profile setup")
	check(not DirAccess.dir_exists_absolute("user://world-rise-portable"),"Exported Host creates no portable profile directory")
	await capture("exported-host-gate")
	print("WORLD_RISE_EXPORTED_UI_GATE "+("PASS" if failures.is_empty() else "FAIL "+str(failures)))
	quit(0 if failures.is_empty() else 1)
