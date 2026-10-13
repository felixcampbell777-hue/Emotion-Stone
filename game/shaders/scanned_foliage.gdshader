shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D needles : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D cutout : filter_linear_mipmap_anisotropic, repeat_disable;
void fragment(){
 ALBEDO=texture(needles,UV).rgb*vec3(.82,.9,.78);
 ALPHA=texture(cutout,UV).r;
 ALPHA_SCISSOR_THRESHOLD=.38;
 ROUGHNESS=.9;
 BACKLIGHT=vec3(.06,.11,.035);
}
