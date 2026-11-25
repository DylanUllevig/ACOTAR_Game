"""Make textures wrap without ghosting, by cutting rather than blending.

make_seamless in fit_art.py blends half-offset copies, which is fine for soft
snow but doubles anything with edges (two half-transparent cobbles on top of
each other). Here the strip that wraps round is joined to the start of the
image along the cheapest path through their overlap, the way image quilting
stitches patches: each pixel comes from one copy or the other, with only a few
pixels of feathering across the cut.
"""
import numpy as np

FEATHER = 3


def _seam(err, keep_off):
    """Cheapest top-to-bottom path through err (H x W), at least keep_off
    pixels from either side. Returns the column of the path in each row."""
    h, w = err.shape
    cost = err.astype(np.float64).copy()
    cost[:, :keep_off] = np.inf
    cost[:, w - keep_off:] = np.inf
    back = np.zeros((h, w), np.int8)
    for y in range(1, h):
        prev = cost[y - 1]
        left = np.r_[np.inf, prev[:-1]]
        right = np.r_[prev[1:], np.inf]
        stack = np.vstack([left, prev, right])
        idx = stack.argmin(0)
        cost[y] += stack[idx, np.arange(w)]
        back[y] = idx.astype(np.int8) - 1
    path = np.zeros(h, int)
    path[-1] = int(np.argmin(cost[-1]))
    for y in range(h - 1, 0, -1):
        path[y - 1] = path[y] + back[y, path[y]]
    return path


def wrap_x(img, overlap):
    """img: H x W x C float array. Returns H x (W - overlap) x C that tiles
    left to right: its first columns continue from its last ones."""
    h, w = img.shape[:2]
    o = int(overlap)
    tail = img[:, w - o:]     # what comes after the kept part
    head = img[:, :o]         # what the kept part starts with
    err = ((tail[..., :3] - head[..., :3]) ** 2).sum(2)
    path = _seam(err, FEATHER + 1)
    d = np.arange(o)[None, :] - path[:, None]
    t = np.clip(0.5 + d / (2.0 * FEATHER), 0.0, 1.0)[..., None]
    band = tail * (1.0 - t) + head * t
    return np.concatenate([band, img[:, o:w - o]], 1)


def wrap_xy(img, overlap):
    """Tiles both ways; the result is overlap pixels smaller on each axis."""
    out = wrap_x(img, overlap)
    return wrap_x(out.transpose(1, 0, 2), overlap).transpose(1, 0, 2)


def periodic_noise(n, seed=0, octaves=(2, 3, 5, 8, 13)):
    """A smooth 1-D signal of length n that wraps, in about -1..1."""
    rng = np.random.default_rng(seed)
    x = np.arange(n) / n
    v = np.zeros(n)
    for k in octaves:
        v += np.sin(2 * np.pi * (k * x + rng.random())) / k ** 0.6
    return v / np.abs(v).max()
