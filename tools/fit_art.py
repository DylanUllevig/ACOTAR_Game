#!/usr/bin/env python3
"""Fit a generated image into the game as final art.

    python3 tools/fit_art.py <asset id> <source image> [--mirror] [--pad 0.04]

Reads the asset's size and final path from data/assets/manifest.json and
writes assets/final/<path>, then its normal map for lit kinds.

The listed size is the size the game lays the sprite out at. Props and actors
are written at twice that (--scale) so they stay sharp when the camera zooms
in, and the ratio is recorded in assets/final/density.json, which the game
reads (Art.density) to draw them at their layout size. By kind:

- portrait    resized to the listed size (2:3), cut from the top if the source
              is taller, so the head stays where the painting put it; a side
              the painting runs off is feathered so it ends softly on screen
- prop, actor trimmed to the painted pixels, scaled to fit the listed size and
              set on its bottom centre (the game places props by their base)
- icon, fx    trimmed, scaled to fit with a little padding, centred
- terrain     centre square, resized, then made seamless: blended
              (make_seamless) or, with --seam cut, joined along the cheapest
              path through the overlap (seams.py), which keeps stones and
              planks from ghosting
- background  scaled to cover the listed size and centre-cropped
- room        a whole painted room: scaled to cover, centre-cropped, lit

Resizing happens on premultiplied alpha, so cut-out edges get no dark or
light fringe. --mirror flips the image left to right first (for a subject
painted facing the wrong way). --box x0,y0,x1,y1 crops to that source box
instead of trimming, so two images that swap in the game (a rose bush with
and without its hips) get the same scale and the same base.
"""
import argparse
import json
import os
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIT_KINDS = {"prop", "actor", "terrain", "room"}
HIRES_KINDS = {"prop", "actor", "room"}
DENSITY = os.path.join(ROOT, "assets", "final", "density.json")


def record_density(rel, k):
    """rel is relative to assets/final; k = layout size / pixel size."""
    d = {}
    if os.path.exists(DENSITY):
        with open(DENSITY, encoding="utf-8") as f:
            d = json.load(f)
    if abs(k - 1.0) < 1e-6:
        d.pop(rel, None)
    else:
        d[rel] = round(k, 6)
    with open(DENSITY, "w", encoding="utf-8") as f:
        json.dump(dict(sorted(d.items())), f, indent=1)
        f.write("\n")


def manifest_entry(asset_id):
    with open(os.path.join(ROOT, "data", "assets", "manifest.json"), encoding="utf-8") as f:
        m = json.load(f)
    for a in m["assets"]:
        if a["id"] == asset_id:
            return a
    sys.exit("no asset %r in the manifest" % asset_id)


def resize_rgba(img, size):
    """Resize on premultiplied alpha (PIL's RGBa mode) to keep edges clean."""
    return img.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")


def trim(img, threshold=8):
    """Crop to the pixels whose alpha is above threshold (0..255)."""
    a = np.asarray(img)[..., 3]
    ys, xs = np.nonzero(a > threshold)
    if len(xs) == 0:
        return img
    return img.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))


def fit_into(img, size, anchor="bottom", pad=0.0):
    """Scale img to fit inside size (less padding) and place it on a clear canvas."""
    w, h = size
    pw, ph = w * (1 - 2 * pad), h * (1 - 2 * pad)
    s = min(pw / img.width, ph / img.height)
    nw, nh = max(1, round(img.width * s)), max(1, round(img.height * s))
    small = resize_rgba(img, (nw, nh))
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x = (w - nw) // 2
    y = h - nh if anchor == "bottom" else (h - nh) // 2
    canvas.alpha_composite(small, (x, y))
    return canvas


def cover(img, size, top=False):
    """Scale to cover size, then crop the centre (or the top, for portraits)."""
    w, h = size
    s = max(w / img.width, h / img.height)
    nw, nh = max(w, round(img.width * s)), max(h, round(img.height * s))
    big = resize_rgba(img, (nw, nh))
    x = (nw - w) // 2
    y = 0 if top else (nh - h) // 2
    return big.crop((x, y, x + w, y + h))


def feather_cut_sides(img, width=0.07):
    """Fade the alpha of a side the subject runs off (a sleeve or a cloak cut by
    the frame) so the dialogue box shows a soft edge, not a straight line."""
    px = np.asarray(img).astype(np.float32)
    a = px[..., 3]
    n = max(2, int(img.width * width))
    ramp = (np.arange(n, dtype=np.float32) + 0.5) / n
    ramp = ramp * ramp * (3 - 2 * ramp)
    if (a[:, 0] > 128).any():
        a[:, :n] *= ramp[None, :]
    if (a[:, -1] > 128).any():
        a[:, -n:] *= ramp[::-1][None, :]
    px[..., 3] = a
    return Image.fromarray(px.round().clip(0, 255).astype(np.uint8), "RGBA")


def make_seamless(rgb):
    """Blend the four half-offset copies of a texture so it tiles.

    Each copy's weight is zero along its own seams (a sin^2 / cos^2 window per
    axis, summing to 1), so the result wraps cleanly. Blending flattens
    contrast, so the detail is rescaled to keep the source's variance.
    """
    img = rgb.astype(np.float32)
    h, w = img.shape[:2]
    ax = np.sin(np.pi * (np.arange(w) + 0.5) / w) ** 2
    ay = np.sin(np.pi * (np.arange(h) + 0.5) / h) ** 2
    bx, by = 1 - ax, 1 - ay
    mean = img.reshape(-1, img.shape[2]).mean(0)
    acc = np.zeros_like(img)
    wsq = np.zeros((h, w), np.float32)
    for sx, wx in ((0, ax), (w // 2, bx)):
        for sy, wy in ((0, ay), (h // 2, by)):
            wgt = np.outer(wy, wx).astype(np.float32)
            shifted = np.roll(np.roll(img, sy, 0), sx, 1)
            acc += wgt[..., None] * (shifted - mean)
            wsq += wgt * wgt
    out = mean + acc / np.sqrt(wsq)[..., None]
    return np.clip(out, 0, 255).astype(np.uint8)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("asset_id")
    ap.add_argument("source")
    ap.add_argument("--mirror", action="store_true")
    ap.add_argument("--pad", type=float, default=None)
    ap.add_argument("--no-normals", action="store_true")
    ap.add_argument("--box", help="x0,y0,x1,y1 source crop used instead of trimming")
    ap.add_argument("--seam", choices=["blend", "cut"], default="blend", help="how terrain is made to tile")
    ap.add_argument("--scale", type=float, default=None,
                    help="pixels per layout pixel (default 2 for props and actors, else 1)")
    args = ap.parse_args()

    a = manifest_entry(args.asset_id)
    kind, layout = a["kind"], tuple(a["size"])
    scale = args.scale if args.scale is not None else (2.0 if kind in HIRES_KINDS else 1.0)
    size = (round(layout[0] * scale), round(layout[1] * scale))
    img = Image.open(args.source).convert("RGBA")
    # the generator's opaque pixels carry alpha 254; make them fully opaque
    px = np.asarray(img).copy()
    px[..., 3] = np.where(px[..., 3] >= 250, 255, px[..., 3])
    img = Image.fromarray(px, "RGBA")
    if args.mirror:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)

    if args.box:
        x0, y0, x1, y1 = (int(v) for v in args.box.split(","))
        cut = img.crop((x0, y0, x1, y1))
    else:
        cut = trim(img)

    if kind == "portrait":
        out = feather_cut_sides(cover(img, size, top=True))
    elif kind in ("prop", "actor"):
        out = fit_into(cut, size, "bottom", args.pad or 0.0)
    elif kind in ("icon", "fx"):
        out = fit_into(cut, size, "center", 0.06 if args.pad is None else args.pad)
    elif kind == "terrain":
        side = min(img.width, img.height)
        sq = img.crop(((img.width - side) // 2, (img.height - side) // 2,
                       (img.width - side) // 2 + side, (img.height - side) // 2 + side))
        if args.seam == "cut":
            from seams import wrap_xy
            o = round(size[0] * 0.14)
            sq = sq.convert("RGB").resize((size[0] + o, size[1] + o), Image.LANCZOS)
            tiled = wrap_xy(np.asarray(sq).astype(np.float32), o)
            out = Image.fromarray(tiled.round().clip(0, 255).astype(np.uint8)).convert("RGBA")
        else:
            sq = sq.convert("RGB").resize(size, Image.LANCZOS)
            out = Image.fromarray(make_seamless(np.asarray(sq))).convert("RGBA")
    elif kind in ("background", "room"):
        out = cover(img.convert("RGB").convert("RGBA"), size)
    else:
        sys.exit("unknown kind " + kind)

    dst = os.path.join(ROOT, a["final"])
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    if kind in ("terrain", "background", "room"):
        out.convert("RGB").save(dst)
    else:
        out.save(dst)
    rel = os.path.relpath(dst, os.path.join(ROOT, "assets", "final")).replace(os.sep, "/")
    record_density(rel, layout[1] / out.size[1])
    print("wrote", os.path.relpath(dst, ROOT), "%dx%d" % out.size, "(layout %dx%d)" % layout)
    if kind in LIT_KINDS and not args.no_normals:
        cmd = [sys.executable, os.path.join(ROOT, "tools", "make_normals.py")]
        if kind == "terrain":
            cmd.append("--wrap")
        subprocess.run(cmd + [dst], check=True)


if __name__ == "__main__":
    main()
