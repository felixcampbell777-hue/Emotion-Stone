shader_type spatial;
render_mode diffuse_burley;
uniform vec4 tint : source_color = vec4(.35,.55,.27,1.0);
uniform float clock=0.0;
varying vec3 local_at;
void vertex(){
 local_at=VERTEX;
 float ripple=sin(VERTEX.x*13.0+clock*2.0)*sin(VERTEX.z*11.0-clock)*.025;
 VERTEX+=NORMAL*ripple*(1.0-smoothstep(.2,.5,abs(VERTEX.y)));
}
void fragment(){
 float grain=sin(local_at.x*76.0)*sin(local_at.z*82.0)*sin(local_at.y*61.0);
 float marbling=sin(local_at.x*18.0+sin(local_at.y*12.0))*sin(local_at.z*17.0-clock*.2);
 ALBEDO=tint.rgb*(.49+.11*marbling+.015*grain);
 ROUGHNESS=.12+.04*marbling;
 METALLIC=.05;
 CLEARCOAT=.95; CLEARCOAT_ROUGHNESS=.12;
 RIM=.45; RIM_TINT=.25;
 SSS_STRENGTH=.3;
 EMISSION=tint.rgb*.045;
}
