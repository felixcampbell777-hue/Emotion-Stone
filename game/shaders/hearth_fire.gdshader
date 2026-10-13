shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float clock=0.0;
varying vec3 local_at;
void vertex(){local_at=VERTEX; VERTEX.x+=sin(VERTEX.y*14.0+clock*7.0)*.035;}
void fragment(){
 float height=clamp(local_at.y+.45,0.0,1.0);
 float flicker=.82+.18*sin(clock*11.0+height*13.0);
 vec3 fire=mix(vec3(3.8,1.7,.25),vec3(1.3,.2,.02),height);
 ALBEDO=fire*flicker; EMISSION=fire*flicker;
}
