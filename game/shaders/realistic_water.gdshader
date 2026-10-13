shader_type spatial;
render_mode cull_disabled;
varying vec3 world_at;
void vertex(){ world_at=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
 float wave=sin(world_at.x*2.1+TIME*.7)*.5+sin(world_at.z*3.3-TIME*.95)*.5;
 ALBEDO=mix(vec3(.025,.10,.13),vec3(.07,.22,.24),wave*.5+.5);
 NORMAL_MAP=normalize(vec3(sin(world_at.x*3.0+TIME)*.08,cos(world_at.z*4.0+TIME*.8)*.08,1.0))*.5+.5;
 NORMAL_MAP_DEPTH=1.0; ROUGHNESS=.13; METALLIC=.35; SPECULAR=.8;
}
