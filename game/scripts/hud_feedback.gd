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
var victory:PanelContainer
var victory_label:Label
var victory_remaining=0.0
func boss_victory() -> void:victory_remaining=4.5
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
	victory=PanelContainer.new();victory.mouse_filter=Control.MOUSE_FILTER_IGNORE;victory.z_index=5
	var style=StyleBoxFlat.new();style.bg_color=Color("#101a22ee");style.border_color=Color("#c8ae71");style.set_border_width_all(2);style.set_corner_radius_all(8);victory.add_theme_stylebox_override("panel",style)
	victory_label=Label.new();victory_label.text="Floor 1 Boss Defeated!";victory_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;victory_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;victory_label.add_theme_color_override("font_color",Color("#f0d39b"));victory_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;victory.add_child(victory_label);game.add_child(victory);victory.hide()
func denied() -> void:
	pulse_remaining=.85
func damaged(amount:int) -> void:
	if game==null or not is_instance_valid(game.player):
		return
	if game.get("game_mode")=="world_rise" and game.get("blood")!=null:
		damage_flash_remaining=0;damage_flash_strength=0
		return
	var fraction=clampf(float(maxi(0,amount))/float(maxi(1,game.player.max_health)),0.0,1.0)
	# Keep the flash readable for light hits while scaling its peak with damage.
	damage_flash_strength=maxf(damage_flash_strength,clampf(.045+fraction*.82,.06,.30))
	damage_flash_remaining=DAMAGE_FLASH_SECONDS
func update(delta:float) -> void:
	if game.player.input_enabled:victory_remaining=maxf(0,victory_remaining-delta)
	victory.visible=victory_remaining>0 and game.player.input_enabled
	if victory.visible:
		var rect=game.world_rect;victory.size=Vector2(rect.size.x*.9,rect.size.y*.25);victory.position=rect.position+(rect.size-victory.size)*.5;victory_label.add_theme_font_size_override("font_size",clampi(int(rect.size.x/24),24,64));victory.modulate.a=minf(smoothstep(0,.25,4.5-victory_remaining),smoothstep(0,.8,victory_remaining))
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
