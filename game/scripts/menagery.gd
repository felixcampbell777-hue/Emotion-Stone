extends Control
const Enemy=preload("res://scripts/menagery_enemy.gd")
var game:Node
var catalog:Dictionary
var opened=false
var panel:PanelContainer
var toolbar:Button
var spawn_buttons:Dictionary={}
var spawned:Dictionary={}
var codex:Control
var core_codex:Control
var tabs:TabContainer
func configure(owner:Node) -> void:
	game=owner; catalog=game.read_data("res://content/menagery.json")
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toolbar=game.button("Menagery catalog [M]",toggle)
	toolbar.position=Vector2(340,22); add_child(toolbar)
	panel=PanelContainer.new(); panel.size=Vector2(760,630); panel.visible=false; add_child(panel)
	var skin=StyleBoxFlat.new(); skin.bg_color=Color("#20352fee"); skin.set_corner_radius_all(10); skin.content_margin_left=20; skin.content_margin_right=20; skin.content_margin_top=18; skin.content_margin_bottom=18; panel.add_theme_stylebox_override("panel",skin)
	var stack=VBoxContainer.new(); stack.add_theme_constant_override("separation",12); panel.add_child(stack)
	stack.add_child(game.label("MENAGERY  -  woodland reference & practice",23))
	stack.add_child(game.label("A Trees / B Rocks / C Wild / D Paths / E Mobs / F Terrain / G Cave",15))
	tabs=TabContainer.new(); tabs.custom_minimum_size=Vector2(710,430); stack.add_child(tabs)
	var mob_scroll=ScrollContainer.new(); mob_scroll.name="Spawn creatures"; mob_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; tabs.add_child(mob_scroll)
	var monsters=VBoxContainer.new(); monsters.size_flags_horizontal=Control.SIZE_EXPAND_FILL; mob_scroll.add_child(monsters)
	monsters.add_child(game.label("Spawn into the east clearing. One specimen per code. Defeats grant XP; respawn to practice or grind.",14))
	var grid=GridContainer.new(); grid.columns=2; grid.add_theme_constant_override("h_separation",12); grid.add_theme_constant_override("v_separation",10); monsters.add_child(grid)
	for entry in catalog.monsters:
		var code=entry.code
		var button=game.button(code+"  "+entry.name+"  (+%d XP)" % (int(game.progression.definition.enemy_xp[entry.style])+game.monster_cores.boss_bonus(entry.style))+"\n"+entry.ability,func(): spawn(code))
		button.custom_minimum_size=Vector2(340,74); button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; grid.add_child(button); spawn_buttons[code]=button
	var scroll=ScrollContainer.new(); scroll.name="Feature codes"; tabs.add_child(scroll)
	var list=VBoxContainer.new(); list.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(list)
	for entry in catalog.features:
		var line=game.label(entry.code+"  "+entry.name+"  -  "+entry.description,16)
		line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; line.custom_minimum_size.x=690; list.add_child(line)
	codex=load("res://scripts/magic_codex.gd").new(); codex.name="Magic items"; tabs.add_child(codex); codex.configure(game)
	core_codex=load("res://scripts/core_codex.gd").new(); core_codex.name="Monster cores"; tabs.add_child(core_codex); core_codex.configure(game)
	var footer=HBoxContainer.new(); stack.add_child(footer)
	footer.add_child(game.button("Clear practice creatures",clear))
	footer.add_child(game.button("Restore health & stamina",func(): game.player.restore_health(game.player.max_health); game.player.restore_stamina(game.player.max_stamina)))
	footer.add_child(game.button("Close [Esc / M]",close))

func _process(_delta:float) -> void:
	visible=game.map_id=="menagery" and not game.recovering and not game.title_screen.visible
	toolbar.visible=not opened and game.player.input_enabled
	toolbar.position=Vector2(game.health_panel.position.x,game.health_panel.position.y+game.health_panel.size.y+10)
	panel.size=Vector2(minf(760,game.get_viewport_rect().size.x-40),minf(630,game.get_viewport_rect().size.y-40))
	tabs.custom_minimum_size=Vector2(panel.size.x-40,maxf(200,panel.size.y-175))
	panel.position=(game.get_viewport_rect().size-panel.size)/2

func toggle() -> void:
	if opened: close()
	elif game.map_id=="menagery" and not game.recovering and not game.title_screen.visible:
		game._cancel_mouse_charge(); game.inventory.close(); game.conversation.close(); game.pause_menu.close(); game.help_panel.visible=false
		codex.refresh(); core_codex.refresh()
		opened=true; panel.visible=true; game._refresh_simulation()

func close() -> void:
	opened=false
	if panel!=null: panel.visible=false
	if is_instance_valid(game.player): game._refresh_simulation()

func clear() -> void:
	for enemy in game.enemies.duplicate():
		if is_instance_valid(enemy) and enemy.definition.get("transient",false): game.retire_transient(enemy)
	for enemy in spawned.values():
		if not is_instance_valid(enemy): continue
		game.enemies.erase(enemy)
		for bar in game.enemy_bars.duplicate():
			if bar.enemy==enemy: bar.root.queue_free(); game.enemy_bars.erase(bar)
		enemy.queue_free()
	spawned.clear()
	for effect in game.get_tree().get_nodes_in_group("menagery_effect"):
		effect.queue_free()
	game.projectiles=game.projectiles.filter(func(item): return is_instance_valid(item) and not item.is_queued_for_deletion())
	game.player.slow_sources.clear()

func forget() -> void:
	spawned.clear(); opened=false
	if panel!=null: panel.visible=false

func spawn(code:String) -> Node3D:
	if game.map_id!="menagery" or game.recovering or game.title_screen.visible: return null
	var matches=catalog.monsters.filter(func(entry): return entry.code==code)
	if matches.is_empty(): return null
	var entry=matches[0]
	if spawned.has(code) and is_instance_valid(spawned[code]):
		var previous=spawned[code]; game.enemies.erase(previous)
		for bar in game.enemy_bars.duplicate():
			if bar.enemy==previous: bar.root.queue_free(); game.enemy_bars.erase(bar)
		previous.queue_free()
	var index=catalog.monsters.find(entry)
	var center=Vector3(catalog.arena[0],0,catalog.arena[1])
	var at=center+Vector3(sin(index*TAU/catalog.monsters.size()),0,cos(index*TAU/catalog.monsters.size()))*float(catalog.spawn_ring_radius)
	var enemy=game.spawn_catalog_creature(entry,at)
	spawned[code]=enemy
	enemy.defeated.connect(func(): game._catalog_enemy_defeated(entry.style,entry.name,enemy))
	close()
	game.notify(entry.code+" "+entry.name+" spawned in the east clearing.")
	return enemy
