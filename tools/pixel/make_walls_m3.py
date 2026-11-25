#!/usr/bin/env python3
"""Wall faces for Milestone 3, made from the existing pixel walls.

    python3 tools/pixel/make_walls_m3.py

Writes to assets/pixel/interior/:
  wall_chateau.png        her father's new house: ivory damask, pale gold
  wall_chateau_blue.png   the same in pale blue (her room, the study)
  wall_manor_wreck.png    the manor's green damask after the sack: claw gouges,
                          soot and blood (wider, so the damage doesn't repeat)
  wall_kitchen_burnt.png  the manor kitchen's plaster, blackened by fire
"""
import os
import random
import colorsys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
D = os.path.join(ROOT, "assets", "pixel", "interior")


def load(name):
    return Image.open(os.path.join(D, name + ".png")).convert("RGBA")


def molding_rows(im):
    """The gold molding along the top: rows whose pixels are mostly warm."""
    w, h = im.size
    px = im.load()
    rows = 0
    for y in range(h):
        warm = 0
        for x in range(w):
            r, g, b, a = px[x, y]
            if r >= g and r > b + 20:
                warm += 1
        if warm < w * 0.6:
            break
        rows = y + 1
    return rows


def recolor(im, base_rgb, accent_rgb):
    """Damask below the molding: the field takes base_rgb, the motifs accent_rgb,
    each keeping the original's light and shade."""
    out = im.copy()
    px = out.load()
    w, h = im.size
    top = molding_rows(im)
    bh, bl, bs = colorsys.rgb_to_hls(*[c / 255.0 for c in base_rgb])
    ah, al, as_ = colorsys.rgb_to_hls(*[c / 255.0 for c in accent_rgb])
    # the field's own lightness, to centre the mapping
    field = []
    for y in range(top, h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if g > r and g >= b:
                field.append(colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)[1])
    mid = sorted(field)[len(field) // 2] if field else 0.3
    for y in range(top, h):
        for x in range(w):
            r, g, b, a = px[x, y]
            hh, ll, ss = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
            if g > r and g >= b:
                nl = min(0.97, max(0.05, bl + (ll - mid) * 0.9))
                nr, ng, nb = colorsys.hls_to_rgb(bh, nl, bs)
            else:
                nl = min(0.95, max(0.1, al + (ll - 0.55) * 0.6))
                nr, ng, nb = colorsys.hls_to_rgb(ah, nl, as_)
            px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return out


def widen(im, n):
    w, h = im.size
    out = Image.new("RGBA", (w * n, h))
    for i in range(n):
        out.paste(im, (i * w, 0))
    return out


def blot(px, w, h, cx, cy, r, col, rnd, alpha=1.0, wrap=True):
    for y in range(int(cy - r * 1.2), int(cy + r * 1.2) + 1):
        for x in range(int(cx - r * 1.2), int(cx + r * 1.2) + 1):
            if not (0 <= y < h):
                continue
            xx = x % w if wrap else x
            if not (0 <= xx < w):
                continue
            d = ((x - cx) ** 2 + ((y - cy) * 1.3) ** 2) ** 0.5
            if d < r * rnd.uniform(0.75, 1.05):
                r0, g0, b0, a0 = px[xx, y]
                k = alpha
                px[xx, y] = (int(r0 * (1 - k) + col[0] * k), int(g0 * (1 - k) + col[1] * k), int(b0 * (1 - k) + col[2] * k), a0)


def smudge(px, w, h, cx, y0, y1, width, col, rnd, alpha):
    """A smoke stain: a soft column that fades as it rises, ragged at the edges."""
    for y in range(max(0, int(y1)), min(h, int(y0))):
        t = (y0 - y) / max(1.0, (y0 - y1))
        half = width * (0.6 + 0.6 * t) / 2.0
        for x in range(int(cx - half - 2), int(cx + half + 3)):
            xx = x % w
            edge = abs(x - cx) / max(1.0, half)
            if edge > 1.0 + rnd.uniform(-0.25, 0.1):
                continue
            k = alpha * (1.0 - t) * (1.0 - 0.5 * edge)
            if (x + y) % 2 == 0:
                k *= 0.85   # a touch of dither, like the rest of the art
            r0, g0, b0, a0 = px[xx, y]
            px[xx, y] = (int(r0 * (1 - k) + col[0] * k), int(g0 * (1 - k) + col[1] * k), int(b0 * (1 - k) + col[2] * k), a0)


def gouge(px, w, h, x0, y0, length, rnd):
    """Three claw marks raking down and across."""
    for k in range(3):
        x = x0 + k * 5
        y = y0 + k * 2
        for i in range(length):
            xx = int(x + i * 0.45) % w
            yy = int(y + i)
            if 0 <= yy < h:
                px[xx, yy] = (34, 26, 22, 255)
                if (xx + 1) < w:
                    r0, g0, b0, a0 = px[xx + 1, yy]
                    px[xx + 1, yy] = (min(255, r0 + 40), min(255, g0 + 40), min(255, b0 + 36), a0)


def main():
    manor = load("wall_manor")
    recolor(manor, (238, 229, 208), (214, 190, 128)).save(os.path.join(D, "wall_chateau.png"))
    recolor(manor, (190, 212, 230), (226, 214, 170)).save(os.path.join(D, "wall_chateau_blue.png"))

    rnd = random.Random(31)
    wreck = widen(manor, 10)
    w, h = wreck.size
    top = molding_rows(manor)
    px = wreck.load()
    for i in range(12):
        smudge(px, w, h, rnd.uniform(0, w), h, h * rnd.uniform(0.25, 0.6), rnd.uniform(8, 22), (24, 20, 18), rnd, 0.5)
    for i in range(9):
        gouge(px, w, h, rnd.uniform(0, w), rnd.uniform(top + 4, h * 0.45), int(rnd.uniform(18, 40)), rnd)
    for i in range(14):
        cx, cy = rnd.uniform(0, w), rnd.uniform(h * 0.35, h - 4)
        blot(px, w, h, cx, cy, rnd.uniform(1.5, 4.0), (92, 12, 14), rnd, 0.9)
        for k in range(rnd.randint(2, 6)):
            blot(px, w, h, cx + rnd.uniform(-10, 10), cy + rnd.uniform(-6, 8), 1.0, (92, 12, 14), rnd, 0.9)
        if rnd.random() < 0.5:
            # a run, dripping down the wall
            x = int(cx) % w
            for yy in range(int(cy), min(h, int(cy) + rnd.randint(4, 14))):
                px[x, yy] = (84, 10, 12, 255)
    # a torn strip of the damask hanging down
    for i in range(4):
        x0 = int(rnd.uniform(0, w - 12))
        for y in range(top + 2, top + 2 + rnd.randint(14, 30)):
            for x in range(x0, x0 + rnd.randint(5, 9)):
                r0, g0, b0, a0 = px[x, y]
                px[x, y] = (int(r0 * 0.55), int(g0 * 0.5), int(b0 * 0.45), a0)
    wreck.save(os.path.join(D, "wall_manor_wreck.png"))

    # the kitchen: rough plaster over stone, a smoke-black beam, soot rising
    cot = load("wall_cottage")
    cw, ch = cot.size
    k = Image.new("RGBA", (cw * 8, 112))
    for i in range(8):
        k.paste(cot, (i * cw, 112 - ch))
    kp = k.load()
    kw, kh = k.size
    for y in range(0, 112 - ch + 2):
        for x in range(kw):
            v = 40 + (6 if (x // 3 + y) % 7 == 0 else 0)
            kp[x, y] = (v, int(v * 0.8), int(v * 0.65), 255)
    rnd = random.Random(32)
    for y in range(kh):
        for x in range(kw):
            r0, g0, b0, a0 = kp[x, y]
            # soot thickest high up, where the smoke pooled
            s = max(0.0, 1.0 - y / kh) * 0.55 + 0.2
            kp[x, y] = (int(r0 * (1 - s)), int(g0 * (1 - s)), int(b0 * (1 - s)), a0)
    for i in range(18):
        smudge(kp, kw, kh, rnd.uniform(0, kw), kh, rnd.uniform(0, kh * 0.4), rnd.uniform(14, 40), (16, 13, 12), rnd, 0.6)
    k.save(os.path.join(D, "wall_kitchen_burnt.png"))
    print("walls written")


if __name__ == "__main__":
    main()
