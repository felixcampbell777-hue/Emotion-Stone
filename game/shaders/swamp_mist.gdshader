shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform float clock=0;
varying vec3 at;
void vertex(){at=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){float edge=smoothstep(0.0,.2,UV.x)*(1.0-smoothstep(.8,1.0,UV.x))*smoothstep(0.0,.2,UV.y)*(1.0-smoothstep(.8,1.0,UV.y));float noise=.5+.5*sin(at.x*.13+sin(at.z*.17+clock*.025))*sin(at.z*.12-clock*.035);ALBEDO=vec3(.39,.46,.35);ALPHA=edge*(.025+.07*noise);}
