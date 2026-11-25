// A tiled ground (snow, trodden mud) that does not show its repeat. A second
// reading of the same tile, turned and at another scale, takes over across
// broad patches picked by slow noise in world space, so the tile's marks no
// longer line up into rows. The normal map is read and turned the same way, so
// the lighting matches the paint. Used by Region.add_ground_tile(vary = true).
shader_type canvas_item;
#include "res://shaders/noise.gdshaderinc"

uniform float patch_scale = 0.0011;   // size of the patches, per world pixel
uniform float turn = 3.14159;         // the second reading is turned half round, so
                                      // streaks and drifts keep their direction
uniform float stretch = 0.79;         // and its scale against the first
uniform float edge = 0.09;            // how sharp the change from one to the other is
uniform vec2 seed = vec2(0.0);

varying highp vec2 world;
varying vec4 tint;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	tint = COLOR;
}

void fragment() {
	float n = fbm(world * patch_scale + seed);
	float m = smoothstep(0.5 - edge, 0.5 + edge, n);
	mat2 r = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn)));
	highp vec2 uv2 = r * UV * stretch + vec2(0.37, 0.61);
	vec4 a = texture(TEXTURE, UV);
	vec4 b = texture(TEXTURE, uv2);
	COLOR = mix(a, b, m) * tint;
	// normals: the second reading's are turned back to the screen's axes
	vec3 na = texture(NORMAL_TEXTURE, UV).rgb * 2.0 - 1.0;
	vec3 nb = texture(NORMAL_TEXTURE, uv2).rgb * 2.0 - 1.0;
	nb.xy = transpose(r) * nb.xy;
	NORMAL_MAP = normalize(mix(na, nb, m)) * 0.5 + 0.5;
}
