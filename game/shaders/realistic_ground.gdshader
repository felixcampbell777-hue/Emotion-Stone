shader_type spatial;
render_mode cull_disabled;
uniform sampler2D soil_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D trail_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D trail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D trail_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D terrain_mask : filter_linear, repeat_disable;
uniform vec2 map_origin;
uniform vec2 map_size;
uniform bool cave=false;
varying vec3 world_at;
void vertex(){ world_at=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; TANGENT=vec3(1.0,0.0,0.0); BINORMAL=vec3(0.0,0.0,1.0); }
void fragment(){
 vec2 uv=world_at.xz*.32;
 vec3 mask=texture(terrain_mask,(world_at.xz-map_origin)/map_size).rgb;
 float path=smoothstep(.1,.88,mask.r); float stone=cave ? 1.0 : smoothstep(.1,.88,mask.b); float sand=smoothstep(.1,.88,mask.g);
 float macro=.86+.14*sin(world_at.x*.21+sin(world_at.z*.29))*sin(world_at.z*.17);
 vec3 soil=texture(soil_albedo,uv).rgb*vec3(.83,.88,.77)*macro; vec3 trail=texture(trail_albedo,uv*.75).rgb*.74; vec3 cobble=texture(stone_albedo,world_at.xz*.45).rgb*.8;
 ALBEDO=mix(mix(soil,trail,path),cobble,stone); ALBEDO=mix(ALBEDO,trail*vec3(1.15,1.07,.85),sand);
 NORMAL_MAP=mix(mix(texture(soil_normal,uv).rgb,texture(trail_normal,uv*.75).rgb,max(path,sand)),texture(stone_normal,world_at.xz*.45).rgb,stone); NORMAL_MAP_DEPTH=.7;
 ROUGHNESS=mix(mix(texture(soil_roughness,uv).r,texture(trail_roughness,uv*.75).r,path),texture(stone_roughness,world_at.xz*.45).r,stone); ROUGHNESS=clamp(ROUGHNESS*.85,.38,.95);
}
