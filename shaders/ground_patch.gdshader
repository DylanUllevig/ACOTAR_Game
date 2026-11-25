// A tiled ground patch (a cobbled square, a muddy yard) whose edges fray into
// the ground under it along a ragged line, instead of stopping at a ruler edge.
// Used by Region.add_ground_patch on a Sprite2D whose region starts at 0, so
// UV / TEXTURE_PIXEL_SIZE is the position inside the patch in pixels.
shader_type canvas_item;
#include "res://shaders/noise.gdshaderinc"

uniform vec2 patch_size = vec2(1024.0, 1024.0);
uniform float feather = 90.0;     // how far, in pixels, the edge takes to fade
uniform float ragged = 50.0;      // how far the edge wanders in and out
uniform vec2 seed = vec2(0.0);    // keeps two patches from fraying alike
uniform float noise_scale = 0.011; // size of the fraying, per pixel

void fragment() {
	highp vec2 pos = UV / TEXTURE_PIXEL_SIZE;
	float d = min(min(pos.x, pos.y), min(patch_size.x - pos.x, patch_size.y - pos.y));
	float n = fbm((pos + seed) * noise_scale) - 0.5;
	float a = smoothstep(0.0, feather, d - ragged * 0.5 + n * ragged * 2.0);
	COLOR.a *= a;
}
