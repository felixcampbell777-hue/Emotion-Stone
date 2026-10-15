extends "res://scripts/rock_projectile.gd"
const Art=preload("res://scripts/environment_art.gd")
static func pod(parent:Node3D) -> Node3D:
	var root=Node3D.new();parent.add_child(root)
	var ball=SphereMesh.new();ball.radius=.4;ball.height=.74;ball.radial_segments=20;ball.rings=12
	var shell=Props.mesh_node(root,ball,Vector3.ZERO,"#657b46");shell.material_override=Art.texture_material("pine_bark",2.4,Color("#81975b"))
	for i in range(7):
		var thorn=Props.cone(root,Vector3(cos(i*TAU/7)*.35,.05,sin(i*TAU/7)*.35),.07,.27,"#a4c89a",0)
		thorn.rotation.z=sin(i*TAU/7)*1.2;thorn.rotation.x=cos(i*TAU/7)*1.2
	return root
func configure(owner_game:Node,source:Node3D,travel:Vector3) -> void:
	super.configure(owner_game,source,travel);stone.visible=false
	pod(self)
func repel(away:Vector3,force:float,stun:float) -> void:
	super.repel(away,force,stun);game.notify("Thornseed returned · break through the parted bark!")
