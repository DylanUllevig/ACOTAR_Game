"""Procedural pixel-art props: trees, rocks, bushes, brambles, logs and small
plants, lit from the upper left with a dark one-pixel outline.

    python3 tools/pixel/props.py          # writes assets/pixel/props/*.png

Every prop is drawn with its base at the bottom centre of the image, so the
game can place it by its feet like any other prop.
"""
import math
import os
import sys
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from common import BAYER4, rgb, outline  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "pixel", "props")

PINE = ["#1d3b3a", "#24493f", "#2d5a46", "#386c4d", "#4a8055", "#5f955f"]
SNOW = ["#9fb0d6", "#c2cfea", "#e1e8f6", "#f7faff"]
BARK = ["#2b1e1d", "#3e2b26", "#55392f", "#6b4a3a", "#82604a"]
STONE = ["#3d3b4a", "#555265", "#6e6b7e", "#8a879a", "#a7a4b5"]
LEAF = ["#2c4a2e", "#3b6436", "#4f7f3d", "#67994a", "#84b25c"]
BERRY = ["#7e1d2a", "#b3283a", "#e04a55"]
DRYGRASS = ["#6d5a3e", "#8c7650", "#ad9566", "#c9b27f"]
OUTLINE = "#191d2b"


def canvas(w, h):
    return np.zeros((h, w, 4), np.uint8)


def put(a, x, y, c):
    h, w = a.shape[:2]
    if 0 <= x < w and 0 <= y < h:
        a[y, x] = (*rgb(c), 255)


def shade_index(t, n, x, y, dither=0.6):
    """t in 0..1 (dark to light) to a ramp index, with ordered dithering."""
    b = BAYER4[y % 4, x % 4] - 0.5
    return int(np.clip(math.floor(t * n + b * dither), 0, n - 1))


def poly_mask(w, h, pts):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).polygon([(float(x), float(y)) for x, y in pts], fill=255)
    return np.asarray(m) > 0


def finish(a, name, line=OUTLINE):
    img = Image.fromarray(a, "RGBA")
    img = outline(img, line)
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name + ".png"))
    return img


# --------------------------------------------------------------------- pines
def pine(name, w, h, tiers, seed, snowy=True):
    rng = np.random.default_rng(seed)
    a = canvas(w, h)
    cx = w / 2.0
    trunk_h = max(5, h // 10)
    base_y = h - 1
    # trunk
    tw = max(3, w // 10)
    for y in range(base_y - trunk_h - 4, base_y + 1):
        for x in range(int(cx - tw / 2), int(cx + tw / 2) + 1):
            t = 1.0 - (x - (cx - tw / 2)) / max(1, tw)
            put(a, x, y, BARK[shade_index(0.25 + 0.6 * t, len(BARK), x, y)])
    crown_bottom = base_y - trunk_h
    crown_top = 1
    span = crown_bottom - crown_top
    for i in range(tiers):
        # tiers from the bottom up, each a little narrower and overlapping the one below
        f0 = i / tiers
        f1 = (i + 1) / tiers
        bottom = crown_bottom - span * f0 * 0.86
        top = crown_bottom - span * min(1.0, f1 * 0.86 + 0.24)
        half = (w / 2.0 - 1) * (1.0 - f0 * 0.72)
        pts = [(cx, top)]
        teeth = 5 + int(half / 4)
        for k in range(teeth + 1):
            fx = k / teeth
            x = cx + half - fx * 2 * half
            droop = 2.5 if k % 2 == 0 else -0.5
            y = bottom + droop + rng.normal(0, 0.5)
            pts.append((x, y))
        m = poly_mask(w, h, pts)
        ys, xs = np.nonzero(m)
        for y, x in zip(ys, xs):
            # light from the upper left: lighter on the left and near the top of the tier
            rel = (x - cx) / max(1.0, half)
            vy = (y - top) / max(1.0, bottom - top)
            t = 0.62 - 0.38 * rel - 0.28 * vy
            if vy > 0.82:
                t -= 0.25          # the shadow tucked under the tier's rim
            a[y, x] = (*rgb(PINE[shade_index(t, len(PINE), x, y)]), 255)
        if snowy:
            # snow lies along the tier's upper slopes, thicker on the lit side
            for x in range(w):
                col = np.nonzero(m[:, x])[0]
                if len(col) == 0:
                    continue
                y0 = col[0]
                rel = (x - cx) / max(1.0, half)
                depth = 2 if rel < 0.2 else 1
                if abs(rel) > 0.9:
                    depth = 1
                for d in range(depth):
                    y = y0 + d
                    if y < h:
                        t = 0.9 - 0.25 * max(0, rel) - 0.2 * d
                        a[y, x] = (*rgb(SNOW[shade_index(t, len(SNOW), x, y)]), 255)
            # clumps hanging from the tips of the lowest needles
            for k in range(0, teeth + 1, 2):
                x = int(round(cx + half - k / teeth * 2 * half))
                yb = int(round(bottom + 2))
                if 0 <= x < w and rng.random() < 0.6:
                    put(a, x, yb - 1, SNOW[2])
                    put(a, x, yb - 2, SNOW[3])
    return finish(a, name)


# ---------------------------------------------------------------- bare trees
def bare_tree(name, w, h, seed, snowy=True):
    rng = np.random.default_rng(seed)
    a = canvas(w, h)
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    snow_pts = []

    def branch(x, y, ang, length, width, depth):
        if depth == 0 or length < 3:
            return
        x2 = x + math.cos(ang) * length
        y2 = y + math.sin(ang) * length
        d.line([(x, y), (x2, y2)], fill=255, width=max(1, int(round(width))))
        steps = int(length)
        for s in range(steps):
            px = x + (x2 - x) * s / steps
            py = y + (y2 - y) * s / steps
            if abs(math.sin(ang)) < 0.85:
                snow_pts.append((px, py - width / 2.0 - 0.5))
        n = 2 if depth > 1 else rng.integers(1, 3)
        for _ in range(n):
            branch(x2, y2, ang + rng.normal(0, 0.55), length * rng.uniform(0.6, 0.78), width * 0.68, depth - 1)

    cx = w / 2.0
    base = h - 1
    trunk_top = base - h * 0.42
    d.polygon([(cx - 3, base), (cx + 3, base), (cx + 1.5, trunk_top), (cx - 1.5, trunk_top)], fill=255)
    for k in range(4):
        branch(cx + rng.normal(0, 0.5), trunk_top + k * 3, -math.pi / 2 + (k - 1.5) * 0.45 + rng.normal(0, 0.12),
               h * 0.26, 2.6 - k * 0.3, 5)
    m = np.asarray(img) > 0
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        left = x > 0 and not m[y, x - 1]
        t = 0.65 if left else 0.35
        t += 0.1 * (1 - y / h)
        a[y, x] = (*rgb(BARK[shade_index(t, len(BARK), x, y)]), 255)
    if snowy:
        for (px, py) in snow_pts:
            x, y = int(round(px)), int(round(py))
            if 0 <= x < w and 0 <= y < h and rng.random() < 0.55:
                if y + 1 < h and m[y + 1, x]:
                    put(a, x, y, SNOW[3] if rng.random() < 0.6 else SNOW[2])
    return finish(a, name)


# ------------------------------------------------------------- rocks, bushes
def blob_mask(w, h, cx, cy, rx, ry, rng, lumps=7, rough=0.12):
    ys, xs = np.mgrid[0:h, 0:w]
    ang = np.arctan2(ys - cy, xs - cx)
    r = np.ones_like(ang)
    for k in range(1, lumps):
        r += rng.normal(0, rough / k) * np.cos(k * ang + rng.random() * 6.28)
    dist = np.hypot((xs - cx) / rx, (ys - cy) / ry)
    return dist <= r


def rock(name, w, h, seed, snowy=True, ramp=STONE):
    rng = np.random.default_rng(seed)
    a = canvas(w, h)
    m = blob_mask(w, h, w / 2, h * 0.58, w * 0.46, h * 0.42, rng)
    m[h - 1:, :] = False
    ys, xs = np.nonzero(m)
    cy0, cx0 = ys.min(), xs.mean()
    for y, x in zip(ys, xs):
        t = 0.75 - 0.5 * (x - xs.min()) / max(1, xs.max() - xs.min()) - 0.45 * (y - cy0) / max(1, ys.max() - cy0) + 0.2
        a[y, x] = (*rgb(ramp[shade_index(t, len(ramp), x, y)]), 255)
    if snowy:
        for x in range(w):
            col = np.nonzero(m[:, x])[0]
            if len(col) == 0:
                continue
            depth = 2 + (1 if x < cx0 else 0)
            for k in range(depth):
                y = col[0] + k
                put(a, x, y, SNOW[3 - min(k, 2)])
    return finish(a, name)


def bush(name, w, h, seed, berries=False, snowy=True, ramp=LEAF):
    rng = np.random.default_rng(seed)
    a = canvas(w, h)
    m = np.zeros((h, w), bool)
    centres = []
    for _ in range(9):
        cx = rng.uniform(w * 0.22, w * 0.78)
        cy = rng.uniform(h * 0.35, h * 0.78)
        r = rng.uniform(w * 0.16, w * 0.26)
        centres.append((cx, cy, r))
        ys, xs = np.mgrid[0:h, 0:w]
        m |= np.hypot(xs - cx, (ys - cy) * 1.1) <= r
    m[h - 1:, :] = False
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        # each leaf cluster is lit on its own upper left
        best = min(centres, key=lambda c: (x - c[0]) ** 2 + (y - c[1]) ** 2)
        dx, dy = (x - best[0]) / best[2], (y - best[1]) / best[2]
        t = 0.55 - 0.35 * dx - 0.35 * dy - 0.15 * (y / h)
        a[y, x] = (*rgb(ramp[shade_index(t, len(ramp), x, y)]), 255)
    if berries:
        for _ in range(int(w * h / 40)):
            i = rng.integers(0, len(xs))
            x, y = xs[i], ys[i]
            put(a, x, y, BERRY[1])
            put(a, x - 1, y - 1, BERRY[2]) if rng.random() < 0.3 else None
    if snowy:
        for x in range(w):
            col = np.nonzero(m[:, x])[0]
            if len(col):
                put(a, x, col[0], SNOW[3])
                if rng.random() < 0.5:
                    put(a, x, col[0] + 1, SNOW[2])
    return finish(a, name)


def brambles(name, w, h, seed, snowy=True):
    rng = np.random.default_rng(seed)
    a = canvas(w, h)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    vine = ["#2a1724", "#3c2133", "#542e44", "#6e3f55"]
    for k in range(int(w * h / 22)):
        x0 = rng.uniform(1, w - 2)
        y0 = rng.uniform(h * 0.3, h - 2)
        ang = rng.uniform(-math.pi, 0)
        L = rng.uniform(5, 12)
        pts = []
        x, y = x0, y0
        for s in range(int(L)):
            pts.append((x, y))
            ang += rng.normal(0, 0.35)
            x += math.cos(ang)
            y += math.sin(ang) * 0.8
        col = rgb(vine[rng.integers(0, len(vine))])
        d.line(pts, fill=(*col, 255), width=1)
        for (px, py) in pts[::3]:   # thorns
            if rng.random() < 0.5:
                d.point((px + rng.choice([-1, 1]), py - 1), fill=(*rgb("#8a5a6a"), 255))
    arr = np.array(img)
    # tops of the tangle catch the snow
    if snowy:
        m = arr[:, :, 3] > 0
        for x in range(w):
            col = np.nonzero(m[:, x])[0]
            if len(col) and rng.random() < 0.7:
                arr[col[0], x] = (*rgb(SNOW[3]), 255)
    a[:] = arr
    return finish(a, name, "#140c14")


def log(name, w, h, seed, snowy=True):
    a = canvas(w, h)
    top, bot = h // 4, h - 2
    for y in range(top, bot + 1):
        for x in range(1, w - 3):
            t = 0.8 - 0.6 * (y - top) / max(1, bot - top)
            c = BARK[shade_index(t, len(BARK), x, y)]
            if (x * 7 + y * 3) % 9 == 0:
                c = BARK[0]
            a[y, x] = (*rgb(c), 255)
    # cut end with rings
    for y in range(top, bot + 1):
        for x in range(w - 5, w - 1):
            r = math.hypot((x - (w - 3)) * 1.4, (y - (top + bot) / 2) / 1.1)
            c = "#c79a6a" if int(r) % 2 == 0 else "#a97b52"
            a[y, x] = (*rgb(c), 255)
    if snowy:
        for x in range(1, w - 4):
            put(a, x, top - 1, SNOW[3])
            if x % 3:
                put(a, x, top - 2, SNOW[2])
    return finish(a, name)


def stump(name, w, h, snowy=True):
    a = canvas(w, h)
    for y in range(h // 3, h - 1):
        for x in range(2, w - 2):
            t = 0.75 - 0.5 * (x - 2) / max(1, w - 4)
            a[y, x] = (*rgb(BARK[shade_index(t, len(BARK), x, y)]), 255)
    cy = h // 3
    for x in range(2, w - 2):
        for y in range(cy - 2, cy + 2):
            r = math.hypot((x - w / 2) / (w / 2 - 2), (y - cy) / 2.0)
            if r <= 1.0:
                a[y, x] = (*rgb(SNOW[3] if snowy else ("#c79a6a" if int(r * 4) % 2 else "#a97b52")), 255)
    return finish(a, name)


def tuft(name, w, h, seed, ramp=DRYGRASS):
    rng = np.random.default_rng(seed)
    a = canvas(w, h)
    for k in range(7):
        x = int(rng.uniform(1, w - 1))
        L = int(rng.uniform(h * 0.4, h - 1))
        lean = rng.normal(0, 0.25)
        for s in range(L):
            put(a, int(round(x + lean * s)), h - 1 - s, ramp[min(len(ramp) - 1, 1 + s * len(ramp) // max(1, L))])
    img = Image.fromarray(a, "RGBA")
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name + ".png"))
    return img


def rose_hips(name, w, h, seed):
    rng = np.random.default_rng(seed)
    a = canvas(w, h)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for k in range(9):
        x0 = w / 2 + rng.normal(0, 1.5)
        ang = -math.pi / 2 + rng.normal(0, 0.6)
        L = rng.uniform(h * 0.5, h * 0.95)
        d.line([(x0, h - 1), (x0 + math.cos(ang) * L, h - 1 + math.sin(ang) * L)], fill=(*rgb("#4a2a2a"), 255))
    arr = np.array(img)
    m = arr[:, :, 3] > 0
    ys, xs = np.nonzero(m)
    for _ in range(10):
        i = rng.integers(0, len(xs))
        x, y = xs[i], ys[i]
        if y < h - 3:
            arr[y, x] = (*rgb(BERRY[1]), 255)
            if x + 1 < w:
                arr[y, x + 1] = (*rgb(BERRY[0]), 255)
            if y > 0:
                arr[y - 1, x] = (*rgb(BERRY[2]), 255)
    a[:] = arr
    return finish(a, name, "#1a0f14")


def main():
    pine("pine_large", 48, 84, 6, 11)
    pine("pine_med", 40, 66, 5, 12)
    pine("pine_small", 28, 46, 4, 13)
    pine("pine_large_b", 46, 80, 6, 14)
    bare_tree("bare_tree", 56, 70, 21)
    bare_tree("bare_tree_b", 50, 62, 22)
    rock("rock_big", 26, 18, 31)
    rock("rock_small", 14, 10, 32)
    rock("rock_flat", 20, 11, 33)
    bush("holly", 22, 18, 41, berries=True)
    bush("bush_snow", 20, 16, 42)
    brambles("brambles", 40, 26, 51)
    brambles("brambles_b", 40, 26, 52)
    log("log", 34, 12, 61)
    stump("stump", 14, 12)
    tuft("tuft", 9, 7, 71)
    tuft("tuft_b", 7, 6, 72)
    rose_hips("rose_hips", 20, 18, 81)
    print("props done")


if __name__ == "__main__":
    main()
