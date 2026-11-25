// Pulsing emissive tint for Fae things (eyes, magic). Values above 1.0 bloom
// through the HDR glow in the WorldEnvironment.
shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float power = 2.2;
uniform float pulse_speed = 1.6;

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float p = 0.75 + 0.25 * sin(TIME * pulse_speed);
	COLOR = vec4(glow_color.rgb * power * p, t.a * COLOR.a);
}
