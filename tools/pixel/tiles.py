"""Terrain tiles for the pixel-art world.

Each terrain is a seamless 256 x 256 pixel texture (an 8 x 8 block of
32-pixel tiles, so the pattern repeats only every eight tiles). Terrains are
drawn in layers: a base layer covers the whole map, and each layer above it is
placed with marching squares on the map's tile corners. For every terrain the
atlas holds 16 shapes (rows, indexed by which corners are covered: top-left 1,
top-right 2, bottom-left 4, bottom-right 8) times the 64 positions in the
8 x 8 pattern (columns: position = (tile_y % 8) * 8 + tile_x % 8). Row 15 is
the full tile, row 0 is empty.

The edge of a shape is drawn from a smooth field (the corners blended across
the tile, plus noise that wraps with the pattern), so edges run continuously
from tile to tile and wobble like a real path or puddle rather than following
the grid. A rim of a few pixels inside the edge gets its own shade, and the
outermost pixel row can get a lip (a darker or lighter line) for depth.

    python3 tools/pixel/tiles.py            # writes assets/pixel/terrain/*.png
"""
import os
import sys
import zlib
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from common import periodic_noise, quantize, rgb, to_image  # noqa: E402

T = 16          # tile size in art pixels (a tile is 48 world units: 3 per art pixel)
M = 128         # pattern size (8 x 8 tiles)
N = M // T
Q = M / 256.0   # the textures below were drawn for a 256 pattern; sizes and counts scale with Q
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "pixel", "terrain")


def blob(img, x, y, rx, ry, color):
    for dy in range(-ry, ry + 1):
        for dx in range(-rx, rx + 1):
            if (dx / max(rx, 0.5)) ** 2 + (dy / max(ry, 0.5)) ** 2 <= 1.0:
                img[(y + dy) % M, (x + dx) % M] = rgb(color) if isinstance(color, str) else color


# ------------------------------------------------------------------ textures
def tex_snow(seed=1):
    n = periodic_noise(M, M, seed, 4, cell=max(4, int(64 * Q)))
    fine = periodic_noise(M, M, seed + 3, 2, cell=max(4, int(16 * Q)))
    ys, xs = np.mgrid[0:M, 0:M]
    # long, soft wind ripples across the drifts
    ripple = 0.5 + 0.5 * np.sin((xs * 1.0 + ys * 0.35) / M * 2 * np.pi * 5 + n * 5.0)
    v = 0.58 * n + 0.22 * ripple + 0.2 * fine
    v = (v - v.min()) / (v.max() - v.min())
    img = quantize(0.18 + v * 0.82, ["#bccae6", "#cbd6ee", "#d9e2f4", "#e6edf9", "#f2f6fd", "#fbfdff"], 0.45)
    rng = np.random.default_rng(seed + 9)
    for _ in range(max(1, int(140 * Q * Q))):   # sparkles and the odd blue fleck
        x, y = rng.integers(0, M, 2)
        img[y, x] = rgb("#ffffff") if rng.random() < 0.75 else rgb("#a9b8dc")
    for _ in range(max(1, int(10 * Q * Q))):    # a dry grass stalk poking through
        x, y = rng.integers(0, M, 2)
        for k in range(rng.integers(2, 4)):
            img[(y - k) % M, (x + (k // 3)) % M] = rgb("#9b8a6e") if k else rgb("#7d6d57")
    return img


def tex_trodden(seed=2):
    n = periodic_noise(M, M, seed, 3, cell=max(4, int(48 * Q)))
    fine = periodic_noise(M, M, seed + 1, 2, cell=max(4, int(12 * Q)))
    v = 0.7 * n + 0.3 * fine
    img = quantize(v, ["#939bb8", "#a1a9c4", "#afb6cf", "#bdc3d9", "#cad0e2"], 0.4)
    rng = np.random.default_rng(seed)
    for _ in range(max(1, int(26 * Q * Q))):  # boot prints pressed into the packed snow, in pairs
        x, y = rng.integers(0, M, 2)
        for side in (0, 1):
            bx, by = x + side * 4, y + side * 5
            blob(img, bx, by, 1, 2, "#949db9")
            img[(by + 2) % M, bx % M] = rgb("#a6aec8")
    for _ in range(max(1, int(60 * Q * Q))):  # grit
        x, y = rng.integers(0, M, 2)
        img[y, x] = rgb("#8d8293") if rng.random() < 0.6 else rgb("#e3e8f4")
    return img


def tex_ice(seed=3):
    n = periodic_noise(M, M, seed, 3, cell=max(4, int(64 * Q)))
    ys, xs = np.mgrid[0:M, 0:M]
    streak = 0.5 + 0.5 * np.sin((xs - ys * 1.6) / M * 2 * np.pi * 4)
    v = 0.62 * n + 0.38 * streak
    img = quantize(v, ["#6a9bcb", "#80b0da", "#98c4e6", "#b2d6ef", "#cde7f6"], 0.6)
    rng = np.random.default_rng(seed)
    for _ in range(max(1, int(16 * Q * Q))):   # thin white cracks
        x, y = rng.integers(0, M, 2).astype(float)
        a = rng.random() * np.pi
        for _ in range(rng.integers(5, 15)):
            img[int(y) % M, int(x) % M] = rgb("#eef8ff")
            a += rng.normal(0, 0.45)
            x += np.cos(a)
            y += np.sin(a)
    for _ in range(max(1, int(12 * Q * Q))):   # dusting of snow on the ice
        x, y = rng.integers(0, M, 2)
        blob(img, x, y, int(rng.integers(2, 4)), 1, "#dfeaf6")
    for _ in range(max(1, int(40 * Q * Q))):
        x, y = rng.integers(0, M, 2)
        img[y, x] = rgb("#ffffff")
    return img


def tex_dirt(seed=4):
    n = periodic_noise(M, M, seed, 3, cell=max(4, int(48 * Q)))
    fine = periodic_noise(M, M, seed + 2, 2, cell=max(4, int(10 * Q)))
    img = quantize(0.7 * n + 0.3 * fine, ["#5a3f33", "#6b4c3b", "#7c5944", "#8d6951", "#9d795e"], 0.35)
    rng = np.random.default_rng(seed)
    for _ in range(max(1, int(70 * Q * Q))):   # pebbles with a lit top
        x, y = rng.integers(0, M, 2)
        img[y, x] = rgb("#b5a48f")
        img[y, (x + 1) % M] = rgb("#9a8a78")
        img[(y + 1) % M, x] = rgb("#4a352a")
        img[(y + 1) % M, (x + 1) % M] = rgb("#4a352a")
    for _ in range(max(1, int(8 * Q * Q))):    # a few roots
        x, y = rng.integers(0, M, 2).astype(float)
        a = rng.random() * np.pi * 2
        for _ in range(rng.integers(3, 7)):
            img[int(y) % M, int(x) % M] = rgb("#4c3428")
            a += rng.normal(0, 0.5)
            x += np.cos(a)
            y += np.sin(a)
    return img


def tex_mud(seed=5):
    n = periodic_noise(M, M, seed, 3, cell=max(4, int(48 * Q)))
    img = quantize(n, ["#4d4245", "#5b4e50", "#6a5c5b", "#7a6b67", "#8b7d78"], 0.35)
    rng = np.random.default_rng(seed)
    for _ in range(max(1, int(40 * Q * Q))):  # slush pooling in the ruts
        x, y = rng.integers(0, M, 2)
        w = rng.integers(2, 5)
        for dx in range(w):
            img[y, (x + dx) % M] = rgb("#a9aec2")
            if 0 < dx < w - 1:
                img[(y + 1) % M, (x + dx) % M] = rgb("#8f94a8")
    return img


def tex_grass(seed=6):
    n = periodic_noise(M, M, seed, 3, cell=max(4, int(48 * Q)))
    img = quantize(n, ["#3d7744", "#4a894b", "#589d54", "#69b05d", "#7dc169"], 0.35)
    rng = np.random.default_rng(seed)
    for _ in range(max(1, int(700 * Q * Q))):  # blades
        x, y = rng.integers(0, M, 2)
        c = rgb("#93d47a") if rng.random() < 0.5 else rgb("#33673c")
        h = rng.integers(1, 3)
        for k in range(h):
            img[(y - k) % M, x] = c
    for _ in range(max(1, int(28 * Q * Q))):   # small flowers
        x, y = rng.integers(0, M, 2)
        c = [rgb("#f4e38a"), rgb("#f2a9c4"), rgb("#ffffff"), rgb("#b9a7f0")][rng.integers(0, 4)]
        img[y, x] = c
        img[(y + 1) % M, x] = rgb("#2f5d36")
    return img


def tex_stones(seed, count, squash, ramp, gap, lip_light, lip_dark, moss=None):
    """Seamless stones: periodic Voronoi cells with a mortar gap, each stone
    shaded on its own with a lit top-left and a dark bottom-right lip."""
    rng = np.random.default_rng(seed)
    pts = rng.random((count, 2)) * M
    ys, xs = np.mgrid[0:M, 0:M].astype(float)
    d1 = np.full((M, M), 1e9)
    d2 = np.full((M, M), 1e9)
    owner = np.zeros((M, M), int)
    for i, (px, py) in enumerate(pts):
        for ox in (-M, 0, M):
            for oy in (-M, 0, M):
                d = np.hypot(xs - px - ox, (ys - py - oy) * squash)
                closer = d < d1
                d2 = np.where(closer, d1, np.minimum(d2, d))
                owner = np.where(closer, i, owner)
                d1 = np.where(closer, d, d1)
    # the gap is where neighbouring pixels belong to different stones (a
    # threshold on d2 - d1 pinches into dark wedges where three stones meet)
    diff = np.zeros((M, M), bool)
    for ax in (0, 1):
        diff |= owner != np.roll(owner, 1, axis=ax)
    edge = diff
    shade = rng.random(count)
    n = periodic_noise(M, M, seed + 1, 2, cell=max(4, int(16 * Q)))
    v = np.clip(shade[owner] * 0.55 + n * 0.45, 0, 1)
    img = quantize(v, list(ramp), 0.5)
    up = (np.roll(edge, 1, axis=0) | np.roll(edge, 1, axis=1)) & ~edge
    dn = (np.roll(edge, -1, axis=0) | np.roll(edge, -1, axis=1)) & ~edge
    img[up] = rgb(lip_light)
    img[dn] = rgb(lip_dark)
    img[edge] = rgb(gap)
    if moss:
        mn = periodic_noise(M, M, seed + 5, 2, cell=max(4, int(32 * Q)))
        mm = edge & (mn > 0.7)
        img[mm] = rgb(moss)
    return img


def tex_cobble(seed=7):
    return tex_stones(seed, 170, 1.2, ("#6f6c7a", "#83808d", "#97949f", "#aaa7b2"), "#4a4654", "#bdbac4", "#5d5a68", "#66705e")


def tex_flagstone(seed=9):
    return tex_stones(seed, 30, 1.0, ("#7b7671", "#8e8882", "#a09a93", "#b2aca4"), "#56514e", "#c4beb5", "#6c6662", "#748360")


def tex_planks(seed=8):
    rng = np.random.default_rng(seed)
    img = np.zeros((M, M, 3), np.uint8)
    ramp = ["#764a31", "#87573a", "#976543", "#a5724d", "#b07e57"]
    n = periodic_noise(M, M, seed, 2, cell=max(4, int(32 * Q)))
    grain = periodic_noise(M, M, seed + 4, 2, cell=max(4, int(4 * Q)))
    H = 8
    for row in range(M // H):
        y0 = row * H
        tone = rng.integers(0, 3)
        seams = sorted(rng.choice(M, 2, replace=False))
        for y in range(y0, y0 + H):
            for x in range(M):
                g = (grain[(y * 7) % M, (x // 6) % M] - 0.5) * 2.0
                v = int(np.clip(tone + (n[y, x] - 0.5) * 2.4 + g * 0.8, 0, 4))
                img[y, x] = rgb(ramp[v])
        img[y0 + H - 1, :] = rgb("#563522")          # gap between boards
        img[y0, :] = rgb("#bd8c62")                  # lit board edge
        for sm in seams:
            img[y0:y0 + H - 1, sm] = rgb("#563522")  # butt joint
            img[y0:y0 + H - 1, (sm + 1) % M] = rgb("#a77a54")
            img[y0 + 2, (sm + 2) % M] = rgb("#3b2417")  # nails
            img[y0 + H - 3, (sm + 2) % M] = rgb("#3b2417")
    return img


TERRAINS = {
    # name: (texture, rim colour, rim width in field units, rim strength, lip colour)
    "snow": (tex_snow, "#c6d1ea", 0.10, 0.45, "#ffffff"),
    "trodden": (tex_trodden, "#909ab8", 0.09, 0.6, None),
    "ice": (tex_ice, "#eaf6ff", 0.10, 0.8, "#ffffff"),
    "dirt": (tex_dirt, "#4a3429", 0.08, 0.55, None),
    "mud": (tex_mud, "#3f3538", 0.08, 0.6, None),
    "grass": (tex_grass, "#2f5f38", 0.07, 0.65, None),
    "cobble": (tex_cobble, "#4a4654", 0.06, 0.6, None),
    "planks": (tex_planks, "#5a3826", 0.0, 0.0, None),
    "flagstone": (tex_flagstone, "#57524f", 0.06, 0.55, None),
}


def edge_noise(seed):
    return periodic_noise(M, M, seed, 3, cell=max(4, int(32 * Q))) - 0.5


def build_atlas(name):
    texf, rim_col, rim_w, rim_k, lip = TERRAINS[name]
    tex = texf()
    noise = edge_noise(zlib.crc32(name.encode()) % 1000 + 50) * 0.46
    rim = np.array(rgb(rim_col), float)
    atlas = np.zeros((16 * T, N * N * T, 4), np.uint8)
    u = (np.arange(T) + 0.5) / T
    U, V = np.meshgrid(u, u)
    for idx in range(16):
        tl, tr, bl, br = idx & 1, (idx >> 1) & 1, (idx >> 2) & 1, (idx >> 3) & 1
        f = tl * (1 - U) * (1 - V) + tr * U * (1 - V) + bl * (1 - U) * V + br * U * V
        for sub in range(N * N):
            sx, sy = (sub % N) * T, (sub // N) * T
            block = tex[sy:sy + T, sx:sx + T].astype(float)
            nz = noise[sy:sy + T, sx:sx + T]
            if idx == 15:
                field = np.ones((T, T))
            elif idx == 0:
                field = np.zeros((T, T))
            else:
                field = f + nz * np.minimum(1.0, 4 * f * (1 - f) + 0.15)
            inside = field > 0.5
            col = block.copy()
            if rim_w > 0 and idx not in (0, 15):
                band = inside & (field < 0.5 + rim_w)
                col[band] = col[band] * (1 - rim_k) + rim * rim_k
                if lip:
                    edge = inside & (field < 0.5 + rim_w * 0.3)
                    col[edge] = col[edge] * 0.4 + np.array(rgb(lip), float) * 0.6
            tile = np.dstack([col, np.where(inside, 255, 0)]).astype(np.uint8)
            atlas[idx * T:(idx + 1) * T, sub * T:(sub + 1) * T] = tile
    return Image.fromarray(atlas, "RGBA"), to_image(tex)


def main():
    os.makedirs(OUT, exist_ok=True)
    names = sys.argv[1:] or list(TERRAINS)
    for name in names:
        atlas, tex = build_atlas(name)
        atlas.save(os.path.join(OUT, name + ".png"))
        tex.save(os.path.join(OUT, name + "_pattern.png"))
        print("terrain", name, atlas.size)


if __name__ == "__main__":
    main()
