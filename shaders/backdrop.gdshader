shader_type canvas_item;
// Behind a menu: the game, softly blurred and washed with a warm tint.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod = 2.6;
uniform vec4 tint : source_color = vec4(0.13, 0.06, 0.07, 0.5);

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, blur_lod).rgb;
	c = mix(c, tint.rgb, tint.a);
	COLOR = vec4(c, COLOR.a);
}
