extends RefCounted
const Props=preload("res://scripts/props.gd")
const Art=preload("res://scripts/environment_art.gd")
const Fen=preload("res://scripts/swamp_shape.gd")
static func center() -> Vector3:
	return Vector3(Fen.spec.raft.anchor[0]+16,.85,Fen.spec.raft.anchor[1])
static func build(world:Node3D) -> void:
	var root=Node3D.new();root.name="FenTradingRaft";world.add_child(root);root.position=center()
	var wood=Art.texture_material("brown_planks_05",1,Color("#887351"))
	# Moored log floats support a compact deck and a level gangplank to E11.
	for z in [-3.5,-1.75,0,1.75,3.5]:
		var log=Props.cone(root,Vector3(0,-.5,z),.48,8.8,"#4a4131",.48);log.rotation.z=PI/2
	for i in range(18):
		var plank=Props.box(root,Vector3(0,-.12,-4.25+i*.5),Vector3(8,.24,.47),"#887351");plank.material_override=wood
	Props.collider(root,Vector3(0,-.16,0),Vector3(8,.32,9))
	for i in range(15):
		var plank=Props.box(root,Vector3(-11+i*.48,-.12,0),Vector3(.46,.24,2.3),"#887351");plank.material_override=wood
	Props.collider(root,Vector3(-7.5,-.16,0),Vector3(7,.32,2.3))
	# Low perimeter posts/rope leave the landward entrance open.
	for x in [-3.7,3.7]:
		for z in [-4.1,4.1]:
			Props.cone(root,Vector3(x,.6,z),.12,1.4,"#584b37",.10)
		if x<0:
			for z in [-2.7,2.7]:
				Props.box(root,Vector3(x,.8,z),Vector3(.045,.045,2.8),"#ab9a75");Props.collider(root,Vector3(x,.45,z),Vector3(.12,.9,2.8))
		else:
			Props.box(root,Vector3(x,.8,0),Vector3(.045,.045,8.2),"#ab9a75");Props.collider(root,Vector3(x,.45,0),Vector3(.12,.9,8.2))
	for z in [-4.1,4.1]:
		Props.box(root,Vector3(0,.8,z),Vector3(7.4,.045,.045),"#ab9a75");Props.collider(root,Vector3(0,.45,z),Vector3(7.4,.9,.12))
	for x in [-1.7,1.7]:
		var desk=Props.box(root,Vector3(x,.9,1.4),Vector3(2.5,.18,1.1),"#887351");desk.material_override=wood
		for leg in [-1,1]:Props.box(root,Vector3(x+leg,.42,1.4),Vector3(.12,.85,.7),"#5b4830")
		Props.collider(root,Vector3(x,.48,1.4),Vector3(2.5,.96,1.1))
	# Records, wares and patched canvas give a small working outpost a purpose.
	Props.box(root,Vector3(-1.7,1.02,1.4),Vector3(.65,.06,.5),"#d5caa1")
	for i in range(3):Props.cone(root,Vector3(-.8+i*.23,1.15,1.4),.07,.25,"#9c4c43",.04)
	for x in [-3.3,3.3]:Props.cone(root,Vector3(x,1.9,3.3),.09,3.8,"#645238",.07)
	var cloth=Props.box(root,Vector3(0,3.7,1.8),Vector3(7,.07,4),"#485b4c");cloth.rotation.x=.1
	for x in [2.6,3.1]:Props.box(root,Vector3(x,.35,-2.8),Vector3(.7,.7,.7),"#66563a")
	# Tall physical lantern and one small local light. Distant glow is a cheap
	# depth-tested sprite rendered after fog, deliberately faint from H11.
	Props.cone(root,Vector3(2.5,3.1,-2.7),.10,6.2,"#5c4b32",.06)
	Props.box(root,Vector3(1.9,6.1,-2.7),Vector3(1.3,.10,.10),"#5c4b32")
	var lamp=Props.box(root,Vector3(1.4,5.7,-2.7),Vector3(.4,.6,.4),"#ffcf79")
	var gold=Props.mat("#ffcf79").duplicate();gold.emission_enabled=true;gold.emission=Color("#ffd58b");gold.emission_energy_multiplier=3;lamp.material_override=gold
	for y in [5.35,6.05]:Props.box(root,Vector3(1.4,y,-2.7),Vector3(.55,.1,.55),"#493d2a")
	var light=OmniLight3D.new();light.position=Vector3(1.4,5.65,-2.7);light.light_color=Color("#ffc879");light.light_energy=2.5;light.omni_range=11;light.shadow_enabled=false;root.add_child(light)
	var mesh=QuadMesh.new();mesh.size=Vector2(2.8,2.8);var glow=Props.mesh_node(root,mesh,light.position,"#ffcf79");glow.name="FogBeacon"
	var mat=ShaderMaterial.new();mat.shader=preload("res://shaders/swamp_beacon.gdshader");mat.render_priority=127;glow.material_override=mat;glow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
static func build_staff(game:Node) -> void:
	var at=center()
	for entry in [["wr_clerk","Mara · Fen Guild Desk","farm_mira",-1.7],["wr_swords","Corin · Fen Vendor","keeper",1.7]]:
		var npc=load("res://scripts/actor.gd").new();npc.name=entry[0]
		var definition=game.read_data("res://content/characters/"+entry[2]+".json").duplicate(true);definition.display_name=entry[1];npc.configure(definition);game.EnvironmentArt.actor_quality(npc,game.environment_profile);npc.ground_world=game.current_world;game.world_root.add_child(npc);npc.position=at+Vector3(entry[3],0,2.5);npc.visual.rotation.y=PI;game.npcs.append(npc)
		game.current_world.interactions.append({"id":entry[0],"title":entry[1],"role":entry[0],"position":at+Vector3(entry[3],0,.1),"actor":npc,"lines":[]})
