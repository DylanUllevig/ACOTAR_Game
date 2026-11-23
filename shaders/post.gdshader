// Final grade: vignette, lift/gamma/gain tint, subtle grain. Full-rect ColorRect
// in the top CanvasLayer under the UI.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.45;
uniform vec3 lift = vec3(0.0);
uniform vec3 gain = vec3(1.0);
uniform float saturation = 1.0;
uniform float grain = 0.025;
uniform float blackout = 0.0;   // 0..1 fade used for magic sleep etc.

float rand(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = c * gain + lift * (1.0 - c);
	vec2 d = SCREEN_UV - 0.5;
	float v = 1.0 - dot(d, d) * vignette * 2.2;
	c *= clamp(v, 0.0, 1.0);
	c += (rand(SCREEN_UV + fract(TIME)) - 0.5) * grain;
	c = mix(c, vec3(0.0), blackout);
	COLOR = vec4(c, 1.0);
}
