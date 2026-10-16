extends RefCounted
func run(test:RefCounted) -> void:
	var game=test.game;var gear=game.magic_items
	var saved=gear.snapshot()
	for entry in gear.catalog.items:gear.claim(entry.id)
	for variant in range(5):
		for slot in gear.SLOTS:
			var category="ring" if slot.begins_with("ring") else slot
			var choices=gear.catalog.items.filter(func(e):return e.category==category)
			gear.equip(slot,choices[mini(variant,choices.size()-1)].id)
		test.check(game.player.find_children("MagicGear_*","BoneAttachment3D",true,false).is_empty(),"Equipment set %d adds no temporary meshes to the skin"%(variant+1))
	gear.restore(saved);game.apply_skill_stats()
