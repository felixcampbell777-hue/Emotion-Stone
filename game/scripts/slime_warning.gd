extends Node3D
const Props=preload("res://scripts/props.gd")
var game:Node
var lifetime=0.0
var age=0.0
func configure(at:Vector3,radius:float,caption:String) -> void:
	position=at+Vector3.UP*.04; add_to_group("menagery_effect")
	var surface=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(64):
		var points=[]
		for edge in [[i,radius-.06],[i,radius+.06],[i+1,radius-.06],[i+1,radius+.06]]:
			var angle=float(edge[0])*TAU/64; var local=Vector3(sin(angle)*edge[1],0,cos(angle)*edge[1])
			local.y=get_parent().ground_height(at+local)-at.y+.01; points.append(local)
		for index in [0,2,1,1,2,3]: surface.add_vertex(points[index])
	surface.generate_normals(); Props.mesh_node(self,surface.commit(),Vector3.ZERO,"#efad57")
	for sign in [-1,1]:
		var line=Props.box(self,Vector3.ZERO,Vector3(radius*.8,.025,.065),"#ffca76"); line.rotation.y=sign*PI/4
	var label=Label3D.new(); label.text=caption; label.position.y=.16; label.font_size=28; label.pixel_size=.005; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; add_child(label)
func _physics_process(delta:float) -> void:
	if lifetime<=0 or game==null or not game.simulation_active() or game.gallery_mode: return
	age+=delta; scale=Vector3.ONE*(1+age*.3)
	if age>=lifetime: queue_free()
