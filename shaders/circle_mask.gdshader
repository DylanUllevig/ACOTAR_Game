shader_type canvas_item;
// Shows a texture inside the largest circle that fits the item's rect, with
// an anti-aliased edge. Works from the vertex position rather than UV, so an
// AtlasTexture (a crop of a portrait) masks correctly. Set rect_size.

uniform vec2 rect_size = vec2(100.0, 100.0);
varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 d = local - rect_size * 0.5;
	float r = min(rect_size.x, rect_size.y) * 0.5;
	float dist = length(d);
	float aa = max(fwidth(dist), 0.75);
	COLOR.a *= 1.0 - smoothstep(r - aa, r, dist);
}
