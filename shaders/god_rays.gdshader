// Screen-space volumetric-style light shafts. Put on a full-rect ColorRect in a
// CanvasLayer above the world. Additive, so it brightens what is below.
shader_type canvas_item;
render_mode blend_add, unshaded;
#include "res://shaders/noise.gdshaderinc"

uniform vec4 ray_color : source_color = vec4(1.0, 0.92, 0.75, 1.0);
uniform float intensity = 0.35;
uniform float angle = -0.35;          // radians; slant of the shafts
uniform float spread = 0.9;            // how far down the screen they reach
uniform vec2 origin = vec2(0.15, -0.1);// light source in UV space
uniform float speed = 0.04;
uniform float density = 3.2;

void fragment() {
	vec2 uv = UV;
	vec2 d = uv - origin;
	float c = cos(angle), s = sin(angle);
	vec2 r = vec2(d.x * c - d.y * s, d.x * s + d.y * c);
	float shafts = fbm(vec2(r.x * density, TIME * speed));
	shafts = smoothstep(0.5, 0.9, shafts);
	float fall = clamp(1.0 - length(d) / spread, 0.0, 1.0);
	fall = fall * fall;
	float dust = fbm(uv * 40.0 + vec2(TIME * 0.05, -TIME * 0.08));
	dust = smoothstep(0.72, 0.95, dust) * 0.4;
	float a = (shafts * fall) * intensity + dust * fall * intensity;
	COLOR = vec4(ray_color.rgb * a, 1.0);
}
