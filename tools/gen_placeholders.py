#!/usr/bin/env python3
"""Generate labeled placeholder art (with normal maps) for the ACOTAR slice.

Every image produced here is a stand-in. Each one carries the id of the asset
in data/assets/manifest.json that will replace it, so swapping in real art is a
file drop: keep the same path and size, regenerate the normal map, done.

Usage:  python3 tools/gen_placeholders.py            (writes into assets/placeholder)
Needs:  Pillow, numpy
"""
import zlib
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "placeholder")
FONT_SERIF = os.path.join(ROOT, "assets", "fonts", "CormorantGaramond.ttf")
FONT_CAPS = os.path.join(ROOT, "assets", "fonts", "Cinzel.ttf")
RNG = np.random.default_rng(1600)


def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


# ---------------------------------------------------------------- noise utils
def value_noise(w, h, scale, octaves=4, seed=0, tile=True):
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        cells = max(2, int(scale * (2 ** o)))
        grid = rng.random((cells, cells)).astype(np.float32)
        if tile:
            grid = np.pad(grid, ((0, 1), (0, 1)), mode="wrap")
        else:
            grid = np.pad(grid, ((0, 1), (0, 1)), mode="edge")
        ys = np.linspace(0, cells, h, endpoint=False)
        xs = np.linspace(0, cells, w, endpoint=False)
        y0 = ys.astype(int)
        x0 = xs.astype(int)
        fy = (ys - y0)[:, None]
        fx = (xs - x0)[None, :]
        fy = fy * fy * (3 - 2 * fy)
        fx = fx * fx * (3 - 2 * fx)
        a = grid[y0][:, x0]
        b = grid[y0][:, x0 + 1]
        c = grid[y0 + 1][:, x0]
        d = grid[y0 + 1][:, x0 + 1]
        layer = (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy
        out += layer * amp
        total += amp
        amp *= 0.5
    return out / total


def normal_from_height(height, strength=4.0, wrap=False):
    """height: float array 0..1. Returns RGB uint8 normal map (OpenGL / Godot convention, green up)."""
    if wrap:
        dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 0.5
        dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 0.5
    else:
        dy, dx = np.gradient(height)
    nx = -dx * strength
    ny = dy * strength  # image y goes down; green = up
    nz = np.ones_like(height)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / ln, ny / ln, nz / ln], -1)
    return ((n * 0.5 + 0.5) * 255).clip(0, 255).astype(np.uint8)


def save_with_normal(img: Image.Image, name: str, strength=3.0, blur=2.0, height=None, wrap=False):
    os.makedirs(os.path.dirname(os.path.join(OUT, name)), exist_ok=True)
    img.save(os.path.join(OUT, name + ".png"))
    if height is None:
        rgba = np.asarray(img.convert("RGBA")).astype(np.float32) / 255.0
        lum = rgba[..., :3].mean(-1)
        alpha = rgba[..., 3]
        h_img = Image.fromarray((np.clip(alpha * 0.7 + lum * 0.3 * alpha, 0, 1) * 255).astype(np.uint8))
        h_img = h_img.filter(ImageFilter.GaussianBlur(blur))
        height = np.asarray(h_img).astype(np.float32) / 255.0
    nmap = normal_from_height(height, strength, wrap)
    alpha = np.asarray(img.convert("RGBA"))[..., 3:4]
    Image.fromarray(np.concatenate([nmap, alpha], -1), "RGBA").save(os.path.join(OUT, name + "_n.png"))


def stamp_label(img, text, color=(255, 255, 255, 150), size=14):
    d = ImageDraw.Draw(img)
    f = font(FONT_CAPS, size)
    d.text((6, img.height - size - 8), text, fill=color, font=f)


def tint(a, rgb):
    return np.stack([a * rgb[0], a * rgb[1], a * rgb[2]], -1)


# ------------------------------------------------------------------- terrain
def ground_snow():
    w = h = 512
    n = value_noise(w, h, 4, 5, seed=11)
    n2 = value_noise(w, h, 16, 3, seed=12)
    height = n * 0.7 + n2 * 0.3
    base = np.array([226, 232, 244], np.float32)
    shade = np.array([170, 184, 210], np.float32)
    col = base[None, None] * height[..., None] + shade[None, None] * (1 - height[..., None])
    sparkle = (RNG.random((h, w)) > 0.997)[..., None] * 40
    col = np.clip(col + sparkle, 0, 255).astype(np.uint8)
    img = Image.fromarray(col, "RGB").convert("RGBA")
    save_with_normal(img, "terrain/snow", strength=6, height=height, wrap=True)


def ground_mud_snow():
    # trampled slush: low contrast, fine-grained so the 512 px repeat does not read
    w = h = 512
    n = value_noise(w, h, 8, 5, seed=21)
    fine = value_noise(w, h, 48, 2, seed=23)
    ruts = value_noise(w, h, 3, 2, seed=22)
    snow_mask = np.clip((n - 0.4) * 1.6 + (fine - 0.5) * 0.3, 0, 1)
    mud = np.array([124, 114, 108], np.float32)
    snow = np.array([192, 198, 210], np.float32)
    col = mud * (1 - snow_mask[..., None]) + snow * snow_mask[..., None]
    col *= (0.9 + 0.1 * ruts[..., None]) * (0.94 + 0.12 * fine[..., None])
    img = Image.fromarray(col.clip(0, 255).astype(np.uint8), "RGB").filter(ImageFilter.GaussianBlur(1.2)).convert("RGBA")
    save_with_normal(img, "terrain/mud_snow", strength=4, height=n * 0.5 + fine * 0.2 + ruts * 0.3, wrap=True)


def floor_planks():
    w = h = 256
    img = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(img)
    grain = value_noise(w, h, 2, 4, seed=31)
    arr = np.zeros((h, w, 3), np.float32)
    plank_h = 32
    height = np.zeros((h, w), np.float32)
    for i in range(h // plank_h):
        shade = 0.75 + RNG.random() * 0.25
        y0 = i * plank_h
        base = np.array([96, 66, 44]) * shade
        arr[y0:y0 + plank_h] = base
        height[y0:y0 + plank_h] = 0.8
        height[y0:y0 + 2] = 0.2
    arr *= (0.85 + 0.3 * grain[..., None])
    img = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGB").convert("RGBA")
    save_with_normal(img, "terrain/planks", strength=5, height=height * 0.7 + grain * 0.3, wrap=True)


def cobbles():
    # stones are Voronoi cells; the grout is where the two nearest seeds are
    # almost equidistant (F2 - F1 small). Frost settles in the grout.
    w = h = 256
    yy, xx = np.mgrid[0:h, 0:w]
    pts = RNG.random((60, 2)) * w
    f1 = np.full((h, w), 1e9)
    f2 = np.full((h, w), 1e9)
    for p in pts:
        for ox in (-w, 0, w):
            for oy in (-h, 0, h):
                dd = np.sqrt((xx - p[0] - ox) ** 2 + (yy - p[1] - oy) ** 2)
                f2 = np.where(dd < f1, f1, np.minimum(f2, dd))
                f1 = np.minimum(f1, dd)
    edge = np.clip((f2 - f1) / 6.0, 0, 1)
    dome = 1 - np.clip(f1 / 22.0, 0, 1) * 0.35
    height = edge * dome
    n = value_noise(w, h, 8, 3, seed=41)
    stone = tint(0.5 + 0.25 * height + 0.15 * (n - 0.5), (150, 146, 144))
    frost = np.clip((1 - edge) * 1.2 + (n - 0.6) * 1.5, 0, 1)[..., None] * 0.8
    col = stone * (1 - frost) + np.array([200, 206, 218]) * frost
    img = Image.fromarray(col.clip(0, 255).astype(np.uint8), "RGB").convert("RGBA")
    save_with_normal(img, "terrain/cobbles", strength=5, height=height, wrap=True)


# -------------------------------------------------------------------- props
def pine(name, w=220, h=340, snowy=True, seed=0):
    rng = np.random.default_rng(seed)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = w // 2
    d.rectangle([cx - 9, h - 70, cx + 9, h - 10], fill=(58, 40, 32, 255))
    tiers = 6
    for i in range(tiers):
        t = i / (tiers - 1)
        y_top = int(20 + t * (h - 130))
        half = int(25 + t * (w * 0.42))
        y_bot = y_top + int(70 + t * 25)
        g = int(46 + rng.integers(-6, 6))
        d.polygon([(cx, y_top), (cx - half, y_bot), (cx + half, y_bot)], fill=(26, g, 48, 255))
        if snowy:
            d.polygon([(cx, y_top + 2), (cx - half * 0.7, y_top + (y_bot - y_top) * 0.7),
                       (cx - half * 0.2, y_top + (y_bot - y_top) * 0.55), (cx + half * 0.5, y_top + (y_bot - y_top) * 0.75),
                       (cx + half * 0.15, y_top + (y_bot - y_top) * 0.35)], fill=(228, 236, 248, 255))
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    save_with_normal(img, name, strength=4)


def bare_tree(name, seed=3):
    w, h = 260, 340
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(seed)

    def branch(x, y, ang, length, width, depth):
        if depth == 0 or length < 6:
            return
        x2 = x + math.cos(ang) * length
        y2 = y - math.sin(ang) * length
        d.line([(x, y), (x2, y2)], fill=(52, 40, 36, 255), width=max(1, int(width)))
        if depth < 3 and rng.random() < 0.5:
            d.line([(x, y - 1), (x2, y2 - 1)], fill=(220, 228, 240, 255), width=max(1, int(width * 0.35)))
        for _ in range(2):
            branch(x2, y2, ang + rng.uniform(-0.7, 0.7), length * rng.uniform(0.6, 0.8), width * 0.65, depth - 1)

    branch(w / 2, h - 10, math.pi / 2, 90, 16, 7)
    save_with_normal(img, name, strength=3, blur=1.2)


def bramble():
    w, h = 200, 120
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(5)
    for _ in range(140):
        x, y = rng.uniform(20, w - 20), rng.uniform(30, h - 10)
        a = rng.uniform(0, math.tau)
        L = rng.uniform(10, 34)
        d.line([(x, y), (x + math.cos(a) * L, y + math.sin(a) * L)], fill=(70, 48, 50, 255), width=2)
    for _ in range(50):
        x, y = rng.uniform(20, w - 20), rng.uniform(20, 60)
        d.ellipse([x - 8, y - 4, x + 8, y + 4], fill=(232, 238, 248, 255))
    save_with_normal(img, "props/bramble", strength=3, blur=1)


def rock(name, seed):
    w, h = 140, 100
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    r = ((xx - w / 2) / (w * 0.45)) ** 2 + ((yy - h * 0.6) / (h * 0.42)) ** 2
    n = value_noise(w, h, 5, 3, seed=seed, tile=False)
    mask = (r + (n - 0.5) * 0.5) < 1
    height = np.clip(1 - r, 0, 1) * mask
    col = tint(0.35 + 0.4 * n, (150, 150, 160))
    snow = (yy < h * 0.5) & (n > 0.45)
    col = np.where(snow[..., None], np.array([226, 232, 244]), col)
    a = (mask * 255).astype(np.uint8)
    img = Image.fromarray(np.concatenate([col.clip(0, 255).astype(np.uint8), a[..., None]], -1), "RGBA")
    save_with_normal(img, name, strength=6, height=height)


def building(name, w, h, wall_rgb, roof_rgb, label, door=True, windows=2, snowy_roof=True, painted=False):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    roof_h = int(h * 0.45)
    # walls (stone)
    d.rectangle([8, roof_h - 10, w - 8, h - 4], fill=wall_rgb + (255,))
    n = value_noise(w, h, 10, 2, seed=w + h, tile=False)
    for yy in range(roof_h, h - 6, 14):
        off = 0 if (yy // 14) % 2 else 12
        for xx in range(10 + off, w - 10, 26):
            c = tuple(int(v * (0.8 + 0.3 * n[yy, min(xx, w - 1)])) for v in wall_rgb)
            d.rectangle([xx, yy, xx + 22, yy + 11], outline=(0, 0, 0, 60), fill=c + (255,))
    # roof
    d.polygon([(0, roof_h), (w // 2, 6), (w, roof_h)], fill=roof_rgb + (255,))
    if snowy_roof:
        d.polygon([(10, roof_h - 8), (w // 2, 10), (w - 10, roof_h - 8), (w - 30, roof_h - 18), (w // 2, 26), (30, roof_h - 18)],
                  fill=(230, 236, 246, 255))
    if door:
        d.rectangle([w // 2 - 18, h - 58, w // 2 + 18, h - 4], fill=(62, 42, 30, 255))
        if painted:  # Feyre's painted vines around the threshold (ch2)
            for i in range(9):
                y = h - 60 + i * 6
                d.ellipse([w // 2 - 26, y, w // 2 - 20, y + 5], fill=(170, 60, 60, 255) if i % 2 else (200, 180, 60, 255))
                d.ellipse([w // 2 + 20, y, w // 2 + 26, y + 5], fill=(60, 90, 170, 255) if i % 2 else (170, 60, 60, 255))
    for i in range(windows):
        x = int(w * (0.2 if i == 0 else 0.68))
        d.rectangle([x, roof_h + 14, x + 30, roof_h + 40], fill=(255, 196, 110, 255))  # emissive-ish window
        d.line([x + 15, roof_h + 14, x + 15, roof_h + 40], fill=(40, 30, 20, 255), width=2)
    stamp_label(img, label, size=12)
    save_with_normal(img, name, strength=3, blur=1.5)


def fountain():
    w, h = 220, 160
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([10, 40, w - 10, h - 10], fill=(120, 120, 128, 255))
    d.ellipse([28, 54, w - 28, h - 26], fill=(170, 190, 210, 255))
    d.polygon([(w // 2 - 30, 50), (w // 2 - 10, 60), (w // 2 - 22, 76)], fill=(60, 60, 66, 255))  # the break
    d.rectangle([w // 2 - 8, 10, w // 2 + 8, 80], fill=(130, 130, 138, 255))
    save_with_normal(img, "props/fountain_broken", strength=4)


def stall(name, cloth):
    w, h = 160, 130
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([10, 60, w - 10, h - 10], fill=(92, 64, 44, 255))
    for i in range(6):
        c = cloth if i % 2 == 0 else (230, 220, 200)
        d.polygon([(10 + i * 23, 20), (33 + i * 23, 20), (33 + i * 23, 60), (10 + i * 23, 60)], fill=c + (255,))
    d.rectangle([10, 14, w - 10, 22], fill=(220, 226, 236, 255))
    save_with_normal(img, name, strength=3)


def doe():
    w, h = 110, 80
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([18, 26, 88, 58], fill=(146, 104, 70, 255))
    d.ellipse([78, 12, 104, 34], fill=(150, 108, 72, 255))
    for x in (26, 38, 70, 80):
        d.rectangle([x, 52, x + 5, 78], fill=(110, 78, 52, 255))
    d.ellipse([92, 18, 96, 22], fill=(10, 10, 10, 255))
    save_with_normal(img, "actors/doe", strength=3)


def wolf_sprite():
    w, h = 190, 120
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([20, 34, 150, 92], fill=(118, 122, 132, 255))
    d.ellipse([130, 18, 182, 62], fill=(124, 128, 138, 255))
    d.polygon([(140, 22), (148, 2), (156, 22)], fill=(90, 94, 104, 255))
    d.polygon([(160, 22), (168, 2), (174, 24)], fill=(90, 94, 104, 255))
    for x in (34, 56, 110, 128):
        d.rectangle([x, 84, x + 10, 118], fill=(92, 96, 106, 255))
    d.polygon([(20, 50), (0, 40), (22, 66)], fill=(100, 104, 114, 255))
    d.ellipse([164, 32, 172, 40], fill=(255, 210, 60, 255))  # golden eye
    save_with_normal(img, "actors/wolf", strength=3)


def beast_sprite():
    w, h = 240, 180
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([20, 60, 190, 140], fill=(196, 152, 70, 255))
    d.ellipse([160, 30, 230, 96], fill=(204, 160, 76, 255))
    # elk-like curled horns
    d.arc([150, 0, 210, 60], 180, 330, fill=(70, 50, 36, 255), width=7)
    d.arc([180, -6, 240, 54], 200, 350, fill=(70, 50, 36, 255), width=7)
    for x in (40, 66, 140, 162):
        d.rectangle([x, 130, x + 14, 178], fill=(170, 128, 58, 255))
        d.polygon([(x, 178), (x + 4, 172), (x + 8, 178)], fill=(10, 10, 10, 255))
    d.ellipse([206, 52, 214, 60], fill=(80, 220, 120, 255))  # green eyes flecked amber
    save_with_normal(img, "actors/beast", strength=3)


def mare_sprite():
    w, h = 170, 130
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([20, 40, 140, 92], fill=(236, 238, 242, 255))
    d.polygon([(120, 50), (150, 10), (166, 20), (140, 62)], fill=(236, 238, 242, 255))
    for x in (34, 52, 104, 122):
        d.rectangle([x, 86, x + 9, 128], fill=(220, 222, 228, 255))
    d.rectangle([60, 36, 100, 50], fill=(110, 70, 40, 255))  # saddle
    save_with_normal(img, "actors/mare", strength=3)


def human_sheet(name, cloak, hair, skin=(232, 196, 170), label=""):
    """4 directions x 4 frames, 48x64 each. Rows: down, left, right, up."""
    fw, fh = 48, 64
    img = Image.new("RGBA", (fw * 4, fh * 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for row in range(4):
        for f in range(4):
            ox, oy = f * fw, row * fh
            bob = [0, -2, 0, -2][f]
            step = [0, 4, 0, -4][f]
            # legs
            d.rectangle([ox + 17 + step // 2, oy + 46, ox + 22 + step // 2, oy + 62], fill=(60, 48, 40, 255))
            d.rectangle([ox + 26 - step // 2, oy + 46, ox + 31 - step // 2, oy + 62], fill=(60, 48, 40, 255))
            # body/cloak
            d.polygon([(ox + 12, oy + 50 + bob), (ox + 24, oy + 18 + bob), (ox + 36, oy + 50 + bob)], fill=cloak + (255,))
            # head
            d.ellipse([ox + 15, oy + 6 + bob, ox + 33, oy + 26 + bob], fill=skin + (255,))
            if row == 3:  # facing up: back of head = hair
                d.ellipse([ox + 15, oy + 6 + bob, ox + 33, oy + 26 + bob], fill=hair + (255,))
            else:
                d.chord([ox + 14, oy + 4 + bob, ox + 34, oy + 22 + bob], 180, 360, fill=hair + (255,))
                if row == 0:
                    d.point([(ox + 20, oy + 16 + bob), (ox + 28, oy + 16 + bob)], fill=(30, 30, 40, 255))
                elif row == 1:
                    d.point([(ox + 18, oy + 16 + bob)], fill=(30, 30, 40, 255))
                else:
                    d.point([(ox + 30, oy + 16 + bob)], fill=(30, 30, 40, 255))
    save_with_normal(img, name, strength=2, blur=1)


def light_cookie():
    s = 256
    yy, xx = np.mgrid[0:s, 0:s]
    r = np.sqrt((xx - s / 2) ** 2 + (yy - s / 2) ** 2) / (s / 2)
    a = np.clip(1 - r, 0, 1) ** 1.6
    img = Image.fromarray((np.stack([a, a, a, a], -1) * 255).astype(np.uint8), "RGBA")
    os.makedirs(os.path.join(OUT, "fx"), exist_ok=True)
    img.save(os.path.join(OUT, "fx/light_soft.png"))


def snowflake():
    s = 16
    yy, xx = np.mgrid[0:s, 0:s]
    r = np.sqrt((xx - s / 2 + 0.5) ** 2 + (yy - s / 2 + 0.5) ** 2) / (s / 2)
    a = np.clip(1 - r, 0, 1) ** 2
    img = Image.fromarray((np.stack([np.ones_like(a), np.ones_like(a), np.ones_like(a), a], -1) * 255).astype(np.uint8), "RGBA")
    img.save(os.path.join(OUT, "fx/snowflake.png"))


def footprint():
    img = Image.new("RGBA", (12, 18), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([2, 0, 10, 12], fill=(120, 130, 160, 120))
    d.ellipse([3, 12, 9, 18], fill=(120, 130, 160, 110))
    img.save(os.path.join(OUT, "fx/footprint.png"))


# ------------------------------------------------------------- portraits/art
def portrait(char_id, display, expr, palette, w=640, h=960):
    """Painted-look placeholder bust: soft silhouette, rim light, label."""
    bg = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    hair, skin, cloth, accent = palette[:4]
    yy, xx = np.mgrid[0:h, 0:w]
    # body silhouette (shoulders + head) as soft mask
    head = ((xx - w * 0.5) / (w * 0.17)) ** 2 + ((yy - h * 0.30) / (h * 0.14)) ** 2 < 1
    neck = (np.abs(xx - w * 0.5) < w * 0.07) & (yy > h * 0.38) & (yy < h * 0.5)
    shoulders = ((xx - w * 0.5) / (w * 0.46)) ** 2 + ((yy - h * 0.86) / (h * 0.38)) ** 2 < 1
    hair_m = (((xx - w * 0.5) / (w * 0.21)) ** 2 + ((yy - h * 0.28) / (h * 0.17)) ** 2 < 1) & (yy < h * 0.30 + (np.abs(xx - w * 0.5) > w * 0.12) * h * 0.25)
    n = value_noise(w, h, 6, 4, seed=zlib.crc32(char_id.encode()) % 1000, tile=False)
    col = np.zeros((h, w, 3), np.float32)
    a = np.zeros((h, w), np.float32)
    for m, c in ((shoulders, cloth), (neck, skin), (head, skin), (hair_m, hair)):
        col = np.where(m[..., None], np.array(c, np.float32) * (0.75 + 0.45 * n[..., None]), col)
        a = np.maximum(a, m.astype(np.float32))
    # painterly light from upper-left, rim from right
    light = np.clip(1.15 - (xx / w) * 0.5 - (yy / h) * 0.35, 0.5, 1.2)
    rim = np.clip((xx / w - 0.55) * 3, 0, 1) * 0.35
    col = col * light[..., None] + np.array(accent, np.float32) * rim[..., None]
    a_img = Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3))
    img = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    img.putalpha(a_img)
    d = ImageDraw.Draw(img)
    # simple expressive marks so expressions read differently
    ey = int(h * 0.30)
    exl, exr = int(w * 0.44), int(w * 0.56)
    eye_col = palette[4] if len(palette) > 4 else (40, 40, 50)
    brow = {"neutral": 0, "angry": 8, "afraid": -10, "sad": -6, "smirk": 4, "cold": 2, "determined": 6, "wounded": -8,
            "furious": 12, "amused": 3, "tender": -3, "hungry": -2, "snarl": 12, "beast": 10}.get(expr, 0)
    d.line([(exl - 22, ey - 22 + brow), (exl + 14, ey - 22 - brow // 2)], fill=(40, 30, 30, 255), width=5)
    d.line([(exr - 14, ey - 22 - brow // 2), (exr + 22, ey - 22 + brow)], fill=(40, 30, 30, 255), width=5)
    for ex in (exl, exr):
        d.ellipse([ex - 10, ey - 7, ex + 10, ey + 7], fill=eye_col + (255,))
    mouth_y = int(h * 0.38)
    if expr in ("smirk", "amused"):
        d.arc([w * 0.46, mouth_y - 10, w * 0.56, mouth_y + 6], 10, 160, fill=(120, 50, 50, 255), width=4)
    elif expr in ("angry", "furious", "snarl", "determined"):
        d.line([(w * 0.46, mouth_y), (w * 0.54, mouth_y)], fill=(110, 40, 40, 255), width=5)
    elif expr in ("afraid", "wounded"):
        d.ellipse([w * 0.48, mouth_y - 6, w * 0.52, mouth_y + 8], fill=(80, 30, 30, 255))
    else:
        d.arc([w * 0.46, mouth_y - 2, w * 0.54, mouth_y + 10], 200, 340, fill=(120, 50, 50, 255), width=4)
    f_big = font(FONT_CAPS, 34)
    f_small = font(FONT_SERIF, 26)
    d.text((24, h - 120), display.upper(), fill=(255, 240, 200, 235), font=f_big, stroke_width=2, stroke_fill=(0, 0, 0, 200))
    d.text((24, h - 76), f"[{expr}]  PLACEHOLDER", fill=(255, 255, 255, 220), font=f_small, stroke_width=2, stroke_fill=(0, 0, 0, 200))
    d.text((24, h - 44), f"manifest: portrait.{char_id}.{expr}", fill=(220, 220, 220, 200), font=f_small, stroke_width=2, stroke_fill=(0, 0, 0, 200))
    path = os.path.join(OUT, "portraits", char_id)
    os.makedirs(path, exist_ok=True)
    img.save(os.path.join(path, f"{expr}.png"))


# ------------------------------------------------------------- icons and fx
SS = 4  # supersampling factor for anti-aliased icons


class Canvas:
    """Draw at SS x size, then downsample: smooth edges without a vector lib."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def P(self, pts):
        return [(x * SS, y * SS) for x, y in pts]

    def poly(self, pts, fill, outline=None, width=1):
        self.d.polygon(self.P(pts), fill=fill, outline=outline, width=int(width * SS) if outline else 1)

    def line(self, pts, fill, width):
        self.d.line(self.P(pts), fill=fill, width=max(1, int(width * SS)), joint="curve")
        for x, y in (pts[0], pts[-1]):  # round caps
            r = width * SS / 2
            self.d.ellipse([x * SS - r, y * SS - r, x * SS + r, y * SS + r], fill=fill)

    def ellipse(self, box, fill, outline=None, width=1):
        x0, y0, x1, y1 = box
        self.d.ellipse([x0 * SS, y0 * SS, x1 * SS, y1 * SS], fill=fill, outline=outline,
                       width=int(width * SS) if outline else 1)

    def arc(self, box, a0, a1, fill, width):
        x0, y0, x1, y1 = box
        self.d.arc([x0 * SS, y0 * SS, x1 * SS, y1 * SS], a0, a1, fill=fill, width=max(1, int(width * SS)))

    def rect(self, box, fill, radius=0):
        x0, y0, x1, y1 = box
        self.d.rounded_rectangle([x0 * SS, y0 * SS, x1 * SS, y1 * SS], radius * SS, fill=fill)

    def done(self):
        return self.img.resize((self.w, self.h), Image.LANCZOS)


def _finish_icon(img, outline=(18, 12, 10), shadow=True):
    """Dark ink outline and a soft drop shadow, so icons read on any slot."""
    a = img.getchannel("A")
    grow = a.filter(ImageFilter.MaxFilter(5))
    ink = Image.new("RGBA", img.size, outline + (0,))
    ink.putalpha(grow.point(lambda v: min(255, int(v * 0.95))))
    base = Image.new("RGBA", img.size, (0, 0, 0, 0))
    if shadow:
        sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
        sa = grow.filter(ImageFilter.GaussianBlur(3)).point(lambda v: int(v * 0.45))
        sh.putalpha(sa)
        base.alpha_composite(sh, (2, 4))
    base.alpha_composite(ink)
    base.alpha_composite(img)
    return base


def _save_icon(iid, img):
    os.makedirs(os.path.join(OUT, "items"), exist_ok=True)
    _finish_icon(img).save(os.path.join(OUT, "items", f"{iid}.png"))


def _shaft(c, x0, y0, x1, y1, wood, head, fletch, width=4.5, glow=None):
    """A diagonal arrow from (x0,y0) nock to (x1,y1) tip."""
    ang = math.atan2(y1 - y0, x1 - x0)
    ux, uy = math.cos(ang), math.sin(ang)
    px, py = -uy, ux
    if glow is not None:
        for r, al in ((14, 40), (9, 70)):
            c.line([(x0 + ux * 10, y0 + uy * 10), (x1 - ux * 6, y1 - uy * 6)], glow + (al,), r)
    c.line([(x0, y0), (x1 - ux * 12, y1 - uy * 12)], wood, width)
    hl = tuple(min(255, v + 45) for v in wood[:3]) + (255,)
    c.line([(x0 + px * 1, y0 + py * 1), (x1 - ux * 14 + px * 1, y1 - uy * 14 + py * 1)], hl, width * 0.35)
    # head
    hx, hy = x1 - ux * 16, y1 - uy * 16
    c.poly([(x1, y1), (hx + px * 7, hy + py * 7), (hx + ux * 3, hy + uy * 3), (hx - px * 7, hy - py * 7)], head)
    c.poly([(x1, y1), (hx + px * 7, hy + py * 7), (hx + ux * 3, hy + uy * 3)], tuple(min(255, v + 50) for v in head[:3]) + (255,))
    # fletching
    for side in (1, -1):
        fx0, fy0 = x0 + ux * 3, y0 + uy * 3
        c.poly([(fx0, fy0), (fx0 + ux * 18, fy0 + uy * 18), (fx0 + ux * 14 + px * 8 * side, fy0 + uy * 14 + py * 8 * side),
                (fx0 - ux * 2 + px * 9 * side, fy0 - uy * 2 + py * 9 * side)], fletch)


def icon_knife():
    c = Canvas(96, 96)
    # blade: lower-left handle, tip to the upper right
    c.poly([(40, 56), (82, 12), (86, 10), (84, 16), (50, 64)], (196, 204, 214, 255))
    c.poly([(40, 56), (82, 12), (86, 10), (46, 52)], (236, 240, 246, 255))      # bright edge
    c.line([(47, 58), (79, 20)], (150, 158, 172, 255), 1.6)                      # fuller
    c.line([(34, 50), (52, 68)], (176, 136, 64, 255), 6)                          # guard
    c.line([(14, 84), (40, 60)], (92, 58, 36, 255), 9)                            # handle
    for t in range(4):                                                             # leather wraps
        x, y = 18 + t * 6, 80 - t * 5.6
        c.line([(x - 3, y - 3), (x + 3, y + 3)], (60, 36, 22, 255), 1.6)
    c.ellipse([9, 80, 19, 90], (176, 136, 64, 255))                               # pommel
    _save_icon("hunting_knife", c.done())


def icon_bow():
    # drawn upright on a larger canvas (belly to +x, string on the archer's side),
    # then turned 45 degrees and cropped so it spans the icon's diagonal
    c = Canvas(136, 136)
    box = [-106, -34, 78, 170]
    c.arc(box, 322, 38, (112, 74, 42, 255), 9)
    c.arc(box, 326, 34, (170, 124, 76, 255), 3)
    c.line([(58.5, 9), (58.5, 127)], (228, 222, 204, 255), 1.8)
    c.line([(77, 58), (77, 78)], (66, 42, 28, 255), 11)
    for y in (9, 127):
        c.ellipse([53, y - 5, 64, y + 5], (90, 60, 36, 255))
    img = c.done().rotate(45, resample=Image.BICUBIC, center=(68, 68)).crop((14, 14, 122, 122)).resize((96, 96), Image.LANCZOS)
    _save_icon("bow", img)


def icon_arrow():
    c = Canvas(96, 96)
    for off in (-9, 0, 9):
        _shaft(c, 12 + off, 84 + off * 0.2, 84 + off * 0.2, 12 + off, (150, 106, 64, 255), (150, 156, 166, 255),
               (214, 214, 206, 255), width=3.5)
    _save_icon("arrow", c.done())


def icon_ash_arrow():
    c = Canvas(96, 96)
    _shaft(c, 12, 84, 84, 12, (236, 226, 200, 255), (58, 58, 66, 255), (244, 240, 230, 255), width=5,
           glow=(255, 214, 120))
    rng = np.random.default_rng(77)
    for _ in range(9):
        t = rng.uniform(0.15, 0.85)
        x, y = 12 + 72 * t + rng.uniform(-9, 9), 84 - 72 * t + rng.uniform(-9, 9)
        r = rng.uniform(0.8, 1.8)
        c.ellipse([x - r, y - r, x + r, y + r], (255, 232, 170, 230))
    _save_icon("ash_arrow", c.done())


def icon_rose_hips():
    c = Canvas(96, 96)
    c.line([(48, 18), (46, 40)], (70, 52, 36, 255), 3)
    c.line([(47, 30), (30, 46)], (70, 52, 36, 255), 2.5)
    c.line([(47, 30), (66, 44)], (70, 52, 36, 255), 2.5)
    for (x, y, rx, ry) in ((30, 58, 13, 17), (64, 56, 13, 17), (47, 66, 14, 18)):
        c.ellipse([x - rx, y - ry, x + rx, y + ry], (186, 44, 30, 255))
        c.ellipse([x - rx * 0.55, y - ry * 0.7, x - rx * 0.05, y - ry * 0.1], (236, 118, 82, 255))
        c.poly([(x - 4, y - ry + 1), (x, y - ry - 6), (x + 4, y - ry + 1)], (48, 30, 22, 255))
    c.poly([(56, 18), (74, 12), (66, 24)], (88, 104, 64, 255))   # a last withered leaf
    _save_icon("rose_hips", c.done())


def icon_venison():
    c = Canvas(96, 96)
    c.poly([(14, 60), (30, 36), (58, 28), (84, 34), (80, 52), (56, 62), (30, 72)], (118, 40, 30, 255))
    c.poly([(30, 40), (58, 32), (80, 38), (58, 46), (34, 54)], (152, 62, 46, 255))
    for x0, y0, x1, y1 in ((26, 58, 44, 46), (44, 56, 66, 42), (60, 52, 78, 42)):
        c.line([(x0, y0), (x1, y1)], (214, 170, 150, 200), 1.6)
    _save_icon("venison_strip", c.done())


def icon_bread():
    c = Canvas(96, 96)
    c.ellipse([10, 26, 86, 80], (150, 92, 44, 255))
    c.ellipse([16, 30, 80, 70], (184, 120, 60, 255))
    c.poly([(48, 22), (90, 50), (84, 82), (46, 84)], (0, 0, 0, 0))
    c.ellipse([46, 34, 78, 78], (226, 196, 150, 255))   # cut face
    c.ellipse([50, 38, 74, 74], (236, 212, 170, 255))
    rng = np.random.default_rng(12)
    for _ in range(14):
        x, y = rng.uniform(53, 72), rng.uniform(42, 70)
        c.ellipse([x - 1.2, y - 0.8, x + 1.2, y + 0.8], (196, 160, 110, 255))
    for x in (24, 34):
        c.line([(x, 34), (x + 8, 50)], (120, 70, 34, 255), 1.6)
    _save_icon("bread", c.done())


def icon_hare():
    c = Canvas(96, 96)
    c.ellipse([14, 46, 74, 80], (232, 232, 236, 255))            # body, lying
    c.ellipse([58, 40, 86, 64], (238, 238, 242, 255))            # head
    c.poly([(66, 44), (52, 14), (60, 12), (74, 42)], (226, 226, 230, 255))
    c.poly([(74, 42), (70, 12), (78, 12), (82, 42)], (220, 220, 226, 255))
    c.poly([(58, 18), (60, 16), (70, 40), (66, 42)], (214, 170, 170, 255))
    c.ellipse([76, 48, 80, 52], (40, 30, 30, 255))
    c.ellipse([10, 54, 22, 66], (246, 246, 248, 255))            # tail
    c.ellipse([22, 70, 50, 80], (200, 200, 208, 255))            # belly shade
    _save_icon("hare", c.done())


def _pelt(c, base, dark, light, torn=False):
    pts = [(10, 40), (22, 26), (40, 30), (56, 22), (74, 28), (88, 40), (84, 62), (70, 74), (48, 70), (26, 76), (12, 62)]
    c.poly(pts, dark)
    c.poly([(16, 42), (26, 30), (42, 34), (56, 27), (72, 32), (82, 42), (78, 60), (66, 68), (48, 64), (28, 70), (17, 60)], base)
    rng = np.random.default_rng(31)
    for _ in range(60):
        x, y = rng.uniform(20, 78), rng.uniform(34, 64)
        a = rng.uniform(-0.6, 0.6) + math.pi / 2
        L = rng.uniform(3, 7)
        c.line([(x, y), (x + math.cos(a) * L, y + math.sin(a) * L)], light, 1)
    if torn:
        c.poly([(44, 28), (52, 46), (46, 50), (40, 30)], (0, 0, 0, 0))
        for (x, y) in ((44, 30), (50, 46), (62, 60), (30, 62)):
            c.poly([(x, y), (x + 7, y + 4), (x + 2, y + 9)], (60, 30, 24, 255))


def icon_wolf_pelt():
    c = Canvas(96, 96)
    _pelt(c, (128, 130, 138, 255), (70, 72, 80, 255), (176, 178, 186, 255))
    c.ellipse([70, 34, 92, 52], (110, 112, 120, 255))     # the head end of the pelt
    c.poly([(74, 36), (78, 24), (82, 36)], (90, 92, 100, 255))
    c.poly([(82, 36), (88, 26), (90, 40)], (90, 92, 100, 255))
    _save_icon("wolf_pelt", c.done())


def icon_doe_hide(torn=False):
    c = Canvas(96, 96)
    _pelt(c, (172, 124, 80, 255), (110, 74, 46, 255), (206, 164, 120, 255), torn=torn)
    if torn:
        c.line([(20, 40), (70, 66)], (90, 30, 24, 220), 2)
    _save_icon("doe_hide_torn" if torn else "doe_hide", c.done())


def icon_snare_wire():
    c = Canvas(96, 96)
    for i in range(5):
        r = 30 - i * 2.2
        c.ellipse([48 - r, 50 - r * 0.8, 48 + r, 50 + r * 0.8], None, (178, 182, 192, 255), 2.2)
    c.ellipse([48 - 30, 50 - 24, 48 + 30, 50 + 24], None, (222, 226, 234, 255), 1)
    c.line([(70, 34), (86, 16)], (178, 182, 192, 255), 2.2)
    c.ellipse([82, 10, 92, 20], None, (178, 182, 192, 255), 2)          # the running loop
    _save_icon("snare_wire", c.done())


def icon_paint_tins():
    c = Canvas(96, 96)
    for (x, y, col) in ((28, 60, (186, 46, 40)), (66, 62, (214, 176, 46)), (47, 40, (48, 78, 168))):
        c.ellipse([x - 18, y - 6, x + 18, y + 20], (110, 110, 118, 255))
        c.rect([x - 18, y - 2, x + 18, y + 12], (150, 150, 158, 255))
        c.ellipse([x - 18, y - 10, x + 18, y + 6], (176, 176, 184, 255))
        c.ellipse([x - 14, y - 7, x + 14, y + 4], col + (255,))
        c.ellipse([x - 8, y - 5, x - 1, y - 1], tuple(min(255, v + 70) for v in col) + (255,))
    _save_icon("paint_tins", c.done())


def icon_iron_bracelet():
    c = Canvas(96, 96)
    c.ellipse([14, 26, 82, 74], None, (62, 62, 70, 255), 12)
    c.ellipse([16, 28, 80, 72], None, (104, 104, 114, 255), 4)
    c.arc([18, 30, 78, 70], 200, 300, (168, 168, 178, 255), 2.5)
    for a in range(0, 360, 45):                                       # hammered rivets
        x = 48 + math.cos(math.radians(a)) * 30
        y = 50 + math.sin(math.radians(a)) * 21
        c.ellipse([x - 2, y - 2, x + 2, y + 2], (140, 140, 150, 255))
    _save_icon("iron_bracelet", c.done())


def icon_coin():
    c = Canvas(96, 96)
    c.ellipse([14, 16, 82, 84], (126, 74, 40, 255))
    c.ellipse([16, 14, 80, 78], (196, 128, 70, 255))
    c.ellipse([22, 20, 74, 72], None, (150, 92, 50, 255), 2.5)
    c.poly([(48, 30), (58, 46), (48, 62), (38, 46)], (226, 166, 104, 255))   # stamped mark
    c.arc([20, 18, 60, 58], 200, 260, (250, 210, 160, 255), 3)
    _save_icon("coin", c.done())


def fx_sprites():
    os.makedirs(os.path.join(OUT, "fx"), exist_ok=True)
    # soft dot for sparks, blood and motes
    s = 24
    yy, xx = np.mgrid[0:s, 0:s]
    r = np.sqrt((xx - s / 2 + 0.5) ** 2 + (yy - s / 2 + 0.5) ** 2) / (s / 2)
    a = np.clip(1 - r, 0, 1) ** 1.3
    Image.fromarray((np.stack([np.ones_like(a), np.ones_like(a), np.ones_like(a), a], -1) * 255).astype(np.uint8),
                    "RGBA").save(os.path.join(OUT, "fx/dot.png"))
    # ground shadow: white, tinted dark by the game
    w, h = 96, 40
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.sqrt(((xx - w / 2 + 0.5) / (w / 2)) ** 2 + ((yy - h / 2 + 0.5) / (h / 2)) ** 2)
    a = np.clip(1 - r, 0, 1) ** 0.9
    Image.fromarray((np.stack([np.ones_like(a), np.ones_like(a), np.ones_like(a), a], -1) * 255).astype(np.uint8),
                    "RGBA").save(os.path.join(OUT, "fx/shadow.png"))
    # knife slash: a crescent bulging toward +x, thick in the middle, fading at the tips
    w, h = 128, 160
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    cx, cy, R = -30.0, h / 2, 132.0
    dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    ang = np.arctan2(yy - cy, xx - cx)
    span = 0.62
    along = np.clip(1 - np.abs(ang) / span, 0, 1)
    thick = 3 + 15 * along ** 0.8
    band = np.clip(1 - np.abs(dist - (R - thick * 0.5)) / (thick * 0.5 + 0.8), 0, 1)
    edge = np.clip(1 - np.abs(dist - (R - 1.5)) / 2.5, 0, 1) * along
    a = np.clip(band * along ** 0.6 * 0.75 + edge * 0.6, 0, 1)
    Image.fromarray((np.stack([np.ones_like(a), np.ones_like(a), np.ones_like(a), a], -1) * 255).astype(np.uint8),
                    "RGBA").save(os.path.join(OUT, "fx/slash.png"))
    # arrows in flight, nocked and stuck: point to +x
    for name, wood, head, fl in (("arrow", (150, 106, 64), (156, 162, 172), (214, 214, 206)),
                                 ("ash_arrow", (238, 228, 204), (58, 58, 66), (246, 242, 232))):
        c = Canvas(64, 12)
        c.line([(6, 6), (50, 6)], wood + (255,), 2.2)
        c.line([(8, 5.4), (48, 5.4)], tuple(min(255, v + 40) for v in wood) + (255,), 0.7)
        c.poly([(63, 6), (49, 1.5), (52, 6), (49, 10.5)], head + (255,))
        c.poly([(2, 1), (16, 4.6), (16, 6), (4, 6)], fl + (255,))
        c.poly([(2, 11), (16, 7.4), (16, 6), (4, 6)], tuple(int(v * 0.85) for v in fl) + (255,))
        img = c.done()
        if name == "ash_arrow":
            glow = img.getchannel("A").filter(ImageFilter.GaussianBlur(2))
            g = Image.new("RGBA", img.size, (255, 220, 140, 0))
            g.putalpha(glow.point(lambda v: int(v * 0.5)))
            g.alpha_composite(img)
            img = g
        img.save(os.path.join(OUT, f"fx/{name}.png"))
    # knife in hand: blade to +x, handle at the left
    c = Canvas(44, 14)
    c.line([(2, 7), (15, 7)], (92, 58, 36, 255), 5)
    c.line([(15, 2), (15, 12)], (176, 136, 64, 255), 2.4)
    c.poly([(16, 4.5), (36, 4.8), (43, 7), (36, 9.6), (16, 9.5)], (204, 210, 220, 255))
    c.poly([(16, 4.5), (36, 4.8), (43, 7), (16, 7)], (240, 244, 248, 255))
    c.done().save(os.path.join(OUT, "fx/knife.png"))
    # bow in hand: belly bulging to +x, string straight on the archer's side
    c = Canvas(26, 80)
    c.arc([-36, 2, 22, 78], 290, 70, (122, 82, 48, 255), 3.6)
    c.arc([-36, 2, 22, 78], 300, 60, (176, 130, 80, 255), 1.2)
    c.line([(9, 6), (9, 74)], (232, 226, 206, 230), 0.9)
    c.line([(20, 34), (21, 46)], (70, 44, 30, 255), 4.4)
    c.done().save(os.path.join(OUT, "fx/bow.png"))


def hare_sprite():
    w, h = 64, 48
    c = Canvas(w, h)
    c.ellipse([6, 18, 46, 44], (232, 232, 238, 255))
    c.ellipse([36, 12, 58, 32], (238, 238, 244, 255))
    c.poly([(42, 16), (36, 0), (41, 0), (47, 15)], (226, 226, 232, 255))
    c.poly([(47, 15), (46, 0), (51, 0), (52, 15)], (220, 220, 228, 255))
    c.poly([(38.5, 2), (40, 2), (45, 15), (43.5, 15)], (214, 176, 176, 255))
    c.ellipse([50, 19, 53, 22], (30, 24, 24, 255))
    c.ellipse([2, 22, 12, 32], (246, 246, 250, 255))
    c.ellipse([12, 38, 26, 46], (210, 210, 218, 255))
    c.ellipse([34, 38, 46, 46], (210, 210, 218, 255))
    c.ellipse([12, 34, 44, 44], (214, 214, 222, 255))
    save_with_normal(c.done(), "actors/hare", strength=2, blur=1)


def rose_bush(name, hips=True):
    w, h = 130, 104
    c = Canvas(w, h)
    rng = np.random.default_rng(91)
    canes = []
    for _ in range(26):                                        # arching thorny canes from one crown
        x0 = rng.uniform(52, 78)
        a = rng.uniform(math.pi * 0.12, math.pi * 0.88)
        L = rng.uniform(40, 70)
        x1, y1 = x0 + math.cos(a) * L, h - 8 - math.sin(a) * L
        mx, my = (x0 + x1) / 2 + rng.uniform(-6, 6), (h - 8 + y1) / 2 - rng.uniform(8, 16)
        canes.append(((x0, h - 8), (mx, my), (x1, y1)))
    for (p0, pm, p1) in canes:
        c.line([p0, pm, p1], (78, 46, 42, 255), 2.6)
        c.line([(p0[0] + 0.8, p0[1]), (pm[0] + 0.8, pm[1] - 0.6), (p1[0] + 0.6, p1[1] - 0.6)], (118, 74, 64, 255), 0.8)
        for t in (0.3, 0.55, 0.8):
            tx = pm[0] + (p1[0] - pm[0]) * t
            ty = pm[1] + (p1[1] - pm[1]) * t
            c.poly([(tx, ty), (tx + 3.5, ty - 3), (tx + 1, ty + 1.2)], (54, 30, 26, 255))
    for (p0, pm, p1) in canes:                                 # snow lies along the top of each arch
        for t in (0.0, 0.35, 0.7):
            x = pm[0] + (p1[0] - pm[0]) * t
            y = pm[1] + (p1[1] - pm[1]) * t - 2
            rx = rng.uniform(4, 7)
            c.ellipse([x - rx, y - 2.6, x + rx, y + 1.6], (232, 238, 248, 255))
    if hips:
        for (p0, pm, p1) in canes[::2]:
            for t in (0.85, 1.0):
                x = pm[0] + (p1[0] - pm[0]) * t + rng.uniform(-2, 2)
                y = pm[1] + (p1[1] - pm[1]) * t + 4
                c.ellipse([x - 2.8, y - 3.8, x + 2.8, y + 3.8], (190, 38, 28, 255))
                c.ellipse([x - 1.8, y - 2.8, x - 0.3, y - 0.8], (246, 128, 90, 255))
                c.poly([(x - 1.2, y - 3.6), (x, y - 5.6), (x + 1.2, y - 3.6)], (48, 30, 22, 255))
    save_with_normal(c.done(), name, strength=3, blur=1.2)


def items_and_fx():
    icon_knife(); icon_bow(); icon_arrow(); icon_ash_arrow(); icon_rose_hips(); icon_venison(); icon_bread()
    icon_hare(); icon_wolf_pelt(); icon_doe_hide(False); icon_doe_hide(True); icon_snare_wire(); icon_paint_tins()
    icon_iron_bracelet(); icon_coin()
    fx_sprites(); hare_sprite(); rose_bush("props/rose_bush", True); rose_bush("props/rose_bush_bare", False)

def main():
    os.makedirs(OUT, exist_ok=True)
    ground_snow(); ground_mud_snow(); floor_planks(); cobbles()
    for i in range(3):
        pine(f"props/pine_{i}", seed=i)
    bare_tree("props/bare_tree_0", seed=3); bare_tree("props/bare_tree_1", seed=8)
    bramble(); rock("props/rock_0", 51); rock("props/rock_1", 52)
    building("props/cottage", 300, 240, (128, 124, 120), (70, 56, 50), "PH cottage", painted=True)
    building("props/house_a", 260, 220, (140, 136, 128), (80, 66, 56), "PH house")
    building("props/house_b", 230, 200, (120, 118, 116), (62, 58, 66), "PH house", windows=1)
    building("props/barn", 280, 220, (106, 80, 60), (64, 48, 40), "PH barn", windows=0)
    fountain(); stall("props/stall_red", (150, 50, 50)); stall("props/stall_blue", (60, 80, 150))
    doe(); wolf_sprite(); beast_sprite(); mare_sprite()
    human_sheet("actors/feyre", (78, 70, 62), (168, 128, 72))
    human_sheet("actors/nesta", (70, 80, 110), (176, 136, 80), skin=(240, 210, 190))
    human_sheet("actors/elain", (120, 100, 110), (180, 140, 86), skin=(246, 220, 204))
    human_sheet("actors/father", (90, 74, 60), (60, 46, 40))
    human_sheet("actors/isaac", (96, 84, 60), (110, 80, 50))
    human_sheet("actors/mercenary", (50, 50, 56), (24, 20, 20), skin=(190, 150, 110))
    human_sheet("actors/acolyte", (170, 190, 220), (40, 30, 30), skin=(250, 240, 236))
    human_sheet("actors/villager", (100, 90, 80), (90, 70, 50))
    light_cookie(); snowflake(); footprint()

    pal = {
        "feyre": ((168, 128, 72), (232, 196, 170), (78, 70, 62), (255, 220, 160), (70, 80, 110)),
        "nesta": ((176, 136, 80), (240, 210, 190), (70, 80, 110), (200, 210, 255), (100, 110, 130)),
        "elain": ((180, 140, 86), (246, 220, 204), (150, 120, 130), (255, 230, 200), (110, 80, 50)),
        "father": ((60, 46, 40), (226, 196, 170), (90, 74, 60), (255, 200, 150), (80, 60, 40)),
        "isaac": ((110, 80, 50), (226, 190, 160), (96, 84, 60), (255, 220, 170), (90, 70, 50)),
        "mercenary": ((24, 20, 20), (190, 150, 110), (50, 50, 56), (255, 200, 150), (30, 20, 20)),
        "acolyte": ((40, 30, 30), (250, 240, 236), (170, 190, 220), (220, 230, 255), (90, 60, 40)),
        "tamlin": ((214, 176, 90), (236, 200, 170), (40, 80, 50), (255, 230, 150), (60, 150, 80)),
        "beast": ((196, 152, 70), (196, 152, 70), (170, 128, 58), (255, 220, 120), (80, 220, 120)),
    }
    names = {"feyre": "Feyre Archeron", "nesta": "Nesta Archeron", "elain": "Elain Archeron", "father": "Father",
             "isaac": "Isaac Hale", "mercenary": "The Mercenary", "acolyte": "Acolyte of the Blessed", "tamlin": "Tamlin",
             "beast": "The Beast"}
    exprs = {
        "feyre": ["neutral", "cold", "determined", "afraid", "angry", "sad", "hungry", "wounded"],
        "nesta": ["neutral", "smirk", "angry", "afraid"],
        "elain": ["neutral", "sad", "afraid", "tender"],
        "father": ["neutral", "sad", "afraid"],
        "isaac": ["neutral"],
        "mercenary": ["neutral", "amused"],
        "acolyte": ["neutral", "angry"],
        "beast": ["snarl", "furious", "neutral"],
    }
    for cid, ex in exprs.items():
        for e in ex:
            portrait(cid, names[cid], e, pal[cid])

    items_and_fx()
    print("placeholders written to", OUT)


if __name__ == "__main__":
    sys.exit(main())
