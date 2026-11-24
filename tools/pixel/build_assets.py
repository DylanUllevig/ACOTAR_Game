"""Builds the game's pixel sprites from generated pixel-art sheets.

Reads the 1024 / 2048 px images that came from the image generator (in the
project's art_pipeline/incoming folder, not in the repo), turns each into
true pixel art with pixelize.py, and writes:

  assets/pixel/actors/<name>.png   people: 4 x 4 walk sheets, rows facing
                                   down, left, right, up; feet on the bottom
                                   of every frame
                                   creatures: one row-major grid of frames,
                                   facing right
  assets/pixel/props/<name>.png    single trimmed sprites, origin = bottom middle
  assets/pixel/meta.json           frame grid, frame size and named animations

    python3 -I tools/pixel/build_assets.py INCOMING_DIR [name ...]
"""
import json
import os
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import pixelize as pz  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "assets", "pixel")

PEOPLE = ["feyre", "nesta", "elain", "father", "isaac", "villager", "villager_woman", "acolyte", "mercenary"]

# creatures: source, grid of the source (cols x rows, reading order), frames
# kept, animations (indices into the kept frames)
CREATURES = {
    "wolf": {"src": "px.wolf.png", "grid": (2, 4), "anims": {"walk": [0, 1, 2, 3], "leap": [4], "snarl": [5], "crouch": [6], "dead": [7]},
             "eyes": "amber"},
    "doe": {"src": "px.doe.png", "grid": (4, 3), "anims": {"walk": [0, 1, 2, 3], "run": [4, 5, 6, 7], "graze": [8], "alert": [9], "look": [10], "dead": [11]}},
    "hare": {"src": "px.hare.png", "grid": (4, 3), "anims": {"hop": [0, 1, 2, 3], "run": [4, 5, 6, 7], "sit": [8], "alert": [9], "crouch": [10], "dead": [11]}},
    "beast": {"src": "px.beast.png", "grid": (2, 2), "anims": {"rear": [0], "side": [1], "snarl": [2], "sit": [3]}},
    "mare": {"src": "px2k.mare.png", "grid": (2, 4), "anims": {"walk": [0, 1, 2, 3], "stand": [4], "rear": [5], "ride_side": [6], "ride_rear": [7]}},
    # small life, one row of the critter sheet each, drawn smaller than the
    # sheet ('f' = how many source blocks make one art pixel)
    "crow": {"src": "px.critters.png", "row": 0, "f": 1.35, "grid": (4, 1), "anims": {"idle": [0], "peck": [1], "fly": [2, 3]}},
    "robin": {"src": "px.critters.png", "row": 1, "f": 1.6, "grid": (4, 1), "anims": {"idle": [0], "peck": [1], "fly": [2, 3]}},
    "squirrel": {"src": "px.critters.png", "row": 2, "f": 1.55, "grid": (4, 1), "anims": {"sit": [0], "run": [1, 2], "eat": [3]}},
    "fox": {"src": "px.critters.png", "row": 3, "f": 1.1, "grid": (4, 1), "anims": {"sit": [0], "trot": [1, 2], "sleep": [3]}},
}

# single props: name -> (source, which shape on the sheet in reading order)
# or (source, index, f, px): f = source blocks per art pixel (1 = as drawn,
# larger = smaller and coarser), px = world density multiplier (2 = scenery,
# the default; 1 = the people's density, for furniture seen close up indoors)
PROPS = {
    "house_a": ("px2k.house_a.png", 0, 1.3),
    "house_b": ("px.house_b.png", 0, 1.3),
    "barn": ("px.barn.png", 0, 1.3),
    "cottage_family": ("px.cottage_family.png", 0, 1.1),
    # first winter set (1024 px sheet, 4 px blocks)
    "pine_0": ("px2k.pines.png", 0),
    "pine_1": ("px2k.pines.png", 1),
    "pine_2": ("pxtest.winter_props.png", 0),
    "pine_3": ("pxtest.winter_props.png", 1),
    "pine_4": ("pxtest.winter_props.png", 2),
    "bare_tree_0": ("pxtest.winter_props.png", 3),
    "bare_tree_1": ("pxtest.winter_props.png", 3),
    "rock_0": ("pxtest.winter_props.png", 4),
    "rock_1": ("pxtest.winter_props.png", 5),
    "log": ("pxtest.winter_props.png", 6),
    "stump": ("pxtest.winter_props.png", 7),
    "holly": ("pxtest.winter_props.png", 8),
    "bramble": ("pxtest.winter_props.png", 9),
    # forest plants (5 px blocks), most drawn smaller than the sheet
    "rose_bush": ("px.forest_plants.png", 0, 1.45),
    "rose_bush_bare": ("px.forest_plants.png", 1, 1.45),
    "reeds": ("px.forest_plants.png", 2, 1.45),
    "grass_tuft": ("px.forest_plants.png", 3, 2.4),
    "fern": ("px.forest_plants.png", 4, 2.0),
    "snow_mound": ("px.forest_plants.png", 5, 1.7),
    "branch": ("px.forest_plants.png", 6, 1.8),
    "pinecones": ("px.forest_plants.png", 7, 3.2),
    "root_stump": ("px.forest_plants.png", 8, 1.5),
    # village (3.6 px blocks)
    "cottage_small": ("pxtest.village_props.png", 0, 1.4),
    "shed": ("pxtest.village_props.png", 1, 1.4),
    "stall_red": ("pxtest.village_props.png", 2, 1.8),
    "stall_blue": ("pxtest.village_props.png", 2, 1.8, 2, "blue_awning"),
    "well": ("pxtest.village_props.png", 3, 1.6),
    "fountain_broken": ("pxtest.village_props.png", 4, 1.4),
    "fence": ("pxtest.village_props.png", 5, 1.6),
    "barrels": ("pxtest.village_props.png", 6, 1.8),
    "crates": ("pxtest.village_props.png", 7, 1.8),
    "cart": ("pxtest.village_props.png", 8, 1.5),
    # village details (5 px blocks)
    "lamp_post": ("px.village_details.png", 0, 1.25),
    "signpost": ("px.village_details.png", 1, 1.3),
    "woodshed": ("px.village_details.png", 2, 1.2),
    "hay_bales": ("px.village_details.png", 3, 1.3),
    "snowman": ("px.village_details.png", 4, 1.4),
    "bench": ("px.village_details.png", 5, 1.5),
    "rail_fence": ("px.village_details.png", 6, 1.3),
    "stone_wall": ("px.village_details.png", 7, 1.3),
    "wheelbarrow": ("px.village_details.png", 8, 1.6),
    "trough": ("px.village_details.png", 9, 1.5),
    "buckets": ("px.village_details.png", 10, 2.0),
    "wreath_post": ("px.village_details.png", 11, 1.5),
    # cottage furniture (4 px blocks), at the people's density
    "hearth": ("px.interior.png", 0, 1.0, 1),
    "table": ("px.interior.png", 1, 1.0, 1),
    "stool": ("px.interior.png", 2, 1.2, 1),
    "bench_in": ("px.interior.png", 3, 1.0, 1),
    "bed_patch": ("px.interior.png", 4, 1.0, 1),
    "bed_rose": ("px.interior.png", 5, 1.0, 1),
    "dresser": ("px.interior.png", 6, 1.0, 1),
    "shelf": ("px.interior.png", 7, 1.0, 1),
    "chest": ("px.interior.png", 8, 1.0, 1),
    "washstand": ("px.interior.png", 9, 1.0, 1),
    "rug": ("px.interior.png", 10, 1.0, 1),
    "easel": ("px.interior.png", 11, 1.0, 1),
}


def shapes_of(path, colors=0, f=1.0, rows_wanted=None, drop_small=True):
    """Every shape on a sheet in reading order, pixelized at the sheet's block
    size times f. Returns (frames, row lengths, block size). Shapes much
    smaller than the others in their row (crumbs, sparks) are left out."""
    arr = pz.load(path)
    boxes, lab, mask = pz.find_shapes(arr, 128, 5, 150)
    s, _ = pz.block_size(arr, mask)
    rows = pz.reading_order(boxes)
    if drop_small:
        kept = []
        for r in rows:
            areas = [(b[2] - b[0]) * (b[3] - b[1]) for b in r]
            med = float(np.median(areas))
            kept.append([b for b, a in zip(r, areas) if a >= 0.2 * med])
        rows = kept
    out = []
    lens = []
    for i, r in enumerate(rows):
        if rows_wanted is not None and i not in rows_wanted:
            continue
        lens.append(len(r))
        for b in r:
            px, meta = pz.pixelize_shape(arr, lab, mask, b, s * f, colors)
            out.append(px)
    return out, lens, s * f


def eye_points(px, kind):
    """Centre of the glowing-eye pixels of a frame (amber: strong red, mid
    green, low blue), or None."""
    rgb = px[:, :, :3].astype(int)
    a = px[:, :, 3] > 0
    if kind == "amber":
        m = a & (rgb[:, :, 0] > 170) & (rgb[:, :, 1] > 90) & (rgb[:, :, 1] < 200) & (rgb[:, :, 2] < 110) & (rgb[:, :, 0] - rgb[:, :, 2] > 110)
    else:
        return None
    ys, xs = np.nonzero(m)
    if len(xs) == 0:
        return None
    # the eye is the cluster nearest the head: take the topmost few pixels
    order = np.argsort(ys)[:6]
    return float(xs[order].mean()), float(ys[order].mean())


def build_people(incoming, names, meta):
    for n in names:
        src = os.path.join(incoming, "px.%s.png" % n)
        if not os.path.exists(src):
            print("missing", src)
            continue
        frames, rows, s = shapes_of(src)
        if len(frames) != 16 or rows != [4, 4, 4, 4]:
            print("SKIP", n, "rows", rows)
            continue
        sheet, fw, fh = pz.assemble(frames, 4, 4)
        rel = "actors/%s.png" % n
        Image.fromarray(sheet, "RGBA").save(os.path.join(OUT, rel))
        h = int(np.median([f.shape[0] for f in frames[:4]]))
        meta[rel] = {"grid": [4, 4], "frame": [fw, fh], "height": h, "block": round(s, 2)}
        print("person", n, "frame", fw, fh, "height", h)


def build_creatures(incoming, names, meta):
    for n in names:
        spec = CREATURES[n]
        src = os.path.join(incoming, spec["src"])
        if not os.path.exists(src):
            print("missing", src)
            continue
        frames, rows, s = shapes_of(src, 0, spec.get("f", 1.0), [spec["row"]] if "row" in spec else None)
        cols, nrows = spec["grid"]
        if len(frames) != cols * nrows:
            print("SKIP", n, "found", len(frames), "rows", rows)
            continue
        # generated facing left; the game's creatures face right and flip
        frames = [f[:, ::-1].copy() for f in frames]
        gc = 4 if len(frames) >= 4 else len(frames)
        gr = int(np.ceil(len(frames) / gc))
        fw = max(f.shape[1] for f in frames) + 4
        fh = max(f.shape[0] for f in frames) + 2
        fw += fw % 2
        sheet = np.zeros((fh * gr, fw * gc, 4), np.uint8)
        eyes = []
        for i, f in enumerate(frames):
            r, c = divmod(i, gc)
            x = (fw - f.shape[1]) // 2          # centred on its box
            y = fh - f.shape[0]                 # feet on the bottom
            sheet[r * fh + y:r * fh + y + f.shape[0], c * fw + x:c * fw + x + f.shape[1]] = f
            if spec.get("eyes"):
                e = eye_points(f, spec["eyes"])
                # relative to the frame's origin: bottom middle
                eyes.append(None if e is None else [round(x + e[0] - fw / 2, 1), round(y + e[1] - fh, 1)])
        rel = "actors/%s.png" % n
        Image.fromarray(sheet, "RGBA").save(os.path.join(OUT, rel))
        m = {"grid": [gc, gr], "frame": [fw, fh], "anims": spec["anims"], "block": round(s, 2),
             "sizes": [[int(f.shape[1]), int(f.shape[0])] for f in frames]}
        if eyes:
            m["eyes"] = eyes
        meta[rel] = m
        print("creature", n, "frame", fw, fh, "grid", gc, gr, "eyes", eyes if eyes else "")


def blue_awning(px):
    """The same stall with a blue and cream awning: red pixels in the top
    half turn blue."""
    out = px.copy()
    h = out.shape[0]
    top = out[: h // 2]
    rgb = top[:, :, :3].astype(int)
    red = (top[:, :, 3] > 0) & (rgb[:, :, 0] > rgb[:, :, 1] + 40) & (rgb[:, :, 0] > rgb[:, :, 2] + 40)
    r, g, b = rgb[:, :, 0].copy(), rgb[:, :, 1].copy(), rgb[:, :, 2].copy()
    top[:, :, 0] = np.where(red, (g * 0.6 + r * 0.15).clip(0, 255), r)
    top[:, :, 1] = np.where(red, (g * 0.85 + r * 0.25).clip(0, 255), g)
    top[:, :, 2] = np.where(red, (r * 0.95).clip(0, 255), b)
    return out


POST = {"blue_awning": blue_awning}


def build_props(incoming, names, meta):
    cache = {}
    for n in names:
        spec = PROPS[n]
        src_name, idx = spec[0], spec[1]
        f = spec[2] if len(spec) > 2 else 1.0
        dens = spec[3] if len(spec) > 3 else 2
        post = spec[4] if len(spec) > 4 else None
        src = os.path.join(incoming, src_name)
        if not os.path.exists(src):
            print("missing", src)
            continue
        key = (src, f)
        if key not in cache:
            cache[key] = shapes_of(src, 0, f)[0]
        shapes = cache[key]
        if idx >= len(shapes):
            print("SKIP", n, "only", len(shapes), "shapes")
            continue
        px = shapes[idx]
        if post:
            px = POST[post](px)
        rel = "props/%s.png" % n
        Image.fromarray(px, "RGBA").save(os.path.join(OUT, rel))
        m = {"size": [int(px.shape[1]), int(px.shape[0])], "px": dens}
        meta[rel] = m
        print("prop", n, px.shape[1], px.shape[0], "px", dens)


def main():
    incoming = sys.argv[1]
    want = set(sys.argv[2:])
    for d in ("actors", "props", "fx"):
        os.makedirs(os.path.join(OUT, d), exist_ok=True)
    mp = os.path.join(OUT, "meta.json")
    meta = json.load(open(mp)) if os.path.exists(mp) else {}
    build_people(incoming, [n for n in PEOPLE if not want or n in want], meta)
    build_creatures(incoming, [n for n in CREATURES if not want or n in want], meta)
    build_props(incoming, [n for n in PROPS if not want or n in want], meta)
    json.dump(meta, open(mp, "w"), indent=1, sort_keys=True)


if __name__ == "__main__":
    main()
