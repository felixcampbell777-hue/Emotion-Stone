shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
    vec2 edge = abs(UV - vec2(0.5)) * 2.0;
    float rim = pow(smoothstep(0.45, 1.0, max(edge.x, edge.y)), 1.7);
    COLOR = vec4(0.65, 0.025, 0.045, rim * intensity * 0.68);
}
