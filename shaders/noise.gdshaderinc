// Shared value noise / fbm for canvas shaders.
//
// The lattice hash works on integers (a PCG step), so every GPU returns the
// same value for the same lattice point. The old hash multiplied coordinates
// by large constants and took fract(), which keeps only a few bits once a
// driver evaluates it at reduced precision; on some Windows GPUs that turned
// the fog into vertical streaks.

uint pcg_hash(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

// p must be a lattice point (already floored). Returns 0..1.
float hash21(highp vec2 p) {
	highp ivec2 q = ivec2(p) + ivec2(32768);
	uint h = pcg_hash(uint(q.x) ^ pcg_hash(uint(q.y) + 2654435769u));
	return float(h >> 8u) * (1.0 / 16777215.0);
}

float vnoise(highp vec2 p) {
	highp vec2 i = floor(p);
	highp vec2 f = p - i;
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(highp vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.0, 31.0);
		a *= 0.5;
	}
	return v;
}

// Per-pixel grain seed for screen effects: integer pixel coordinates plus a
// frame counter, no trigonometry.
float grain_hash(highp vec2 frag_coord, float t) {
	highp ivec2 q = ivec2(frag_coord);
	uint h = pcg_hash(uint(q.x) + pcg_hash(uint(q.y) + pcg_hash(uint(t * 60.0))));
	return float(h >> 8u) * (1.0 / 16777215.0);
}
