extends "res://scripts/menagery_enemy.gd"
var engaged=false
func _physics_process(delta:float) -> void:
	if not simulation_enabled or health<=0:return
	engaged=player.health>0 and ((player.position-position)*Vector3(1,0,1)).length()<12
	super._physics_process(delta)
func _release_ability() -> void:
	var old=game.projectiles.size();super._release_ability()
	for index in range(old,game.projectiles.size()):
		var shot=game.projectiles[index]
		if is_instance_valid(shot) and shot.get("damage")!=null:shot.damage=int(specimen.damage)
