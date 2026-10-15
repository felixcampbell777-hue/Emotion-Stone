extends RefCounted
## Campaign landmarks assembled from the existing trusted scenery/material library.
const Props=preload("res://scripts/props.gd")
const Art=preload("res://scripts/environment_art.gd")
static func build(game:Node) -> void:
	var world=game.current_world;var id=String(game.map_id)
	if id in ["a2_mill","a2_fen"]:
		for region in world.definition.terrain_regions:
			if region.kind!="water": continue
			var r=region.rect;var water=Props.box(world,Vector3(r[0]+r[2]/2,-.035,r[1]+r[3]/2),Vector3(r[2],.04,r[3]),"#528a92")
			water.material_override=load("res://shaders/realistic_water.tres")
	if id=="a2_mill":
		var wheel=Node3D.new();world.add_child(wheel);wheel.position=Vector3(-15,1.65,-11)
		var torus=TorusMesh.new();torus.inner_radius=1.27;torus.outer_radius=1.45;torus.rings=40;torus.ring_segments=8
		for x in [-.25,.25]:
			var ring=Props.mesh_node(wheel,torus,Vector3(x,0,0),"#806243");ring.rotation.z=PI/2;ring.material_override=Art.texture_material("brown_planks_05",.8,Color("#a3957a"))
		for i in range(12):
			var angle=i*TAU/12
			var paddle=Props.box(wheel,Vector3(0,sin(angle)*1.32,cos(angle)*1.32),Vector3(.78,.18,.36),"#78583a");paddle.rotation.x=-angle
			var spoke=Props.box(wheel,Vector3(0,sin(angle)*.65,cos(angle)*.65),Vector3(.12,.12,1.35),"#78583a");spoke.rotation.x=-angle
		Props.collider(world,Vector3(-15,1.65,-11),Vector3(.9,3.2,3.1))
		Props.box(world,Vector3(-12.8,1.65,-11),Vector3(4.5,.25,.25),"#66503a")
	if id=="a2_quarry":
		for i in range(7):
			var scaffold=Node3D.new();world.add_child(scaffold);scaffold.position=Vector3(-20 if i%2==0 else 21,0,-16+i*5)
			for x in [-1.3,1.3]: Props.box(scaffold,Vector3(x,1.5,0),Vector3(.20,3,.24),"#795f43")
			Props.box(scaffold,Vector3(0,3,0),Vector3(3.1,.20,.24),"#795f43")
			Props.collider(scaffold,Vector3(-1.3,1.5,0),Vector3(.2,3,.24));Props.collider(scaffold,Vector3(1.3,1.5,0),Vector3(.2,3,.24))
	if id=="a2_belfry":
		for x in [-11,11]:
			Props.box(world,Vector3(x,3,-13),Vector3(1.1,6,1.1),"#68776b");Props.collider(world,Vector3(x,3,-13),Vector3(1.1,6,1.1))
		Props.box(world,Vector3(0,6,-13),Vector3(23,1,1.3),"#748076")
		var bell=Props.cone(world,Vector3(0,4.7,-13),1.05,1.8,"#9c885c",.44)
		bell.material_override=Art.texture_material("rocky_trail",.8,Color("#bba46d"))
		Props.box(world,Vector3(0,5.7,-13),Vector3(.16,1.0,.16),"#806b45")
	# Shared materials, distinct atmospheres; no new downloads or third-party scripts.
	if id=="a2_haven":
		game.environment_settings.tonemap_exposure=1.08;game.environment_settings.fog_density=.007
	elif id=="a2_fen":
		game.environment_settings.fog_light_color=Color("#658e89");game.environment_settings.fog_density=.021
	elif id=="a2_quarry":
		game.environment_settings.fog_density=.008;game.environment_settings.tonemap_exposure=1.02
	elif id=="a2_wood":
		game.environment_settings.fog_light_color=Color("#748665");game.environment_settings.fog_density=.017
