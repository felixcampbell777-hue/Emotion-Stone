extends RefCounted
const Shape=preload("res://scripts/rise_shape.gd")
var game:Node
var hold=0.0
var armed=true
var unlocked:Array=["arrival"]
func sites() -> Array:
	return [{"id":"arrival","at":[0,0],"title":"Central Platform","type":"rest"}]+Shape.spec.landmarks.filter(func(e):return e.type=="rest")
func migrate(data:Dictionary) -> void:
	if int(data.get("checkpoint_layout",1))>=2:return
	var old:Vector2=Vector2(game.worldrise.checkpoint[0],game.worldrise.checkpoint[1])
	if old.distance_to(Vector2(0,8))<.1:game.worldrise.checkpoint=[0,0];return
	for entry in sites():
		if entry.has("legacy_at") and old.distance_to(Vector2(entry.legacy_at[0],entry.legacy_at[1]))<.1:
			game.worldrise.checkpoint=entry.at.duplicate();return
func point(entry:Dictionary) -> Vector3:
	var at=Vector3(entry.at[0],0,entry.at[1]);at.y=game.current_world.ground_height(at);return at
func nearby() -> Dictionary:
	if not game.worldrise.active():return {}
	for entry in sites():
		if game.player.position.distance_to(point(entry))<=6:return entry
	return {}
func discover() -> void:
	if not game.worldrise.active() or game.player.health<=0:return
	var entry=nearby()
	if entry.is_empty() or entry.id in unlocked:return
	unlocked.append(entry.id)
	game.notify("Checkpoint unlocked: "+entry.title+".")
func hostile_nearby() -> bool:
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.health<=0 or enemy.position.distance_squared_to(game.player.position)>900:continue
		if enemy.get("pack_engaged")==true or enemy.get("encounter_engaged")==true or enemy.get("engaged")==true or enemy.state in ["windup","lunge","strike","rush","howl","leap"]:return true
	return false
func block_reason() -> String:
	if not game.worldrise.active():return "Travel is available on Floor One, near a checkpoint."
	if game.player.health<=0 or game.recovering:return "Travel is unavailable while defeated."
	if game.player.state!="free":return "Finish your current action before travelling."
	if nearby().is_empty():return "Move within 6 metres of a checkpoint to travel."
	if hostile_nearby():return "Travel blocked: an aggressive enemy is within 30 metres."
	return ""
func rest(entry:Dictionary) -> bool:
	if not game.worldrise.active() or game.player.health<=0:return false
	if hostile_nearby() or game.enemies.any(func(e):return is_instance_valid(e) and e.health>0 and e.position.distance_squared_to(game.player.position)<144):
		game.notify("Clear nearby enemies before resting.");return false
	game.worldrise.checkpoint=entry.at.duplicate()
	if entry.id=="arrival":armed=false
	hold=0
	var yaw=game.camera_driver.yaw;var pitch=game.camera_driver.first_pitch
	game.worldrise.respawn_reset();game.load_map("wr_floor_01",Vector2(entry.at[0],entry.at[1]),true)
	game.player.restore_health(game.player.max_health);game.player.restore_stamina(game.player.max_stamina)
	game.camera_driver.yaw=yaw;game.camera_driver.first_pitch=pitch;game.camera_driver.update_first_person()
	game.notify("Rested at "+entry.title+". Respawn set; ordinary packs return.")
	return true
func tick(delta:float) -> bool:
	discover()
	var inside=Vector2(game.player.position.x,game.player.position.z).length()<=2
	if not inside:armed=true;hold=0;return false
	if not armed:return false
	if game.player.state!="free" or game.player.jump_active or game.player.velocity.length_squared()>.04 or hostile_nearby() or game.enemies.any(func(e):return is_instance_valid(e) and e.health>0 and e.position.distance_squared_to(game.player.position)<144):hold=0;return false
	hold+=delta
	if hold<1:return false
	hold=0;return rest(sites()[0])
func travel(id:String) -> bool:
	if id not in unlocked:game.notify("Visit this checkpoint to unlock it first.");return false
	var reason=block_reason()
	if not reason.is_empty():game.notify(reason);return false
	var matches=sites().filter(func(e):return e.id==id)
	if matches.is_empty() or nearby().id==id:return false
	var entry:Dictionary=matches[0];var at=Vector2(entry.at[0],entry.at[1])
	if id!="arrival":
		var found=false
		for i in range(8):
			var candidate=at+Vector2(sin(i*TAU/8),cos(i*TAU/8))*2
			if Shape.safe(Vector3(candidate.x,0,candidate.y)):at=candidate;found=true;break
		if not found:game.notify("This checkpoint's arrival spot is obstructed.");return false
	# Preserve damaged enemies, loot, bosses and progress across the map reload.
	game.worldrise.snapshot()
	var yaw=game.camera_driver.yaw;var pitch=game.camera_driver.first_pitch
	game.inventory.close();hold=0;armed=true
	game.load_map("wr_floor_01",at)
	game.camera_driver.yaw=yaw;game.camera_driver.first_pitch=pitch;game.camera_driver.update_first_person()
	game.notify("Arrived at "+entry.title+".");return true
