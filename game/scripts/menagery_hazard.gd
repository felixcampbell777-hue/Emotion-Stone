extends Node3D
const Props=preload("res://scripts/props.gd")
var game:Node
var age=0.0
var lifetime=5.0
var sticky=true
var radius=1.0
var producer:WeakRef
var dash_triggered=false
var splash:Node3D
var trapped=false
var surface:MeshInstance3D
func configure(owner:Node,at:Vector3,sap:bool,thrower:Node=null) -> void:
	game=owner
	if game.has_method("bind_effect"):game.bind_effect(self)
	position=Vector3(at.x,game.current_world.ground_height(at)+.025,at.z)
	if game.map_id=="wr_floor_02":position.y=maxf(position.y,.025)
	sticky=sap
	lifetime=float(game.menagery.catalog.sticky_seconds) if sticky else 2.4
	radius=1.15 if sticky else 2.0
	if thrower!=null:
		producer=weakref(thrower); radius=float(game.menagery.catalog.resin_attack.puddle_radius); lifetime=float(game.menagery.catalog.resin_attack.puddle_seconds)
	add_to_group("menagery_effect")
	surface=Props.cone(self,Vector3.ZERO,radius,.02,"#bc9442" if sticky else "#b995b1",radius)
	var label=Label3D.new(); label.text="2E Sticky sap" if sticky else "8E Spore warning"; label.font_size=28; label.pixel_size=.006; label.position.y=.15; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.visible=game.map_id!="wr_floor_02"
	add_child(label)
	if thrower!=null:
		splash=Node3D.new(); add_child(splash)
		var droplet=SphereMesh.new(); droplet.radius=.08; droplet.height=.16; droplet.radial_segments=6; droplet.rings=3
		for i in range(8): Props.mesh_node(splash,droplet,Vector3(sin(i*TAU/8)*radius*.6,.10,cos(i*TAU/8)*radius*.6),"#e1b550")
func contains_player() -> bool:
	return age<lifetime and ((game.player.position-position)*Vector3(1,0,1)).length()<radius
func _physics_process(delta:float) -> void:
	if is_queued_for_deletion(): return
	if not is_instance_valid(game) or not game.simulation_active() or game.gallery_mode: return
	age+=delta
	if age>=lifetime:
		if trapped:preload("res://scripts/world_sound.gd").play(game,"enemy.resin.release",position)
		queue_free(); return
	var targets=game.combat_players() if game.has_method("combat_players") else [game.player]
	var was_trapped=trapped;trapped=false
	for target in targets:
		var offset=(target.position-position)*Vector3(1,0,1)
		if offset.length()>=radius:continue
		if sticky:
			trapped=true
			target.slow_sources[get_instance_id()]={"remaining":.15,"factor":float(game.menagery.catalog.sticky_multiplier)}
			if producer!=null and not dash_triggered:
				var owner=producer.get_ref()
				if is_instance_valid(owner):dash_triggered=owner.notice_trapped_target(target)
		elif age>=.75:target.take_damage(9,offset.normalized())
	if trapped and not was_trapped:preload("res://scripts/world_sound.gd").play(game,"enemy.resin.sticky",position)
	if was_trapped and not trapped:preload("res://scripts/world_sound.gd").play(game,"enemy.resin.release",position)
	if splash!=null: splash.visible=age<.45; splash.position.y=.35*sin(PI*clampf(age/.45,0,1)); splash.scale=Vector3.ONE*(1+age)
	surface.scale=Vector3.ONE*(1+.025*sin(age*8))
