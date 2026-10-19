extends RefCounted
## Optional presentation only: sound never changes combat or economy outcomes.
static func play(game:Node,event:String,at:Vector3=Vector3.ZERO,context:Dictionary={}) -> void:
	if not is_instance_valid(game) or game.get("game_mode")!="world_rise":return
	var director=game.get("audio")
	if director!=null and director.has_method("play"):director.play(event,at,context)

static func creature(enemy:Node) -> void:
	var game=enemy.get("game")
	if not is_instance_valid(game) or game.get("game_mode")!="world_rise":return
	var kind="ashfang" if String(enemy.definition.get("id",""))=="ashfang" else String(enemy.definition.get("kind",""))
	var prefix={"beta_wolf":"wolf","library_boar":"boar","beta_twin_wolf":"twin_wolf","ashfang":"ashfang","green_slime":"slime","giant_green_slime":"giant_slime","resin_slime":"resin","vault_elder":"elder"}.get(kind,"")
	if prefix.is_empty():return
	var owner={"actor_id":String(enemy.definition.id)}
	var last=enemy.get_meta("audio_position",enemy.position);enemy.set_meta("audio_position",enemy.position)
	var distance=enemy.position.distance_to(last)
	if prefix in ["wolf","boar","twin_wolf","ashfang"] and enemy.state in ["idle","patrol","circle","lunge","rush"] and distance>.001 and distance<3:
		var travelled=float(enemy.get_meta("audio_step_distance",0))+distance
		if travelled>=1.2:
			travelled=fmod(travelled,1.2)
			var surface=preload("res://scripts/audio/audio_surface_resolver.gd").surface(game,enemy.global_position)
			play(game,"enemy.step."+surface,enemy.position,owner)
		enemy.set_meta("audio_step_distance",travelled)
	var previous=String(enemy.get_meta("audio_state",""));var current=String(enemy.state)
	if previous==current:return
	enemy.set_meta("audio_state",current)
	var sequence=int(enemy.get_meta("audio_sequence",0))+1;enemy.set_meta("audio_sequence",sequence);owner.action_id=str(sequence)
	var cue=""
	if current in ["windup","giant_warn","follow_windup"]:cue="tell"
	elif current=="forming":cue="form"
	elif current=="howl":cue="howl"
	elif current in ["leap","giant_jump"]:cue="leap" if prefix in ["slime","giant_slime"] else "lunge"
	elif current=="lunge":cue="charge" if prefix=="boar" else "bite" if prefix=="wolf" else "leap" if prefix=="slime" else "lunge"
	elif current=="bite":cue="bite_a"
	elif current=="follow_bite":cue="bite_b"
	elif current=="rush":cue="rush"
	elif current=="recover" and previous in ["leap","giant_jump","lunge"] and prefix in ["slime","giant_slime","ashfang"]:cue="land"
	elif current=="strike" and prefix=="elder":cue="throw" if enemy.attack_kind=="stone" else enemy.attack_kind
	if prefix=="resin" and cue in ["tell","lunge"]:return
	if not cue.is_empty():play(game,"enemy."+prefix+"."+cue,enemy.position,owner)

static func creature_damage(enemy:Node) -> void:
	var game=enemy.get("game")
	if not is_instance_valid(game) or game.get("game_mode")!="world_rise":return
	var prefix={"beta_wolf":"wolf","library_boar":"boar","beta_twin_wolf":"twin_wolf","ashfang":"ashfang","green_slime":"slime","giant_green_slime":"giant_slime","resin_slime":"resin","vault_elder":"elder"}.get("ashfang" if String(enemy.definition.get("id",""))=="ashfang" else String(enemy.definition.get("kind","")),"")
	if prefix.is_empty():return
	var owner={"actor_id":String(enemy.definition.id)}
	if enemy.health<=0:play(game,"enemy."+prefix+".death",enemy.position,owner)
	elif prefix in ["wolf","boar"]:play(game,"enemy."+prefix+".pain",enemy.position,owner)
	elif prefix in ["slime","giant_slime"]:play(game,"enemy.slime.hit",enemy.position,owner)
