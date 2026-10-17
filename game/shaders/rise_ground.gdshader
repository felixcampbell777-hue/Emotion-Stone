shader_type spatial;
render_mode cull_disabled;
uniform sampler2D grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cobbles : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 terrain_center=vec2(0.0);
uniform float terrain_radius=240.0;
uniform bool arrival_enabled=true;
varying vec3 at;
varying vec3 n;
float trail_distance(vec2 p){
 vec2 points[6]={vec2(0,0),vec2(10,35),vec2(45,67),vec2(85,95),vec2(118,117),vec2(139,139)};
 float nearest=10000.0;
 for(int i=0;i<5;i++){vec2 a=points[i];vec2 b=points[i+1];vec2 d=b-a;nearest=min(nearest,length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0)));}
 return nearest;
}
void vertex(){at=VERTEX;n=NORMAL;}
void fragment(){
 float r=length(at.xz-terrain_center);
 vec3 g=texture(grass,at.xz*.18).rgb;
 vec3 rock=texture(stone,at.xz*.16).rgb;
 float slope=1.0-smoothstep(.5,.85,n.y);
 float variation=.5+.5*sin(at.x*.024+sin(at.z*.031))*sin(at.z*.022);
 vec3 meadow=mix(vec3(.12,.23,.055),vec3(.26,.35,.10),variation);
 vec3 c=mix(meadow, g*vec3(.65,1.0,.42),.28);
 c=mix(c,rock,slope*.9);
 float trail=1.0-smoothstep(2.0,3.2,trail_distance(at.xz));
 c=mix(c,texture(cobbles,at.xz*.45).rgb*.85,trail*.95);
 float hub=arrival_enabled?1.0-smoothstep(8.8,9.2,r):0.0;float rim=smoothstep(terrain_radius*.94,terrain_radius*.946,r);float metal=max(hub,rim);
 vec3 silver=vec3(.39,.46,.44);float lines=step(.96,fract(r*.32));silver+=lines*.1;
 ALBEDO=mix(c,silver,metal);METALLIC=metal*.6;ROUGHNESS=mix(.95,.47,metal);
}
