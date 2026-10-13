shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(0.7, 0.75, 0.8, 1.0);
uniform mat4 mesh_to_sword;
uniform float energy_front = -0.15;
uniform float energy_strength = 1.0;
uniform float steel_roughness = .65;
uniform float steel_metallic = 0.0;
uniform float blade_base = .045;
uniform float blade_length = 1.125;
varying float blade_position;
void vertex() {
    vec3 sword_vertex = (mesh_to_sword * vec4(VERTEX, 1.0)).xyz;
    blade_position = clamp((-sword_vertex.y - blade_base) / blade_length, 0.0, 1.0);
}
void fragment() {
    float charged = 1.0 - smoothstep(energy_front - 0.045, energy_front + 0.025, blade_position);
    float crest = exp(-pow((blade_position - energy_front) / 0.055, 2.0));
    ALBEDO = mix(base_color.rgb, vec3(0.10, 0.38, 0.85), charged * 0.92);
    ROUGHNESS = steel_roughness;
    METALLIC = steel_metallic;
    EMISSION = vec3(0.08, 0.42, 1.0) * (charged * 0.35 + crest * 1.5) * energy_strength;
}
