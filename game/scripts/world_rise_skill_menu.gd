extends Control
## World Rise: separate attributes, perks and earned weapon practice.
const MigrationNotice=preload("res://scripts/world_rise_migration_notice.gd")
const ATTRIBUTE_ORDER=["body","reflexes","precision","endurance","mastery"]
const ATTRIBUTE_COPY={
	"body":"Resilience & efficiency", "reflexes":"Movement & evasion",
	"precision":"Aim & control", "endurance":"Stamina & travel", "mastery":"Weapon techniques"
}
const COLORS={"body":Color("#bd7562"),"reflexes":Color("#64b9a4"),"precision":Color("#8bb5d4"),"endurance":Color("#c4ab69"),"mastery":Color("#b19bd8")}
const PRACTICE_MILESTONES=[15,50,100,200,400]
var game:Node
var selected="body"
var header:Label
var status:Label
var categories:HBoxContainer
var scroll:ScrollContainer
var content:VBoxContainer
var grid:GridContainer
var attribute_tiles:Dictionary={}
var reset_confirm=false
var practice_expanded=false

func configure(g:Node) -> void:
	game=g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header=game.label("WORLD RISE  /  CHARACTER",22,Color("#e1f5ff"));add_child(header)
	status=_text("",14,Color("#c1d8e9"));add_child(status)
	categories=HBoxContainer.new();categories.add_theme_constant_override("separation",8);add_child(categories)
	for attribute in ATTRIBUTE_ORDER:
		var tile=VBoxContainer.new();tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tile.add_theme_constant_override("separation",5);categories.add_child(tile)
		var id:String=attribute
		var select=game.button("",func():selected=id;reset_confirm=false;refresh())
		select.size_flags_horizontal=Control.SIZE_EXPAND_FILL;select.custom_minimum_size.y=54;select.add_theme_font_size_override("font_size",15);compact_button(select);tile.add_child(select)
		var raise_button=game.button("RAISE  +1",func():game.increase_attribute(id))
		raise_button.add_theme_font_size_override("font_size",12);raise_button.custom_minimum_size.y=28
		compact_button(raise_button)
		tile.add_child(raise_button)
		attribute_tiles[id]={"select":select,"raise":raise_button}
	scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;add_child(scroll)
	content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",8);scroll.add_child(content)
	resized.connect(_layout)

func panel(fill:Color,edge:Color) -> StyleBoxFlat:
	var style=StyleBoxFlat.new();style.bg_color=fill;style.border_color=edge;style.set_border_width_all(1);style.set_corner_radius_all(12)
	style.content_margin_left=16;style.content_margin_right=16;style.content_margin_top=14;style.content_margin_bottom=14
	return style

func compact_panel(fill:Color,edge:Color) -> StyleBoxFlat:
	var style=panel(fill,edge)
	style.content_margin_left=10;style.content_margin_right=10;style.content_margin_top=6;style.content_margin_bottom=6
	return style

func compact_button(button:Button) -> void:
	for state in ["normal","hover","pressed","disabled","focus"]:
		var fill=Color("#203d34").darkened(.35) if state=="disabled" else Color("#28493e") if state in ["hover","pressed"] else Color("#203d34")
		var edge=Color("#d6f1e4") if state=="focus" else Color("#4e7565").darkened(.4) if state=="disabled" else Color("#4e7565")
		button.add_theme_stylebox_override(state,compact_panel(fill,edge))

func _text(value:String,font_size:int=16,color:Color=Color("#d1dfeb")) -> Label:
	var result=game.label(value,font_size,color);result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;result.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return result

func _section(fill:Color,edge:Color) -> VBoxContainer:
	var card=PanelContainer.new();card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.add_theme_stylebox_override("panel",panel(fill,edge));content.add_child(card)
	var body=VBoxContainer.new();body.add_theme_constant_override("separation",9);card.add_child(body)
	return body

func refresh() -> void:
	if game==null or content==null:return
	for child in content.get_children():content.remove_child(child);child.queue_free()
	var state=game.progression
	status.text="LEVEL %d    •    %d ATTRIBUTE POINTS    •    %d PERK POINTS"%[state.level(),state.attribute_points(),state.points()]
	status.tooltip_text="Attributes 3–20. Perk tiers 4 / 9 / 15 / 20. All learned passives are always active."
	for attribute in ATTRIBUTE_ORDER:
		var value=int(state.attributes.get(attribute,3));var tile=attribute_tiles[attribute];var accent:Color=COLORS[attribute]
		tile.select.text="%s\n%d / 20"%[attribute.to_upper(),value]
		tile.select.tooltip_text=ATTRIBUTE_COPY[attribute]
		tile.select.add_theme_stylebox_override("normal",compact_panel(accent.darkened(.72 if selected==attribute else .88),accent if selected==attribute else Color("#334553")))
		tile.select.add_theme_stylebox_override("focus",compact_panel(accent.darkened(.68),Color("#e2f4ff")))
		tile.raise.disabled=state.attribute_points()<=0 or value>=20
		tile.raise.text="AT MAXIMUM" if value>=20 else "RAISE +1  /  1 AP"
	if bool(state.migration_notice):
		if MigrationNotice.acknowledged(MigrationNotice.key_for(game),state.migration_v4):state.migration_notice=false
		else:_migration_notice(state)
	_practice(state)
	var heading=HBoxContainer.new();content.add_child(heading)
	var title=_text(selected.to_upper()+"  /  "+ATTRIBUTE_COPY[selected],17,COLORS[selected]);heading.add_child(title)
	heading.add_child(_text("Attribute %d / 20"%int(state.attributes.get(selected,3)),14,COLORS[selected]))
	for attribute_definition in state.definition.get("attributes",[]):
		if str(attribute_definition.get("id",""))==selected:content.add_child(_text(str(attribute_definition.get("description","")),14))
	grid=GridContainer.new();grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);content.add_child(grid)
	for item in state.definition.skills:
		if str(item.get("attribute",""))==selected:_perk_card(state,item)
	_reset_section(state)
	_layout()

func _migration_notice(state) -> void:
	var body=_section(Color("#192e35"),Color("#75bfae"))
	body.add_child(_text("YOUR CHARACTER HAS BEEN UPDATED",18,Color("#b9eedf")))
	var description="Your XP, equipment and lifetime kills are preserved. Attribute and perk points are ready to spend in the new progression."
	if not state.migration_v4.is_empty():description+=" Previous passive allocations were refunded; your migration receipt is saved with this character."
	body.add_child(_text(description))
	body.add_child(game.button("GOT IT",func():
		MigrationNotice.remember(MigrationNotice.key_for(game),state.migration_v4)
		state.migration_notice=false;refresh()))

func _practice(state) -> void:
	var card=PanelContainer.new();card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel",compact_panel(Color("#131e29"),Color("#344e64")));content.add_child(card)
	var body=VBoxContainer.new();body.add_theme_constant_override("separation",8);card.add_child(body)
	var heading=HBoxContainer.new();heading.add_theme_constant_override("separation",8);body.add_child(heading)
	var summary:Array[String]=[]
	for weapon in ["greatsword","spear","rapier","bow"]:summary.append("%s %d/5"%[weapon.capitalize(),state.practice_rank(weapon)])
	heading.add_child(_text("PRACTICE   "+" · ".join(summary),13,Color("#9fc1d8")))
	var toggle=game.button("HIDE DETAILS" if practice_expanded else "SHOW DETAILS",func():practice_expanded=not practice_expanded;refresh())
	toggle.add_theme_font_size_override("font_size",12);toggle.custom_minimum_size.y=26
	compact_button(toggle);heading.add_child(toggle)
	if not practice_expanded:return
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",12);body.add_child(row)
	for weapon in ["greatsword","spear","rapier","bow"]:
		var kills=int(state.weapon_kills.get(weapon,0));var rank=int(state.practice_rank(weapon));var next="Complete"
		for milestone in PRACTICE_MILESTONES:
			if kills<int(milestone):next="Next: %d kills"%int(milestone);break
		row.add_child(_text("%s  %d / 5\n%d kills · +%d%% damage\n%s"%[weapon.capitalize(),rank,kills,rank*2,next],14))
	body.add_child(_text("Milestones: 15 / 50 / 100 / 200 / 400 kills. Each grants +2% damage with that weapon; no points required.",13,Color("#97adbf")))

func _perk_card(state,item:Dictionary) -> void:
	var id:String=item.id;var rank=int(state.rank(id));var cap=int(item.max_rank);var gate=int(item.get("gate",4));var available=bool(state.can_learn(id));var accent:Color=COLORS[selected]
	var card=PanelContainer.new();card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.add_theme_stylebox_override("panel",compact_panel(Color("#172330"),accent if available or rank>0 else Color("#344251")));grid.add_child(card)
	var body=VBoxContainer.new();body.add_theme_constant_override("separation",6);card.add_child(body)
	var top=HBoxContainer.new();body.add_child(top)
	var title=_text(str(item.name),18,Color("#edf4fa"));top.add_child(title)
	var rank_label=game.label("%d / %d"%[rank,cap],16,accent);top.add_child(rank_label)
	body.add_child(_text("%s %d  •  %s"%[selected.capitalize(),gate,str(item.get("category","perk")).to_upper()],13,accent))
	body.add_child(_text(str(item.get("description","")),14))
	var requirements:Array[String]=["%s %d (%d / %d)"%[selected.capitalize(),gate,int(state.attributes.get(selected,3)),gate]]
	for parent in item.get("requires",[]):
		var needed=int(item.get("requires_ranks",{}).get(parent,1));var parent_item:Dictionary=state.skill(parent)
		requirements.append("%s rank %d (%d / %d)"%[str(parent_item.get("name",parent)),needed,state.rank(parent),needed])
	body.add_child(_text("REQUIRES  "+" · ".join(requirements),12,Color("#a7d2bb") if state.requirements_met(id) else Color("#d5b58d")))
	var actions=HBoxContainer.new();actions.add_theme_constant_override("separation",8);body.add_child(actions)
	var learn=game.button("MAX RANK" if rank>=cap else "LEARN  /  1 PERK POINT" if rank==0 else "UPGRADE  /  1 PERK POINT",func():game.learn_skill(id))
	learn.size_flags_horizontal=Control.SIZE_EXPAND_FILL;learn.add_theme_font_size_override("font_size",13);learn.disabled=not available;learn.custom_minimum_size.y=32
	compact_button(learn)
	actions.add_child(learn)
	var refund=game.button("REFUND",func():game.refund_skill(id));refund.add_theme_font_size_override("font_size",13);refund.disabled=not state.can_refund(id);refund.custom_minimum_size.y=32
	compact_button(refund)
	actions.add_child(refund)
	refund.tooltip_text="Refund one rank for one perk point. Refund dependent perks first."

func _reset_section(state) -> void:
	var body=_section(Color("#201f29"),Color("#625b72"))
	body.add_child(_text("ATTRIBUTE RESET  /  ONE FREE USE",15,Color("#cfbfdf")))
	body.add_child(_text("Reset every attribute to 3 and refund all perk allocations. Your XP and weapon practice are preserved.",14))
	if bool(state.attribute_reset_used):
		reset_confirm=false;body.add_child(_text("Free attribute reset already used.",14,Color("#a09aaa")));return
	if reset_confirm:
		body.add_child(_text("Use your one free reset now? This refunds all learned perks and resets all five attributes.",14,Color("#ead1b1")))
		var row=HBoxContainer.new();row.add_theme_constant_override("separation",10);body.add_child(row)
		row.add_child(game.button("CONFIRM FREE RESET",func():reset_confirm=false;game.reset_attributes()))
		row.add_child(game.button("KEEP MY BUILD",func():reset_confirm=false;refresh()))
	else:body.add_child(game.button("USE FREE ATTRIBUTE RESET…",func():reset_confirm=true;refresh()))

func _layout() -> void:
	if header==null or scroll==null:return
	var margin=maxf(12,size.x*.018);var width=maxf(300,size.x-2*margin)
	header.position=Vector2(margin,3);header.size=Vector2(width,27)
	status.position=Vector2(margin,32);status.size=Vector2(width,20)
	var category_height=maxf(86,categories.get_combined_minimum_size().y)
	categories.position=Vector2(margin,58);categories.size=Vector2(width,category_height)
	var content_top=58+category_height+8
	scroll.position=Vector2(margin,content_top);scroll.size=Vector2(width,maxf(80,size.y-content_top-10))
	if is_instance_valid(grid):
		grid.columns=2 if size.x>=1100 else 1
		for card in grid.get_children():card.custom_minimum_size.x=maxf(130,(width-24-12*(grid.columns-1))/grid.columns)
