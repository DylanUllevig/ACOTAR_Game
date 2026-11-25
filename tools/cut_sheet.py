#!/usr/bin/env python3
"""Cut a generated sheet of separate objects into one image per object.

    python3 tools/cut_sheet.py sheet.png outdir arrow ash_arrow bow bread coin ...

The sheet holds objects on a transparent background with empty space between
them, laid out in rows (a grid of icons, or a single row of effect sprites).
Objects are found as connected areas of the alpha channel (small specks are
ignored and pieces closer than --join pixels are merged, so a loose bow string
or a hare's whisker stays with its object), ordered row by row, top to bottom
and left to right, and written as <outdir>/<name>.png, cropped with a margin.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet")
    ap.add_argument("outdir")
    ap.add_argument("names", nargs="+")
    ap.add_argument("--join", type=int, default=24, help="merge pieces closer than this many pixels")
    ap.add_argument("--margin", type=int, default=8)
    args = ap.parse_args()

    img = Image.open(args.sheet).convert("RGBA")
    px = np.asarray(img)
    solid = px[..., 3] > 40
    # grow each piece so near neighbours touch, label, then keep labels on the original pixels
    grown = ndimage.binary_dilation(solid, iterations=max(1, args.join // 2))
    labels, n = ndimage.label(grown)
    labels = np.where(solid, labels, 0)
    found = []
    for i, sl in enumerate(ndimage.find_objects(labels), start=1):
        if sl is None:
            continue
        area = int((labels[sl] == i).sum())
        if area < solid.sum() * 0.002:
            continue
        found.append((sl, i, area))
    if len(found) != len(args.names):
        sys.exit("found %d objects in %s, expected %d" % (len(found), args.sheet, len(args.names)))

    # order into rows: objects whose vertical centres are within half a typical
    # object height of each other share a row
    centres = [((sl[0].start + sl[0].stop) / 2, (sl[1].start + sl[1].stop) / 2) for sl, _, _ in found]
    heights = sorted(sl[0].stop - sl[0].start for sl, _, _ in found)
    tol = heights[len(heights) // 2] / 2
    order = sorted(range(len(found)), key=lambda k: centres[k][0])
    rows, row = [], [order[0]]
    for k in order[1:]:
        if abs(centres[k][0] - np.mean([centres[j][0] for j in row])) < tol:
            row.append(k)
        else:
            rows.append(row)
            row = [k]
    rows.append(row)
    ordered = [k for r in rows for k in sorted(r, key=lambda j: centres[j][1])]

    os.makedirs(args.outdir, exist_ok=True)
    h, w = solid.shape
    for name, k in zip(args.names, ordered):
        sl, label, _ = found[k]
        y0, y1 = max(0, sl[0].start - args.margin), min(h, sl[0].stop + args.margin)
        x0, x1 = max(0, sl[1].start - args.margin), min(w, sl[1].stop + args.margin)
        piece = px[y0:y1, x0:x1].copy()
        # drop anything that belongs to a neighbour
        piece[..., 3] = np.where(labels[y0:y1, x0:x1] == label, piece[..., 3],
                                 np.where(labels[y0:y1, x0:x1] == 0, piece[..., 3], 0))
        out = os.path.join(args.outdir, name + ".png")
        Image.fromarray(piece, "RGBA").save(out)
        print("%-16s %4dx%-4d at %d,%d" % (name, x1 - x0, y1 - y0, x0, y0))


if __name__ == "__main__":
    main()
