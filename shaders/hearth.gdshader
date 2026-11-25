// Animated fire tongue for the hearth (emissive, blooms).
shader_type canvas_item;
render_mode blend_add, unshaded;
#include "res://shaders/noise.gdshaderinc"

uniform float power = 2.4;

void fragment() {
	vec2 uv = UV;
	float n = fbm(vec2(uv.x * 4.0, uv.y * 3.0 + TIME * 2.2));
	float shape = smoothstep(0.0, 0.6, 1.0 - uv.y) * (1.0 - abs(uv.x - 0.5) * 2.0);
	float f = smoothstep(0.25, 0.75, n * shape * 1.6);
	vec3 col = mix(vec3(1.0, 0.25, 0.05), vec3(1.0, 0.85, 0.4), f);
	COLOR = vec4(col * f * power, 1.0);
}
