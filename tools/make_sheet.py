#!/usr/bin/env python3
"""Build a 4 x 4 character sheet from generated figure strips.

    python3 tools/make_sheet.py actor.nesta --views turnaround.png
    python3 tools/make_sheet.py actor.feyre --views turnaround.png \\
        --walk down=walk_down.png --walk right=walk_right.png --walk up=walk_up.png

A strip is one image holding several full-body figures side by side on a
transparent background, with empty space between them. --views takes a
turnaround of three figures (facing the viewer, facing right, facing away), or
four (facing the viewer, facing left, facing right, facing away); --view-order
changes that. A missing left view is the right view mirrored.

Sheet rows face down, left, right, up; columns are the steps of a walk, and
column 0 is also the standing pose. A row with --walk <row>=<strip> takes its
four frames from that strip (ordered standing, step, standing, step: the strip
should hold four frames, or two contact poses, which are padded with the
standing view). Rows without a walk strip repeat the standing view, which is
all the non-player characters need since they never walk.

Every figure in a sheet is scaled by the same factor, so views keep their
relative size, set with the feet on the bottom of the frame and the torso
centred. Output size and density follow fit_art.py (twice the layout size).
"""
import argparse
import os
import subprocess
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fit_art import ROOT, manifest_entry, record_density, resize_rgba  # noqa: E402

ROWS = ["down", "left", "right", "up"]
FIGURE_FILL = 60 / 64      # placeholder figures stand 60 px tall in a 64 px frame
FOOT_MARGIN = 1 / 64       # and leave a pixel under the feet


def load(path):
    img = Image.open(path).convert("RGBA")
    px = np.asarray(img).copy()
    px[..., 3] = np.where(px[..., 3] >= 250, 255, px[..., 3])
    return Image.fromarray(px, "RGBA")


def figures(img, count=None, min_gap=0.01):
    """Split a strip into figures by empty columns; returns tight crops, left to right."""
    a = np.asarray(img)[..., 3].astype(np.float32)
    cols = (a > 24).sum(0) > 0
    runs, start = [], None
    for x, on in enumerate(cols):
        if on and start is None:
            start = x
        elif not on and start is not None:
            runs.append([start, x])
            start = None
    if start is not None:
        runs.append([start, len(cols)])
    # join runs split by hairline gaps (a bow tip, a loose strand of hair)
    gap = max(2, int(img.width * min_gap))
    merged = []
    for r in runs:
        if merged and r[0] - merged[-1][1] < gap:
            merged[-1][1] = r[1]
        else:
            merged.append(r)
    mass = [a[:, x0:x1].sum() for x0, x1 in merged]
    keep = sorted(range(len(merged)), key=lambda i: -mass[i])[:count] if count else range(len(merged))
    out = []
    for i in sorted(keep):
        x0, x1 = merged[i]
        sub = a[:, x0:x1]
        ys = np.nonzero((sub > 8).any(1))[0]
        out.append(img.crop((x0, int(ys.min()), x1, int(ys.max()) + 1)))
    return out


def torso_x(fig):
    """Alpha-weighted centre of the head and torso (top 55%), which stays put
    while legs and cloak swing."""
    a = np.asarray(fig)[..., 3].astype(np.float32)
    top = a[: max(1, int(a.shape[0] * 0.55))]
    w = top.sum(0)
    return float((w * np.arange(len(w))).sum() / max(w.sum(), 1e-6))


def place(fig, frame, scale):
    fw, fh = frame
    nw, nh = max(1, round(fig.width * scale)), max(1, round(fig.height * scale))
    small = resize_rgba(fig, (nw, nh))
    canvas = Image.new("RGBA", frame, (0, 0, 0, 0))
    x = round(fw / 2 - torso_x(fig) * scale)
    y = round(fh - fh * FOOT_MARGIN - nh)
    canvas.alpha_composite(small, (max(0, min(fw - nw, x)), max(0, y)))
    return canvas


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("asset_id")
    ap.add_argument("--views", required=True)
    ap.add_argument("--view-order", default=None,
                    help="comma list naming each figure in --views, e.g. down,right,up ('skip' drops one)")
    ap.add_argument("--walk", action="append", default=[], help="row=strip.png")
    ap.add_argument("--scale", type=float, default=2.0)
    ap.add_argument("--no-normals", action="store_true")
    args = ap.parse_args()

    a = manifest_entry(args.asset_id)
    lw, lh = a["size"]
    sheet_w, sheet_h = round(lw * args.scale), round(lh * args.scale)
    frame = (sheet_w // 4, sheet_h // 4)

    views_img = load(args.views)
    figs = figures(views_img)
    order = args.view_order.split(",") if args.view_order else (
        ["down", "right", "up"] if len(figs) == 3 else ["down", "left", "right", "up"])
    if len(figs) != len(order):
        sys.exit("found %d figures in %s, expected %d" % (len(figs), args.views, len(order)))
    stand = {n: f for n, f in zip(order, figs) if n != "skip"}
    if "left" not in stand:
        stand["left"] = stand["right"].transpose(Image.FLIP_LEFT_RIGHT)
    if "right" not in stand:
        stand["right"] = stand["left"].transpose(Image.FLIP_LEFT_RIGHT)

    rows = {r: [stand[r]] * 4 for r in ROWS}
    for spec in args.walk:
        r, path = spec.split("=", 1)
        steps = figures(load(path))
        if len(steps) == 2:
            steps = [stand[r], steps[0], stand[r], steps[1]]
        if len(steps) != 4:
            sys.exit("walk strip %s has %d figures, expected 2 or 4" % (path, len(steps)))
        rows[r] = steps
    if any(s.startswith("right=") for s in args.walk) and not any(s.startswith("left=") for s in args.walk):
        rows["left"] = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in rows["right"]]

    tallest = max(f.height for r in ROWS for f in rows[r])
    widest = max(f.width for r in ROWS for f in rows[r])
    scale = min(frame[1] * FIGURE_FILL / tallest, frame[0] * 0.98 / widest)
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))
    for ri, r in enumerate(ROWS):
        for ci, f in enumerate(rows[r]):
            sheet.alpha_composite(place(f, frame, scale), (ci * frame[0], ri * frame[1]))

    dst = os.path.join(ROOT, a["final"])
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    sheet.save(dst)
    rel = os.path.relpath(dst, os.path.join(ROOT, "assets", "final")).replace(os.sep, "/")
    record_density(rel, lh / sheet_h)
    print("wrote", os.path.relpath(dst, ROOT), "%dx%d" % sheet.size, "frames %dx%d" % frame,
          "figure %.0f px tall" % (tallest * scale))
    if not args.no_normals:
        subprocess.run([sys.executable, os.path.join(ROOT, "tools", "make_normals.py"), dst], check=True)


if __name__ == "__main__":
    main()
