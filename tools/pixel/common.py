"""Shared helpers for the pixel-art generators: periodic noise, palettes,
ordered dithering and PNG output. Everything is seeded, so a run always
produces the same pixels."""
import numpy as np
from PIL import Image

BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def periodic_noise(size, period, seed, octaves=3, persistence=0.5, cell=8):
    """Value noise on a size x size grid that wraps every `period` pixels
    (size must be a multiple of period); the coarsest features are about
    `cell` pixels across. Returns floats in 0..1."""
    rng = np.random.default_rng(seed)
    out = np.zeros((size, size))
    amp, total = 1.0, 0.0
    cells = max(2, period // cell)
    for _ in range(octaves):
        lat = rng.random((cells, cells))
        ys, xs = np.mgrid[0:size, 0:size].astype(float)
        fx = (xs % period) / period * cells
        fy = (ys % period) / period * cells
        x0 = np.floor(fx).astype(int) % cells
        y0 = np.floor(fy).astype(int) % cells
        x1 = (x0 + 1) % cells
        y1 = (y0 + 1) % cells
        tx = fx - np.floor(fx)
        ty = fy - np.floor(fy)
        tx = tx * tx * (3 - 2 * tx)
        ty = ty * ty * (3 - 2 * ty)
        a = lat[y0, x0] * (1 - tx) + lat[y0, x1] * tx
        b = lat[y1, x0] * (1 - tx) + lat[y1, x1] * tx
        out += (a * (1 - ty) + b * ty) * amp
        total += amp
        amp *= persistence
        cells *= 2
    return out / total


def quantize(values, ramp, dither=0.5):
    """Map 0..1 values onto a colour ramp (dark to light) with a little ordered
    dithering at the steps, the way pixel artists blend two shades."""
    h, w = values.shape
    n = len(ramp)
    bay = np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w]
    idx = np.clip(np.floor(values * n + (bay - 0.5) * dither), 0, n - 1).astype(int)
    pal = np.array([rgb(c) if isinstance(c, str) else c for c in ramp], dtype=np.uint8)
    return pal[idx]


def to_image(arr_rgb, alpha=None):
    h, w = arr_rgb.shape[:2]
    if alpha is None:
        alpha = np.full((h, w), 255, np.uint8)
    out = np.dstack([arr_rgb.astype(np.uint8), alpha.astype(np.uint8)])
    return Image.fromarray(out, "RGBA")


def outline(img, color, diagonal=False):
    """Adds a one-pixel outline around the opaque shape of an RGBA image."""
    a = np.asarray(img)[:, :, 3] > 0
    h, w = a.shape
    grow = np.zeros_like(a)
    shifts = [(-1, 0), (1, 0), (0, -1), (0, 1)]
    if diagonal:
        shifts += [(-1, -1), (-1, 1), (1, -1), (1, 1)]
    for dy, dx in shifts:
        s = np.zeros_like(a)
        ys = slice(max(dy, 0), h + min(dy, 0))
        yd = slice(max(-dy, 0), h + min(-dy, 0))
        xs = slice(max(dx, 0), w + min(dx, 0))
        xd = slice(max(-dx, 0), w + min(-dx, 0))
        s[yd, xd] = a[ys, xs]
        grow |= s
    edge = grow & ~a
    arr = np.array(img)
    c = rgb(color) if isinstance(color, str) else color
    arr[edge] = (*c, 255)
    return Image.fromarray(arr, "RGBA")
