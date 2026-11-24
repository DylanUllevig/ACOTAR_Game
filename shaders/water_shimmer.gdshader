shader_type canvas_item;
// Pixel water: drifting glints on the open water of a terrain layer. Works on
// whole art pixels (px world units each) so the glints stay square, and only
// on the deep-water colours, so the shallows and the foam line are left alone.

uniform float px = 3.0;
uniform vec4 glint : source_color = vec4(0.88, 0.97, 1.0, 1.0);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 g = floor(world_pos / px);
	// deep water: blue clearly above red, not the pale shallows or foam
	float deep = step(0.18, c.b - c.r) * step(c.g, 0.8);
	// slow bands of light moving across the pond; inside a band, a sparse
	// scatter of pixels twinkles on and off
	float band = sin(g.x * 0.11 + g.y * 0.23 - TIME * 0.9) * sin(g.y * 0.07 - g.x * 0.05 + TIME * 0.6);
	float h = hash(g);
	float tw = step(0.82, fract(h * 7.0 + TIME * (0.25 + h * 0.35)));
	float on = step(0.55, band) * step(0.6, h) * tw * deep;
	c.rgb = mix(c.rgb, glint.rgb, on * 0.85);
	COLOR = c;
}
