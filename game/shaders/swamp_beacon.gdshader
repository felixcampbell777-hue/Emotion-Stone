shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, blend_add;
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);}
void fragment(){
 float r=length(UV-.5)*2.;
 float distance=length(VERTEX);
 float core=exp(-r*r*100.0)*.85;
 float halo=exp(-r*r*8.0)*.12;
 ALBEDO=vec3(1.,.65,.23);ALPHA=(core+halo)*(1.-smoothstep(120.,155.,distance));
}
