extends Node3D
## Static Blender review presentation; never owns combat, rigs or equipment state.
const MODEL_PATH="res://assets/characters/heroine-standalone.glb"
static var model:PackedScene
var actor:Node3D

static func apply(target:Node3D,profile:String) -> void:
	if String(target.definition.id)!="hero": return
	var current=target.get_node_or_null("StandaloneHero")
	if profile!="standalone":
		target.remove_meta("standalone_static")
		target.visual.visible=true
		if current!=null: target.remove_child(current); current.queue_free()
		return
	if current==null:
		if model==null: model=load(MODEL_PATH)
		current=load("res://scripts/standalone_hero.gd").new()
		current.name="StandaloneHero"; current.actor=target
		current.add_child(model.instantiate()); target.add_child(current)
	target.set_meta("standalone_static",true)
	target.visual.visible=false
	current.rotation.y=target.visual.rotation.y

func _process(_delta:float) -> void:
	# Translation follows the actor parent; orientation follows smooth game facing.
	if is_instance_valid(actor): rotation.y=actor.visual.rotation.y

static func bounds(node:Node3D,parent:Transform3D=Transform3D.IDENTITY) -> AABB:
	var transform=parent*node.transform
	var box=AABB();var first=true
	if node is MeshInstance3D: box=transform*node.get_aabb(); first=false
	for child in node.get_children():
		if not child is Node3D: continue
		var part=bounds(child,transform)
		if part.size.length_squared()<.000001: continue
		box=part if first else box.merge(part); first=false
	return box
