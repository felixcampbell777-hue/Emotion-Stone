shader_type canvas_item;
uniform float strength : hint_range(0.0, 0.4) = 0.0;
void fragment() {
	vec2 centered = abs(UV - vec2(0.5)) * 2.0;
	float edge = smoothstep(0.42, 1.0, max(centered.x, centered.y));
	COLOR = vec4(0.45, 0.008, 0.018, strength * edge * edge);
}
