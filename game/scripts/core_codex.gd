extends VBoxContainer
var game:Node
var list:VBoxContainer
func configure(owner:Node) -> void:
	game=owner
	add_child(game.label("MONSTER CORE CODEX",22,Color("#e9c894")))
	var hint=game.label("Monsters drop cores; beasts do not. Slimes: 50% drop chance, then a second roll for a special core. Bosses guarantee their core and bonus XP. Add test cores here; consume in Inventory.",15); hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(hint)
	var scroll=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; add_child(scroll)
	list=VBoxContainer.new(); list.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(list); refresh()
func refresh() -> void:
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	for entry in game.monster_cores.catalog.cores:
		var card=game.panel(list); var body=VBoxContainer.new(); card.add_child(body)
		body.add_child(game.label(entry.name+" · Heal %d%% maximum HP" % roundi(entry.healing_percent*100),18,Color(entry.color)))
		var sources=[]
		for kind in game.monster_cores.catalog.profiles:
			var table=game.monster_cores.catalog.profiles[kind]
			if table.generic==entry.id: sources.append(kind.capitalize()+": %d%% core drop" % roundi(table.drop_rate*100)+("; %d%% generic on success" % roundi((1-table.variant_chance)*100) if not table.variant.is_empty() else "")+("; +%d boss XP" % int(table.boss_bonus) if table.boss_bonus>0 else ""))
			elif table.variant==entry.id: sources.append(kind.capitalize()+": %d%% drop, then %d%% special" % [roundi(table.drop_rate*100),roundi(table.variant_chance*100)])
		var detail=game.label("; ".join(sources)+(" · Quest locked for Mother" if entry.id=="golem_core" else ""),14); detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; body.add_child(detail)
		var row=HBoxContainer.new(); body.add_child(row); var id:String=entry.id
		row.add_child(game.button("Add test core · ×%d owned" % int(game.monster_cores.quantities.get(id,0)),func(): game.monster_cores.claim(id); refresh()))
		row.add_child(game.button("Add 5",func(): game.monster_cores.claim(id,5); refresh()))
