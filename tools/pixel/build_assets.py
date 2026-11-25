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

PEOPLE = ["feyre", "nesta", "elain", "father", "isaac", "villager", "villager_woman", "acolyte", "mercenary",
          "feyre_spring", "lord_gold", "courtier_red", "housekeeper", "sentry", "lord_night",
          "fae_reveler", "bark_servant",
          # home across the Wall (Chapters 28 to 32): summer clothes, the
          # chateau's household and guests, the village in summer
          "feyre_finery", "feyre_ride", "nesta_rich", "elain_rich", "father_rich", "footman", "maid",
          "guest_gent", "guest_lady", "tomas", "isaac_summer", "isaac_wife", "villager_summer",
          "villager_woman_summer", "feyre_gown", "elain_gown", "feyre_garden",
          # Under the Mountain (Chapters 33 to 46): Feyre as a prisoner, painted
          # for the revels and remade, the queen and her court, the unmasked
          "feyre_mountain", "feyre_painted", "feyre_reborn", "amarantha", "guard_red",
          "courtier_masked_lady", "courtier_masked_gent", "shadow_maid", "servant_black",
          "lord_gold_free", "courtier_red_free"]

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
    # spring: 'h' = the height in art pixels of the tallest frame (the block
    # size guess is unreliable on these sheets, so size them by height)
    "butterfly": {"src": "px.spring_critters.png", "row": 0, "h": 9, "grid": (4, 1), "anims": {"white": [0, 1], "yellow": [2, 3]}},
    "bluebird": {"src": "px.spring_critters.png", "row": 1, "h": 12, "grid": (4, 1), "anims": {"idle": [0], "peck": [1], "fly": [2, 3]}},
    "rabbit": {"src": "px.spring_critters.png", "row": 2, "h": 15, "grid": (4, 1), "anims": {"sit": [0], "hop": [0, 1], "alert": [2], "eat": [3]}},
    "stag": {"src": "px.spring_critters.png", "row": 3, "h": 58, "grid": (4, 1), "anims": {"stand": [0], "walk": [1, 2], "graze": [3]}},
    # the woods' stranger things
    "suriel": {"src": "px.oracle.png", "h": 96, "grid": (2, 2), "anims": {"stand": [0], "speak": [1], "snared": [2], "walk": [3]}},
    "naga": {"src": "px.serpentfolk.png", "h": 64, "grid": (4, 2), "anims": {"walk": [0, 1, 2, 3], "rear": [4], "lunge": [5], "hurt": [6], "dead": [7]}},
    "attor": {"src": "px.fiend.png", "h": 70, "grid": (4, 2), "anims": {"crawl": [0, 1, 2, 3], "crouch": [4], "snarl": [5], "fly": [6, 7]}},
    "puca": {"src": "px.puca.png", "h": 84, "grid": (4, 2), "anims": {"walk": [0, 1, 2, 3], "rear": [4], "lunge": [5], "hurt": [6], "dead": [7]}},
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
    # ---- the Spring Court ----
    # the manor house (4 px blocks): drawn as the sheet has it, the front door
    # about a head taller than Feyre
    "manor": ("px.manor.png", 0, 1.0),
    # garden pieces (3.2 px blocks)
    "rose_red": ("px.garden_props.png", 0, 2.0),
    "rose_pink": ("px.garden_props.png", 1, 2.0),
    "rose_white": ("px.garden_props.png", 2, 2.0),
    "topiary": ("px.garden_props.png", 3, 2.0),
    "hedge": ("px.garden_props.png", 4, 1.4),
    "fountain": ("px.garden_props.png", 5, 1.1),
    "statue": ("px.garden_props.png", 6, 1.8),
    "bench_marble": ("px.garden_props.png", 7, 2.8),
    "rose_arch": ("px.garden_props.png", 8, 1.3),
    "tulip_bed": ("px.garden_props.png", 9, 3.0),
    "urn": ("px.garden_props.png", 10, 2.5),
    "garden_lamp": ("px.garden_props.png", 11, 1.7),
    # trees (4 and 5 px blocks), each in two sizes
    "blossom_pink": ("px.trees_blossom.png", 0, 1.0),
    "blossom_pink_s": ("px.trees_blossom.png", 0, 1.35),
    "blossom_white": ("px.trees_blossom.png", 1, 1.0),
    "blossom_white_s": ("px.trees_blossom.png", 1, 1.35),
    "oak": ("px.trees_oak_birch.png", 0, 1.0),
    "oak_s": ("px.trees_oak_birch.png", 0, 1.3),
    "birch": ("px.trees_oak_birch.png", 1, 1.0),
    "birch_s": ("px.trees_oak_birch.png", 1, 1.3),
    # wild flowers and woodland odds and ends (4 px blocks), knee high
    "poppies": ("px.spring_decor.png", 0, 3.6),
    "bluebells": ("px.spring_decor.png", 1, 3.6),
    "daisies": ("px.spring_decor.png", 2, 3.6),
    "buttercups": ("px.spring_decor.png", 3, 3.6),
    "mushroom_ring": ("px.spring_decor.png", 4, 3.0),
    "toadstool": ("px.spring_decor.png", 5, 3.2),
    "fern_spring": ("px.spring_decor.png", 6, 2.4),
    "tall_grass": ("px.spring_decor.png", 7, 2.6),
    "mossy_rock": ("px.spring_decor.png", 8, 2.2),
    "flower_log": ("px.spring_decor.png", 9, 2.0),
    "lily_pads": ("px.spring_decor.png", 10, 2.2),
    "stepping_stones": ("px.spring_decor.png", 11, 2.2),
    # the manor's rooms (3.2 px blocks), at the people's density
    "bed_canopy": ("px.manor_furniture.png", 0, 1.26, 1),
    "dining_table": ("px.manor_furniture.png", 1, 1.21, 1),
    "chair_carved": ("px.manor_furniture.png", 2, 1.5, 1),
    "armchair": ("px.manor_furniture.png", 3, 1.6, 1),
    "fireplace": ("px.manor_furniture.png", 4, 1.15, 1),
    "bookcase": ("px.manor_furniture.png", 5, 1.0, 1),
    "desk": ("px.manor_furniture.png", 6, 1.12, 1),
    "wardrobe": ("px.manor_furniture.png", 7, 1.0, 1),
    "vanity": ("px.manor_furniture.png", 8, 1.27, 1),
    "vase_roses": ("px.manor_furniture.png", 9, 1.48, 1),
    "orange_tree": ("px.manor_furniture.png", 10, 1.28, 1),
    "screen_painted": ("px.manor_furniture.png", 11, 1.12, 1),
    # fire night and the woods' errands (3.3 px blocks; sparks on the sheet
    # count as shapes 4, 5 and 14)
    "bonfire": ("px.fire_night.png", 0, 2.3),
    "maypole": ("px.fire_night.png", 1, 1.3),
    "standing_stone": ("px.fire_night.png", 2, 1.5),
    "drum": ("px.fire_night.png", 3, 2.85),
    "cave_mouth": ("px.fire_night.png", 6, 1.0),
    "gate_iron": ("px.fire_night.png", 7, 1.15),
    "snare": ("px.fire_night.png", 8, 1.9),
    "dead_chicken": ("px.fire_night.png", 9, 2.6),
    "stretcher": ("px.fire_night.png", 10, 1.25, 1),
    "easel_canvas": ("px.fire_night.png", 11, 1.45, 1),
    "paint_table": ("px.fire_night.png", 12, 1.7, 1),
    "campfire": ("px.fire_night.png", 13, 2.95),
    # spring extras: the glen's willow, the stable, the heron fountain, a
    # footbridge, the solstice pole, a swing, a well and a rose fence (f is
    # small: these were painted fine, so they are cut at a finer block)
    "willow": ("px.spring_extras.png", 0, 0.185),
    "stable": ("px.spring_extras.png", 1, 0.246),
    "heron_fountain": ("px.spring_extras.png", 2, 0.263),
    "footbridge": ("px.spring_extras.png", 3, 0.277),
    "ribbon_pole": ("px.spring_extras.png", 4, 0.345),
    "swing": ("px.spring_extras.png", 5, 0.37),
    "well_roses": ("px.spring_extras.png", 6, 0.383),
    "rose_fence": ("px.spring_extras.png", 7, 0.45),
    # more of the manor's furniture, on the people's scale (px 1)
    "staircase": ("px.manor_furniture2.png", 0, 0.442, 1),
    "harp": ("px.manor_furniture2.png", 1, 0.893, 1),
    "grandfather_clock": ("px.manor_furniture2.png", 2, 0.823, 1),
    "candelabra_table": ("px.manor_furniture2.png", 3, 1.07, 1),
    "bathtub": ("px.manor_furniture2.png", 4, 0.586, 1),
    "chaise": ("px.manor_furniture2.png", 5, 0.662, 1),
    "palm": ("px.manor_furniture2.png", 6, 0.717, 1),
    "tapestry": ("px.manor_furniture2.png", 7, 0.685, 1),
}


# props sized by height: name -> (source, which shape in reading order,
# height in art pixels, world density). The block-size guess is unreliable on
# finely painted sheets, so these are cut at whatever block gives the height.
PROPS_H = {
    # the village and the cottage in summer: the winter pieces' heights
    "house_a_summer": ("px.house_a_summer.png", 0, 169, 2),
    "house_b_summer": ("px.house_b_summer.png", 0, 162, 2),
    "barn_summer": ("px.barn_summer.png", 0, 173, 2),
    "cottage_family_summer": ("px.cottage_family_summer.png", 0, 154, 2),
    "cottage_small_summer": ("px.village_props_summer.png", 0, 91, 2),
    "shed_summer": ("px.village_props_summer.png", 1, 83, 2),
    "stall_red_summer": ("px.village_props_summer.png", 2, 58, 2),
    "well_summer": ("px.village_props_summer.png", 3, 55, 2),
    "fountain_summer": ("px.village_props_summer.png", 4, 65, 2),
    "fence_summer": ("px.village_props_summer.png", 5, 39, 2),
    "barrels_summer": ("px.village_props_summer.png", 6, 41, 2),
    "crates_summer": ("px.village_props_summer.png", 7, 42, 2),
    "cart_summer": ("px.village_props_summer.png", 8, 54, 2),
    "lamp_post_summer": ("px.village_details_summer.png", 0, 61, 2),
    "signpost_summer": ("px.village_details_summer.png", 1, 49, 2),
    "woodshed_summer": ("px.village_details_summer.png", 2, 51, 2),
    "hay_bales_summer": ("px.village_details_summer.png", 3, 44, 2),
    "flower_barrel": ("px.village_details_summer.png", 4, 39, 2),
    "bench_summer": ("px.village_details_summer.png", 5, 30, 2),
    "rail_fence_summer": ("px.village_details_summer.png", 6, 34, 2),
    "stone_wall_summer": ("px.village_details_summer.png", 7, 35, 2),
    "wheelbarrow_summer": ("px.village_details_summer.png", 8, 34, 2),
    "trough_summer": ("px.village_details_summer.png", 9, 29, 2),
    "buckets_summer": ("px.village_details_summer.png", 10, 25, 2),
    "basket_post": ("px.village_details_summer.png", 11, 43, 2),
    # the chateau and its grounds
    "chateau": ("px.chateau.png", 0, 196, 2),
    "carriage": ("px.carriage.png", 0, 60, 2),
    "carriage_trot": ("px.carriage.png", 1, 60, 2),
    "topiary_flame": ("px.chateau_garden.png", 0, 50, 2),
    "irises": ("px.chateau_garden.png", 1, 22, 2),
    "tulips_elain": ("px.chateau_garden.png", 2, 22, 2),
    "mulberry": ("px.chateau_garden.png", 3, 132, 2),
    "glasshouse": ("px.chateau_garden.png", 4, 100, 2),
    "lantern_post": ("px.chateau_garden.png", 5, 60, 2),
    "bench_iron": ("px.chateau_garden.png", 6, 30, 2),
    "dug_plot": ("px.chateau_garden.png", 7, 30, 2),
    # the road back to the Wall
    "whorl_stone": ("px.summer_extras.png", 0, 60, 2),
    "whorl_stone_s": ("px.summer_extras.png", 1, 42, 2),
    "foxgloves": ("px.summer_extras.png", 2, 32, 2),
    "bramble_summer": ("px.summer_extras.png", 3, 52, 2),
    "oak_summer": ("px.summer_extras.png", 4, 170, 2),
    "mossy_log": ("px.summer_extras.png", 5, 28, 2),
    "fire_ring": ("px.summer_extras.png", 6, 22, 2),
    "bedroll": ("px.summer_extras.png", 7, 20, 2),
    # the chateau's rooms, at the people's density
    "chandelier": ("px.chateau_furniture.png", 0, 64, 1),
    "banquet_table": ("px.chateau_furniture.png", 1, 84, 1),
    "chair_gilded": ("px.chateau_furniture.png", 2, 56, 1),
    "pianoforte": ("px.chateau_furniture.png", 3, 74, 1),
    "bed_white": ("px.chateau_furniture.png", 4, 104, 1),
    "desk_gems": ("px.chateau_furniture.png", 5, 74, 1),
    "wardrobe_white": ("px.chateau_furniture.png", 6, 96, 1),
    "flower_arch": ("px.chateau_furniture.png", 7, 104, 1),
    "mirror_gilded": ("px.chateau_furniture.png", 8, 100, 1),
    "lunch_table": ("px.chateau_furniture.png", 9, 74, 1),
    "easel_paints": ("px.chateau_furniture.png", 10, 80, 1),
    "vase_pedestal": ("px.chateau_furniture.png", 11, 80, 1),
    # the manor wrecked, at the people's density
    "wreck_chandelier": ("px.wreckage.png", 0, 46, 1),
    "wreck_table": ("px.wreckage.png", 1, 66, 1),
    "wreck_tapestry": ("px.wreckage.png", 2, 96, 1),
    "wreck_statue": ("px.wreckage.png", 3, 54, 1),
    "wreck_vase": ("px.wreckage.png", 4, 26, 1),
    "wreck_door": ("px.wreckage.png", 5, 92, 1),
    "wreck_chair": ("px.wreckage.png", 6, 48, 1),
    "wreck_worktable": ("px.wreckage.png", 7, 60, 1),
    "wreck_hearth": ("px.wreckage.png", 8, 76, 1),
    "wreck_window": ("px.wreckage.png", 9, 84, 1),
    "wreck_clock": ("px.wreckage.png", 10, 86, 1),
    "wreck_shelf": ("px.wreckage.png", 11, 80, 1),
}


# where two pictures on a sheet touch (grass running into grass), a strip
# cleared between them so they come out as two shapes: x0, y0, x1, y1 in
# source pixels
CUTS = {
    "px.spring_extras.png": [(256, 60, 268, 470), (750, 60, 762, 470)],
    "px.manor_furniture2.png": [(249, 580, 266, 930)],
}


def shapes_of(path, colors=0, f=1.0, rows_wanted=None, drop_small=True, s_force=None):
    """Every shape on a sheet in reading order, pixelized at the sheet's block
    size times f (or at s_force). Returns (frames, row lengths, block size).
    Shapes much smaller than the others in their row (crumbs, sparks) are
    left out."""
    arr = pz.load(path)
    for x0, y0, x1, y1 in CUTS.get(os.path.basename(path), []):
        arr[y0:y1, x0:x1, 3] = 0
    boxes, lab, mask = pz.find_shapes(arr, 128, 5, 150)
    s, _ = pz.block_size(arr, mask)
    if s_force is not None:
        s, f = s_force, 1.0
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


# Standing height in art pixels for people whose sheets the block-size guess
# gets wrong (it can lock onto twice or four times the real grid). Feyre is
# 76; Fae lords stand a head taller.
PEOPLE_HEIGHT = {"lord_gold": 86, "courtier_red": 84, "lord_night": 86, "housekeeper": 66, "sentry": 78, "feyre_spring": 76,
                 "fae_reveler": 76, "bark_servant": 72,
                 "feyre_finery": 76, "feyre_ride": 76, "nesta_rich": 76, "elain_rich": 73, "father_rich": 72,
                 "footman": 76, "maid": 68, "guest_gent": 78, "guest_lady": 74, "tomas": 84, "isaac_summer": 74,
                 "isaac_wife": 66, "villager_summer": 67, "villager_woman_summer": 58,
                 "feyre_gown": 76, "elain_gown": 73, "feyre_garden": 76,
                 "feyre_mountain": 76, "feyre_painted": 76, "feyre_reborn": 77, "amarantha": 79, "guard_red": 64,
                 "courtier_masked_lady": 78, "courtier_masked_gent": 82, "shadow_maid": 76, "servant_black": 82,
                 "lord_gold_free": 86, "courtier_red_free": 84}


def build_people(incoming, names, meta):
    for n in names:
        src = os.path.join(incoming, "px.%s.png" % n)
        if not os.path.exists(src):
            print("missing", src)
            continue
        frames, rows, s = shapes_of(src)
        if n in PEOPLE_HEIGHT and len(frames) >= 4:
            h0 = float(np.median([f.shape[0] for f in frames[:4]]))
            frames, rows, s = shapes_of(src, s_force=s * h0 / PEOPLE_HEIGHT[n])
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
        rows_wanted = [spec["row"]] if "row" in spec else None
        frames, rows, s = shapes_of(src, 0, spec.get("f", 1.0), rows_wanted)
        if "h" in spec and frames:
            tallest = max(f.shape[0] for f in frames)
            frames, rows, s = shapes_of(src, 0, 1.0, rows_wanted, s_force=s * tallest / spec["h"])
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

# props whose lit windows (or flames) get a light at night: the centre and
# size of each warm-glass patch is recorded in the meta as "windows",
# [x, y, size] in art pixels from the bottom middle
GLOW = {"manor", "garden_lamp", "bonfire", "campfire", "candelabra_table", "chateau", "lantern_post", "lamp_post_summer",
        "fire_ring", "chandelier", "house_a_summer", "house_b_summer", "cottage_family_summer", "cottage_small_summer"}


def glow_points(px, min_area=6):
    """Patches of warm, bright, yellow-orange pixels (lit window glass, a lamp
    flame): [[x, y, size], ...] relative to the bottom middle of the sprite."""
    from scipy import ndimage
    rgb = px[:, :, :3].astype(int)
    a = px[:, :, 3] > 0
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    m = a & (r > 200) & (g > 150) & (b < 140) & (r - b > 110)
    lab, n = ndimage.label(m)
    out = []
    h, w = m.shape
    for i in range(1, n + 1):
        ys, xs = np.nonzero(lab == i)
        if len(xs) < min_area:
            continue
        out.append([round(float(xs.mean()) - w / 2.0, 1), round(float(ys.mean()) - h, 1), int(len(xs))])
    return out


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
        if n in GLOW:
            m["windows"] = glow_points(px)
        elif "windows" in meta.get(rel, {}):
            m["windows"] = meta[rel]["windows"]   # set by hand before
        meta[rel] = m
        print("prop", n, px.shape[1], px.shape[0], "px", dens)


_SHEETS = {}


def shape_at_height(path, idx, h):
    """Shape idx of a sheet (reading order, crumbs left out) pixelized at the
    block that makes it h art pixels tall."""
    if path not in _SHEETS:
        arr = pz.load(path)
        for x0, y0, x1, y1 in CUTS.get(os.path.basename(path), []):
            arr[y0:y1, x0:x1, 3] = 0
        boxes, lab, mask = pz.find_shapes(arr, 128, 5, 150)
        rows = pz.reading_order(boxes)
        flat = []
        for r in rows:
            areas = [(b[2] - b[0]) * (b[3] - b[1]) for b in r]
            med = float(np.median(areas))
            flat += [b for b, a in zip(r, areas) if a >= 0.2 * med]
        _SHEETS[path] = (arr, lab, mask, flat)
    arr, lab, mask, flat = _SHEETS[path]
    if idx >= len(flat):
        return None
    b = flat[idx]
    s = (b[2] - b[0]) / float(h)
    px, _ = pz.pixelize_shape(arr, lab, mask, b, s, 0)
    # the grid search settles on slightly smaller cells than asked: correct once
    if abs(px.shape[0] - h) > max(2, h * 0.03):
        s *= px.shape[0] / float(h)
        px, _ = pz.pixelize_shape(arr, lab, mask, b, s, 0)
    return px


def build_props_h(incoming, names, meta):
    for n in names:
        src_name, idx, h, dens = PROPS_H[n]
        src = os.path.join(incoming, src_name)
        if not os.path.exists(src):
            print("missing", src)
            continue
        px = shape_at_height(src, idx, h)
        if px is None:
            print("SKIP", n, "no shape", idx)
            continue
        rel = "props/%s.png" % n
        Image.fromarray(px, "RGBA").save(os.path.join(OUT, rel))
        m = {"size": [int(px.shape[1]), int(px.shape[0])], "px": dens}
        if n in GLOW:
            m["windows"] = glow_points(px)
        elif "windows" in meta.get(rel, {}):
            m["windows"] = meta[rel]["windows"]
        meta[rel] = m
        print("prop", n, px.shape[1], px.shape[0], "px", dens)


# Indoor copies of yard props: the same art with the grass and wild flowers
# at the foot cleared away, for kitchens and cellars. Only wood-brown and
# grey-metal pixels are kept in the bottom third.
INDOOR = ["crates_summer", "barrels_summer", "buckets_summer"]


def derive_indoor(meta):
    import colorsys
    for n in INDOOR:
        src = os.path.join(OUT, "props", n + ".png")
        if not os.path.exists(src):
            continue
        im = Image.open(src).convert("RGBA")
        w, h = im.size
        px = im.load()
        for y in range(int(h * 0.68), h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a == 0:
                    continue
                hh, ss, vv = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
                woodish = (hh <= 0.125 or hh >= 0.97) and ss >= 0.12
                metal = ss < 0.12 and 0.12 < vv < 0.8
                if not (woodish or metal):
                    px[x, y] = (0, 0, 0, 0)
        name = n.replace("_summer", "_indoor")
        im.save(os.path.join(OUT, "props", name + ".png"))
        if "props/%s.png" % n in meta:
            meta["props/%s.png" % name] = dict(meta["props/%s.png" % n])
        print("indoor", name)


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
    build_props_h(incoming, [n for n in PROPS_H if not want or n in want], meta)
    derive_indoor(meta)
    json.dump(meta, open(mp, "w"), indent=1, sort_keys=True)


if __name__ == "__main__":
    main()
