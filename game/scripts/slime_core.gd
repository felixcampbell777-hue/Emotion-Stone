extends "res://scripts/slime.gd"
var game:Node
var queen:Node3D
var entry:Dictionary
var age=0.0
var duration=5.0
var lobes:Array=[]
var core_label:Label3D
var forming_body:MeshInstance3D
func setup_core(owner:Node,source:Node3D,variant:Dictionary,at:Vector3) -> void:
	game=owner; queen=source; entry=variant; duration=float(game.menagery.catalog.queen_attack.core_seconds)
	configure({"id":"brood_core_"+str(get_instance_id()),"kind":"practice","at":[at.x,at.z],"size":"small","display_name":"Brood core","transient":true,"combat_height":.8,"label_height":1.2},game.player)
	position=at; max_health=int(game.menagery.catalog.queen_attack.core_health); health=max_health; collision.shape.radius=.33; collision.position.y=.35
	for child in visual.get_children(): child.free()
	body=Props.cone(visual,Vector3(0,.40,0),.20,.65,"#ecdbc0",.04)
	var slime_mesh=SphereMesh.new(); slime_mesh.radius=.55; slime_mesh.height=.95; slime_mesh.radial_segments=10; slime_mesh.rings=5
	forming_body=Props.mesh_node(visual,slime_mesh,Vector3(0,.48,0),entry.color); forming_body.scale=Vector3.ONE*.05
	var puddle=Props.cone(visual,Vector3(0,.025,0),1.15,.045,entry.color,1.15); puddle.name="BroodPuddle"
	var mesh=SphereMesh.new(); mesh.radius=.28; mesh.height=.25; mesh.radial_segments=8; mesh.rings=4
	for i in range(10): lobes.append(Props.mesh_node(visual,mesh,Vector3(sin(i*TAU/10),.09,cos(i*TAU/10)),entry.color))
	core_label=Label3D.new(); core_label.font_size=26; core_label.pixel_size=.0045; core_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; core_label.position.y=1.1; add_child(core_label)
	add_to_group("queen_brood"); add_to_group("menagery_effect")
	defeated.connect(func(): game.call_deferred("retire_transient",self))
	var offset=(game.player.position-position)*Vector3(1,0,1)
	if offset.length()<float(game.menagery.catalog.queen_attack.splash_radius) and not game.impact_blocked(position,game.player.position): game.player.take_damage(int(game.menagery.catalog.queen_attack.splash_damage),offset.normalized())
func take_damage(amount:int,from_direction:Vector3) -> void:
	super.take_damage(amount,from_direction); knockback=Vector3.ZERO
func _physics_process(delta:float) -> void:
	if not simulation_enabled or health<=0 or not game.simulation_active() or game.gallery_mode: return
	if not is_instance_valid(queen) or queen.health<=0: take_damage(health,Vector3.ZERO); return
	age+=delta; var t=clampf(age/duration,0,1)
	core_label.text="CORE  %.1fs" % maxf(0,duration-age)
	body.scale=Vector3.ONE*(1+.15*sin(age*12)); visual.get_node("BroodPuddle").scale=Vector3(1-t*.8,1,1-t*.8)
	forming_body.scale=Vector3.ONE*lerpf(.05,1,smoothstep(.4,1,t)); body.position.y=.4+.55*smoothstep(.4,1,t)
	for i in range(lobes.size()):
		var a=i*TAU/10+age*.35; var radius=1.0*(1-smoothstep(.15,1,t))
		lobes[i].position=Vector3(sin(a)*radius,.10+.45*t+sin(age*9+i)*.07,cos(a)*radius); lobes[i].scale=Vector3(1,1+t*2,1)
	if t>=1:
		queen.spawn_brood(entry,position); take_damage(health,Vector3.ZERO)
