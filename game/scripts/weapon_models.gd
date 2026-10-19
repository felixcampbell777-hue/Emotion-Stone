extends RefCounted
## Original weapon meshes. Local origin is grip; weapon points toward local -Y.
static func material(color:String,metallic:float=0.0,roughness:float=.6) -> StandardMaterial3D:
 var m=StandardMaterial3D.new();m.albedo_color=Color(color);m.metallic=metallic;m.roughness=roughness;return m
static func mesh(parent:Node3D,shape:Mesh,at:Vector3,mat:Material) -> MeshInstance3D:
 var node=MeshInstance3D.new();node.mesh=shape;node.material_override=mat;node.position=at;parent.add_child(node);return node
static func link(parent:Node3D,a:Vector3,b:Vector3,radius:float,mat:Material) -> MeshInstance3D:
 var shape=CylinderMesh.new();shape.top_radius=radius;shape.bottom_radius=radius;shape.height=a.distance_to(b);shape.radial_segments=10
 var node=mesh(parent,shape,(a+b)*.5,mat)
 var up=(b-a).normalized();var right=Vector3.RIGHT-up*up.x
 if right.length_squared()<.001:right=Vector3.FORWARD-up*up.z
 right=right.normalized();node.basis=Basis(right,up,right.cross(up));return node
static func create(kind:String,p:Dictionary) -> Node3D:
 var root=Node3D.new();root.name="Weapon_"+kind;root.set_meta("weapon_kind",kind)
 var wood=material("#493023",0,.54);var leather=material("#211a17",0,.85);var steel=material("#b8c6cf",.82,.23);var gold=material("#b89b58",.68,.31)
 if kind=="spear":
  link(root,Vector3(0,.08,0),Vector3(0,-float(p.length)+.40,0),.016,wood)
  var head=PrismMesh.new();head.size=Vector3(.15,.49,.055);var tip=mesh(root,head,Vector3(0,-float(p.length)+.245,0),steel);tip.rotation.z=PI
  for y in [-.53,-.48,-.43,-.38,-.33,-.28,-.23,-.18,-.13,-.08,-.03,.02]:link(root,Vector3(0,y,0),Vector3(0,y+.025,0),.019,leather)
  link(root,Vector3(0,-float(p.length)+.42,0),Vector3(0,-float(p.length)+.58,0),.028,gold)
  link(root,Vector3(0,.055,0),Vector3(0,.085,0),.020,steel)
 elif kind=="rapier":
  var blade=PrismMesh.new();blade.size=Vector3(.044,float(p.length)-.10,.025);mesh(root,blade,Vector3(0,-(float(p.length)+.1)*.5,0),steel).rotation.z=PI
  link(root,Vector3(0,.07,0),Vector3(0,-.1,0),.027,leather)
  link(root,Vector3(-.17,-.08,0),Vector3(.17,-.08,0),.016,gold)
  # Swept knuckle bow and bowl rings make the guard readable at first-person scale.
  for i in range(16):
   var a=float(i)/16*TAU;var b=float(i+1)/16*TAU
   link(root,Vector3(cos(a)*.12,-.095,sin(a)*.12),Vector3(cos(b)*.12,-.095,sin(b)*.12),.009,gold)
  for i in range(12):
   var a=float(i)/12*PI;var b=float(i+1)/12*PI
   link(root,Vector3(.11*sin(a),.01+.13*cos(a),.04),Vector3(.11*sin(b),.01+.13*cos(b),.04),.009,gold)
  var pommel=SphereMesh.new();pommel.radius=.028;pommel.height=.056;mesh(root,pommel,Vector3(0,.095,0),gold)
 elif kind=="bow":
  # Bow lives in X/Y plane. Curved limbs terminate behind the grip toward string.
  for side in [-1.0,1.0]:
   for i in range(12):
    var t=float(i)/12;var u=float(i+1)/12
    var a=Vector3(0,side*.72*t,.19*sin(t*PI*.85));var b=Vector3(0,side*.72*u,.19*sin(u*PI*.85))
    link(root,a,b,lerpf(.012,.007,t),wood)
   link(root,Vector3(0,side*.69,.19*sin(PI*.85)),Vector3(0,side*.74,.19*sin(PI*.85)),.010,gold)
  link(root,Vector3(0,-.12,0),Vector3(0,.12,0),.020,leather)
  var string=Node3D.new();string.name="String";root.add_child(string)
  var nocked=arrow();nocked.name="NockedArrow";root.add_child(nocked)
  update_string(root,0)
 return root
static func bow_grip() -> Vector3:return Vector3(-.18,-.16,-.55)
static func nock_position(charge:float) -> Vector3:
 return Vector3(0,0,lerpf(.08,.16,clampf(charge,0,1)))
static func arrow_tip_socket(charge:float) -> Vector3:
 return nock_position(charge)+Vector3(0,0,-.705)
static func update_string(root:Node3D,charge:float) -> void:
 var string=root.get_node_or_null("String")
 if string==null:return
 for child in string.get_children():child.free()
 var nock=nock_position(charge)
 var nocked=root.get_node_or_null("NockedArrow")
 if nocked!=null:nocked.position=nock+Vector3(0,0,-.32)
 var m=material("#ded4b6",0,.9)
 link(string,Vector3(0,.72,.086),nock,.0025,m);link(string,nock,Vector3(0,-.72,.086),.0025,m)
static func arrow() -> Node3D:
 var root=Node3D.new();var wood=material("#775537");var steel=material("#aab7bd",.7,.3);var feather=material("#ddd7bc")
 link(root,Vector3(0,0,.32),Vector3(0,0,-.32),.006,wood)
 var tip=PrismMesh.new();tip.size=Vector3(.035,.09,.018);var head=mesh(root,tip,Vector3(0,0,-.34),steel);head.rotation.x=PI*.5
 for angle in [0.0,PI*.5]:
  var f=BoxMesh.new();f.size=Vector3(.05,.003,.10);var fin=mesh(root,f,Vector3(0,0,.24),feather);fin.rotation.z=angle
 return root
