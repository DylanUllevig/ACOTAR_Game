#!/usr/bin/env python3
"""Generate labeled placeholder art (with normal maps) for the ACOTAR slice.

Every image produced here is a stand-in. Each one carries the id of the asset
in data/assets/manifest.json that will replace it, so swapping in real art is a
file drop: keep the same path and size, regenerate the normal map, done.

Usage:  python3 tools/gen_placeholders.py            (writes into assets/placeholder)
Needs:  Pillow, numpy
"""
import json
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


def creature_battle_art(cid, display, body, eye, horns=False, w=900, h=700):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([90, 230, 700, 560], fill=body + (255,))
    d.ellipse([560, 110, 860, 380], fill=tuple(min(255, c + 10) for c in body) + (255,))
    if horns:
        d.arc([560, -40, 760, 180], 180, 330, fill=(70, 50, 36, 255), width=22)
        d.arc([680, -60, 900, 160], 200, 350, fill=(70, 50, 36, 255), width=22)
    else:
        d.polygon([(600, 140), (640, 40), (680, 150)], fill=tuple(c - 30 for c in body) + (255,))
        d.polygon([(720, 140), (760, 40), (790, 160)], fill=tuple(c - 30 for c in body) + (255,))
    for x in (160, 260, 520, 600):
        d.rectangle([x, 520, x + 50, 690], fill=tuple(c - 25 for c in body) + (255,))
    d.polygon([(760, 300), (860, 300), (820, 360)], fill=(240, 230, 220, 255))  # fangs suggestion
    d.ellipse([760, 210, 800, 240], fill=eye + (255,))
    img = img.filter(ImageFilter.GaussianBlur(1.2))
    img = img.transpose(Image.FLIP_LEFT_RIGHT)  # enemies face left, toward Feyre (style guide)
    d = ImageDraw.Draw(img)
    d.text((30, h - 90), display.upper(), fill=(255, 240, 200, 235), font=font(FONT_CAPS, 40), stroke_width=2, stroke_fill=(0, 0, 0, 200))
    d.text((30, h - 44), f"PLACEHOLDER  battle.{cid}", fill=(255, 255, 255, 220), font=font(FONT_SERIF, 28), stroke_width=2, stroke_fill=(0, 0, 0, 200))
    os.makedirs(os.path.join(OUT, "battle"), exist_ok=True)
    save_with_normal(img, f"battle/{cid}", strength=3, blur=3)


def card_art(cid, title, hue_seed, motif):
    w, h = 300, 200
    rng = np.random.default_rng(hue_seed)
    base = rng.integers(40, 140, 3)
    n = value_noise(w, h, 3, 4, seed=hue_seed, tile=False)
    col = base[None, None, :] * (0.6 + 0.8 * n[..., None])
    img = Image.fromarray(col.clip(0, 255).astype(np.uint8), "RGB").convert("RGBA")
    d = ImageDraw.Draw(img)
    gold = (232, 196, 120, 255)
    if motif == "arrow":
        d.line([(40, 160), (250, 40)], fill=gold, width=6)
        d.polygon([(250, 40), (226, 44), (240, 60)], fill=(200, 200, 210, 255))
    elif motif == "ash":
        d.line([(40, 160), (250, 40)], fill=(240, 236, 220, 255), width=8)
        d.polygon([(250, 40), (222, 42), (238, 64)], fill=(60, 60, 70, 255))
        for i in range(12):
            x, y = rng.integers(40, 260), rng.integers(30, 170)
            d.ellipse([x, y, x + 4, y + 4], fill=(255, 220, 150, 200))
    elif motif == "knife":
        d.polygon([(80, 150), (220, 50), (232, 62), (96, 164)], fill=(210, 214, 224, 255))
        d.rectangle([60, 150, 100, 172], fill=(110, 76, 50, 255))
    elif motif == "shield":
        d.polygon([(150, 30), (230, 60), (210, 150), (150, 180), (90, 150), (70, 60)], fill=(110, 90, 70, 255), outline=gold)
    elif motif == "move":
        for i in range(3):
            d.polygon([(60 + i * 60, 60), (110 + i * 60, 100), (60 + i * 60, 140)], fill=gold)
    elif motif == "eye":
        d.ellipse([80, 70, 220, 130], fill=(230, 230, 220, 255))
        d.ellipse([130, 80, 170, 120], fill=(40, 40, 60, 255))
    elif motif == "leaf":
        d.ellipse([90, 50, 210, 150], fill=(90, 140, 80, 255))
    else:
        d.ellipse([110, 60, 190, 140], fill=gold)
    d.text((10, 8), "PLACEHOLDER", fill=(255, 255, 255, 160), font=font(FONT_CAPS, 14))
    os.makedirs(os.path.join(OUT, "cards"), exist_ok=True)
    img.save(os.path.join(OUT, "cards", f"{cid}.png"))


def relic_icon(rid, colors):
    s = 128
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([4, 4, s - 4, s - 4], fill=(40, 30, 40, 230), outline=(232, 196, 120, 255), width=4)
    for i, c in enumerate(colors):
        x = 26 + i * 28
        d.rounded_rectangle([x, 44, x + 22, 84], 4, fill=tuple(c) + (255,), outline=(20, 20, 20, 255))
    d.text((10, s - 24), "PH", fill=(255, 255, 255, 150), font=font(FONT_CAPS, 14))
    os.makedirs(os.path.join(OUT, "relics"), exist_ok=True)
    img.save(os.path.join(OUT, "relics", f"{rid}.png"))


def item_icon(iid, color, shape="circle"):
    s = 96
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if shape == "nail":
        d.polygon([(44, 10), (52, 10), (52, 76), (48, 90), (44, 76)], fill=color + (255,))
        d.rectangle([34, 8, 62, 16], fill=color + (255,))
    elif shape == "meat":
        d.ellipse([14, 26, 82, 70], fill=color + (255,))
        d.rectangle([70, 42, 92, 52], fill=(236, 230, 214, 255))
    else:
        d.ellipse([16, 16, 80, 80], fill=color + (255,))
    os.makedirs(os.path.join(OUT, "items"), exist_ok=True)
    img.save(os.path.join(OUT, "items", f"{iid}.png"))


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

    creature_battle_art("andras_wolf", "The Wolf", (118, 122, 132), (255, 210, 60))
    creature_battle_art("beast", "The Beast", (196, 152, 70), (80, 220, 120), horns=True)

    cards_path = os.path.join(ROOT, "data", "cards.json")
    if os.path.exists(cards_path):
        with open(cards_path) as f:
            cards = json.load(f)["cards"]
        for i, c in enumerate(cards):
            card_art(c["id"], c["name"], 100 + i, c.get("art_motif", "orb"))
    relic_icon("elains_paint_tins", [(190, 50, 50), (220, 190, 60), (50, 80, 180)])
    relic_icon("snare_wire", [(170, 176, 190)])
    relic_icon("iron_bracelet", [(110, 110, 120), (80, 80, 90)])
    item_icon("venison_strip", (140, 60, 50), "meat")
    item_icon("hot_water", (190, 200, 220))
    item_icon("iron_nail", (110, 110, 120), "nail")
    print("placeholders written to", OUT)


if __name__ == "__main__":
    sys.exit(main())
