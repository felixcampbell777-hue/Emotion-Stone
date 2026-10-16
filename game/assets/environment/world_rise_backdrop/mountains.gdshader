shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D stone : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 haze_color : source_color = vec3(0.69,0.79,0.84);
varying vec3 world_at;
varying vec3 world_normal;
varying float local_height;
void vertex(){local_height=VERTEX.y;world_at=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=normalize(mat3(MODEL_MATRIX)*NORMAL);}
void fragment(){
 vec3 n=normalize(world_normal);vec3 w=pow(abs(n),vec3(4.0));w/=max(dot(w,vec3(1.0)),0.001);
 vec3 p=world_at*0.009;
 vec3 rock=texture(stone,p.yz).rgb*w.x+texture(stone,p.xz).rgb*w.y+texture(stone,p.xy).rgb*w.z;
 float sun=0.72+0.28*max(0.0,dot(n,normalize(vec3(-0.45,0.75,0.3))));
 vec3 color=COLOR.rgb*(vec3(0.7)+rock*0.7)*sun;
 float low_haze=1.0-smoothstep(-350.0,-130.0,local_height);
 ALBEDO=mix(color,haze_color,low_haze*0.86);ROUGHNESS=1.0;
}
