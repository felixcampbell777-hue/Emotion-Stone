extends Control
const DOCKER_HOSTING_NOTICE="Hosting runs in a separate Docker dedicated server. Follow docs/DEDICATED-SERVER.md in the source download, then join its server address here."
var game:Control
var box:PanelContainer
var address:LineEdit
var port:SpinBox
var password:LineEdit
var recovery:CheckBox
var pending=false
var pvp:CheckBox
var retry_button:Button
var port_pair:Label
var description:Label
var hosting_notice:Label
var status:Label
var host_button:Button
var join_button:Button
var disconnect_button:Button
var return_focus:Control

func configure(owner_game:Control) -> void:
	game=owner_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var frost=load("res://scripts/frosted_backdrop.gd").new(); add_child(frost); frost.configure(game)
	box=game.panel(self)
	box.add_theme_stylebox_override("panel",game.style(Color("#203630"),Color("#c6c6a74a")))
	var scroll=ScrollContainer.new(); scroll.follow_focus=true; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; box.add_child(scroll)
	var column=VBoxContainer.new(); column.size_flags_horizontal=Control.SIZE_EXPAND_FILL; column.add_theme_constant_override("separation",10); scroll.add_child(column)
	column.add_child(game.label("WORLD RISE · MULTIPLAYER",24,Color("#e9c894")))
	description=game.label("Host a session or join a running host / dedicated server by address. Use your private VPN address for remote play.",16); description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; column.add_child(description)
	status=game.label("Offline",16); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; column.add_child(status)
	column.add_child(game.label("Server address",16))
	address=LineEdit.new(); address.text="127.0.0.1"; address.placeholder_text="Server hostname or VPN address"; address.custom_minimum_size.y=40; column.add_child(address)
	var port_row=HBoxContainer.new(); column.add_child(port_row); port_row.add_child(game.label("Game UDP port",16))
	port=SpinBox.new(); port.min_value=1024; port.max_value=65534; port.value=24571; port.step=1; port.rounded=true; port.size_flags_horizontal=Control.SIZE_EXPAND_FILL; port_row.add_child(port)
	port_pair=game.label("Hosting voice uses UDP 24572",14); column.add_child(port_pair)
	port.value_changed.connect(func(value:float):port_pair.text="Hosting voice uses UDP %d" % (int(value)+1) if local_host_available() else "Voice connects through the dedicated server.")
	password=LineEdit.new(); password.secret=true; password.max_length=256; password.placeholder_text="Server password (if required)"; password.custom_minimum_size.y=40; column.add_child(password)
	recovery=CheckBox.new(); recovery.text="Recover this server’s character checkpoint"; recovery.tooltip_text="Reconnect using the character version retained by this server. Your offline save is separate."; column.add_child(recovery)
	var actions=HBoxContainer.new(); column.add_child(actions)
	join_button=game.button("Join server",join_server); join_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; actions.add_child(join_button)
	host_button=game.button("Host session",host_session); host_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; actions.add_child(host_button)
	hosting_notice=game.label(DOCKER_HOSTING_NOTICE,15); hosting_notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; column.add_child(hosting_notice)
	disconnect_button=game.button("Disconnect",disconnect_session); column.add_child(disconnect_button)
	pvp=CheckBox.new(); pvp.text="Allow player-versus-player combat"; pvp.tooltip_text="Both players must opt in. The server applies the combat cooldown before changing your choice."; column.add_child(pvp)
	pvp.toggled.connect(func(enabled:bool):
		if session()!=null and session().online_session_active():session().request_action("pvp",{"enabled":enabled}))
	retry_button=game.button("Retry saving received character checkpoint",retry_checkpoint); column.add_child(retry_button)
	var hint=game.label("Your own character joins the shared world. Escape returns to the previous screen. Online worlds continue while menus are open.",14); hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; column.add_child(hint)
	column.add_child(game.button("Back [Esc]",close))
	address.text_submitted.connect(func(_text):join_server())
	visible=false

func session() -> Node:
	return game.get("wr_session")

func open() -> void:
	return_focus=get_viewport().gui_get_focus_owner()
	game.move_child(self,game.get_child_count()-1)
	var connection=session()
	if connection!=null and not connection.status_changed.is_connected(update_status): connection.status_changed.connect(update_status)
	if connection!=null and connection.has_signal("action_result") and not connection.action_result.is_connected(action_result):connection.action_result.connect(action_result)
	if connection!=null:
		var message=connection.get("status")
		if message is String:status.text=message
	visible=true
	game._cancel_mouse_charge()
	game._refresh_simulation()
	update_buttons()
	if connection==null:status.text="Network service is unavailable in this build. Your offline progress is unchanged."
	focus_address.call_deferred()

func focus_address()->void:
	await get_tree().process_frame
	if not visible:return
	address.grab_focus()
	box.get_child(0).scroll_vertical=0

func update_status(message:String) -> void:
	status.text=message
	if visible:box.get_child(0).scroll_vertical=0
	pending=message.begins_with("Connecting") or message.begins_with("Connected; authenticating")
	update_buttons()

func local_host_available()->bool:
	var connection=session()
	return connection!=null and connection.has_method("local_host_available") and connection.local_host_available()

func update_buttons() -> void:
	var connection=session()
	var online=connection!=null and connection.online_session_active()
	var server_running=connection!=null and connection.get("server")==true
	var busy=online or pending or server_running
	var can_host=local_host_available()
	host_button.disabled=not can_host or busy
	host_button.text="Host session" if can_host else "Host with Docker"
	host_button.tooltip_text="" if can_host else DOCKER_HOSTING_NOTICE
	hosting_notice.visible=not can_host
	port_pair.text="Hosting voice uses UDP %d" % (int(port.value)+1) if can_host else "Voice connects through the dedicated server."
	description.text="Host a session or join a running host / dedicated server by address. Use your private VPN address for remote play." if can_host else "Join a Docker dedicated server by address. Use your private VPN address for remote play."
	join_button.disabled=connection==null or busy
	disconnect_button.disabled=connection==null or not busy
	address.editable=not busy
	port.editable=not busy
	password.editable=not busy
	recovery.disabled=busy
	pvp.visible=online
	pvp.set_pressed_no_signal(game.get("online_pvp")==true)
	var exported=connection.get("pending_export") if connection!=null else null
	retry_button.visible=exported is Dictionary and not exported.is_empty()
	retry_button.disabled=connection==null or not connection.has_method("retry_checkpoint_install")

func join_server() -> void:
	var host=address.text.strip_edges()
	if host.is_empty() or host.length()>253 or " " in host or "/" in host:
		update_status("Enter a server hostname or IP address."); address.grab_focus(); return
	if session()==null:update_status("Network service is unavailable.");return
	update_status("Connecting to %s:%d…" % [host,int(port.value)])
	set_connection_options()
	var result=session().join(host,int(port.value))
	if result is int and result==ERR_ALREADY_IN_USE:update_status("A session is already active. Disconnect before joining another server.")

func host_session() -> void:
	if session()==null:update_status("Network service is unavailable.");return
	if not local_host_available():update_status(DOCKER_HOSTING_NOTICE);return
	set_connection_options()
	var result=session().host(int(port.value))
	if result is int and result==ERR_ALREADY_IN_USE:update_status("A session is already active. Disconnect before hosting another server.")
	update_buttons()

func disconnect_session() -> void:
	if session()==null:return
	update_status("Exporting character checkpoint before disconnecting…" if session().online_session_active() else "Cancelling connection…")
	session().disconnect_session()

func close() -> void:
	visible=false
	game._refresh_simulation()
	if is_instance_valid(return_focus) and return_focus.is_visible_in_tree():return_focus.grab_focus()

func _process(_delta:float) -> void:
	if not visible:return
	update_buttons()
	var screen=get_viewport_rect().size
	box.size=Vector2(minf(620,screen.x-36),minf(680,screen.y-36)); box.position=(screen-box.size)*.5

func set_connection_options()->void:
	var connection=session()
	var properties=connection.get_property_list().map(func(property):return property.name)
	if "password" in properties:connection.set("password",password.text)
	if "reconnect_requested" in properties:connection.set("reconnect_requested",recovery.button_pressed)

func action_result(result:Dictionary)->void:
	if not visible:return
	if not result.get("ok",false):update_status(String(result.get("error","The server could not complete this action.")))
	elif not String(result.get("message","")).is_empty():update_status(String(result.message))

func retry_checkpoint()->void:
	if session()==null or not session().has_method("retry_checkpoint_install"):return
	update_status("Saving received character checkpoint…")
	if session().retry_checkpoint_install():update_status("Character checkpoint saved.")
	else:update_status(String(session().get("last_error")))
