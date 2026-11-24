#!/usr/bin/env python3
"""Builds the art manifest: one entry per placeholder, with the generation prompt.

Prompts are assembled from the book data in data/book1 (character looks) and
data/items.json plus the shared style block from the style guide, so changing
a description in the data changes the prompt. Run after adding or renaming art
or editing characters or items:

    python3 tools/build_manifest.py

Writes data/assets/manifest.json and docs/ASSET_MANIFEST.md.

Each entry's `final` path is where the finished art goes. The game looks in
res://assets/final/ first and falls back to the placeholder, so dropping a file
there is the whole integration step (run tools/make_normals.py afterwards for
anything that is lit in the world). Sprites are drawn at a fixed scale in code,
so finished art must be resized to the entry's `size`.

Sound is not listed here: tools/gen_audio.py makes every sound in code, and a
file under res://assets/final/audio/<kind>/ with the same name replaces it.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PH = os.path.join(ROOT, "assets", "placeholder")

# Credits per image for Higgsfield's default image model (gpt_image_2_6), as
# quoted by the estimate tool on 2026-11-23. Re-check before a batch.
CREDITS_PER_IMAGE = 0.75
# Expected generations per kept image (rerolls, consistency passes).
REROLL = {"portrait": 3, "actor": 4, "icon": 2, "fx": 2, "prop": 3, "terrain": 3, "background": 3}

# Reference images the user supplied, uploaded to Higgsfield through the art
# pipeline folder (see /mnt/project-files/art_pipeline/README.md).
USER_REF = {"feyre": "art_pipeline/refs/feyre_ref.png", "andras": "art_pipeline/refs/wolf_ref.png"}

STYLE = (
    "Painted illustration in the style of a hand-painted dark-fairytale game, "
    "visible brush strokes and soft painterly edges, rich deep colours with gold "
    "accents, dramatic rim light, cinematic chiaroscuro, muted winter palette for "
    "mortal lands, no text, no watermark, no frame"
)
NEG = "photo, 3d render, anime, chibi, text, letters, watermark, signature, border, extra fingers, modern clothing"

# The series describes nearly everyone as beautiful, and the art should be
# stunning: hunger and hardship show in clothes and mood, never as ugliness.
BEAUTY = {
    "feyre": "Strikingly beautiful: fine bone structure, luminous skin, blue-gray eyes, "
             "full lips; lean from hunger, with her beauty showing through the hardship.",
    "nesta": "Coldly, breathtakingly beautiful, regal posture.",
    "elain": "Soft, luminous, delicate beauty, gentle eyes.",
    "father": "A handsome man worn down by grief, kind eyes.",
    "isaac": "A handsome, good-natured young man.",
    "mercenary": "Striking and formidable, handsome despite the scars.",
    "acolyte": "Serene, pale, unsettlingly lovely.",
    "beast": "Majestic and terrifying, beautiful in its menace.",
    "andras": "Majestic, beautiful and dangerous.",
}

EXPR = {
    "neutral": "calm, guarded neutral expression",
    "cold": "flat cold stare, jaw set, unimpressed",
    "determined": "narrowed eyes, focused, ready to act",
    "afraid": "wide eyes, lips parted, fear she is trying to hide",
    "angry": "furious, brows drawn, teeth showing slightly",
    "sad": "downcast eyes, quiet grief",
    "hungry": "tired eyes, cheeks a little hollow with winter hunger",
    "wounded": "a fine bleeding scratch on the cheek, wincing, snow in her hair",
    "smirk": "a cutting, superior half smile",
    "tender": "soft, warm, gentle smile",
    "amused": "dry amusement, one corner of the mouth raised",
    "snarl": "lips peeled back over yellow fangs, snarling",
    "furious": "roaring, fur bristling, terrifying",
}

ICON = {
    "hunting_knife": "a worn hunting knife with a wooden hilt and an old, sharp blade",
    "bow": "a plain ash-wood hunting bow with a worn leather grip",
    "arrow": "a single hunting arrow with plain grey fletching and an iron tip",
    "ash_arrow": "a long heavy arrow of pale mountain ash with an iron head, a faint warm sheen in the grain",
    "rose_hips": "a small cluster of wrinkled red rose hips on a thorny twig, touched with frost",
    "venison_strip": "a strip of dried salted venison wrapped in cloth",
    "bread": "a day-old heel of dark rye bread",
    "hare": "a thin white snow hare hung by its hind legs",
    "wolf_pelt": "a huge folded wolf pelt, charcoal, black and ivory fur",
    "doe_hide": "a clean rolled doe hide, tawny brown",
    "doe_hide_torn": "a doe hide ripped by teeth, ragged edges",
    "snare_wire": "a neat coil of bright snare wire on snowy creek stones",
    "paint_tins": "three small nearly empty paint tins, red, yellow and blue, on worn wood",
    "iron_bracelet": "a plain hammered iron bracelet, a mortal charm against the Fae",
    "coin": "a single worn copper coin",
}

FX = {
    "arrow": "a single plain hunting arrow seen from directly above, pointing right, grey fletching",
    "ash_arrow": "a single pale mountain-ash arrow seen from directly above, pointing right, faint warm glow along the shaft",
    "bow": "a plain ash-wood hunting bow seen from the side, upright, string taut",
    "knife": "a wooden-hilted hunting knife seen from above, blade pointing right",
    "slash": "a pale crescent arc of a knife slash, a soft white motion streak fading at both ends, on black",
}

PROP = {
    "pine": "a snow-laden pine tree seen from a high three-quarter top-down angle",
    "bare_tree": "a bare winter tree, black branches dusted with snow, high three-quarter top-down angle",
    "bramble": "a dense bramble thicket with snow, thorns and dead leaves, top-down three-quarter view",
    "rock": "a snow-capped boulder, top-down three-quarter view",
    "rose_bush_bare": "a wild rose bush in winter, bare thorny canes dusted with snow, top-down three-quarter view",
    "rose_bush": "a wild rose bush in winter with bright red rose hips among bare thorny canes and snow, top-down three-quarter view",
    "cottage": "a small poor thatched cottage with a sagging roof and a smoking chimney in snow, top-down three-quarter view",
    "barn": "a weathered wooden barn half buried in snow, top-down three-quarter view",
    "house": "a modest timber-and-plaster village house with a snowy roof and one warm lit window, top-down three-quarter view",
    "fountain_broken": "a cracked stone village fountain, dry and frosted, top-down three-quarter view",
    "stall": "a market stall with a canvas awning, lanterns, top-down three-quarter view",
}

# Full-screen paintings with no placeholder file; the game draws a labelled
# stand-in until the final image exists.
BACKGROUND = {
    "spring_manor": ("The first sight of Prythian after the Wall: a sprawling alabaster manor across rolling green "
                     "hills in eternal spring, veiled in climbing roses and ivy, balconies and staircases on its sides, "
                     "a gravel path through a hushed, sleeping garden to its doors, soft golden morning light and mist; "
                     "lush spring palette, not winter", "End of the Wall cinematic (wall_ride.gd)."),
}

TERRAIN = {
    "snow": "seamless tileable texture of untouched deep snow, subtle wind ripples, top-down",
    "mud_snow": "seamless tileable texture of trampled snow and frozen mud on a village road, top-down",
    "planks": "seamless tileable texture of worn dark wooden floor planks, top-down",
    "cobbles": "seamless tileable texture of frosty uneven cobblestones, top-down",
}

# Animals and the Beast are single images the game moves and squashes in code.
# People are 4 x 4 walk sheets: rows face down, left, right, up; columns are
# the four steps of the walk.
CREATURE = {
    "wolf": "andras", "beast": "beast",
    "doe": "a lean winter doe, tawny coat",
    "hare": "a thin white snow hare",
    "mare": "an old swaybacked farm mare, shaggy winter coat",
}


def load(p):
    with open(os.path.join(ROOT, p)) as f:
        return json.load(f)


def entry(kind, mid, rel, prompt, aspect, notes="", ref=None):
    ph = os.path.join(PH, rel)
    size = None
    if os.path.exists(ph):
        try:
            from PIL import Image
            size = list(Image.open(ph).size)
        except Exception:
            pass
    e = {
        "id": mid, "kind": kind, "placeholder": "assets/placeholder/" + rel,
        "final": "assets/final/" + rel, "size": size, "aspect": aspect,
        "prompt": prompt, "negative": NEG, "status": "placeholder",
        "est_generations": REROLL[kind],
    }
    if ref:
        e["reference"] = ref
    if notes:
        e["notes"] = notes
    return e


def main():
    chars = load("data/book1/characters.json")["characters"]
    items = load("data/items.json")["items"]
    out = []

    # Portraits. The neutral one is generated first (from the user's reference
    # where there is one); every other expression of that character uses it as
    # the reference image so the face stays the same.
    pdir = os.path.join(PH, "portraits")
    for cid in sorted(os.listdir(pdir)):
        c = chars[cid]
        exprs = sorted(f[:-4] for f in os.listdir(os.path.join(pdir, cid)) if f.endswith(".png") and not f.endswith("_n.png"))
        base = "neutral" if "neutral" in exprs else exprs[0]
        exprs.sort(key=lambda e: e != base)
        for e in exprs:
            is_beast = cid == "beast"
            subject = c["look"] + (" " + BEAUTY[cid] if cid in BEAUTY else "")
            frame = ("full body creature portrait, side three-quarter view" if is_beast
                     else "half-length character portrait from the waist up, three-quarter view, facing " + ("right" if cid == "feyre" else "left"))
            p = f"{STYLE}. {frame}. {c['name']}: {subject} Expression: {EXPR.get(e, e)}. Plain flat mid-grey background for cutout."
            ref = USER_REF.get(cid) if e == base else f"portrait.{cid}.{base}"
            out.append(entry("portrait", f"portrait.{cid}.{e}", f"portraits/{cid}/{e}.png", p, "2:3",
                             notes="Remove background after generation (transparent PNG). Feyre faces right (left side of screen); others face left.",
                             ref=ref))

    # Sprites in the world.
    for f in sorted(os.listdir(os.path.join(PH, "actors"))):
        if not f.endswith(".png") or f.endswith("_n.png"):
            continue
        name = f[:-4]
        if name in CREATURE:
            who = CREATURE[name]
            look = chars[who]["look"] + " " + BEAUTY.get(who, "") if who in chars else who
            look = look.strip()
            p = (f"{STYLE}. Game sprite of {look[0].lower() + look[1:]} Seen from a high three-quarter top-down angle, "
                 "standing side-on facing right, whole body in frame, isolated on a plain flat background, light from the upper left.")
            out.append(entry("actor", f"actor.{name}", f"actors/{f}", p, "3:2", ref=USER_REF.get(who),
                             notes="Single image, faces right. Remove background, crop to the body, resize to the listed size. Run make_normals.py after."))
        else:
            c = chars.get(name)
            look = (c["look"] + " " + BEAUTY.get(name, "")).strip() if c else f"a mortal {name} in plain winter clothes"
            p = (f"{STYLE}. Sprite sheet of one character, 4 rows by 4 columns on a plain flat background: "
                 f"{look} Seen from a high three-quarter top-down angle. Row 1 walks toward the viewer, row 2 walks left, "
                 "row 3 walks right, row 4 walks away; each row is four even steps of a walk cycle. Identical proportions, "
                 "clothes and colours in every frame, feet on the same baseline.")
            out.append(entry("actor", f"actor.{name}", f"actors/{f}", p, "3:4", ref=USER_REF.get(name),
                             notes="Walk sheet: 4 x 4 frames of 48 x 64 px. Frames drift between generations, so expect to align them by hand "
                                   "on the grid (feet on one baseline) before resizing. Run make_normals.py after."))
    for name, desc in FX.items():
        if not os.path.exists(os.path.join(PH, "fx", name + ".png")):
            continue
        p = f"{STYLE}. Single small game effect sprite, centred, isolated on a plain flat background: {desc}."
        out.append(entry("fx", f"fx.{name}", f"fx/{name}.png", p, "1:1",
                         notes="Remove background, crop tight to the object and resize to the listed size."))

    # Icons for the satchel and hotbar.
    icons = sorted(set(items) | {"coin"})
    for iid in icons:
        if not os.path.exists(os.path.join(PH, "items", iid + ".png")):
            continue
        name = items[iid]["name"] if iid in items else iid
        p = f"{STYLE}. Single object icon, centred, dark vignette background: {ICON.get(iid, name)}."
        out.append(entry("icon", f"item.{iid}", f"items/{iid}.png", p, "1:1"))

    for f in sorted(os.listdir(os.path.join(PH, "props"))):
        if not f.endswith(".png") or f.endswith("_n.png"):
            continue
        name = f[:-4]
        key = max((k for k in PROP if name.startswith(k)), key=len, default=None)
        p = f"{STYLE}. Game prop sprite, isolated on a plain background, light from the upper left: {PROP.get(key, name)}."
        out.append(entry("prop", f"prop.{name}", f"props/{f}", p, "1:1",
                         notes="Remove background. Base of the object at the bottom centre. Run make_normals.py after."))
    for name, (desc, where) in BACKGROUND.items():
        p = f"{STYLE}. Full-screen cinematic painting, wide landscape: {desc}."
        e = entry("background", f"bg.{name}", f"backgrounds/{name}.png", p, "16:9",
                  notes=where + " Shown full screen and cropped to fill wider or taller windows, so keep the subject central.")
        e["size"] = [1920, 1080]
        e["placeholder"] = None
        out.append(e)
    for name, desc in TERRAIN.items():
        p = f"{STYLE}. {desc}, even lighting, no shadows, no objects."
        out.append(entry("terrain", f"terrain.{name}", f"terrain/{name}.png", p, "1:1",
                         notes="Must tile. Check seams by tiling 2x2; fix with offset + heal if needed. Run make_normals.py --wrap."))

    total_imgs = sum(e["est_generations"] for e in out)
    summary = {
        "credits_per_image": CREDITS_PER_IMAGE, "model": "gpt_image_2_6",
        "kept_images": len(out),
        "est_generations": total_imgs, "est_credits": round(total_imgs * CREDITS_PER_IMAGE, 1),
    }
    os.makedirs(os.path.join(ROOT, "data", "assets"), exist_ok=True)
    with open(os.path.join(ROOT, "data", "assets", "manifest.json"), "w") as f:
        json.dump({"schema": 1, "style": STYLE, "negative": NEG, "summary": summary, "assets": out}, f, indent=1)

    by = {}
    for e in out:
        by.setdefault(e["kind"], []).append(e)
    md = ["# Asset manifest", "",
          "Generated by `tools/build_manifest.py` from the book data. Do not edit by hand; edit the data or the script and rerun.", "",
          f"Estimate: {summary['kept_images']} images to keep, about {summary['est_generations']} generations with rerolls, "
          f"about {summary['est_credits']} credits at {CREDITS_PER_IMAGE} credits per image ({summary['model']}). "
          "Walk sheets need hand alignment after generation (see their notes).", "",
          "| Kind | Count | Generations | Credits |", "|---|---|---|---|"]
    for k, v in by.items():
        g = sum(e["est_generations"] for e in v)
        md.append(f"| {k} | {len(v)} | {g} | {round(g * CREDITS_PER_IMAGE, 1)} |")
    md += ["", "Shared style block prepended to every prompt:", "", "> " + STYLE, "", "Negative: " + NEG, ""]
    for k, v in by.items():
        md += [f"## {k}", ""]
        for e in v:
            md.append(f"- `{e['id']}` -> `{e['final']}`" + (f" (reference: `{e['reference']}`)" if e.get("reference") else ""))
            if e.get("notes"):
                md.append(f"  - {e['notes']}")
        md.append("")
    os.makedirs(os.path.join(ROOT, "docs"), exist_ok=True)
    with open(os.path.join(ROOT, "docs", "ASSET_MANIFEST.md"), "w") as f:
        f.write("\n".join(md))
    print(json.dumps(summary))


if __name__ == "__main__":
    main()
