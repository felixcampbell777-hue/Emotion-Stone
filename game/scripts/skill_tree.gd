extends Control
const Frost=preload("res://scripts/frosted_backdrop.gd")
const Star=preload("res://scripts/skill_star.gd")
var game:Control
var selected_id="strength"
var category="all"
var branch="Strength"
var nodes:Dictionary={}
var captions:Dictionary={}
var cards:Dictionary={}
var heading:Label
var status:Label
var detail:Label
var detail_scroll:ScrollContainer
var spend:Button
var close_button:Button
var filters:HBoxContainer
var branches:HBoxContainer
var scroll:ScrollContainer
var canvas:Control
var shown:Array=[]
var rise_menu:Control
func configure(owner_game:Control) -> void:
	game=owner_game;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
	var frost=Frost.new();add_child(frost);frost.configure(game)
	heading=game.label("CONSTELLATIONS",25,Color("#ead3a7"));add_child(heading)
	status=game.label("",16);add_child(status)
	branches=HBoxContainer.new();branches.add_theme_constant_override("separation",20);add_child(branches)
	for name in ["Strength","Form","Mana"]:
		branches.add_child(game.button(name.to_upper(),func():branch=name;category="all";refresh()))
	filters=HBoxContainer.new();add_child(filters)
	for entry in [["all","All"],["active","Active"],["passive","Passive"],["capacity","Capacities"]]:
		var id:String=entry[0];filters.add_child(game.button(entry[1],func():category=id;refresh()))
	scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;add_child(scroll)
	canvas=load("res://scripts/skill_constellation.gd").new();canvas.tree=self;scroll.add_child(canvas)
	for item in game.progression.definition.skills:
		var id:String=item.id;var card=Control.new();canvas.add_child(card);cards[id]=card
		var star=Star.new();star.size=Vector2(44,44);star.position=Vector2(-22,0);star.accent={"Strength":Color("#efb090"),"Form":Color("#91d7c5"),"Mana":Color("#83bfff")}[item.branch]
		star.pressed.connect(func():selected_id=id;refresh());card.add_child(star);nodes[id]=star
		var caption=game.label("",13);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.position=Vector2(-75,46);caption.size=Vector2(150,40);caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(caption);captions[id]=caption
	detail_scroll=ScrollContainer.new();detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(detail_scroll)
	detail=game.label("",17);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_scroll.add_child(detail)
	spend=game.button("",func():game.learn_skill(selected_id));add_child(spend)
	close_button=game.button("Return / Escape",close);add_child(close_button);visible=false
func revealed(id:String) -> bool:
	var item=game.progression.skill(id)
	if item.is_empty():return false
	return game.progression.has(id) or item.requires.all(func(parent):return game.progression.has(parent))
func refresh() -> void:
	if game.game_mode=="world_rise":
		if rise_menu==null:rise_menu=load("res://scripts/world_rise_skill_menu.gd").new();add_child(rise_menu);rise_menu.configure(game)
		for child in get_children():child.visible=child==rise_menu
		rise_menu.refresh();return
	for child in get_children():child.visible=child!=rise_menu and child.get_script()!=Frost
	var state=game.progression;shown.clear()
	status.text="Level %d   ·   %d XP   ·   %d perk points"%[state.level(),state.xp,state.points()]
	for id in nodes:
		var item=state.skill(id);var node=nodes[id]
		node.learned=state.has(id);node.available=state.can_learn(id);node.blocked=false
		cards[id].visible=id!="jump" and item.branch==branch and revealed(id) and (category=="all" or item.category==category)
		if cards[id].visible:shown.append(id)
		captions[id].text=item.name+"\n%d / %d"%[state.rank(id),item.max_rank]
	if selected_id not in shown:selected_id=shown[0] if not shown.is_empty() else ""
	for id in nodes:nodes[id].selected=selected_id==id;nodes[id].queue_redraw()
	if selected_id.is_empty():detail.text="Learn this constellation's foundation to reveal its skills.";spend.text="No revealed skills";spend.disabled=true
	else:
		var item=state.skill(selected_id)
		detail.text=item.name.to_upper()+"\n\n"+item.category.capitalize()+" · Rank %d / %d\n\n"%[state.rank(selected_id),item.max_rank]+item.description+"\n\nFurther stars appear as you learn their prerequisites."
		spend.text="Maximum rank" if state.rank(selected_id)>=int(item.max_rank) else "Upgrade · 1 point" if state.has(selected_id) else "Learn · 1 point";spend.disabled=not state.can_learn(selected_id)
	for i in range(4):filters.get_child(i).disabled=["all","active","passive","capacity"][i]==category
	for i in range(3):branches.get_child(i).disabled=["Strength","Form","Mana"][i]==branch
	_layout()
func depth(id:String) -> int:
	var result=0
	for parent in game.progression.skill(id).requires:result=maxi(result,depth(parent)+1)
	return result
func _process(_delta:float) -> void:
	if visible and game.game_mode!="world_rise":_layout()
func _layout() -> void:
	heading.position=Vector2(12,2);status.position=Vector2(12,36);branches.position=Vector2(12,65);filters.position=Vector2(12,108)
	var side=clampf(size.x*.29,230,345);var width=maxf(270,size.x-side-38)
	scroll.position=Vector2(12,154);scroll.size=Vector2(width,maxf(80,size.y-166))
	var levels={};var row=0
	for id in shown:
		var tier=depth(id)
		if not levels.has(tier):levels[tier]=[]
		levels[tier].append(id)
	var columns=clampi(int((width-16)/170),1,3)
	var total=0
	for tier in levels:total+=ceili(levels[tier].size()/float(columns))
	canvas.custom_minimum_size=Vector2(width-16,maxf(scroll.size.y,total*118+28));canvas.size=canvas.custom_minimum_size
	var tiers=levels.keys();tiers.sort();tiers.reverse()
	for tier in tiers:
		var entries=levels[tier]
		for start in range(0,entries.size(),columns):
			var count=mini(columns,entries.size()-start)
			for col in range(count):cards[entries[start+col]].position=Vector2((col+1)*canvas.size.x/(count+1),22+row*118)
			row+=1
	canvas.queue_redraw()
	detail_scroll.position=Vector2(width+28,154);detail_scroll.size=Vector2(side,maxf(60,size.y-288));detail.custom_minimum_size.x=side-20
	spend.position=Vector2(width+28,size.y-112);spend.size=Vector2(side,44)
	close_button.position=Vector2(width+28,size.y-58);close_button.size=Vector2(side,40)
func close() -> void:
	visible=false
	if game.inventory.visible and game.inventory.page=="level":game.inventory.close()
