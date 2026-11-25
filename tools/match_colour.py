#!/usr/bin/env python3
"""Pull a generated image's colours toward a reference image of the same subject.

    python3 tools/match_colour.py <source> <reference> <out> [--strength 0.8]

Expression portraits are generated from a neutral one as the reference, and now
and then one drifts warmer or cooler than the rest of its set, which shows when
the dialogue swaps faces mid-scene. This matches the mean and spread of each
channel in Lab space (Reinhard's transfer) over the painted pixels only (alpha
above one half), then blends the result with the source by --strength. Alpha
is kept as it is.
"""
import argparse

import numpy as np
from PIL import Image


def to_lab(rgb):
    """sRGB 0..1 -> CIE Lab (D65)."""
    a = np.where(rgb > 0.04045, ((rgb + 0.055) / 1.055) ** 2.4, rgb / 12.92)
    m = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = a @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 216 / 24389, np.cbrt(xyz), (24389 / 27 * xyz + 16) / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def from_lab(lab):
    fy = (lab[..., 0] + 16) / 116
    fx = fy + lab[..., 1] / 500
    fz = fy - lab[..., 2] / 200
    f = np.stack([fx, fy, fz], -1)
    xyz = np.where(f ** 3 > 216 / 24389, f ** 3, (116 * f - 16) / (24389 / 27)) * np.array([0.95047, 1.0, 1.08883])
    m = np.array([[3.2406, -1.5372, -0.4986], [-0.9689, 1.8758, 0.0415], [0.0557, -0.2040, 1.0570]])
    a = xyz @ m.T
    rgb = np.where(a > 0.0031308, 1.055 * np.clip(a, 0, None) ** (1 / 2.4) - 0.055, 12.92 * a)
    return np.clip(rgb, 0, 1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source")
    ap.add_argument("reference")
    ap.add_argument("out")
    ap.add_argument("--strength", type=float, default=0.8)
    a = ap.parse_args()
    src = np.asarray(Image.open(a.source).convert("RGBA"), dtype=np.float64) / 255
    ref = np.asarray(Image.open(a.reference).convert("RGBA"), dtype=np.float64) / 255
    ls, lr = to_lab(src[..., :3]), to_lab(ref[..., :3])
    ms, mr = src[..., 3] > 0.5, ref[..., 3] > 0.5
    out = ls.copy()
    for c in range(3):
        s_mu, s_sd = ls[..., c][ms].mean(), ls[..., c][ms].std() + 1e-6
        r_mu, r_sd = lr[..., c][mr].mean(), lr[..., c][mr].std() + 1e-6
        out[..., c] = (ls[..., c] - s_mu) * (r_sd / s_sd) + r_mu
    rgb = from_lab(out)
    rgb = src[..., :3] * (1 - a.strength) + rgb * a.strength
    res = np.concatenate([rgb, src[..., 3:]], -1)
    Image.fromarray((res * 255 + 0.5).astype(np.uint8), "RGBA").save(a.out)
    print(a.out)


if __name__ == "__main__":
    main()
