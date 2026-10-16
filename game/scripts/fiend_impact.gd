extends Node3D
## Visual-only boss impact. Damage remains the single actor-owned landing hit.
var game:Node
var age=0.0
var ring:MeshInstance3D
var debris:Array=[]
func configure(owner:Node,at:Vector3) -> void:
	game=owner;position=at+Vector3.UP*.04;add_to_group("fiend_impact")
	var torus=TorusMesh.new();torus.inner_radius=.91;torus.outer_radius=1.0;torus.rings=48;torus.ring_segments=6
	ring=load("res://scripts/props.gd").mesh_node(self,torus,Vector3.ZERO,"#cab38a");ring.scale=Vector3(.1,.2,.1)
	var mat=StandardMaterial3D.new();mat.albedo_color=Color(.63,.57,.43,.8);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ring.material_override=mat
	for i in range(20):
		var a=i*TAU/20;var direction=Vector3(sin(a),0,cos(a))
		var rock=load("res://scripts/props.gd").box(self,direction*.3,Vector3(.12,.16,.13)*(1+i%3*.3),"#7c7965")
		debris.append({"node":rock,"velocity":direction*(2.1+i%4*.4)+Vector3.UP*(2.8+i%3*.6)})
func _physics_process(delta:float) -> void:
	if not is_instance_valid(game) or not game.player.input_enabled:return
	age+=delta
	var radius=lerpf(.1,3.0,clampf(age/.48,0,1));ring.scale=Vector3(radius,.2,radius);ring.material_override.albedo_color.a=maxf(0,.8*(1-age/.65))
	for entry in debris:
		var n:Node3D=entry.node;n.position+=entry.velocity*delta;entry.velocity.y-=9.8*delta;n.position.y=maxf(.02,n.position.y);n.rotation+=Vector3(2,3,1)*delta
	if age>=1.3:queue_free()
