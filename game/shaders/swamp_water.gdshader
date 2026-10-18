shader_type spatial;
render_mode cull_disabled;
uniform sampler2D bed:filter_linear,repeat_disable;
uniform float clock=0;
varying vec3 at;
void vertex(){at=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 if(length(at.xz)>240.0){discard;}
 float ground=texture(bed,((at.xz+240.0)/2.0+vec2(.5))/241.0).r*6.0-4.0;
 float depth=max(0.0,-ground);float dark=smoothstep(1.30,1.38,depth);
 vec3 shallow=mix(vec3(.43,.49,.28),vec3(.28,.38,.20),smoothstep(0.0,1.22,depth));
 float wave=sin(at.x*2.8+clock*.65+sin(at.z*1.8))*sin(at.z*2.1-clock*.45);
 float film=noise(at.xz*.65+vec2(clock*.008,0));
 float algae=smoothstep(.56,.79,noise(at.xz*.19+vec2(0,clock*.004)))*film;
 vec3 base=mix(shallow,vec3(.065,.16,.10),dark);
 ALBEDO=base*(.91+.16*film)+vec3(.025,.035,.005)*algae+wave*.009;
 ROUGHNESS=mix(.37,.68,algae);SPECULAR=.4;
 NORMAL_MAP=vec3(.5+wave*.075,.5+cos(at.x*2.0-clock*.5)*.055,1.0);NORMAL_MAP_DEPTH=.65;
}
