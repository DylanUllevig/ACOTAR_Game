// Hit flash for creatures: blends the sprite toward a flat colour for a few
// frames when struck. Lighting still applies afterwards.
shader_type canvas_item;

uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.96, 0.9, 1.0);
uniform float tint_amount = 0.0;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 t = texture(TEXTURE, UV) * COLOR;
	vec3 c = mix(t.rgb, t.rgb * tint_color.rgb, tint_amount);
	COLOR = vec4(mix(c, flash_color.rgb, flash), t.a);
}
