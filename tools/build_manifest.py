#!/usr/bin/env python3
"""Builds the art manifest: one entry per placeholder, with the generation prompt.

Prompts are assembled from the book data in data/book1 (character looks,
location moods and palettes) plus the shared style block from the style guide,
so changing a description in the data changes the prompt. Run after editing
characters, cards, relics or locations:

    python3 tools/build_manifest.py

Writes data/assets/manifest.json and docs/ASSET_MANIFEST.md.

Each entry's `final` path is where the finished art goes. The game looks in
res://assets/final/ first and falls back to the placeholder, so dropping a file
there is the whole integration step (run tools/make_normals.py afterwards for
anything that is lit in the world).
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PH = os.path.join(ROOT, "assets", "placeholder")

# Credits per image for Higgsfield's default image model (gpt_image_2_6), as
# quoted by the estimate tool on 2026-11-23. Re-check before a batch.
CREDITS_PER_IMAGE = 0.75
# Expected generations per kept image (rerolls, expression consistency passes).
REROLL = {"portrait": 3, "battle": 3, "card": 2, "icon": 2, "prop": 3, "terrain": 3, "actor": 0}

STYLE = (
    "Painted illustration in the style of a hand-painted dark-fairytale game, "
    "visible brush strokes and soft painterly edges, rich deep colours with gold "
    "accents, dramatic rim light, cinematic chiaroscuro, muted winter palette for "
    "mortal lands, no text, no watermark, no frame"
)
NEG = "photo, 3d render, anime, chibi, text, letters, watermark, signature, border, extra fingers, modern clothing"

EXPR = {
    "neutral": "calm, guarded neutral expression",
    "cold": "flat cold stare, jaw set, unimpressed",
    "determined": "narrowed eyes, focused, ready to act",
    "afraid": "wide eyes, lips parted, fear she is trying to hide",
    "angry": "furious, brows drawn, teeth showing slightly",
    "sad": "downcast eyes, quiet grief",
    "hungry": "hollow cheeks, tired eyes, gaunt with winter hunger",
    "wounded": "bleeding scratch on the cheek, grimacing in pain, snow in her hair",
    "smirk": "a cutting, superior half smile",
    "tender": "soft, warm, gentle smile",
    "amused": "dry amusement, one corner of the mouth raised",
    "snarl": "lips peeled back over yellow fangs, snarling",
    "furious": "roaring, fur bristling, terrifying",
}

CARD_SCENE = {
    "ordinary_arrow": "a plain fletched arrow nocked on a worn ash-wood bow, snowy pine forest behind",
    "ash_arrow": "a single arrow of pale ash wood glowing faintly, ember motes in the cold air",
    "knife_slash": "a wooden-hilted hunting knife slashing, an arc of motion and spray of snow",
    "brace": "a thin cloaked girl bracing behind a snow-covered fallen log",
    "sidestep": "boots skidding sideways in fresh snow, a blur of motion",
    "hold_still": "a pair of watchful grey-blue eyes peering through bramble thorns",
    "fall_back": "footprints retreating backwards through deep snow between pines",
    "close_the_gap": "a huntress sprinting low through snow toward a dark shape",
    "steady_breath": "a single plume of breath in freezing air, a bowstring drawn",
    "quiet_as_the_wind": "wind-blown snow curling around tree trunks, hushed and still",
    "skinning_cut": "a hunting knife and a pelt on snow, practical and grim",
    "survivors_resolve": "chapped hands tightening on a bow grip, knuckles split by cold",
    "painters_eye": "a mental picture of colour: the wolf's eye rendered as swatches of paint",
    "hurl_the_knife": "a knife spinning through the air toward a pair of yellow eyes",
    "dinner_knife": "a battered table knife gripped like a weapon in candlelight",
    "second_arrow": "a second arrow already on the string, the first one buried in grey fur",
    "winter_hunger": "an empty bowl on a rough table, frost on the window",
    "rough_hands": "calloused, scarred hands holding a skinning knife",
    "the_vow": "a young woman by a dying mother's bedside, a promise spoken in candlelight",
}

ICON = {
    "elains_paint_tins": "three small paint tins, red, yellow and blue, on a worn wooden surface",
    "snare_wire": "a neat coil of bright snare wire on snowy creek stones",
    "iron_bracelet": "a plain hammered iron bracelet, protective charm against the Fae",
    "venison_strip": "a strip of dried venison wrapped in cloth",
    "hot_water": "a chipped clay cup of steaming hot water",
    "iron_nail": "a single old iron nail, rust at the tip",
}

PROP = {
    "pine": "a snow-laden pine tree seen from a high three-quarter top-down angle",
    "bare_tree": "a bare winter tree, black branches dusted with snow, high three-quarter top-down angle",
    "bramble": "a dense bramble thicket with snow, thorns and dead leaves, top-down three-quarter view",
    "rock": "a snow-capped boulder, top-down three-quarter view",
    "cottage": "a small poor thatched cottage with a sagging roof and a smoking chimney in snow, top-down three-quarter view",
    "barn": "a weathered wooden barn half buried in snow, top-down three-quarter view",
    "house": "a modest timber-and-plaster village house with a snowy roof and one warm lit window, top-down three-quarter view",
    "fountain_broken": "a cracked stone village fountain, dry and frosted, top-down three-quarter view",
    "stall": "a market stall with a canvas awning, lanterns, top-down three-quarter view",
}

TERRAIN = {
    "snow": "seamless tileable texture of untouched deep snow, subtle wind ripples, top-down",
    "mud_snow": "seamless tileable texture of trampled snow and frozen mud on a village road, top-down",
    "planks": "seamless tileable texture of worn dark wooden floor planks, top-down",
    "cobbles": "seamless tileable texture of frosty uneven cobblestones, top-down",
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
    cards = load("data/cards.json")["cards"]
    relics = load("data/relics.json")["relics"]
    items = load("data/items.json")["items"]
    enemies = load("data/enemies.json")["enemies"]
    out = []

    # Portraits. The neutral one is generated first; every other expression of
    # that character uses it as the reference image so the face stays the same.
    pdir = os.path.join(PH, "portraits")
    for cid in sorted(os.listdir(pdir)):
        c = chars[cid]
        exprs = sorted(f[:-4] for f in os.listdir(os.path.join(pdir, cid)) if f.endswith(".png") and not f.endswith("_n.png"))
        base = "neutral" if "neutral" in exprs else exprs[0]
        exprs.sort(key=lambda e: e != base)
        for e in exprs:
            is_beast = cid == "beast"
            subject = c["look"]
            frame = ("full body creature portrait, side three-quarter view" if is_beast
                     else "half-length character portrait from the waist up, three-quarter view, facing " + ("right" if cid == "feyre" else "left"))
            p = f"{STYLE}. {frame}. {c['name']}: {subject} Expression: {EXPR.get(e, e)}. Plain flat mid-grey background for cutout."
            out.append(entry("portrait", f"portrait.{cid}.{e}", f"portraits/{cid}/{e}.png", p, "2:3",
                             notes="Remove background after generation (transparent PNG). Feyre faces right (left side of screen); others face left.",
                             ref=None if e == base else f"portrait.{cid}.{base}"))

    for eid, en in enemies.items():
        c = chars.get(en.get("true_name", "").lower(), {})
        look = c.get("look") or "An enormous grey wolf, far too large to be natural, with yellow eyes and unnatural stillness."
        p = (f"{STYLE}. Battle illustration of {en['name']}: {look} Standing in a snowy winter clearing at dusk, "
             f"facing left toward the viewer's side, low menacing stance, pale cold rim light. Plain background for cutout.")
        out.append(entry("battle", f"battle.{eid}", f"battle/{eid}.png", p, "4:3", notes="Remove background. Faces left."))
    p = (f"{STYLE}. Battle illustration of the Beast: {chars['beast']['look']} Snow swirling around it, "
         "warm hearth light from one side, cold blue from the other. Plain background for cutout.")
    out.append(entry("battle", "battle.beast", "battle/beast.png", p, "4:3", notes="Remove background. Faces left."))

    for c in cards:
        scene = CARD_SCENE.get(c["id"], c["name"])
        p = f"{STYLE}. Card illustration, landscape, single clear focal subject: {scene}."
        out.append(entry("card", f"card.{c['id']}", f"cards/{c['id']}.png", p, "3:2",
                         notes=f"Card '{c['name']}'. Read at 250 px wide in game: keep one bold subject."))

    for rid in relics:
        p = f"{STYLE}. Single object icon, centred, dark vignette background: {ICON.get(rid, relics[rid]['name'])}."
        out.append(entry("icon", f"relic.{rid}", f"relics/{rid}.png", p, "1:1"))
    for iid in items:
        p = f"{STYLE}. Single object icon, centred, dark vignette background: {ICON.get(iid, items[iid]['name'])}."
        out.append(entry("icon", f"item.{iid}", f"items/{iid}.png", p, "1:1"))

    for f in sorted(os.listdir(os.path.join(PH, "props"))):
        if not f.endswith(".png") or f.endswith("_n.png"):
            continue
        name = f[:-4]
        key = next((k for k in PROP if name.startswith(k)), None)
        p = f"{STYLE}. Game prop sprite, isolated on a plain background, light from the upper left: {PROP.get(key, name)}."
        out.append(entry("prop", f"prop.{name}", f"props/{f}", p, "1:1",
                         notes="Remove background. Base of the object at the bottom centre. Run make_normals.py after."))
    for name, desc in TERRAIN.items():
        p = f"{STYLE}. {desc}, even lighting, no shadows, no objects."
        out.append(entry("terrain", f"terrain.{name}", f"terrain/{name}.png", p, "1:1",
                         notes="Must tile. Check seams by tiling 2x2; fix with offset + heal if needed. Run make_normals.py --wrap."))

    for f in sorted(os.listdir(os.path.join(PH, "actors"))):
        if f.endswith(".png") and not f.endswith("_n.png"):
            out.append(entry("actor", f"actor.{f[:-4]}", f"actors/{f}", "", "sheet",
                             notes="Walk sheet (4 directions x 4 frames). Not suited to image generation: frames drift. Hand-draw, commission, or use a sprite tool; keep the placeholder until then."))

    total_imgs = sum(e["est_generations"] for e in out)
    summary = {
        "credits_per_image": CREDITS_PER_IMAGE, "model": "gpt_image_2_6",
        "kept_images": sum(1 for e in out if e["kind"] != "actor"),
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
          "Walk-cycle sheets are excluded (see notes).", "",
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
