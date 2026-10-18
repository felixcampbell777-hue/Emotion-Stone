shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D scene_depth:hint_depth_texture,repeat_disable,filter_nearest;
uniform sampler2D deep_mask:repeat_disable,filter_linear;
uniform float clock=0;
uniform float density=.20;
uniform vec3 fog_colour:source_color=vec3(.43,.57,.32);
void vertex(){POSITION=vec4(VERTEX.xy,1.0,1.0);}
void fragment(){
 float depth=texture(scene_depth,SCREEN_UV).r;
 vec3 ndc=vec3(SCREEN_UV*2.0-1.0,depth);
 #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
 ndc.z=depth*2.0-1.0;
 #endif
 vec4 view=INV_PROJECTION_MATRIX*vec4(ndc,1.0);view.xyz/=view.w;
 vec3 origin=INV_VIEW_MATRIX[3].xyz;
 vec3 ray=(INV_VIEW_MATRIX*vec4(normalize(view.xyz),0.0)).xyz;
 float distance=min(length(view.xyz),72.0);float step_size=distance/24.0;
 float optical=0.0;
 for(int i=0;i<24;i++){
  vec3 p=origin+ray*((float(i)+.5)*step_size);
  float deep=texture(deep_mask,((p.xz+240.0)/2.0+vec2(.5))/241.0).r*(1.0-smoothstep(238.0,241.0,length(p.xz)));
  float height=smoothstep(-.1,.25,p.y)*(1.0-smoothstep(3.0,6.5,p.y));
  float billow=.7+.3*sin(p.x*.24+sin(p.z*.19+clock*.035)+p.y*.8);
  optical+=deep*height*billow*step_size*density;
 }
 ALBEDO=fog_colour;ALPHA=clamp(1.0-exp(-optical),0.0,.985);
}
