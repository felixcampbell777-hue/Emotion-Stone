shader_type spatial;
render_mode cull_disabled;
uniform float shore_x=20.0;
varying vec3 at;
void vertex(){at=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;VERTEX.y+=sin(at.x*.6+TIME)*.035+cos(at.z*.34+TIME*.8)*.025;}
void fragment(){
 float depth=smoothstep(shore_x,shore_x+22.0,at.x);vec3 sea=mix(vec3(.16,.48,.48),vec3(.035,.17,.27),depth);
 float foam=(1.0-smoothstep(0.0,2.6,at.x-shore_x))*smoothstep(.65,.93,sin(at.x*2.0-at.z*.15-TIME*1.5));
 float detail=1.0-smoothstep(.15,.7,length(fwidth(at.xz)));foam*=detail;
 ALBEDO=mix(sea,vec3(.84,.91,.82),foam*.72);
 NORMAL_MAP=normalize(vec3(sin(at.x*1.6+TIME)*.16*detail,cos(at.z*1.4-TIME)*.14*detail,1.0))*.5+.5;
 METALLIC=.2;ROUGHNESS=.18;SPECULAR=.85;
}
