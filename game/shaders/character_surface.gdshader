shader_type spatial;
uniform vec4 tint : source_color=vec4(.5,.5,.5,1.0);
uniform float fabric=0.0;
uniform float skin=0.0;
varying vec3 local_at;
void vertex(){local_at=VERTEX;}
void fragment(){
 float weave=sin(local_at.x*550.0)*sin(local_at.y*700.0);
 float variation=sin(local_at.y*13.0+local_at.x*8.0)*sin(local_at.z*17.0);
 ALBEDO=tint.rgb*(1.0+weave*.04*fabric+variation*.04);
 ROUGHNESS=mix(.58,.88,fabric);
 SSS_STRENGTH=skin*.18;
 RIM=.05;
}
