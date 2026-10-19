extends Node3D
## Shadowless white ballistic preview and small surface circle, hidden outside bow aim.
var lines:MeshInstance3D
var circle:MeshInstance3D
func _ready() -> void:
 lines=MeshInstance3D.new();lines.mesh=ImmediateMesh.new();lines.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(lines)
 var mat=StandardMaterial3D.new();mat.albedo_color=Color.WHITE;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;lines.material_override=mat
 circle=MeshInstance3D.new();circle.mesh=ImmediateMesh.new();circle.material_override=mat;circle.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(circle)
func display(prediction:Dictionary) -> void:
 if lines==null:_ready()
 visible=true;var shape=lines.mesh as ImmediateMesh;shape.clear_surfaces()
 var points:Array=prediction.points
 if points.size()>1:
  shape.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
  for point in points:shape.surface_add_vertex(to_local(point))
  shape.surface_end()
 var ring=circle.mesh as ImmediateMesh;ring.clear_surfaces();circle.visible=not prediction.hit.is_empty()
 if circle.visible:
  var hit:Dictionary=prediction.hit;var normal:Vector3=hit.normal;var right=normal.cross(Vector3.UP)
  if right.length_squared()<.01:right=normal.cross(Vector3.RIGHT)
  right=right.normalized();var forward=normal.cross(right).normalized()
  ring.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
  for i in range(25):
   var a=float(i)/24*TAU;ring.surface_add_vertex(to_local(hit.position+normal*.012+(right*cos(a)+forward*sin(a))*.075))
  ring.surface_end()
