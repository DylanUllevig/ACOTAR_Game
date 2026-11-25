#!/usr/bin/env python3
"""Turn a generated strip (a path, brook or road running left to right across
the middle of the image) into a texture for Region.add_strip.

    python3 tools/make_strip.py strip.path_snow source.png
    python3 tools/make_strip.py strip.brook source.png --inner 0.3 --outer 0.46

The result wraps left to right (cut, not blended, see seams.py), and its top
and bottom fade to transparent along a wavering line, so the strip lies on
whatever ground is under it. --inner and --outer are distances from the
centre line, as fractions of the height, where the fade starts and ends.
Height is twice the manifest's layout height; normals are made with --wrap.
"""
import argparse
import os
import subprocess
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fit_art import ROOT, manifest_entry, record_density  # noqa: E402
from seams import periodic_noise, wrap_x  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("asset_id")
    ap.add_argument("source")
    ap.add_argument("--inner", type=float, default=0.24)
    ap.add_argument("--outer", type=float, default=0.42)
    ap.add_argument("--wobble", type=float, default=0.05, help="how far the fade line wanders, as a fraction of the height")
    ap.add_argument("--overlap", type=float, default=0.14, help="fraction of the width used to join the ends")
    ap.add_argument("--scale", type=float, default=2.0)
    args = ap.parse_args()

    a = manifest_entry(args.asset_id)
    lh = a["size"][1]
    th = round(lh * args.scale)
    src = Image.open(args.source).convert("RGB")
    tw = round(src.width * th / src.height)
    img = np.asarray(src.resize((tw, th), Image.LANCZOS)).astype(np.float32)
    img = wrap_x(img, tw * args.overlap)
    h, w = img.shape[:2]

    y = (np.arange(h)[:, None] + 0.5) / h
    dist = np.abs(y - 0.5)
    top = periodic_noise(w, 1)[None, :] * args.wobble
    bottom = periodic_noise(w, 2)[None, :] * args.wobble
    edge = np.where(y < 0.5, top, bottom)
    t = np.clip((dist + edge - args.inner) / (args.outer - args.inner), 0.0, 1.0)
    alpha = 1.0 - t * t * (3.0 - 2.0 * t)

    out = np.dstack([img, alpha * 255.0]).round().clip(0, 255).astype(np.uint8)
    dst = os.path.join(ROOT, a["final"])
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    Image.fromarray(out, "RGBA").save(dst)
    rel = os.path.relpath(dst, os.path.join(ROOT, "assets", "final")).replace(os.sep, "/")
    record_density(rel, lh / h)
    print("wrote", os.path.relpath(dst, ROOT), "%dx%d" % (w, h), "(layout height %d)" % lh)
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "make_normals.py"), "--wrap", dst], check=True)


if __name__ == "__main__":
    main()
