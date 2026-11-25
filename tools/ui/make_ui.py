"""Textures for the interface: paper cards (nine-patch, with a soft shadow, a
rosewood rim, a fine honey hairline and a little grain), a recessed inset,
and small icons (heart, sun, moon, flourish, slider knob, the "more" chevron).

Everything is drawn from signed distance fields, so edges are anti-aliased
without supersampling, and seeded, so it is repeatable.

    python3 tools/ui/make_ui.py        # writes assets/ui/*.png

The card textures are read by Art.card_style() in scripts/util/art.gd; keep
the margins there in step with SHADOW, RADIUS and the sizes here.
"""
import os
import numpy as np
from PIL import Image, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "ui")


def hexc(h, a=1.0):
    h = h.lstrip("#")
    return np.array([int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)], np.float64) / 255.0, a


PAPER = "#fbf4e6"
PAPER_DEEP = "#e5d2b2"
ROSEWOOD = "#6e3434"
ROSEWOOD_LIT = "#8d4a45"
HONEY = "#c8973f"
ROSE = "#b23e57"
ROSE_DEEP = "#7c2238"


def save(rgba, name):
    os.makedirs(OUT, exist_ok=True)
    img = Image.fromarray((np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")
    img.save(os.path.join(OUT, name + ".png"))
    print("ui", name, img.size[0], img.size[1])


def grid(w, h):
    y, x = np.mgrid[0:h, 0:w].astype(np.float64)
    return x + 0.5, y + 0.5


def sd_round_rect(x, y, cx, cy, hw, hh, r):
    qx = np.abs(x - cx) - (hw - r)
    qy = np.abs(y - cy) - (hh - r)
    out = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2)
    return out + np.minimum(np.maximum(qx, qy), 0) - r


def cover(sd, soft=0.75):
    """Anti-aliased coverage of the inside (sd <= 0)."""
    return np.clip(0.5 - sd / (2 * soft), 0, 1)


def over(dst, rgb, a):
    """Paint rgb with alpha a (arrays) over dst (premultiplied-free RGBA)."""
    a = a[..., None]
    da = dst[..., 3:4]
    out_a = a + da * (1 - a)
    with np.errstate(invalid="ignore", divide="ignore"):
        out_rgb = (rgb * a + dst[..., :3] * da * (1 - a)) / np.maximum(out_a, 1e-6)
    dst[..., :3] = out_rgb
    dst[..., 3:4] = out_a


def periodic_grain(w, h, period, seed):
    """Paper grain that repeats every 'period' pixels, offset so the repeat
    lines up with the start of the nine-patch centre."""
    rng = np.random.default_rng(seed)
    fine = rng.random((period, period))
    coarse = rng.random((period // 8 + 1, period // 8 + 1))
    # bilinear upsample of the coarse mottling, wrapping round
    cy, cx = np.mgrid[0:period, 0:period] / 8.0
    x0, y0 = np.floor(cx).astype(int), np.floor(cy).astype(int)
    fx, fy = cx - x0, cy - y0
    n = coarse.shape[0]
    def at(a, b):
        return coarse[a % n, b % n]
    mott = (at(y0, x0) * (1 - fx) * (1 - fy) + at(y0, x0 + 1) * fx * (1 - fy)
            + at(y0 + 1, x0) * (1 - fx) * fy + at(y0 + 1, x0 + 1) * fx * fy)
    tile = (fine - 0.5) * 0.018 + (mott - 0.5) * 0.03
    return tile


def card(name, paper, rim, rim_lit, hair, size=128, shadow=18, radius=22, rim_w=3.0, hair_in=8.0, seed=3, center=40):
    W = H = size
    x, y = grid(W, H)
    half = size / 2.0 - shadow
    img = np.zeros((H, W, 4))
    # soft shadow, a little below
    sh = cover(sd_round_rect(x, y, W / 2, H / 2 + 5, half, half, radius), 1.0)
    sh_img = Image.fromarray((sh * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(6.5))
    sh = np.asarray(sh_img).astype(np.float64) / 255.0 * 0.42
    over(img, hexc("#1c0f0c")[0], sh)
    sd = sd_round_rect(x, y, W / 2, H / 2, half, half, radius)
    # rim
    rim_rgb = hexc(rim)[0]
    lit_rgb = hexc(rim_lit)[0]
    t = np.clip((y - (H / 2 - half)) / (2 * half), 0, 1)[..., None]
    rim_col = lit_rgb * (1 - t) + rim_rgb * t
    over(img, rim_col, cover(sd))
    # paper, darker toward the rim, with grain
    inner = sd + rim_w
    p = hexc(paper)[0]
    deep = hexc(PAPER_DEEP)[0]
    edge = np.clip(1.0 - (-inner) / 16.0, 0, 1) ** 2 * 0.55
    off = (size - center) // 2
    g = periodic_grain(W, H, center, seed)
    gy = (np.arange(H) - off) % center
    gx = (np.arange(W) - off) % center
    grain = g[gy[:, None], gx[None, :]][..., None]
    col = p * (1 - edge[..., None]) + deep * edge[..., None] + grain
    over(img, col, cover(inner))
    # a lit bevel just inside the rim
    bevel = np.clip(1 - np.abs(inner + 0.9) / 0.9, 0, 1) * 0.35 * (1 - t[..., 0])
    over(img, np.array([1.0, 0.97, 0.9]), bevel)
    # the hairline
    hl = np.clip(1 - np.abs(sd + hair_in) / 0.8, 0, 1) * 0.8
    over(img, hexc(hair)[0], hl)
    save(img, name)


def inset(name="inset", size=64, radius=14, seed=9):
    W = H = size
    x, y = grid(W, H)
    img = np.zeros((H, W, 4))
    sd = sd_round_rect(x, y, W / 2, H / 2, W / 2 - 1, H / 2 - 1, radius)
    over(img, hexc("#d6bf98")[0], cover(sd))
    inner = sd + 1.5
    base = hexc("#f1e5ce")[0]
    # recessed: a soft shadow along the top edge inside
    top = sd_round_rect(x, y + 4, W / 2, H / 2, W / 2 - 1, H / 2 - 1, radius)
    shade = np.clip(1 - (-top) / 7.0, 0, 1) ** 1.5 * 0.10
    col = base * (1 - shade[..., None]) + hexc("#b99d74")[0] * shade[..., None]
    over(img, col, cover(inner))
    save(img, name)


def heart(name="heart", W=30, H=28):
    x, y = grid(W, H)
    # the exact heart distance (two arcs meeting in a point), in units where
    # the heart is about 1.2 wide and 1.1 tall with its tip at the origin
    k = 22.0                      # pixels per unit
    px = np.abs(x - W / 2) / k
    py = (H - 3.0 - y) / k
    def d2(ax, ay):
        return ax * ax + ay * ay
    upper = np.sqrt(d2(px - 0.25, py - 0.75)) - np.sqrt(2.0) / 4.0
    m = np.maximum(px + py, 0.0) * 0.5
    lower = np.sqrt(np.minimum(d2(px, py - 1.0), d2(px - m, py - m))) * np.sign(px - py)
    sd = np.where(px + py > 1.0, upper, lower) * k
    img = np.zeros((H, W, 4))
    over(img, hexc(ROSEWOOD)[0], cover(sd))
    t = np.clip((y - 2) / (H - 4), 0, 1)[..., None]
    fill = hexc("#d9536a")[0] * (1 - t) + hexc("#9b2a42")[0] * t
    over(img, fill, cover(sd + 1.6))
    hl = cover(np.sqrt((x - W * 0.33) ** 2 + (y - H * 0.3) ** 2) - 2.6, 0.9) * 0.7
    over(img, np.array([1.0, 0.92, 0.9]), hl)
    save(img, name)


def sun(name="sun", S=28):
    x, y = grid(S, S)
    c = S / 2
    r = np.sqrt((x - c) ** 2 + (y - c) ** 2)
    ang = np.arctan2(y - c, x - c)
    img = np.zeros((S, S, 4))
    rays = (np.cos(ang * 8) * 0.5 + 0.5) ** 6
    ray_sd = r - (8.5 + rays * 4.5)
    over(img, hexc("#d99a35")[0], cover(ray_sd) * np.clip((r - 6) / 2, 0, 1))
    over(img, hexc("#a8691f")[0], cover(r - 7.5))
    t = np.clip((y - c + 7) / 14, 0, 1)[..., None]
    over(img, hexc("#ffd773")[0] * (1 - t) + hexc("#f0a93f")[0] * t, cover(r - 6.3))
    save(img, name)


def moon(name="moon", S=28):
    x, y = grid(S, S)
    c = S / 2
    a = np.sqrt((x - c) ** 2 + (y - c) ** 2) - 9.5
    b = np.sqrt((x - c - 5.5) ** 2 + (y - c + 4) ** 2) - 8.5
    sd = np.maximum(a, -b)
    img = np.zeros((S, S, 4))
    over(img, hexc("#4b5577")[0], cover(sd))
    over(img, hexc("#e9e4cf")[0], cover(sd + 1.4))
    save(img, name)


def flourish(name="flourish", W=300, H=22):
    x, y = grid(W, H)
    c = W / 2
    cy = H / 2
    img = np.zeros((H, W, 4))
    d = np.abs(x - c)
    # tapering lines either side
    width = np.clip(2.2 * (1 - (d - 40) / (W / 2 - 40)), 0.6, 2.2)
    line_sd = np.abs(y - cy) - width / 2
    fade = np.clip((W / 2 - 4 - d) / 40, 0, 1) * np.clip(d - 39, 0, 1)
    over(img, hexc(HONEY)[0], np.clip(cover(line_sd, 0.6) + 0.35 * cover(line_sd - 0.8, 0.8), 0, 1) * fade)
    # small dots
    for k in (19, 30):
        for s in (-1, 1):
            dot = np.sqrt((x - c - s * k) ** 2 + (y - cy) ** 2) - (2.0 if k == 19 else 1.5)
            over(img, hexc(HONEY)[0], cover(dot, 0.6))
    # the diamond
    dia = (np.abs(x - c) + np.abs(y - cy)) / 1.0 - 7.5
    over(img, hexc(HONEY)[0], cover(dia, 0.7))
    over(img, hexc(ROSE)[0], cover(dia + 1.6, 0.7))
    save(img, name)


def knob(name, fill, S=30):
    x, y = grid(S, S)
    c = S / 2
    r = np.sqrt((x - c) ** 2 + (y - c - 1.2) ** 2)
    img = np.zeros((S, S, 4))
    sh = cover(np.sqrt((x - c) ** 2 + (y - c - 2.5) ** 2) - 12.0, 1.6) * 0.35
    over(img, hexc("#1c0f0c")[0], sh)
    over(img, hexc(ROSEWOOD)[0], cover(r - 11.5))
    over(img, hexc(PAPER)[0], cover(r - 10.0))
    t = np.clip((y - c + 7) / 14, 0, 1)[..., None]
    f = hexc(fill)[0]
    over(img, np.minimum(f * 1.25, 1) * (1 - t) + f * t, cover(r - 7.0))
    save(img, name)


def chevron(name="chevron", W=24, H=16):
    x, y = grid(W, H)
    img = np.zeros((H, W, 4))
    # a soft downward triangle
    cx = W / 2
    top, bot = 3.0, H - 3.0
    half = (bot - y) / (bot - top) * (W / 2 - 3)
    sd = np.maximum(np.abs(x - cx) - half, np.maximum(top - y, y - bot))
    over(img, hexc(ROSE_DEEP)[0], cover(sd - 1.0, 0.8))
    over(img, hexc(ROSE)[0], cover(sd + 0.6, 0.8))
    save(img, name)


def check(name="check", S=26):
    x, y = grid(S, S)
    img = np.zeros((S, S, 4))
    # tick mark from two capsules
    def capsule(ax, ay, bx, by, r):
        px, py = x - ax, y - ay
        dx, dy = bx - ax, by - ay
        h = np.clip((px * dx + py * dy) / (dx * dx + dy * dy), 0, 1)
        return np.sqrt((px - dx * h) ** 2 + (py - dy * h) ** 2) - r
    sd = np.minimum(capsule(6, 13.5, 11, 18.5, 2.0), capsule(11, 18.5, 20, 7.5, 2.0))
    over(img, hexc(PAPER)[0], cover(sd))
    save(img, name)


if __name__ == "__main__":
    card("card", PAPER, ROSEWOOD, ROSEWOOD_LIT, HONEY)
    card("card_tip", "#fbf0d4", "#9a6a28", "#b8863c", ROSE, seed=5)
    inset()
    heart()
    sun()
    moon()
    flourish()
    knob("knob", ROSE)
    knob("knob_hi", "#d2566f")
    chevron()
    check()
