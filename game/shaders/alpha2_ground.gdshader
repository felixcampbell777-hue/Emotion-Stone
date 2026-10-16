shader_type spatial;
uniform sampler2D soil_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D trail_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D trail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mask_texture : filter_linear, repeat_disable;
uniform sampler2D cliff_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 map_origin;
uniform vec2 map_size;
uniform vec3 soil_tint=vec3(1.0);
varying vec3 at;
varying vec3 world_normal;
void vertex(){at=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);TANGENT=vec3(1,0,0);BINORMAL=vec3(0,0,1);}
void fragment(){
 vec3 mask=texture(mask_texture,(at.xz-map_origin)/map_size).rgb;
 float path=smoothstep(.1,.8,mask.r);float sand=smoothstep(.1,.8,mask.g);vec2 uv=at.xz*.38;
 vec3 earth=texture(soil_albedo,uv).rgb*soil_tint*(.94+.06*sin(at.x*.31)*sin(at.z*.27));
 ALBEDO=mix(mix(earth,texture(trail_albedo,uv*.8).rgb,path),texture(sand_albedo,uv*.65).rgb,sand);
 vec3 face_normal=normalize(cross(dFdx(at),dFdy(at)));
 float cliff=smoothstep(.3,.65,1.0-abs(face_normal.y));
 vec3 weights=pow(abs(face_normal),vec3(4));weights/=max(.001,weights.x+weights.y+weights.z);
 vec3 rock=texture(cliff_albedo,at.zy*.3).rgb*weights.x+texture(cliff_albedo,at.xz*.3).rgb*weights.y+texture(cliff_albedo,at.xy*.3).rgb*weights.z;
 ALBEDO=mix(ALBEDO,rock,cliff);
 NORMAL_MAP=mix(mix(texture(soil_normal,uv).rgb,texture(trail_normal,uv*.8).rgb,path),texture(sand_normal,uv*.65).rgb,sand);
 NORMAL_MAP=mix(NORMAL_MAP,vec3(.5,.5,1.0),cliff);
 NORMAL_MAP_DEPTH=.65;ROUGHNESS=.86;
}
