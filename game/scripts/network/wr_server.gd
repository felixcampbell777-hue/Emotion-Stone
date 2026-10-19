extends "res://scripts/network/wr_session.gd"
func _ready() -> void:
 super._ready()
 var options={"port":"24571","data-dir":"user://world-rise-server","bind":"127.0.0.1"}
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--") and "=" in arg:
   var pieces=arg.substr(2).split("=",true,1);options[pieces[0]]=pieces[1]
 if OS.get_environment("WORLD_RISE_PRIVATE_VPN")=="1":options.bind="0.0.0.0"
 var secret=""
 if not OS.get_environment("WORLD_RISE_PASSWORD_FILE").is_empty():options["password-file"]=OS.get_environment("WORLD_RISE_PASSWORD_FILE")
 if options.has("password-file"):
  if not FileAccess.file_exists(options["password-file"]):push_error("Configured server password file is unavailable");get_tree().quit(1);return
  secret=FileAccess.get_file_as_string(options["password-file"]).strip_edges()
  if secret.is_empty():push_error("Configured server password file is empty");get_tree().quit(1);return
 var result=start_server(int(options.port),options["data-dir"],secret,options.bind,int(options.get("voice-port",OS.get_environment("WORLD_RISE_VOICE_PORT") if not OS.get_environment("WORLD_RISE_VOICE_PORT").is_empty() else "0")))
 if result!=OK:push_error(last_error);get_tree().quit(1)
 else:print("WORLD_RISE_SERVER_READY "+storage.data.world_id)
