extends Node
# No spatial node, meshes, collision or labels: this point only owns a death timer.
var game
var entry:Dictionary
var placement:Dictionary
var key:String
var creature
var remaining=0.0
func setup(owner_game,definition:Dictionary,encounter:Dictionary,identity:String) -> void:
 game=owner_game; entry=definition; placement=encounter.duplicate(true); key=identity
 remaining=float(game.respawn_timers.get(key,0))
func _ready() -> void:
 if remaining<=0: spawn()
func spawn() -> void:
 remaining=0; game.respawn_timers.erase(key)
 creature=game.spawn_catalog_creature(entry,Vector3(placement.at[0],0,placement.at[1]))
 creature.definition.id=placement.id; creature.configure_placement(placement)
 creature.defeated.connect(on_death,CONNECT_ONE_SHOT)
func on_death() -> void:
 remaining=float(placement.respawn_seconds); game.respawn_timers[key]=remaining
 game._catalog_enemy_defeated(entry.style,entry.name,creature)
 game.call_deferred("retire_transient",creature)
 creature=null
func _process(delta:float) -> void:
 if remaining<=0 or not game.player.input_enabled or game.gallery_mode: return
 remaining=maxf(0,remaining-delta)
 if remaining<=0: spawn()
 else: game.respawn_timers[key]=remaining
