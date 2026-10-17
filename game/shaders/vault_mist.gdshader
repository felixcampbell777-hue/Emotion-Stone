shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float opacity = 0.16;
void fragment(){
    vec2 p=UV*2.0-1.0;
    float wisps=.65+.18*sin(UV.x*31.0+sin(UV.y*17.0)*2.0)+.13*cos(UV.y*43.0+UV.x*15.0);
    ALBEDO=vec3(.09,.18,.29);
    ALPHA=opacity*wisps*(1.0-smoothstep(.60,1.0,length(p)));
}
