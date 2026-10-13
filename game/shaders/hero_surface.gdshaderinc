uniform vec4 tint : source_color = vec4(.5,.5,.5,1);
uniform float surface_kind=0.0;
uniform sampler2D atlas : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D fabric_normal : hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D leather_normal : hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D fabric_roughness : filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D leather_roughness : filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 rest_at;
void vertex(){rest_at=VERTEX;}
void fragment(){
 NORMAL_MAP=vec3(.5,.5,1.0);NORMAL_MAP_DEPTH=0.0;
 vec2 scale_uv=UV*8.0;
 vec2 tile=vec2(0,0);
 if(surface_kind==1.0){tile=vec2(.5,.5);scale_uv=UV*12.0;}
 if(surface_kind==2.0){tile=vec2(0,.5);scale_uv=vec2(UV.x*2.0,UV.y);}
 if(surface_kind==3.0){tile=vec2(.5,0);scale_uv=UV*6.0;}
 vec2 at=tile+vec2(.003)+fract(scale_uv)*.494;
 float sample_gray=dot(texture(atlas,at).rgb,vec3(.3333));
 float strength=surface_kind==1.0?.09:surface_kind==2.0?.18:.22;
 ALBEDO=tint.rgb*(1.0+(sample_gray-.35)*strength);
 ROUGHNESS=.85;
 if(surface_kind==0.0){
  NORMAL_MAP=texture(fabric_normal,UV*18.0).rgb;NORMAL_MAP_DEPTH=.22;
  float warp=.5+.5*sin((UV.x*1.0+UV.y*.45)*1600.0);
  ALBEDO*=.965+.055*warp;
  ROUGHNESS=.77+.14*texture(fabric_roughness,UV*18.0).r;}
 if(surface_kind==1.0){ROUGHNESS=.54;
#ifndef PREVIEW_SURFACE
  SSS_STRENGTH=.15;SSS_TRANSMITTANCE_COLOR=vec4(1.0,.48,.27,1);SSS_TRANSMITTANCE_DEPTH=.04;
#endif
  float cheeks=(exp(-pow((rest_at.x-.0505)/.0253,2.0))+exp(-pow((rest_at.x+.0505)/.0253,2.0)))*exp(-pow((rest_at.y-1.615)/.0213,2.0))*smoothstep(.01,.08,rest_at.z);
  ALBEDO=mix(ALBEDO,ALBEDO*vec3(1.035,.89,.87),cheeks*.22);
  float lip=1.0-smoothstep(.70,1.10,length(vec2(rest_at.x/.023,(rest_at.y-1.580)/.007)));
  lip*=smoothstep(.075,.11,rest_at.z);
  ALBEDO=mix(ALBEDO,ALBEDO*vec3(.85,.60,.62),lip*.62);
  float bump_x=texture(atlas,at+vec2(.0008,0)).r-sample_gray;float bump_y=texture(atlas,at+vec2(0,.0008)).r-sample_gray;
  NORMAL_MAP=normalize(vec3(-bump_x*2.0,-bump_y*2.0,1.0))*.5+.5;NORMAL_MAP_DEPTH= .12;
 }
 if(surface_kind==2.0){ROUGHNESS=.55;
  float fiber=.5+.5*sin(UV.x*640.0+sin(UV.y*17.0)*.4);ALBEDO*=.9+fiber*.18;
  ANISOTROPY=.35;ANISOTROPY_FLOW=vec2(0,1);
  SPECULAR=.23;}
 if(surface_kind==3.0){
  NORMAL_MAP=texture(leather_normal,UV*6.0).rgb;NORMAL_MAP_DEPTH=.16;
  SPECULAR=.20;ROUGHNESS=.62+.16*texture(leather_roughness,UV*6.0).r;}
 if(surface_kind==4.0){ALBEDO=tint.rgb;ROUGHNESS=.13;CLEARCOAT=.8;CLEARCOAT_ROUGHNESS=.08;}
 if(surface_kind==5.0){
  vec2 d=UV-vec2(.5);float radius=length(d)*2.0;float angle=atan(d.y,d.x);
  float fibers=.5+.5*sin(angle*83.0+sin(radius*45.0)*2.0);
  vec3 iris=tint.rgb*(.9+fibers*.7);
  iris=mix(iris,vec3(.025,.015,.009),smoothstep(.72,1.0,radius));
  iris=mix(vec3(.007,.005,.004),iris,smoothstep(.34,.43,radius));
  ALBEDO=iris;ROUGHNESS=.10;CLEARCOAT=1.0;CLEARCOAT_ROUGHNESS=.06;
 }
 if(surface_kind==6.0){ALBEDO=tint.rgb;ROUGHNESS=.46;
#ifndef PREVIEW_SURFACE
  SSS_STRENGTH=.10;
#endif
 }
 if(surface_kind==7.0){METALLIC=.8;ROUGHNESS=.30;}
 if(surface_kind==8.0){ALBEDO=tint.rgb;ROUGHNESS=.72;}
}


