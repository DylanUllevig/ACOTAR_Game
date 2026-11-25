#!/usr/bin/env python3
"""Derive approximate normal maps for final art so 2D lights shade it.

    python3 tools/make_normals.py assets/final/props/pine_0.png [...]
    python3 tools/make_normals.py --wrap assets/final/terrain/snow.png
    python3 tools/make_normals.py --all          # every lit folder under assets/final

Writes <name>_n.png next to each image. The height field is a blend of the
alpha silhouette (so edges round off) and luminance (so painted highlights read
as raised). This is an approximation: AI images carry no real depth, so for
hero assets a hand-tuned map from a tool such as Laigter will look better.

Art written at a higher resolution than its layout size (see density.json and
tools/fit_art.py) gets a proportionally wider blur and steeper slope, so it
shades the same as it would at layout size.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_placeholders import normal_from_height  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIT_DIRS = ["props", "terrain", "actors"]


def pixel_scale(path):
    """Pixels per layout pixel for a file under assets/final (1 elsewhere)."""
    final = os.path.join(ROOT, "assets", "final")
    rel = os.path.relpath(os.path.abspath(path), final).replace(os.sep, "/")
    dpath = os.path.join(final, "density.json")
    if rel.startswith("..") or not os.path.exists(dpath):
        return 1.0
    with open(dpath, encoding="utf-8") as f:
        k = json.load(f).get(rel, 1.0)
    return 1.0 / k


def make(path, wrap=False, strength=3.0, blur=2.0):
    sc = pixel_scale(path)
    strength, blur = strength * sc, blur * sc
    img = Image.open(path).convert("RGBA")
    rgba = np.asarray(img).astype(np.float32) / 255.0
    lum = rgba[..., :3].mean(-1)
    alpha = rgba[..., 3]
    h = np.clip(alpha * 0.7 + lum * 0.3 * alpha, 0, 1)
    h_img = Image.fromarray((h * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(blur))
    height = np.asarray(h_img).astype(np.float32) / 255.0
    n = normal_from_height(height, strength, wrap)
    out = np.concatenate([n, np.asarray(img)[..., 3:4]], -1)
    dst = path[:-4] + "_n.png"
    Image.fromarray(out, "RGBA").save(dst)
    print("wrote", os.path.relpath(dst, ROOT))


def main(argv):
    wrap = "--wrap" in argv
    files = [a for a in argv if not a.startswith("--")]
    if "--all" in argv:
        for d in LIT_DIRS:
            base = os.path.join(ROOT, "assets", "final", d)
            for dp, _, fs in os.walk(base):
                for f in fs:
                    if f.endswith(".png") and not f.endswith("_n.png"):
                        files.append(os.path.join(dp, f))
    for f in files:
        make(f, wrap=wrap or "/terrain/" in f.replace("\\", "/"))


if __name__ == "__main__":
    main(sys.argv[1:])
