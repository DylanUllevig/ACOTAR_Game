"""Turns a generated 'pixel art' image into true pixel art.

A generated image draws each art pixel as a block of roughly N x N screen
pixels, but the blocks drift, their edges are soft and the "transparent"
background is a faint haze. This:

  1. finds the shapes on the sheet (opaque areas, close bits merged),
  2. estimates the block size from the whole sheet (autocorrelation of where
     colour changes, refined by folding),
  3. for every shape finds its own grid lines with dynamic programming: cut
     lines go where colour edges are strongest, spaced near the block size,
     so the grid follows the drift instead of fighting it,
  4. samples the middle of every cell (median colour, majority alpha),
  5. drops lone specks and fills pinholes, and reduces each shape's colours.

    python3 -I tools/pixel/pixelize.py IN.png OUT_DIR --name base [--colors 40]
        writes base_00.png, base_01.png ... (reading order) and prints JSON
    python3 -I tools/pixel/pixelize.py IN.png OUT_DIR --name base --sheet 4x4 [--mirror-right]
        assembles the shapes, read as a grid of frames, into one evenly spaced
        sheet base.png (feet on the bottom of each frame, bodies centred)
"""
import argparse
import json
import os
import numpy as np
from PIL import Image
from scipy import ndimage


# ------------------------------------------------------------------ shapes
def load(path):
    im = Image.open(path)
    arr = np.asarray(im.convert("RGBA")).astype(np.float32)
    return arr


def find_shapes(arr, alpha_cut=128, merge=5, min_area=150):
    """Opaque shapes as (y0, x0, y1, x1) boxes, in reading order."""
    mask = arr[:, :, 3] >= alpha_cut
    grown = ndimage.binary_dilation(mask, iterations=merge)
    lab, n = ndimage.label(grown, structure=np.ones((3, 3)))
    boxes = []
    for k, sl in enumerate(ndimage.find_objects(lab), start=1):
        if sl is None:
            continue
        sub = (lab[sl] == k) & mask[sl]
        if sub.sum() < min_area:
            continue
        ys, xs = np.nonzero(sub)
        boxes.append((sl[0].start + ys.min(), sl[1].start + xs.min(), sl[0].start + ys.max() + 1, sl[1].start + xs.max() + 1, k))
    return boxes, lab, mask


def reading_order(boxes):
    """Group boxes into rows (by vertical overlap) and sort each row left to right."""
    rows = []
    for b in sorted(boxes, key=lambda b: (b[0] + b[2]) / 2):
        cy = (b[0] + b[2]) / 2
        for r in rows:
            if r["y0"] - 4 <= cy <= r["y1"] + 4:
                r["items"].append(b)
                r["y0"] = min(r["y0"], b[0])
                r["y1"] = max(r["y1"], b[2])
                break
        else:
            rows.append({"y0": b[0], "y1": b[2], "items": [b]})
    rows.sort(key=lambda r: r["y0"])
    return [sorted(r["items"], key=lambda b: b[1]) for r in rows]


# -------------------------------------------------------------------- grid
def edge_profiles(arr, mask):
    a = arr[:, :, 3:4] / 255.0
    rgb = arr[:, :, :3] * a
    dx = np.abs(np.diff(rgb, axis=1)).sum(axis=2) + np.abs(np.diff(arr[:, :, 3], axis=1)) * 0.6
    dy = np.abs(np.diff(rgb, axis=0)).sum(axis=2) + np.abs(np.diff(arr[:, :, 3], axis=0)) * 0.6
    # only count the strong, crisp steps: soft ramps inside a block are noise
    dx = np.where(dx > 18, dx, 0)
    dy = np.where(dy > 18, dy, 0)
    m = ndimage.binary_dilation(mask, iterations=2)
    dx *= (m[:, 1:] | m[:, :-1])
    dy *= (m[1:, :] | m[:-1, :])
    return dx.sum(axis=0), dy.sum(axis=1)


def block_size(arr, mask, lo=2.5, hi=14.0):
    px, py = edge_profiles(arr, mask)
    best = None
    scores = []
    for s in np.arange(lo, hi, 0.02):
        sc = 0.0
        for prof in (px, py):
            pos = np.arange(len(prof)) + 0.5
            ph = (pos % s) / s * 2 * np.pi
            # strength of the fundamental of the fold, normalised: 1 = every
            # edge lands on one phase, 0 = spread evenly
            c = np.abs((prof * np.exp(1j * ph)).sum()) / (prof.sum() + 1e-9)
            sc += c
        scores.append((s, sc / 2))
    scores = np.array(scores)
    top = scores[:, 1].max()
    # the true size and its multiples score alike; take the smallest that is
    # nearly as good as the best (its halves score far lower)
    ok = scores[scores[:, 1] >= top * 0.8]
    s0 = ok[0, 0]
    # refine: best score within +-8 % of that first good size
    near = scores[(scores[:, 0] >= s0 * 0.94) & (scores[:, 0] <= s0 * 1.08)]
    s0 = near[np.argmax(near[:, 1]), 0]
    return float(s0), float(top)


def dp_cuts(prof, s, lam=0.35):
    """Cut positions (edge index x = between pixel x and x+1) spaced about s
    apart that collect the most edge energy."""
    n = len(prof)
    if n < 2:
        return [-1, n - 1]
    p = prof / (np.mean(prof[prof > 0]) + 1e-9) if (prof > 0).any() else prof * 0
    gmin = max(2, int(np.floor(s * 0.72)))
    gmax = max(gmin + 1, int(np.ceil(s * 1.3)))
    neg = -1e18
    best = np.full(n, neg)
    back = np.full(n, -1, int)
    first = int(np.ceil(s * 1.3))
    for x in range(n):
        if x < first:
            best[x] = p[x] - lam * 0.5   # a first cut anywhere near the start
        for g in range(gmin, gmax + 1):
            y = x - g
            if y < 0:
                break
            v = best[y] + p[x] - lam * ((g - s) / s * 4) ** 2
            if v > best[x]:
                best[x] = v
                back[x] = y
    tail = max(0, n - first)
    end = tail + int(np.argmax(best[tail:]))
    cuts = []
    x = end
    while x >= 0:
        cuts.append(x)
        x = back[x]
    cuts.reverse()
    # pad with whole cells beyond the first and last cut
    while cuts[0] - s > -1:
        cuts.insert(0, int(round(cuts[0] - s)))
    while cuts[-1] + s < n:
        cuts.append(int(round(cuts[-1] + s)))
    return cuts


def sample(arr, mask, xc, yc, alpha_frac=0.5):
    ny, nx = len(yc) - 1, len(xc) - 1
    h, w = mask.shape
    out = np.zeros((ny, nx, 4), np.uint8)
    for j in range(ny):
        y0, y1 = yc[j] + 1, yc[j + 1] + 1      # cell rows y0..y1-1
        cy0, cy1 = max(0, y0), min(h, y1)
        if y1 - y0 >= 4:
            cy0, cy1 = max(0, y0 + 1), min(h, y1 - 1)
        for i in range(nx):
            x0, x1 = xc[i] + 1, xc[i + 1] + 1
            cx0, cx1 = max(0, x0), min(w, x1)
            if x1 - x0 >= 4:
                cx0, cx1 = max(0, x0 + 1), min(w, x1 - 1)
            if cy1 <= cy0 or cx1 <= cx0:
                continue
            m = mask[cy0:cy1, cx0:cx1]
            if m.mean() < alpha_frac:
                continue
            px = arr[cy0:cy1, cx0:cx1, :3][m]
            # the cell's most typical real colour: the pixel nearest the
            # others (a median of each channel can invent a colour that is in
            # neither half of a cell that straddles an edge)
            if len(px) > 2:
                d = np.abs(px[:, None, :] - px[None, :, :]).sum(axis=2).sum(axis=1)
                out[j, i, :3] = px[int(np.argmin(d))]
            else:
                out[j, i, :3] = px[0]
            out[j, i, 3] = 255
    return out


def clean(px):
    a = px[:, :, 3] > 0
    nb = ndimage.convolve(a.astype(int), np.ones((3, 3), int), mode="constant") - a
    specks = a & (nb == 0)
    px[specks] = 0
    a = px[:, :, 3] > 0
    four = ndimage.convolve(a.astype(int), np.array([[0, 1, 0], [1, 0, 1], [0, 1, 0]]), mode="constant")
    holes = (~a) & (four == 4)
    if holes.any():
        # fill a pinhole with the mean of its four neighbours
        ys, xs = np.nonzero(holes)
        for y, x in zip(ys, xs):
            nbrs = [px[y - 1, x], px[y + 1, x], px[y, x - 1], px[y, x + 1]]
            px[y, x, :3] = np.mean([n[:3] for n in nbrs], axis=0)
            px[y, x, 3] = 255
    return px


def reduce_colors(px, n):
    if n <= 0:
        return px
    a = px[:, :, 3]
    if (a > 0).sum() == 0:
        return px
    img = Image.fromarray(px[:, :, :3], "RGB")
    q = img.quantize(colors=n, method=Image.Quantize.MEDIANCUT, kmeans=4, dither=Image.Dither.NONE).convert("RGB")
    out = np.dstack([np.asarray(q), a]).astype(np.uint8)
    out[a == 0] = 0
    return out


def trim(px):
    a = px[:, :, 3] > 0
    if not a.any():
        return px, (0, 0)
    ys, xs = np.nonzero(a)
    return px[ys.min():ys.max() + 1, xs.min():xs.max() + 1], (int(xs.min()), int(ys.min()))


def pixelize_shape(arr, lab, mask, box, s, colors, margin=6):
    y0, x0, y1, x1, k = box
    h, w = mask.shape
    Y0, X0, Y1, X1 = max(0, y0 - margin), max(0, x0 - margin), min(h, y1 + margin), min(w, x1 + margin)
    sub = arr[Y0:Y1, X0:X1]
    m = mask[Y0:Y1, X0:X1] & (lab[Y0:Y1, X0:X1] == k)
    sub = sub.copy()
    sub[~m] = 0
    px, py = edge_profiles(sub, m)
    xc = dp_cuts(px, s)
    yc = dp_cuts(py, s)
    out = sample(sub, m, xc, yc)
    out = clean(out)
    out = reduce_colors(out, colors)
    out, off = trim(out)
    gaps = np.diff(xc).tolist() + np.diff(yc).tolist()
    return out, {"src_box": [int(x0), int(y0), int(x1 - x0), int(y1 - y0)], "cells": [len(xc) - 1, len(yc) - 1],
                 "gap_mean": round(float(np.mean(gaps)), 2), "gap_sd": round(float(np.std(gaps)), 2)}


# ------------------------------------------------------------------- sheet
def body_center_x(px):
    a = px[:, :, 3] > 0
    h = a.shape[0]
    top = a[: max(1, int(h * 0.6))]
    ys, xs = np.nonzero(top)
    if len(xs) == 0:
        ys, xs = np.nonzero(a)
    return float(xs.mean())


def assemble(frames, cols, rows, pad=2):
    fw = max(f.shape[1] for f in frames) + pad * 2
    fh = max(f.shape[0] for f in frames) + pad
    fw += fw % 2
    sheet = np.zeros((fh * rows, fw * cols, 4), np.uint8)
    for idx, f in enumerate(frames):
        r, c = divmod(idx, cols)
        cx = body_center_x(f)
        x = int(round(fw / 2 - cx))
        x = min(max(x, 0), fw - f.shape[1])
        y = fh - f.shape[0]   # feet on the bottom row of the frame
        sheet[r * fh + y:r * fh + y + f.shape[0], c * fw + x:c * fw + x + f.shape[1]] = f
    return sheet, fw, fh


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--name", required=True)
    ap.add_argument("--colors", type=int, default=40)
    ap.add_argument("--alpha", type=int, default=128)
    ap.add_argument("--merge", type=int, default=5)
    ap.add_argument("--min-area", type=int, default=150)
    ap.add_argument("--size", type=float, default=None, help="block size, if known")
    ap.add_argument("--sheet", default=None, help="CxR: assemble the shapes as a grid of frames")
    ap.add_argument("--mirror-right", action="store_true", help="sheet row 3 = row 2 mirrored")
    a = ap.parse_args()
    arr = load(a.src)
    boxes, lab, mask = find_shapes(arr, a.alpha, a.merge, a.min_area)
    s, score = (a.size, 0.0) if a.size else block_size(arr, mask)
    os.makedirs(a.out, exist_ok=True)
    info = {"block": round(s, 3), "score": round(score, 3), "shapes": []}
    rows = reading_order(boxes)
    info["rows"] = [len(r) for r in rows]
    frames = []
    for r in rows:
        for b in r:
            px, meta = pixelize_shape(arr, lab, mask, b, s, a.colors)
            frames.append(px)
            meta["size"] = [int(px.shape[1]), int(px.shape[0])]
            info["shapes"].append(meta)
    if a.sheet:
        cols, nrows = [int(v) for v in a.sheet.lower().split("x")]
        want = cols * nrows
        if len(frames) != want:
            info["error"] = "expected %d frames, found %d" % (want, len(frames))
            print(json.dumps(info))
            raise SystemExit(2)
        if a.mirror_right and nrows >= 3:
            for c in range(cols):
                frames[2 * cols + c] = frames[1 * cols + c][:, ::-1].copy()
        sheet, fw, fh = assemble(frames, cols, nrows)
        Image.fromarray(sheet, "RGBA").save(os.path.join(a.out, a.name + ".png"))
        info["frame"] = [fw, fh]
    else:
        for k, px in enumerate(frames):
            fn = "%s_%02d.png" % (a.name, k)
            Image.fromarray(px, "RGBA").save(os.path.join(a.out, fn))
            info["shapes"][k]["file"] = fn
    print(json.dumps(info))


if __name__ == "__main__":
    main()
