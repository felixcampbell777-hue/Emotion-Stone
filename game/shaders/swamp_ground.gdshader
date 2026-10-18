shader_type spatial;
render_mode cull_disabled;
uniform sampler2D soil:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D litter:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D cover:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D soil_normal:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 at;
void vertex(){at=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;TANGENT=vec3(1,0,0);BINORMAL=vec3(0,0,1);}
void fragment(){vec2 uv=at.xz*.38;float patch=.5+.5*sin(at.x*.29+sin(at.z*.37))*cos(at.z*.21);vec3 earth=texture(soil,uv).rgb*vec3(.52,.60,.40);vec3 leaves=texture(litter,uv*.7).rgb*vec3(.48,.55,.35);vec3 grass=texture(cover,uv*.8).rgb*vec3(.48,.60,.33);float wet=1.0-smoothstep(-.2,.65,at.y);ALBEDO=mix(mix(earth,leaves,patch*.5),grass,smoothstep(.4,.8,patch)*.5)*(1.0-wet*.25);NORMAL_MAP=texture(soil_normal,uv).rgb;NORMAL_MAP_DEPTH=.65;ROUGHNESS=mix(.52,.9,smoothstep(0,.8,at.y));SPECULAR=.25;}
