#!/usr/bin/env python3
"""Draws the manor's large carpets as pixel art, one per room and size.

    python3 tools/pixel/make_carpets.py

Writes assets/pixel/interior/carpet_<name>.png. Each is drawn at art-pixel
resolution (the game shows one art pixel as Art.PX world units), in the
palette of the small manor rug: a fringe on the short ends, a dark edge, a
patterned gold band, a fine inner line, a field with a faint diamond lattice,
corner motifs and, on the wider carpets, a stepped medallion in the middle.
Runners (long and narrow) repeat a small medallion along their length.
"""
import os
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "pixel", "interior")

# name: (width, height in art pixels, palette)
PALETTES = {
    "green": {"field": (58, 104, 76), "lattice": (50, 92, 67), "edge": (38, 52, 40), "band": (214, 164, 64),
              "band_dot": (176, 84, 100), "line": (226, 196, 120), "medal": (176, 84, 100), "medal_in": (226, 156, 152),
              "medal_core": (246, 222, 196), "fringe": (236, 222, 190)},
    "rose": {"field": (150, 66, 82), "lattice": (136, 58, 74), "edge": (70, 34, 42), "band": (222, 196, 150),
             "band_dot": (76, 112, 84), "line": (232, 210, 170), "medal": (70, 104, 82), "medal_in": (214, 164, 64),
             "medal_core": (246, 226, 190), "fringe": (240, 228, 200)},
    "wine": {"field": (110, 40, 52), "lattice": (98, 34, 46), "edge": (52, 22, 28), "band": (206, 156, 60),
             "band_dot": (62, 92, 70), "line": (220, 186, 110), "medal": (206, 156, 60), "medal_in": (150, 66, 82),
             "medal_core": (240, 214, 168), "fringe": (232, 216, 182)},
    "teal": {"field": (52, 96, 100), "lattice": (46, 86, 90), "edge": (30, 46, 50), "band": (214, 170, 80),
             "band_dot": (164, 80, 92), "line": (222, 200, 140), "medal": (164, 80, 92), "medal_in": (222, 170, 150),
             "medal_core": (244, 224, 196), "fringe": (236, 226, 200)},
    "cream": {"field": (214, 196, 160), "lattice": (200, 182, 146), "edge": (120, 96, 70), "band": (92, 120, 150),
              "band_dot": (200, 120, 110), "line": (240, 228, 200), "medal": (92, 120, 150), "medal_in": (200, 140, 120),
              "medal_core": (244, 234, 210), "fringe": (244, 236, 216)},
}

CARPETS = {
    "library": (292, 152, "green"),     # the reading corner
    "desk": (200, 128, "teal"),         # under her writing desk
    "bedroom": (280, 136, "rose"),
    "dining": (372, 140, "wine"),       # under the long table
    "gallery": (920, 60, "teal"),       # a runner the length of the gallery
    "landing": (820, 56, "green"),      # a runner along the upper hall
    "studio": (200, 104, "cream"),
}


def draw(w, h, pal):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    fringe = 3
    runner = w > 4 * h
    # the woven body, inside the fringe
    x0, x1 = fringe, w - fringe - 1
    for y in range(h):
        for x in range(x0, x1 + 1):
            px[x, y] = pal["field"] + (255,)
    # fringe: threads on the short ends, every other pixel, uneven lengths
    for y in range(1, h - 1, 2):
        n = 3 if (y // 2) % 3 else 2
        for i in range(n):
            px[x0 - 1 - i, y] = pal["fringe"] + (255,)
            px[x1 + 1 + i, y] = pal["fringe"] + (255,)

    def rect(ax, ay, bx, by, c):
        for yy in range(ay, by + 1):
            for xx in range(ax, bx + 1):
                if 0 <= xx < w and 0 <= yy < h:
                    px[xx, yy] = c + (255,)

    def frame(ax, ay, bx, by, t, c):
        rect(ax, ay, bx, ay + t - 1, c)
        rect(ax, by - t + 1, bx, by, c)
        rect(ax, ay, ax + t - 1, by, c)
        rect(bx - t + 1, ay, bx, by, c)

    edge = 1
    band = 3 if runner else 5
    frame(x0, 0, x1, h - 1, edge, pal["edge"])
    frame(x0 + edge, edge, x1 - edge, h - 1 - edge, band, pal["band"])
    # dots along the band
    step = 4
    for x in range(x0 + edge + 2, x1 - edge - 1, step):
        for y in (edge + band // 2, h - 1 - edge - band // 2):
            px[x, y] = pal["band_dot"] + (255,)
    for y in range(edge + 2, h - edge - 2, step):
        for x in (x0 + edge + band // 2, x1 - edge - band // 2):
            px[x, y] = pal["band_dot"] + (255,)
    inner = edge + band
    frame(x0 + inner, inner, x1 - inner, h - 1 - inner, 1, pal["line"])
    fx0, fy0, fx1, fy1 = x0 + inner + 1, inner + 1, x1 - inner - 1, h - 2 - inner
    # a faint diamond lattice in the field
    for y in range(fy0, fy1 + 1):
        for x in range(fx0, fx1 + 1):
            if (x - fx0 + y - fy0) % 10 == 0 or (x - fx0 - (y - fy0)) % 10 == 0:
                px[x, y] = pal["lattice"] + (255,)

    def diamond(cx, cy, a, b, rings):
        # filled stepped diamond with concentric rings of colour
        for y in range(cy - b, cy + b + 1):
            for x in range(cx - a, cx + a + 1):
                d = abs(x - cx) / max(a, 1) + abs(y - cy) / max(b, 1)
                if d <= 1.0:
                    k = min(int((1.0 - d) * len(rings) * 1.25), len(rings) - 1)
                    if fx0 <= x <= fx1 and fy0 <= y <= fy1:
                        px[x, y] = rings[k] + (255,)
        # gold outline
        for y in range(cy - b - 1, cy + b + 2):
            for x in range(cx - a - 1, cx + a + 2):
                d = abs(x - cx) / max(a + 1, 1) + abs(y - cy) / max(b + 1, 1)
                if 0.86 < d <= 1.0 and fx0 <= x <= fx1 and fy0 <= y <= fy1:
                    if px[x, y][:3] in (pal["field"], pal["lattice"]):
                        px[x, y] = pal["line"] + (255,)

    rings = [pal["medal"], pal["medal_in"], pal["medal_core"]]
    fh = fy1 - fy0
    if runner:
        # small medallions spaced along the runner
        a, b = int(fh * 0.7), int(fh * 0.36)
        n = max(2, (fx1 - fx0) // (a * 4))
        for i in range(n):
            cx = fx0 + int((i + 0.5) * (fx1 - fx0) / n)
            diamond(cx, (fy0 + fy1) // 2, a, b, rings)
    else:
        diamond((fx0 + fx1) // 2, (fy0 + fy1) // 2, int((fx1 - fx0) * 0.24), int(fh * 0.34), rings)
        # quarter motifs in the corners
        q = max(5, fh // 6)
        for cx, cy in ((fx0, fy0), (fx1, fy0), (fx0, fy1), (fx1, fy1)):
            diamond(cx, cy, q, int(q * 0.8), [pal["medal"], pal["medal_in"]])
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (w, h, p) in CARPETS.items():
        img = draw(w, h, PALETTES[p])
        path = os.path.join(OUT, "carpet_%s.png" % name)
        img.save(path)
        print("wrote", os.path.relpath(path), img.size)


if __name__ == "__main__":
    main()
