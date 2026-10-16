shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec4 mist_color : source_color = vec4(0.12,0.19,0.16,0.4);
uniform float layer = 0.0;
varying vec3 world_at;
void vertex(){world_at=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float flow=sin(world_at.x*0.24+TIME*0.05)+sin(world_at.z*0.18-TIME*0.035)+sin((world_at.x+world_at.z)*0.47+TIME*0.06);
 float edge=smoothstep(0.0,0.14,UV.x)*smoothstep(0.0,0.14,1.0-UV.x)*smoothstep(0.0,0.14,UV.y)*smoothstep(0.0,0.14,1.0-UV.y);
 ALBEDO=mist_color.rgb;
 ALPHA=mist_color.a*edge*clamp(0.62+flow*0.15,0.12,1.0);
}
