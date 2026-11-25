shader_type canvas_item;
render_mode unshaded;

// Feyre's silhouette where a creature in front of her hides her. Drawn on a
// copy of her sprite above the world, and masked by the creature's own
// painting: it shows only where both she and the creature are opaque, which
// is exactly the part of her that the creature covers. A soft fill and a
// brighter rim, so she reads through the wolf without looking like a glow.

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform vec2 inv_x = vec2(1.0, 0.0);     // canvas -> mask sprite local (Transform2D columns)
uniform vec2 inv_y = vec2(0.0, 1.0);
uniform vec2 inv_o = vec2(0.0, 0.0);
uniform vec4 mask_rect = vec4(0.0, 0.0, 1.0, 1.0);   // the sprite's local rect (x, y, w, h)
uniform vec4 mask_uv = vec4(0.0, 0.0, 1.0, 1.0);     // the part of mask_tex it shows (u, v, du, dv)
uniform vec2 mask_flip = vec2(0.0, 0.0);             // flip_h, flip_v as 0 or 1
uniform vec4 fill_color : source_color = vec4(0.93, 0.87, 0.72, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.86, 1.0);
uniform float rim_texels = 5.0;
uniform float strength = 0.0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 local = inv_x * world.x + inv_y * world.y + inv_o;
	vec2 t = (local - mask_rect.xy) / mask_rect.zw;
	float inside = step(0.0, t.x) * step(t.x, 1.0) * step(0.0, t.y) * step(t.y, 1.0);
	t = mix(t, 1.0 - t, mask_flip);
	float m = texture(mask_tex, mask_uv.xy + clamp(t, 0.0, 1.0) * mask_uv.zw).a * inside;
	float a = texture(TEXTURE, UV).a;
	vec2 px = TEXTURE_PIXEL_SIZE * rim_texels;
	float n = min(min(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
			min(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
	float rim = clamp(a - n, 0.0, 1.0);
	vec3 col = mix(fill_color.rgb, rim_color.rgb, rim);
	float alpha = max(a * 0.16, rim * 0.85);
	COLOR = vec4(col, alpha * m * strength * COLOR.a);
}
