extends RefCounted
const Props=preload("res://scripts/props.gd")
const STEP=.5
static func local_point(piece:Dictionary,at:Vector3) -> Vector2:
 return (Vector2(at.x,at.z)-Vector2(piece.at[0],piece.at[1])).rotated(deg_to_rad(float(piece.get("rotation",0))))
static func raw(piece:Dictionary,p:Vector2) -> float:
 var r=float(piece.radius); var h=float(piece.height)
 if piece.profile=="smooth": return h*(1-smoothstep(0,1,p.length()/r))
 var rough=float(piece.get("edge_roughness",0))
 var width=float(piece.get("plateau_width",r*2))*.5+(sin(p.y*.45)+sin(p.y*1.17)*.35)*rough
 var depth=float(piece.get("plateau_depth",r))+sin(p.x*.58)*rough
 if absf(p.x)>width or p.y< -depth or p.y>r: return 0
 # South side is a continuous walk-up; other sides are sharp escarpments.
 var result=h*clampf(1-p.y/r,0,1)
 if rough>0:
  result*=smoothstep(0,.7,width-absf(p.x))*smoothstep(0,.7,p.y+depth)
  result*=1+sin(p.x*.8)*sin(p.y*.65)*.025
 return result
static func height(piece:Dictionary,at:Vector3,top_only:bool=false) -> float:
 var p=local_point(piece,at)
 if piece.profile=="overhang" and p.y< -float(piece.get("plateau_depth",piece.radius))*.35 and not top_only and at.y<float(piece.height)-.45: return 0
 if piece.profile=="overhang": return raw(piece,p)
 var cell=(p/STEP).floor()*STEP; var uv=(p-cell)/STEP
 var a=raw(piece,cell); var b=raw(piece,cell+Vector2(STEP,0)); var c=raw(piece,cell+Vector2(0,STEP)); var d=raw(piece,cell+Vector2.ONE*STEP)
 return a+(b-a)*uv.x+(c-a)*uv.y if uv.x+uv.y<=1 else d+(c-d)*(1-uv.x)+(b-d)*(1-uv.y)
static func apply(pieces:Array,at:Vector3,base:float,top_only:bool=false) -> float:
 var result=base
 for piece in pieces:
  var value=height(piece,at,top_only)
  if is_zero_approx(value): continue
  result=maxf(result,value) if piece.height>=0 else minf(result,value)
 return result
static func mesh(parent:Node3D,surface:SurfaceTool,color:String,actor_collision:bool=false) -> void:
 surface.generate_normals(); var geometry=surface.commit()
 var visual=Props.mesh_node(parent,geometry,Vector3.ZERO,color)
 var material=Props.mat(color).duplicate(); material.cull_mode=BaseMaterial3D.CULL_DISABLED; visual.material_override=material
 var body=StaticBody3D.new(); body.set_meta("terrain_surface",true); body.collision_layer=9 if actor_collision else 8; body.collision_mask=0
 var collision=CollisionShape3D.new(); collision.shape=geometry.create_trimesh_shape(); collision.shape.backface_collision=true; body.add_child(collision); parent.add_child(body)
static func build_ground(world:Node3D) -> void:
 var surface=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var b=world.definition.bounds
 for x in range(b[0]*2,b[2]*2):
  for z in range(b[1]*2,b[3]*2):
   var kind=world.terrain_at(int(floor(x*.5)),int(floor(z*.5)))
   if kind=="water": continue
   var color=Color("#799369") if kind=="grass" else Color("#b0a485") if kind=="path" else Color("#707d60") if kind=="cobble" else Color("#bfaf90")
   if world.definition.get("biome","")=="jungle" and kind=="grass": color=Color("#507858")
   for offset in [Vector2.ZERO,Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2.ONE,Vector2(0,1)]:
    var at=Vector3((x+offset.x)*.5,0,(z+offset.y)*.5)
    # Overhanging ledges get their own closed mesh, leaving ground below intact.
    at.y=world.raw_sculpt_height(at)+.006; surface.set_color(color); surface.add_vertex(at)
 surface.generate_normals(); var geometry=surface.commit(); var visual=Props.mesh_node(world,geometry,Vector3.ZERO,"#ffffff")
 var material=Props.mat("#ffffff").duplicate(); material.vertex_color_use_as_albedo=true; visual.material_override=material
 var body=StaticBody3D.new(); body.set_meta("terrain_surface",true); body.collision_layer=8; body.collision_mask=0
 var collision=CollisionShape3D.new(); collision.shape=geometry.create_trimesh_shape(); body.add_child(collision); world.add_child(body)
 # Alpha 2 escarpments are physical walls even during jumps. Walkable ground
 # keeps its existing virtual-height contract and camera-only surface collider.
 if String(world.definition.id).begins_with("a2_"):
  var faces=geometry.get_faces();var steep=PackedVector3Array()
  for i in range(0,faces.size(),3):
   var normal=(faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).normalized()
   if absf(normal.y)<.65:steep.append_array([faces[i],faces[i+1],faces[i+2]])
  if not steep.is_empty():
   var cliff=StaticBody3D.new();cliff.name="ImpassableEscarpments";cliff.collision_layer=1;cliff.collision_mask=0
   var shape=ConcavePolygonShape3D.new();shape.set_faces(steep);shape.backface_collision=true
   var wall=CollisionShape3D.new();wall.shape=shape;cliff.add_child(wall);world.add_child(cliff)
 for piece in world.definition.get("sculpted_terrain",[]):
  if piece.profile=="overhang": build_ledge(world,piece)
static func build_ledge(world:Node3D,piece:Dictionary) -> void:
 var node=Node3D.new(); node.position=Vector3(piece.at[0],0,piece.at[1]); node.rotation.y=deg_to_rad(piece.get("rotation",0)); world.add_child(node)
 var r=float(piece.radius); var h=float(piece.height); var width=float(piece.get("plateau_width",r*2))*.5; var depth=float(piece.get("plateau_depth",r))
 # Closed cross-section: south ramp, supported cliff, undercut and projecting roof.
 var section=[Vector2(r,0),Vector2(0,h),Vector2(-depth,h),Vector2(-depth,h-.6),Vector2(-depth*.35,h-.6),Vector2(-depth*.35,0)]
 var surface=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(section.size()):
  var a=section[i]; var b=section[(i+1)%section.size()]
  for v in [Vector3(-width,a.y,a.x),Vector3(width,a.y,a.x),Vector3(-width,b.y,b.x),Vector3(width,a.y,a.x),Vector3(width,b.y,b.x),Vector3(-width,b.y,b.x)]: surface.add_vertex(v)
 # Triangulate the concave end faces, preserving the underside opening.
 var polygon=PackedVector2Array(section); var indices=Geometry2D.triangulate_polygon(polygon)
 for side in [-1,1]:
  for i in indices: surface.add_vertex(Vector3(side*width,section[i].y,section[i].x))
 mesh(node,surface,"#7d8c70",true)

static func contains(piece:Dictionary,at:Vector2) -> bool:
 var p=local_point(piece,Vector3(at.x,0,at.y))
 if piece.profile=="smooth": return p.length()<=piece.radius
 return absf(p.x)<=float(piece.get("plateau_width",piece.radius*2))*.5 and p.y>=-float(piece.get("plateau_depth",piece.radius)) and p.y<=piece.radius
static func fits(piece:Dictionary,bounds:Rect2) -> bool:
 var center=Vector2(piece.at[0],piece.at[1])
 if piece.profile=="smooth": return bounds.grow(.00001).encloses(Rect2(center-Vector2.ONE*float(piece.radius),Vector2.ONE*float(piece.radius)*2))
 var half=float(piece.get("plateau_width",piece.radius*2))*.5; var depth=float(piece.get("plateau_depth",piece.radius))
 for corner in [Vector2(-half,-depth),Vector2(half,-depth),Vector2(-half,piece.radius),Vector2(half,piece.radius)]:
  if not bounds.grow(.00001).has_point(center+corner.rotated(-deg_to_rad(float(piece.get("rotation",0))))): return false
 return true
