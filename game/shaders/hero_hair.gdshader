shader_type spatial;
render_mode cull_disabled,depth_draw_opaque;
uniform vec4 tint:source_color=vec4(.35,.20,.10,1);
void fragment(){
 float strand=fract(UV.x*34.0+.065*sin(UV.y*14.0+UV.x*8.0));
 float coverage=smoothstep(.07,.22,strand)*(1.0-smoothstep(.81,.96,strand));
 float half_width=.5*(1.0-smoothstep(.84,1.0,UV.y));
 float edge=1.0-smoothstep(max(0.0,half_width-.018),half_width+.018,abs(UV.x-.5));
 ALPHA=mix(.96,coverage,smoothstep(.83,.98,UV.y))*edge;ALPHA_SCISSOR_THRESHOLD=.30;
 float fiber=.5+.5*sin(UV.x*213.628+sin(UV.y*18.0)*.3);
 ALBEDO=tint.rgb*(.76+fiber*.065);
 ROUGHNESS=.68;SPECULAR=.12;ANISOTROPY=.35;ANISOTROPY_FLOW=vec2(0,1);
 NORMAL_MAP=normalize(vec3((fiber-.5)*.06,0,1))*.5+.5;NORMAL_MAP_DEPTH=.10;
}
