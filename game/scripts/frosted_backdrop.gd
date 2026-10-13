extends TextureRect
var game: Control

func configure(owner_game: Control) -> void:
	game=owner_game
	texture=game.world_view.get_texture()
	expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	mouse_filter=Control.MOUSE_FILTER_STOP
	var shader=Shader.new()
	shader.code="""shader_type canvas_item;
uniform vec2 texel=vec2(0.001,0.002);
void fragment(){
 vec3 result=vec3(0.0); float weight=0.0;
 for(int x=-3;x<=3;x++){for(int y=-3;y<=3;y++){
 float w=exp(-float(x*x+y*y)/5.0);
 result+=texture(TEXTURE,UV+vec2(float(x),float(y))*texel*2.0).rgb*w; weight+=w;
 }}
 COLOR=vec4(result/weight*0.52,1.0);
}"""
	var frost=ShaderMaterial.new()
	frost.shader=shader
	material=frost

func _process(_delta: float) -> void:
	position=game.world_rect.position
	size=game.world_rect.size
	material.set_shader_parameter("texel",Vector2.ONE/Vector2(game.world_view.size))
