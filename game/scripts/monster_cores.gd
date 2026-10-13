extends RefCounted
const Props=preload("res://scripts/props.gd")
const Worlds=preload("res://scripts/world_pack.gd")
var game:Node
var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://content/monster_cores.json"))
var quantities:Dictionary={}
var pending:Array=[]
var serial=0
var nodes:Dictionary={}
var rng=RandomNumberGenerator.new()
var warning:Control
var warning_panel:PanelContainer
func _init() -> void: rng.randomize()
func item(id:String) -> Dictionary:
	for entry in catalog.cores:
		if entry.id==id: return entry
	return {}
func boss_bonus(kind:String) -> int: return int(catalog.profiles.get(kind,{}).get("boss_bonus",0))
func roll(kind:String,drop_roll:float=-1,variant_roll:float=-1) -> String:
	if kind in catalog.beasts or not catalog.profiles.has(kind): return ""
	var table=catalog.profiles[kind]
	if float(table.drop_rate)<1.0 and (rng.randf() if drop_roll<0 else drop_roll)>=float(table.drop_rate): return ""
	if not table.variant.is_empty() and (rng.randf() if variant_roll<0 else variant_roll)<float(table.variant_chance): return table.variant
	return table.generic
func reset() -> void:
	quantities.clear(); pending.clear(); serial=0; nodes.clear()
	if warning!=null: warning.hide()
func snapshot() -> Dictionary: return {"quantities":quantities.duplicate(),"pending":pending.duplicate(true),"serial":serial}
static func valid_save(data:Variant,world:String="") -> bool:
	if not data is Dictionary: return false
	var definitions=JSON.parse_string(FileAccess.get_file_as_string("res://content/monster_cores.json")).cores
	var counts=data.get("quantities",{}); var drops=data.get("pending",[]); var sequence=data.get("serial",0)
	if not counts is Dictionary or not drops is Array or drops.size()>4096: return false
	if not Worlds.finite_number(sequence) or sequence!=int(sequence) or sequence<0 or sequence>1000000000: return false
	for id in counts:
		if not definitions.any(func(e): return e.id==id) or not Worlds.finite_number(counts[id]) or counts[id]!=int(counts[id]) or counts[id]<1 or counts[id]>99999: return false
	var seen=[]
	for drop in drops:
		if not drop is Dictionary or drop.size()!=4 or not drop.has_all(["key","id","map","at"]): return false
		if not Worlds.finite_number(drop.key) or drop.key!=int(drop.key) or drop.key<1 or drop.key>sequence or drop.key in seen: return false
		seen.append(drop.key)
		if not definitions.any(func(e): return e.id==drop.id) or not drop.map is String or not drop.at is Array or drop.at.size()!=3: return false
		for value in drop.at:
			if not Worlds.finite_number(value): return false
		var area=Worlds.definition(drop.map,world)
		if area.is_empty(): return false
		var b=area.bounds
		if drop.at[0]<b[0] or drop.at[0]>b[2] or drop.at[2]<b[1] or drop.at[2]>b[3] or drop.at[1]< -6 or drop.at[1]>12: return false
	return true
func restore(data:Dictionary) -> void:
	quantities=data.get("quantities",{}).duplicate(); pending=data.get("pending",[]).duplicate(true); serial=int(data.get("serial",0)); nodes.clear()
	if game.quest_stage=="component_ready" and int(quantities.get("golem_core",0))==0: give("golem_core")
func give(id:String,count:int=1) -> bool:
	if item(id).is_empty() or count<1: return false
	quantities[id]=mini(99999,int(quantities.get(id,0))+count); return true
func claim(id:String,count:int=1) -> bool:
	return game.map_id=="menagery" and give(id,count)
func defeated(kind:String,at:Vector3,quest_warden:bool=false,drop_roll:float=-1,variant_roll:float=-1) -> String:
	var id=roll(kind,drop_roll,variant_roll)
	# The story warden's guaranteed drop already has an authored corpse interaction.
	if id.is_empty() or quest_warden: return id
	serial+=1
	var bounds=game.current_world.bounds
	var safe=Vector3(clampf(at.x,bounds.position.x+.1,bounds.end.x-.1),0,clampf(at.z,bounds.position.y+.1,bounds.end.y-.1)); safe.y=game.current_world.ground_height(safe)
	var drop={"key":serial,"id":id,"map":game.map_id,"at":[safe.x,safe.y,safe.z]}
	pending.append(drop); build_drop(drop); return id
func build_map() -> void:
	nodes.clear()
	for drop in pending:
		if drop.map==game.map_id: build_drop(drop)
func build_drop(drop:Dictionary) -> void:
	var root=Node3D.new(); root.name="MonsterCore_"+str(drop.key); game.current_world.add_child(root); nodes[int(drop.key)]=root
	root.position=Vector3(drop.at[0],drop.at[1],drop.at[2])
	var ring=TorusMesh.new(); ring.inner_radius=.20; ring.outer_radius=.26; ring.rings=12; ring.ring_segments=6
	Props.mesh_node(root,ring,Vector3(0,.03,0),item(drop.id).color)
	var shape=SphereMesh.new(); shape.radius=.16; shape.height=.36; shape.radial_segments=8; shape.rings=4
	var gem=Props.mesh_node(root,shape,Vector3(0,.24,0),item(drop.id).color)
	var material=StandardMaterial3D.new(); material.albedo_color=Color(item(drop.id).color); material.emission_enabled=true; material.emission=material.albedo_color; material.emission_energy_multiplier=.8; gem.material_override=material
	game.current_world.interactions.append({"id":"monster_core_"+str(drop.key),"loot_core":int(drop.key),"title":"Loot "+item(drop.id).name,"position":root.position,"actor":null,"lines":[]})
func collect(key:int) -> bool:
	var matches=pending.filter(func(drop): return int(drop.key)==key and drop.map==game.map_id)
	if matches.is_empty() or not game.player.input_enabled: return false
	var drop=matches[0]; var at=Vector3(drop.at[0],drop.at[1],drop.at[2])
	if game.player.position.distance_to(at)>float(game.config.interaction_distance): return false
	give(drop.id); pending.erase(drop)
	if nodes.has(key) and is_instance_valid(nodes[key]): nodes[key].queue_free()
	nodes.erase(key); game.current_world.interactions=game.current_world.interactions.filter(func(target): return int(target.get("loot_core",-1))!=key)
	game.nearest={}; game.notify("Collected "+item(drop.id).name+"."); return true
func consume(id:String) -> bool:
	if int(quantities.get(id,0))<=0 or game.player.health<=0: return false
	if id=="golem_core" and game.quest_stage!="completed": show_warning(); return false
	var amount=maxi(1,roundi(game.player.max_health*float(item(id).healing_percent)))
	remove(id); game.player.restore_health(game.player.health+amount); return true
func remove(id:String) -> void:
	var count=int(quantities.get(id,0))-1
	if count<=0: quantities.erase(id)
	else: quantities[id]=count
func configure_ui() -> void:
	warning=Control.new(); warning.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); warning.z_index=20; warning.mouse_filter=Control.MOUSE_FILTER_STOP; warning.hide(); game.add_child(warning)
	var shade=ColorRect.new(); shade.color=Color(0,0,0,.60); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); warning.add_child(shade)
	warning_panel=game.panel(warning); var body=VBoxContainer.new(); body.add_theme_constant_override("separation",18); warning_panel.add_child(body)
	body.add_child(game.label("This may be useful.",26,Color("#e9c894")))
	var message=game.label("Quest lock: Mother needs this calcified aether core for her alchemical remedy. Keep it safe until you give it to her.",18); message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; message.custom_minimum_size=Vector2(390,70); body.add_child(message)
	body.add_child(game.button("Keep the core",close_warning))
func show_warning() -> void:
	game._cancel_mouse_charge(); warning.show(); warning_panel.size=Vector2(440,0); warning_panel.position=(game.get_viewport_rect().size-warning_panel.get_combined_minimum_size())/2; game._refresh_simulation()
func close_warning() -> void:
	warning.hide(); game._refresh_simulation()
