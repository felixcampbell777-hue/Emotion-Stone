extends CharacterBody3D
## Combat body owned by the authority; UI control state never grants immunity.
var character_id=""
var runtime:Node
var health=100
var max_health=100
var input_enabled=true
var controllable=true
var jump_active=false
var jump_velocity=0.0
var invulnerability=0.0
var knockback=Vector3.ZERO
var slow_sources={}
var magic_gear=preload("res://scripts/magic_items.gd").new()
var gear_signature=""
var ground_world:Node
var combat:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://content/combat.json"))
var parry_handler:Callable
func _init() -> void:
	collision_layer=2;collision_mask=1
	var collider=CollisionShape3D.new();var capsule=CapsuleShape3D.new();capsule.radius=.23;capsule.height=1.12;collider.shape=capsule;collider.position.y=.56;add_child(collider)
func simulation_active() -> bool:return true
func finish_jump() -> void:jump_active=false;jump_velocity=0
func take_damage(amount:int,away:Vector3) -> void:
	if health<=0:return
	runtime.player_damaged.emit(character_id,amount,away)
func try_parry(enemy:Node,contact:Variant=null) -> bool:
	return bool(parry_handler.call(character_id,enemy,contact)) if parry_handler.is_valid() else false
