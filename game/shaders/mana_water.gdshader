shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;
uniform vec4 tint : source_color = vec4(0.025,0.36,0.67,0.86);
uniform float clock = 0.0;
uniform float dissolve = 1.0;
void fragment() {
    float flow = sin(UV.x*38.0 + UV.y*21.0-clock*4.5)*sin(UV.y*54.0-clock*6.0);
    float caustic = pow(max(0.0,flow),5.0);
    float edge = pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),2.3);
    ALBEDO = mix(tint.rgb,vec3(0.4,0.94,1.0),caustic*0.65+edge*0.3);
    EMISSION = vec3(0.04,0.48,0.75)*(0.35+caustic*1.6+edge*0.8)*dissolve;
    ROUGHNESS = 0.15;
    METALLIC = 0.12;
    ALPHA = tint.a*dissolve;
}
