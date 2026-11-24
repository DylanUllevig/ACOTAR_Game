"""Pixel-art pieces for building rooms: wall faces, wall tops, windows, a
doormat. Drawn at the people's density (1.5 world units per art pixel, so a
16-pixel tile is 24 world units). Everything is seeded and repeatable.

    python3 tools/pixel/interior.py      # writes assets/pixel/interior/*.png
"""
import os
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from common import periodic_noise, quantize, rgb  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "pixel", "interior")


def save(img, alpha, name):
    os.makedirs(OUT, exist_ok=True)
    a = alpha if alpha is not None else np.full(img.shape[:2], 255, np.uint8)
    Image.fromarray(np.dstack([img.astype(np.uint8), a.astype(np.uint8)]), "RGBA").save(os.path.join(OUT, name + ".png"))
    print("interior", name, img.shape[1], img.shape[0])


def wood_rows(img, y0, y1, x0, x1, ramp, seed, vertical=False, board=8, gap="#3a2419", lit="#9a6a46"):
    """Planks between y0..y1 and x0..x1: boards 'board' pixels wide with dark
    gaps, a lit edge, and a soft grain."""
    rng = np.random.default_rng(seed)
    h, w = y1 - y0, x1 - x0
    n = periodic_noise(64, 64, seed, 2, cell=16)
    for y in range(y0, y1):
        for x in range(x0, x1):
            k = (x - x0) if vertical else (y - y0)
            b = k // board
            tone = (b * 7 + seed) % 3
            g = n[(y * 3) % 64, (x // 4) % 64] if vertical else n[(y // 4) % 64, (x * 3) % 64]
            v = int(np.clip(tone + (g - 0.5) * 2.2, 0, len(ramp) - 1))
            img[y, x] = rgb(ramp[v])
    for k in range(0, (w if vertical else h), board):
        if vertical:
            img[y0:y1, x0 + k] = rgb(gap)
            if x0 + k + 1 < x1:
                img[y0:y1, x0 + k + 1] = rgb(lit)
        else:
            img[y0 + k, x0:x1] = rgb(lit)
            if y0 + k + board - 1 < y1:
                img[y0 + k + board - 1, x0:x1] = rgb(gap)


def wall_cottage():
    """A stretch of the back wall, 64 wide (it repeats sideways) and 96 tall:
    a dark top beam, lime plaster between timber posts, a rail, and a plank
    wainscot down to a shadowed skirting."""
    W, H = 64, 96
    img = np.zeros((H, W, 3), np.uint8)
    # plaster, softly mottled, with a few hairline cracks
    n = periodic_noise(W, W, 31, 3, cell=16)
    pl = np.vstack([n, n])[:H]
    img[:, :] = quantize(0.25 + pl * 0.6, ["#b9a284", "#c4ae90", "#cfba9d", "#d8c6ab"], 0.3)
    rng = np.random.default_rng(5)
    for _ in range(3):
        x, y = int(rng.integers(8, W - 8)), int(rng.integers(14, 60))
        for k in range(int(rng.integers(4, 9))):
            img[y + k, (x + (k // 3) * (1 if k % 2 else -1)) % W] = rgb("#a48e72")
    # top beam
    wood_rows(img, 0, 10, 0, W, ["#4b3022", "#573827", "#62402c"], 3, board=10, gap="#2f1d14", lit="#7a5238")
    img[10, :] = rgb("#2f1d14")
    img[11, :] = rgb("#9c8466")                 # shadow line under the beam
    # timber post with its own shading
    for y in range(12, 72):
        img[y, 0] = rgb("#2f1d14")
        img[y, 1] = rgb("#7a5238")
        img[y, 2:6] = rgb("#62402c")
        img[y, 6] = rgb("#4b3022")
        img[y, 7] = rgb("#9c8466")
    # a brace from the post up to the beam
    for k in range(14):
        x = 8 + k
        y = 26 - k
        img[y, x] = rgb("#62402c")
        img[y + 1, x] = rgb("#4b3022")
        img[y - 1, x] = rgb("#7a5238")
    # rail and wainscot
    img[72, :] = rgb("#9a6a46")
    img[73:75, :] = rgb("#6e4a33")
    img[75, :] = rgb("#3a2419")
    wood_rows(img, 76, 92, 0, W, ["#5f3f2c", "#6b4630", "#775037"], 7, vertical=True, board=8)
    img[92:94, :] = rgb("#3a2419")              # skirting
    img[94:96, :] = rgb("#241510")
    save(img, None, "wall_cottage")


def wall_top():
    """The top of a wall seen from above: dark timber with a lit edge, 16 x 16,
    repeats both ways."""
    img = np.zeros((16, 16, 3), np.uint8)
    n = periodic_noise(16, 16, 12, 2, cell=8)
    img[:, :] = quantize(n, ["#2d1c14", "#36231a", "#3f2a1f"], 0.3)
    img[:, 0] = rgb("#1c110c")
    img[:, 15] = rgb("#1c110c")
    img[0, :] = rgb("#5a3a28")
    save(img, None, "wall_top")


def window_night():
    """A small-paned cottage window in the back wall, shutters open on a
    moonlit night: 30 x 34."""
    W, H = 30, 34
    img = np.zeros((H, W, 3), np.uint8)
    a = np.zeros((H, W), np.uint8)
    def rect(x0, y0, x1, y1, c):
        img[y0:y1, x0:x1] = rgb(c)
        a[y0:y1, x0:x1] = 255
    # shutters
    for sx in (0, 24):
        rect(sx, 3, sx + 6, 29, "#6b4630")
        for y in range(3, 29, 5):
            img[y, sx:sx + 6] = rgb("#4b3022")
        img[3:29, sx] = rgb("#3a2419")
        img[3:29, sx + 5] = rgb("#3a2419")
        img[8, sx + 1:sx + 5] = rgb("#2a2a2e")    # hinges
        img[23, sx + 1:sx + 5] = rgb("#2a2a2e")
    # frame
    rect(6, 0, 24, 31, "#4b3022")
    img[0, 6:24] = rgb("#7a5238")
    # glass: night sky, darker at the top, a moon glint and a little frost
    for y in range(2, 29):
        for x in range(8, 22):
            t = (y - 2) / 27.0
            c = ["#1d2748", "#24305a", "#2c3a6a", "#35467a"][min(3, int(t * 4))]
            img[y, x] = rgb(c)
    img[5:7, 17:19] = rgb("#dfe8ff")
    img[4, 17:19] = rgb("#9fb3e6")
    for x in range(8, 22):
        if x % 3 == 0:
            img[27, x] = rgb("#c9d6f2")
        img[28, x] = rgb("#e4ecfb")
    # mullions
    img[2:29, 14:16] = rgb("#4b3022")
    img[15, 8:22] = rgb("#4b3022")
    # sill
    rect(4, 29, 26, 32, "#8a5f40")
    img[29, 4:26] = rgb("#a8774f")
    img[31, 4:26] = rgb("#3a2419")
    a[32:34, 5:25] = 0
    save(img, a, "window_night")


def doormat():
    W, H = 30, 12
    img = np.zeros((H, W, 3), np.uint8)
    a = np.full((H, W), 255, np.uint8)
    for y in range(H):
        for x in range(W):
            c = "#9a7a44" if (x // 2 + y // 2) % 2 == 0 else "#86683a"
            if y in (0, H - 1) or x in (0, W - 1):
                c = "#5e4526"
            elif y in (2, H - 3):
                c = "#7a2f2a"
            img[y, x] = rgb(c)
    for x in (0, W - 1):
        a[0, x] = a[H - 1, x] = 0
    save(img, a, "doormat")


def ember():
    img = np.zeros((1, 1, 3), np.uint8)
    img[0, 0] = rgb("#ffd27a")
    save(img, None, "ember")



# ------------------------------------------------------------- the manor
def _damask(img, y0, y1, W, base, lattice, motif, accent):
    """Wallpaper between rows y0 and y1: a diamond lattice with a small
    flower in every diamond."""
    img[y0:y1, :] = rgb(base)
    for y in range(y0, y1):
        for x in range(W):
            u, v = x % 16, (y - y0) % 16
            if u == v or u == 15 - v:
                img[y, x] = rgb(lattice)
    for cy in range(y0 + 8, y1 - 2, 16):
        for cx in range(0, W, 16):
            for dx, dy in ((0, -2), (-1, -1), (1, -1), (-2, 0), (2, 0), (0, 0), (-1, 1), (1, 1), (0, 2)):
                yy, xx = cy + dy, (cx + dx) % W
                if y0 <= yy < y1:
                    img[yy, xx] = rgb(motif if (dx, dy) != (0, 0) else accent)


def _manor_wall(name, base, lattice, motif, accent):
    """A stretch of a manor room's back wall, 64 wide (it repeats) and 112
    tall: crown moulding with a gilt line, damask paper, a chair rail, cream
    wainscot panels and a skirting board."""
    W, H = 64, 112
    img = np.zeros((H, W, 3), np.uint8)
    img[0, :] = rgb("#7d6337")
    img[1:4, :] = rgb("#efe4c8")
    img[1, :] = rgb("#fbf5e6")
    img[4, :] = rgb("#d4a94a")
    img[5, :] = rgb("#a8884f")
    for x in range(0, W, 4):                    # dentils under the moulding
        img[6, x:x + 2] = rgb("#e2d5b5")
        img[6, x + 2:x + 4] = rgb("#b49a6a")
    _damask(img, 7, 63, W, base, lattice, motif, accent)
    img[7, :] = np.minimum(img[7, :].astype(int) - 30, 255).clip(0, 255).astype(np.uint8)  # shadow under the moulding
    img[63, :] = rgb("#fbf5e6")
    img[64, :] = rgb("#f1e6cc")
    img[65, :] = rgb("#d4a94a")
    img[66, :] = rgb("#c9b48a")
    img[67, :] = rgb("#8f7a55")
    img[68:105, :] = rgb("#e6dbc2")
    for px0 in range(0, W, 32):                  # raised panels
        x0, x1, y0, y1 = px0 + 3, px0 + 29, 71, 101
        img[y0:y1, x0:x1] = rgb("#ece2cb")
        img[y0, x0:x1] = rgb("#f9f2e1")
        img[y0:y1, x0] = rgb("#f9f2e1")
        img[y1 - 1, x0:x1] = rgb("#b9a987")
        img[y0:y1, x1 - 1] = rgb("#b9a987")
        img[y0 + 3, x0 + 3:x1 - 3] = rgb("#d9cdb1")
        img[y1 - 4, x0 + 3:x1 - 3] = rgb("#f5edd9")
    img[105, :] = rgb("#f3ead4")
    img[106:109, :] = rgb("#cdbf9f")
    img[109, :] = rgb("#a89878")
    img[110:112, :] = rgb("#6e5f45")
    save(img, None, name)


def wall_manor():
    _manor_wall("wall_manor", "#4d7a56", "#5d8c64", "#c9b27a", "#e8d39a")


def wall_manor_rose():
    _manor_wall("wall_manor_rose", "#b07480", "#c08690", "#f1d9c4", "#fff1dc")


def wall_manor_study():
    _manor_wall("wall_manor_study", "#2f4a40", "#3a594c", "#a88a4a", "#d4b064")


def wall_top_manor():
    """The top of a manor wall seen from above: cream stone with a gilt edge,
    16 x 16, repeats both ways."""
    img = np.zeros((16, 16, 3), np.uint8)
    n = periodic_noise(16, 16, 14, 2, cell=8)
    img[:, :] = quantize(n, ["#cbbd9d", "#d6c9aa", "#e0d4b7"], 0.3)
    img[:, 0] = rgb("#7d6a4a")
    img[:, 15] = rgb("#7d6a4a")
    img[0, :] = rgb("#f3ead4")
    img[1, :] = rgb("#d4a94a")
    save(img, None, "wall_top_manor")


def _arched_window(name, glass):
    """A tall arched window between green velvet curtains, 44 x 60. glass(x,
    y, t) gives the colour of the view at a pane pixel (t: 0 top .. 1 bottom)."""
    W, H = 44, 60
    img = np.zeros((H, W, 3), np.uint8)
    a = np.zeros((H, W), np.uint8)
    cx = W / 2.0
    # frame: an arch of cream stone
    for y in range(2, 54):
        for x in range(8, 36):
            r = 14.0
            if y < 16 and (x + 0.5 - cx) ** 2 + (y + 0.5 - 16) ** 2 > r * r:
                continue
            img[y, x] = rgb("#efe4c8")
            a[y, x] = 255
    for y in range(5, 52):
        for x in range(11, 33):
            r = 11.0
            if y < 16 and (x + 0.5 - cx) ** 2 + (y + 0.5 - 16) ** 2 > r * r:
                continue
            img[y, x] = glass(x, y, (y - 5) / 47.0)
    img[4:52, 21:23] = rgb("#f4ead2")             # mullions, gilt-edged
    img[30, 11:33] = rgb("#f4ead2")
    img[31, 11:33] = rgb("#d4a94a")
    img[2:5, 20:24] = rgb("#d4a94a")              # keystone
    # sill
    img[52:55, 6:38] = rgb("#e2d5b5")
    img[52, 6:38] = rgb("#fbf5e6")
    img[54, 6:38] = rgb("#9c8664")
    a[52:55, 6:38] = 255
    # curtains, gathered with a gold tie
    for side in (0, 1):
        x0 = 0 if side == 0 else W - 9
        for y in range(0, 58):
            for k in range(9):
                x = x0 + k
                fold = (k + (y // 6) % 2) % 3
                img[y, x] = rgb(["#2f5a3e", "#3f6f4d", "#4f805a"][fold])
                a[y, x] = 255
        img[0:2, x0:x0 + 9] = rgb("#d4a94a")
        img[34:36, x0:x0 + 9] = rgb("#d4a94a")
        img[56:58, x0:x0 + 9] = rgb("#26492f")
    save(img, a, name)


def window_day():
    def glass(x, y, t):
        if t > 0.78:
            return rgb("#6fae57" if (x + y) % 3 else "#f4b6c8")     # treetops and blossom
        if t > 0.68:
            return rgb("#8cc46a")
        c = ["#9fd2ec", "#b4ddf1", "#c8e7f5", "#dcf0f8"][min(3, int(t * 5))]
        if 0.3 < t < 0.42 and (x + int(t * 40)) % 9 < 5:
            c = "#f4fafd"                                       # a wisp of cloud
        return rgb(c)
    _arched_window("window_day", glass)


def window_manor_night():
    def glass(x, y, t):
        c = ["#1b2547", "#222e58", "#2a3868", "#334379"][min(3, int(t * 4))]
        if (x * 13 + y * 7) % 37 == 0:
            c = "#e9efff"
        if t > 0.8:
            c = "#1b2b2a"
        return rgb(c)
    _arched_window("window_manor_night", glass)


def _painting(name, W, H, seed, sky, hills, accent):
    """A small landscape in a gilt frame."""
    rng = np.random.default_rng(seed)
    img = np.zeros((H, W, 3), np.uint8)
    for y in range(H):
        t = y / (H - 1)
        img[y, :] = rgb(sky[min(len(sky) - 1, int(t * len(sky)))])
    base = int(H * 0.55)
    for layer, col in enumerate(hills):
        ph = rng.random() * 6
        for x in range(W):
            top = base + layer * 4 + int(3 * np.sin(x * (0.18 + layer * 0.07) + ph))
            img[max(0, top):, x] = rgb(col)
    for _ in range(int(rng.integers(2, 5))):      # trees or blossom dabs
        x = int(rng.integers(4, W - 4))
        y = base + int(rng.integers(2, 8))
        for dy in range(-3, 1):
            for dx in range(-1, 2):
                if 0 <= y + dy < H:
                    img[y + dy, x + dx] = rgb(accent)
        if y + 1 < H:
            img[y + 1, x] = rgb("#4b3424")
    a = np.full((H, W), 255, np.uint8)
    img[0, :] = img[-1, :] = rgb("#7d5e2a")
    img[:, 0] = img[:, -1] = rgb("#7d5e2a")
    img[1, 1:-1] = img[-2, 1:-1] = rgb("#e8c35c")
    img[1:-1, 1] = img[1:-1, -2] = rgb("#e8c35c")
    img[2, 2:-2] = img[-3, 2:-2] = rgb("#b48a3a")
    img[2:-2, 2] = img[2:-2, -3] = rgb("#b48a3a")
    img[3, 3:-3] = rgb("#3a2a1a")                   # the canvas edge in shadow
    save(img, a, name)


def paintings():
    _painting("painting_0", 36, 26, 1, ["#f4c9a7", "#f6dcbf", "#fbe9d4"], ["#8fbf6a", "#6ea455", "#4f8a45"], "#f2a7c0")
    _painting("painting_1", 30, 38, 2, ["#9cc4e4", "#bcd8ee", "#dceaf4"], ["#e8eef6", "#cdd8e6", "#aebdd2"], "#3b5a46")
    _painting("painting_2", 44, 28, 3, ["#2a2f5c", "#433f73", "#6b5a8a", "#e0a37a"], ["#2b3354", "#202842", "#171d33"], "#d8d2f0")
    _painting("painting_3", 32, 26, 4, ["#f7d98a", "#f3c47a", "#e9a86b"], ["#c9884a", "#a96d3c", "#83522f"], "#d14b3a")
    _painting("painting_4", 26, 34, 5, ["#d3e9f0", "#e6f2f4"], ["#7fb0c8", "#5d93b0", "#3f7593"], "#f6f2e6")
    _painting("painting_5", 40, 30, 6, ["#bfe3c9", "#d8efd9", "#eef8ea"], ["#6aa55a", "#4f8a45", "#3a6e38"], "#f6e27a")


def rug_manor():
    """A big flat rug: deep green field, rose medallion, gilt border, 72 x 44."""
    W, H = 72, 44
    img = np.zeros((H, W, 3), np.uint8)
    img[:, :] = rgb("#3d6b4f")
    cx, cy = W / 2.0, H / 2.0
    for y in range(H):
        for x in range(W):
            d = abs(x + 0.5 - cx) / 26.0 + abs(y + 0.5 - cy) / 15.0
            if d < 1.0:
                img[y, x] = rgb("#b5606f" if d > 0.55 else ("#e7b6a7" if d > 0.3 else "#f4dcc4"))
            if 0.96 < d < 1.04:
                img[y, x] = rgb("#e1bd62")
    img[0:2, :] = img[-2:, :] = rgb("#d4a94a")
    img[:, 0:2] = img[:, -2:] = rgb("#d4a94a")
    img[3, 3:-3] = img[-4, 3:-3] = rgb("#e1bd62")
    img[3:-3, 3] = img[3:-3, -4] = rgb("#e1bd62")
    for x in range(6, W - 6, 6):                  # a little border pattern
        img[5, x:x + 2] = img[-6, x:x + 2] = rgb("#b5606f")
    a = np.full((H, W), 255, np.uint8)
    for x in range(0, W, 3):                      # fringe at the short ends
        a[0, x] = a[-1, x] = 0
    save(img, a, "rug_manor")


if __name__ == "__main__":
    wall_cottage()
    wall_top()
    window_night()
    doormat()
    ember()
    wall_manor()
    wall_manor_rose()
    wall_manor_study()
    wall_top_manor()
    window_day()
    window_manor_night()
    paintings()
    rug_manor()
