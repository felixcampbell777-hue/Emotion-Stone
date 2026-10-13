extends RefCounted
var game:Node
var veil:ColorRect
var material:ShaderMaterial
var pulse_remaining=0.0
var intensity=0.0
func configure(owner:Node) -> void:
	game=owner
	veil=ColorRect.new(); veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	material=ShaderMaterial.new(); material.shader=load("res://shaders/low_health.gdshader"); veil.material=material
	game.add_child(veil)
func denied() -> void:
	pulse_remaining=.85
func update(delta:float) -> void:
	veil.position=game.world_rect.position; veil.size=game.world_rect.size
	intensity=clampf((.25-float(game.player.health)/maxi(1,game.player.max_health))/.25,0,1)
	material.set_shader_parameter("intensity",intensity)
	veil.visible=intensity>0 and game.player.input_enabled
	if game.player.input_enabled: pulse_remaining=maxf(0,pulse_remaining-delta)
	var pulse=(.45+.55*absf(sin(pulse_remaining*PI*4)))*minf(1,pulse_remaining/.18) if pulse_remaining>0 else 0.0
	var red=Color("#ff3d48")
	game.stamina_bar.get_theme_stylebox("fill").bg_color=Color("#55e2bc").lerp(red,pulse)
	game.stamina_bar.get_theme_stylebox("background").border_color=Color("#bdf5e2").lerp(red,pulse)
	game.stamina_bar.get_theme_stylebox("background").bg_color=Color("#112b27").lerp(Color("#7c1829"),pulse*.8)
	game.stamina_label.add_theme_color_override("font_color",Color("#defff2").lerp(red,pulse))
