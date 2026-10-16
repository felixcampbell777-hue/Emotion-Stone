@tool
extends Node3D
## One 45-degree sector, centered on the floor origin. Rotate copies, do not translate.
func _ready() -> void:
	for mesh in find_children("*","MeshInstance3D",true,false):
		var mat=ShaderMaterial.new();mat.shader=preload("res://assets/environment/world_rise_backdrop/mountains.gdshader");mat.set_shader_parameter("stone",preload("res://assets/alpha2/rock_face/albedo.jpg"));mesh.material_override=mat
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;mesh.visibility_range_end=0
