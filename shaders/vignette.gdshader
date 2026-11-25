shader_type canvas_item;
// Screen-edge tint for taking damage and for low health. 'amount' 0..1.

uniform vec4 tint : source_color = vec4(0.55, 0.02, 0.05, 1.0);
uniform float amount = 0.0;
uniform float aspect = 1.78;

void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= aspect * 0.62;
	float d = length(uv);
	float v = smoothstep(0.3, 0.78, d);
	COLOR = vec4(tint.rgb, clamp(v * amount, 0.0, 1.0));
}
