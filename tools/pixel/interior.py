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


if __name__ == "__main__":
    wall_cottage()
    wall_top()
    window_night()
    doormat()
    ember()
