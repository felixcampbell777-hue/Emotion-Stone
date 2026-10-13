extends Node3D
const Guardian=preload("res://scripts/warden_visual.gd")
var component: Node3D
func build(has_component: bool) -> void:
	name="WardenRemains"
	var kit=Guardian.new()
	add_child(kit)
	for piece in [[Vector3(0,.28,0),Vector3(1.6,.55,1.1)],[Vector3(-1,.16,.25),Vector3(.7,.32,.6)],[Vector3(.9,.2,-.35),Vector3(.6,.4,.7)],[Vector3(.3,.15,.85),Vector3(.7,.28,.5)]]:
		var stone=kit.stone(kit,piece[0],piece[1],"#536562")
		stone.rotation.y=piece[0].x*.7
	kit.stone(kit,Vector3(-.3,.42,.25),Vector3(.5,.4,.45),"#69766d")
	component=Node3D.new()
	component.name="AlchemicalCore"
	add_child(component)
	var core=kit.stone(component,Vector3(0,.64,0),Vector3(.36,.42,.36),"#75f0d7")
	var material=StandardMaterial3D.new()
	material.albedo_color=Color("#a4fff1")
	material.emission_enabled=true
	material.emission=Color("#37bfa8")
	material.emission_energy_multiplier=1.3
	core.material_override=material
	component.visible=has_component
