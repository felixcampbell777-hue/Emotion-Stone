extends RefCounted
var game:Node
var veil:ColorRect
var damage_veil:ColorRect
var material:ShaderMaterial
var pulse_remaining=0.0
var intensity=0.0
var damage_flash_remaining=0.0
var damage_flash_strength=0.0
const DAMAGE_FLASH_SECONDS=0.24
func configure(owner:Node) -> void:
	game=owner
	veil=ColorRect.new(); veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	material=ShaderMaterial.new(); material.shader=load("res://shaders/low_health.gdshader"); veil.material=material
	game.add_child(veil)
	damage_veil=ColorRect.new()
	damage_veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	damage_veil.color=Color(1.0,.04,.04,0.0)
	damage_veil.z_index=4
	game.add_child(damage_veil)
func denied() -> void:
	pulse_remaining=.85
func damaged(amount:int) -> void:
	if game==null or not is_instance_valid(game.player):
		return
	var fraction=clampf(float(maxi(0,amount))/float(maxi(1,game.player.max_health)),0.0,1.0)
	# Keep the flash readable for light hits while scaling its peak with damage.
	damage_flash_strength=maxf(damage_flash_strength,clampf(.045+fraction*.82,.06,.30))
	damage_flash_remaining=DAMAGE_FLASH_SECONDS
func update(delta:float) -> void:
	veil.position=game.world_rect.position; veil.size=game.world_rect.size
	damage_veil.position=game.world_rect.position; damage_veil.size=game.world_rect.size
	intensity=clampf((.25-float(game.player.health)/maxi(1,game.player.max_health))/.25,0,1)
	material.set_shader_parameter("intensity",intensity)
	veil.visible=intensity>0 and game.player.input_enabled
	if game.player.input_enabled: pulse_remaining=maxf(0,pulse_remaining-delta)
	if game.player.input_enabled: damage_flash_remaining=maxf(0,damage_flash_remaining-delta)
	var damage_t=damage_flash_remaining/DAMAGE_FLASH_SECONDS if DAMAGE_FLASH_SECONDS>0 else 0.0
	var damage_alpha=damage_flash_strength*damage_t*damage_t
	damage_veil.color=Color(1.0,.04,.04,damage_alpha)
	damage_veil.visible=damage_alpha>0.001 and game.player.input_enabled
	if damage_flash_remaining<=0: damage_flash_strength=0.0
	var pulse=(.45+.55*absf(sin(pulse_remaining*PI*4)))*minf(1,pulse_remaining/.18) if pulse_remaining>0 else 0.0
	var red=Color("#ff3d48")
	game.stamina_bar.get_theme_stylebox("fill").bg_color=Color("#55e2bc").lerp(red,pulse)
	game.stamina_bar.get_theme_stylebox("background").border_color=Color("#bdf5e2").lerp(red,pulse)
	game.stamina_bar.get_theme_stylebox("background").bg_color=Color("#112b27").lerp(Color("#7c1829"),pulse*.8)
	game.stamina_label.add_theme_color_override("font_color",Color("#defff2").lerp(red,pulse))
