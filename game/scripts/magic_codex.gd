extends VBoxContainer
var game:Node
var list:VBoxContainer
var filter="all"
func configure(owner:Node) -> void:
	game=owner
	add_child(game.label("MAGIC ITEM CODEX",22,Color("#e9c894")))
	var hint=game.label("Twenty-eight wearables and three healing draughts, including King's Armor. Claim a copy here, then choose a slot in Inventory. Each ring is unique; equip two different rings.",15)
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(hint)
	var pick=OptionButton.new()
	for title in ["All equipment","Rings","Torso pieces","Leggings","Boots","Headwear","Necklaces","Healing draughts"]: pick.add_item(title)
	pick.item_selected.connect(func(index): filter=["all","ring","torso","leggings","boots","headwear","necklace","consumable"][index]; refresh())
	var controls=HBoxContainer.new(); add_child(controls)
	pick.size_flags_horizontal=Control.SIZE_EXPAND_FILL; controls.add_child(pick)
	controls.add_child(game.button("Claim all test specimens",func():
		for entry in game.magic_items.catalog.items: game.magic_items.claim(entry.id)
		refresh()
	))
	var scroll=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; add_child(scroll)
	list=VBoxContainer.new(); list.size_flags_horizontal=Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation",10); scroll.add_child(list)
	refresh()
func refresh() -> void:
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	for entry in game.magic_items.catalog.items:
		if filter!="all" and entry.category!=filter: continue
		var card=game.panel(list)
		var row=HBoxContainer.new(); card.add_child(row)
		var swatch=ColorRect.new(); swatch.color=Color(entry.color); swatch.custom_minimum_size=Vector2(12,80); row.add_child(swatch)
		var text=VBoxContainer.new(); text.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(text)
		text.add_child(game.label(entry.code+"  "+entry.name+"  /  "+entry.category.capitalize(),18,Color(entry.accent)))
		var detail=game.label(entry.description,15); detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; text.add_child(detail)
		var id:String=entry.id
		var caption=("Add bottle · %d owned" % int(game.magic_items.quantities.get(id,0))) if entry.category=="consumable" else "Owned · equip in Inventory" if id in game.magic_items.owned else "Claim specimen"
		var take=game.button(caption,func(): game.magic_items.claim(id); refresh())
		take.disabled=int(game.magic_items.quantities.get(id,0))>=99 if entry.category=="consumable" else id in game.magic_items.owned; text.add_child(take)
