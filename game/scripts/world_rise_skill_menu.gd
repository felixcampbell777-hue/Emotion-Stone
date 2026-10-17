extends Control
## System-window cards: categories first, explicit prerequisites on expansion.
var game:Node
var selected=""
var header:Label
var status:Label
var categories:HBoxContainer
var scroll:ScrollContainer
var grid:GridContainer
const COLORS={"Strength":Color("#b51623"),"Agility":Color("#146d61"),"Greatsword":Color("#245a99")}
func configure(g:Node) -> void:
	game=g;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header=game.label("WORLD RISE  /  BODY ENHANCEMENT",27,Color("#e1f5ff"));add_child(header)
	status=game.label("",16,Color("#c1d8e9"));status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(status)
	categories=HBoxContainer.new();categories.add_theme_constant_override("separation",14);add_child(categories)
	for name in ["Strength","Agility","Greatsword"]:
		var button=game.button(name.to_upper()+"\n"+{"Strength":"Resilience & efficiency","Agility":"Movement & evasion","Greatsword":"Mastery & impact"}[name],func():selected=name if selected!=name else "";refresh())
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.custom_minimum_size.y=90;button.add_theme_font_size_override("font_size",22)
		button.add_theme_stylebox_override("normal",panel(COLORS[name].darkened(.35),Color("#6ab5db")));categories.add_child(button)
	scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;add_child(scroll)
	grid=GridContainer.new();grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",16);grid.add_theme_constant_override("v_separation",16);scroll.add_child(grid)
func panel(fill:Color,edge:Color) -> StyleBoxFlat:
	var style=StyleBoxFlat.new();style.bg_color=fill;style.border_color=edge;style.set_border_width_all(2);style.set_corner_radius_all(22);style.content_margin_left=22;style.content_margin_right=22;style.content_margin_top=18;style.content_margin_bottom=18;return style
func refresh() -> void:
	for child in grid.get_children():grid.remove_child(child);child.queue_free()
	var state=game.progression
	for i in range(3):
		var name=["Strength","Agility","Greatsword"][i];categories.get_child(i).add_theme_stylebox_override("normal",panel(COLORS[name].darkened(.15 if selected==name else .35),Color("#e9faff") if selected==name else Color("#6ab5db")))
	status.text="LEVEL %d  ·  %d SKILL POINTS  ·  %d GREATSWORD KILLS\nHP %d  /  STAMINA %d  ·  Damage reduction %d%%  ·  All learned passives are active"%[state.level(),state.points(),state.greatsword_kills,game.player.max_health,roundi(game.player.max_stamina),roundi(load("res://scripts/world_rise_stats.gd").reduction(game)*100)]
	if selected.is_empty():
		var message=game.label("SELECT AN ENHANCEMENT CATEGORY\n\nEach new level grants +1% maximum health, +1% maximum stamina and one skill point.\nExpand a category to inspect its skills and requirements.\n\nGreatsword kills unlock mastery options; kills are a lifetime threshold and are not consumed.",20,Color("#c2ddeb"));message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;message.custom_minimum_size.y=230;grid.add_child(message)
	else:
		for item in state.definition.skills:
			if item.branch!=selected:continue
			var rank=state.rank(item.id);var card=PanelContainer.new();card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.add_theme_stylebox_override("panel",panel(COLORS[selected].darkened(.18),Color("#8cddf7") if state.can_learn(item.id) else Color("#385d75")));grid.add_child(card)
			var body=VBoxContainer.new();body.add_theme_constant_override("separation",10);card.add_child(body)
			var top=HBoxContainer.new();body.add_child(top)
			var title=game.label(item.name+" ("+item.category+")",21,Color.WHITE);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(title)
			top.add_child(game.label("Lvl: %d%s"%[rank," / %d"%item.max_rank if item.max_rank<99999 else ""],20,Color.WHITE))
			var text=game.label(item.description,17,Color("#f3f6ff"));text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(text)
			var requirements=[]
			for parent in item.requires:
				var needed=int(item.get("requires_ranks",{}).get(parent,1));requirements.append("%s Lv %d  (%d/%d)"%[state.skill(parent).name,needed,state.rank(parent),needed])
			var kills=state.kill_requirement(item.id)
			if kills>0:requirements.append("Greatsword kills  %d / %d"%[state.greatsword_kills,kills])
			var req=game.label("REQUIRES: "+("1 skill point" if requirements.is_empty() else " · ".join(requirements)+" · 1 skill point"),14,Color("#c4f2d6") if state.requirements_met(item.id) else Color("#ffdcab"));req.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(req)
			var id:String=item.id
			var action=game.button("MAXIMUM LEVEL" if rank>=item.max_rank else "UPGRADE  +1 LEVEL  /  1 POINT" if rank>0 else "UNLOCK  /  1 POINT",func():game.learn_skill(id));action.disabled=not state.can_learn(id);body.add_child(action)
	_layout()
func _process(_delta:float) -> void:
	if visible:_layout()
func _layout() -> void:
	var screen=size;var margin=screen.x*.018
	header.position=Vector2(margin,10);status.position=Vector2(margin,46);status.size=Vector2(screen.x-2*margin,55)
	categories.position=Vector2(margin,108);categories.size=Vector2(screen.x-2*margin,90)
	scroll.position=Vector2(margin,214);scroll.size=Vector2(screen.x-2*margin,maxf(80,screen.y-224));grid.columns=2 if screen.x>=1200 and not selected.is_empty() else 1
	for card in grid.get_children():card.custom_minimum_size.x=(scroll.size.x-24-(16 if grid.columns==2 else 0))/grid.columns
