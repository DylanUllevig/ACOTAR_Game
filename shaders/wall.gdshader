// The Wall: an invisible ward seen as a shimmering seam and ripples.
shader_type canvas_item;
render_mode blend_add, unshaded;
#include "res://shaders/noise.gdshaderinc"

uniform vec4 seam_color : source_color = vec4(0.55, 0.72, 1.0, 1.0);
uniform float strength = 1.6;   // >1 feeds the HDR glow
uniform float reveal = 1.0;

void fragment() {
	vec2 uv = UV;
	float wave = fbm(vec2(uv.x * 6.0, TIME * 0.3)) * 0.12;
	float dist = abs(uv.y - 0.5 - wave + 0.06);
	float seam = exp(-dist * 60.0);
	float ripple = sin((uv.y - 0.5) * 80.0 - TIME * 3.0) * 0.5 + 0.5;
	ripple *= exp(-dist * 9.0) * 0.35;
	float sparks = smoothstep(0.86, 1.0, fbm(uv * vec2(30.0, 8.0) + vec2(TIME * 0.4, 0.0))) * exp(-dist * 14.0);
	float a = (seam + ripple + sparks) * reveal;
	COLOR = vec4(seam_color.rgb * a * strength, 1.0);
}
