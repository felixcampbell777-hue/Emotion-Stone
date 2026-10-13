extends Control
const Frost=preload("res://scripts/frosted_backdrop.gd")
const Hex=preload("res://scripts/skill_hex.gd")
var game:Control
var selected_id="strength"
var category="all"
var nodes:Dictionary={}
var captions:Dictionary={}
var cards:Dictionary={}
var heading:Label
var status:Label
var detail:Label
var spend:Button
var close_button:Button
var filters:HBoxContainer
var scroll:ScrollContainer
var grid:GridContainer

func configure(owner_game:Control) -> void:
	game=owner_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var frost=Frost.new();add_child(frost);frost.configure(game)
	heading=game.label("SKILL UPGRADES",25,Color("#ead3a7"));add_child(heading)
	status=game.label("",16);add_child(status)
	filters=HBoxContainer.new();add_child(filters)
	for entry in [["all","All"],["active","Active skills"],["passive","Passive skills"],["capacity","Capacities"]]:
		var id:String=entry[0]
		filters.add_child(game.button(entry[1],func(): category=id;refresh()))
	scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;add_child(scroll)
	grid=GridContainer.new();grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",14);grid.add_theme_constant_override("v_separation",10);scroll.add_child(grid)
	for item in game.progression.definition.skills:
		var id:String=item.id
		var card=VBoxContainer.new();card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_child(card);cards[id]=card
		var row=HBoxContainer.new();card.add_child(row)
		var node=Hex.new();node.custom_minimum_size=Vector2(56,56);node.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
		node.accent={"Strength":Color("#c98267"),"Form":Color("#80b89e"),"Mana":Color("#7aaee1")}[item.branch]
		node.glyph={"capacity":"+","passive":"◇","active":"↑"}[item.category]
		node.pressed.connect(func(): selected_id=id;refresh());row.add_child(node);nodes[id]=node
		var caption=game.label("",15);caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(caption);captions[id]=caption
		var select=game.button("Inspect",func(): selected_id=id;refresh());card.add_child(select)
	detail=game.label("",16);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(detail)
	spend=game.button("",func(): game.learn_skill(selected_id));add_child(spend)
	close_button=game.button("Return / Escape",close);add_child(close_button)
	visible=false

func refresh() -> void:
	var state=game.progression
	status.text="Level %d · %d XP · %d points available · One point per rank"%[state.level(),state.xp,state.points()]
	if category!="all" and state.skill(selected_id).category!=category:
		for item in state.definition.skills:
			if item.category==category: selected_id=item.id;break
	for id in nodes:
		var item=state.skill(id);var node=nodes[id]
		node.learned=state.has(id);node.available=state.can_learn(id);node.blocked=false;node.selected=selected_id==id;node.queue_redraw()
		cards[id].visible=category=="all" or item.category==category
		captions[id].text=item.name+"\n"+item.branch+" · "+item.category.capitalize()+"\nRank %d / %d"%[state.rank(id),item.max_rank]
	var item=state.skill(selected_id)
	var prerequisites=[]
	for id in item.requires: prerequisites.append(state.skill(id).name)
	detail.text=item.name.to_upper()+"\n"+item.description+("\nRequires: "+", ".join(prerequisites) if not prerequisites.is_empty() else "")
	spend.text="Maximum rank" if state.rank(selected_id)>=int(item.max_rank) else "Upgrade · 1 point" if state.has(selected_id) else "Learn · 1 point"
	spend.disabled=not state.can_learn(selected_id)
	for index in range(4): filters.get_child(index).disabled=["all","active","passive","capacity"][index]==category
	_layout()

func _process(_delta:float) -> void:
	if visible: _layout()

func _layout() -> void:
	heading.position=Vector2(12,0);status.position=Vector2(12,34)
	filters.position=Vector2(12,62)
	scroll.position=Vector2(12,112);scroll.size=Vector2(size.x-24,maxf(80,size.y-260))
	grid.columns=3 if size.x>=850 else 2
	for card in cards.values(): card.custom_minimum_size.x=(scroll.size.x-40)/grid.columns
	detail.position=Vector2(12,size.y-137);detail.size=Vector2(size.x*.70,125)
	spend.position=Vector2(size.x*.73,size.y-128);spend.size=Vector2(size.x*.25,46)
	close_button.position=Vector2(size.x*.73,size.y-66);close_button.size=Vector2(size.x*.25,40)

func close() -> void:
	visible=false
	if game.inventory.visible and game.inventory.page=="level": game.inventory.close()
