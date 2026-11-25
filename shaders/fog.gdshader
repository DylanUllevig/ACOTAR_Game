// Drifting fog / ground mist. World-space: put on a large ColorRect or Sprite2D
// above the props. 'world_scale' ties the noise to world units so it doesn't
// swim with the camera.
shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/noise.gdshaderinc"

uniform vec4 fog_color : source_color = vec4(0.82, 0.86, 0.95, 1.0);
uniform float density = 0.35;
uniform float world_scale = 0.0025;
uniform vec2 wind = vec2(0.02, 0.006);
uniform float low = 0.35;
uniform float high = 0.85;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = world_pos * world_scale + TIME * wind;
	float n = fbm(p);
	float n2 = fbm(p * 2.7 - TIME * wind * 1.7);
	float f = smoothstep(low, high, n * 0.7 + n2 * 0.3);
	COLOR = vec4(fog_color.rgb, f * density);
}
