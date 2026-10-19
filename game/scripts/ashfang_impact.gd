extends Node3D
var game:Node
var age=0.0
var ring:MeshInstance3D
func _ready() -> void:
	var mesh=TorusMesh.new();mesh.inner_radius=.85;mesh.outer_radius=1.0;mesh.rings=48;mesh.ring_segments=6
	ring=preload("res://scripts/props.gd").mesh_node(self,mesh,Vector3(0,.06,0),"#c4b29b")
	var mat=ring.material_override.duplicate();mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;ring.material_override=mat
func _process(delta:float) -> void:
	if game==null or not game.simulation_active():return
	age+=delta;ring.scale=Vector3.ONE*(1+age*3);ring.material_override.albedo_color.a=maxf(0,1-age/.65)
	if age>.65:queue_free()
