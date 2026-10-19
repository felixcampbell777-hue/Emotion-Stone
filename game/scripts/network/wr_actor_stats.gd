extends RefCounted
## Server and client share the existing stat/equipment builders without loading a rig.
const Growth=preload("res://scripts/progression.gd")
const Gear=preload("res://scripts/magic_items.gd")
const Stats=preload("res://scripts/world_rise_stats.gd")
const Profiles=preload("res://scripts/weapon_profiles.gd")
class StatActor extends Node:
	var values:Dictionary={}
	func _get(key:StringName) -> Variant:return values.get(String(key))
	func _set(key:StringName,value:Variant) -> bool:
		values[String(key)]=value
		return true
class Context extends Node:
	var player:Node
	var progression:RefCounted
	var magic_items:RefCounted
	var game_mode="world_rise"
	var selected_special_attack="water_sweep"
static func build(profile:Dictionary) -> Dictionary:
	var context=Context.new();var actor=StatActor.new();context.player=actor
	var growth=Growth.new();growth.restore(profile.get("progression",{}));context.progression=growth
	var gear=Gear.new();gear.restore(profile.get("magic_items",{}));gear.game=context;context.magic_items=gear
	# Prevent the presentation-only attachment pass; numeric effects use the same builder.
	gear.visual_key=JSON.stringify(gear.slots)
	actor.combat=JSON.parse_string(FileAccess.get_file_as_string("res://content/combat.json"))
	actor.max_health=int(actor.combat.max_health)+roundi(growth.bonus("health"))
	actor.max_stamina=float(actor.combat.max_stamina)+growth.bonus("stamina")
	actor.walk_speed=2.4;actor.weapon_type=Profiles.kind(gear.weapon_id)
	Profiles.apply_tuning(actor,gear.weapon_id)
	gear.apply_stats();Stats.apply(context)
	var weapon=Profiles.profile(gear.weapon_id)
	if not bool(weapon.get("legacy",true)):
		var damage=1+.02*growth.rank("iron_body")
		if weapon.kind!="bow":damage*=1+gear.bonus("melee")
		weapon.damage=roundi(float(weapon.damage)*damage*(1+gear.bonus("all_damage")))
		weapon.stamina*=maxf(.01,1-.02*growth.rank("iron_body"))*maxf(.01,1-.15*growth.rank("honed_arms"))
	var result={"combat":actor.combat.duplicate(true),"weapon":weapon,"weapon_multiplier":gear.weapon_base(),"max_health":actor.max_health,"max_stamina":actor.max_stamina,"walk_speed":actor.walk_speed,"damage_reduction":Stats.reduction(context),"gear_armor":gear.bonus("armor"),"sword_recoil":gear.bonus("sword_recoil"),"life_on_hit":gear.bonus("life_on_hit"),"canine_bonus":gear.weapon_bonus_against("canine"),"terrain_water_speed":gear.bonus("terrain_water_speed"),"dash_distance_multiplier":actor.dash_distance_multiplier,"dash_stamina_multiplier":actor.dash_stamina_multiplier,"jump_stamina_multiplier":actor.jump_stamina_multiplier}
	actor.free();context.free()
	return result
