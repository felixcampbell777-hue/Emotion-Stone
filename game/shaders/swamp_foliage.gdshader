shader_type spatial;
render_mode cull_disabled;
uniform sampler2D leaf:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
void fragment(){vec4 tex=texture(leaf,UV);float value=dot(tex.rgb,vec3(.3,.5,.2));ALBEDO=mix(vec3(.075,.15,.055),vec3(.32,.40,.14),value);ALPHA=tex.a;ALPHA_SCISSOR_THRESHOLD=.45;ROUGHNESS=.94;}
