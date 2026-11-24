#!/usr/bin/env python3
"""Cross-checks the game's dialogue JSON against the rest of the game: speakers,
items, lore, places, regions, region methods, fights, the scenes the code asks
for, and each speaker's portrait for every expression a line uses.

    python3 tools/dialogue/check.py
"""
import json, re, glob, os
R = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")) + "/"
J = lambda p: json.load(open(R + p))
chars = J("data/book1/characters.json")["characters"]
items = J("data/items.json")["items"]
lore = J("data/book1/lore.json")["entries"]
locs = J("data/book1/locations.json")["regions"]
enc = J("data/enemies.json")
router = open(R + "scripts/autoload/router.gd").read()
regions = set(re.findall(r'"([a-z_]+)":\s*"res://scripts/world/regions/', router))
methods = set()
for f in glob.glob(R + "scripts/world/regions/*.gd"):
    methods |= set(re.findall(r"^func ([a-z_]+)\(", open(f).read(), re.M))
scenes = {}
for f in sorted(glob.glob(R + "data/book1/dialogue/*.json")):
    for k, v in json.load(open(f))["scenes"].items():
        if k in scenes:
            print("DUP", k)
        scenes[k] = v
probs = []
for sid, sc in scenes.items():
    for ln in sc["lines"]:
        if "s" in ln and ln["s"] not in chars:
            probs.append("%s: unknown speaker %s" % (sid, ln["s"]))
        if "goto" in ln and ln["goto"] not in scenes:
            probs.append("%s: goto unknown %s" % (sid, ln["goto"]))
        for k in ("if_item", "if_not_item"):
            if k in ln and ln[k] not in items:
                probs.append("%s: unknown item %s" % (sid, ln[k]))
        acts = list(ln.get("do", []))
        for ch in ln.get("choices", []):
            acts += ch.get("do", [])
            if "goto" in ch and ch["goto"] not in scenes:
                probs.append("%s: choice goto unknown %s" % (sid, ch["goto"]))
        for a in acts:
            t = a["type"]
            if t in ("item", "take_item") and a.get("id") not in items:
                probs.append("%s: unknown item %s" % (sid, a.get("id")))
            if t == "journal" and a["id"] not in lore:
                probs.append("%s: unknown lore %s" % (sid, a["id"]))
            if t == "place" and a["id"] not in locs:
                probs.append("%s: unknown place %s" % (sid, a["id"]))
            if t == "goto":
                if a.get("region") not in regions:
                    probs.append("%s: unknown region %s" % (sid, a.get("region")))
                if "chapter" not in a:
                    probs.append("%s: goto without chapter" % sid)
            if t == "region_call" and a["method"] not in methods:
                probs.append("%s: unknown region method %s" % (sid, a["method"]))
            if t == "start_fight" and a["id"] not in enc["encounters"]:
                probs.append("%s: unknown fight %s" % (sid, a["id"]))
# scenes the code asks for
want = set()
for f in glob.glob(R + "scripts/**/*.gd", recursive=True):
    src = open(f).read()
    want |= set(re.findall(r'Dialogue\.play\("([a-z0-9_]+)"\)', src))
for b in re.findall(r'\["\w+", \d+, "\w*", "\w+", "(\w+)"\]', open(R + "scripts/world/regions/manor_in.gd").read()):
    want.add(b)
for l in ["fountain", "pool", "stables", "gate"]:
    want |= {"ch08_" + l, "spring_" + l}
for e in list(enc["encounters"].values()) + list(enc["enemies"].values()):
    for tr in e.get("triggers", []):
        if "scene" in tr:
            want.add(tr["scene"])
missing = sorted(w for w in want if w not in scenes)
# BEATS: the must-not flag is set in the scene's first do-line
mi = open(R + "scripts/world/regions/manor_in.gd").read()
for room, ch, req, mustnot, scene in re.findall(r'\["(\w+)", (\d+), "(\w*)", "(\w+)", "(\w+)"\]', mi):
    sc = scenes.get(scene)
    if not sc:
        continue
    first = next((l for l in sc["lines"] if "do" in l), None)
    ok = first and any(a["type"] == "set_flag" and a["flag"] == mustnot for a in first["do"]) and sc["lines"].index(first) == 0
    if not ok:
        probs.append("%s: beat flag %s not set first" % (scene, mustnot))
# portraits: an expression with no painting of its own shows a nearer one
# (art.gd PORTRAIT_ALIAS, then neutral); list those so they are a choice
art = open(R + "scripts/util/art.gd").read()
alias = dict(re.findall(r'"(\w+)": "(\w+)"', re.search(r"PORTRAIT_ALIAS := \{([^}]*)\}", art).group(1)))
faces = {}
for d in glob.glob(R + "assets/final/portraits/*/"):
    faces[os.path.basename(d.rstrip("/"))] = {os.path.splitext(f)[0] for f in os.listdir(d) if f.endswith(".png")}
fallbacks = {}
for sid, sc in scenes.items():
    for ln in sc["lines"]:
        if "s" not in ln:
            continue
        info = chars.get(ln["s"], {})
        if info.get("voice_only"):
            continue
        who = info.get("portrait_as", ln["s"])
        sets = ["feyre_spring", "feyre"] if who == "feyre" else [who]
        e = ln.get("e", "neutral")
        have = set().union(*[faces.get(w, set()) for w in sets])
        if not have:
            probs.append("%s: %s has no portraits" % (sid, who))
        elif e not in have and alias.get(e) not in have:
            fallbacks.setdefault("%s/%s" % (who, e), sid)
print("scenes:", len(scenes))
if fallbacks:
    print("expressions shown as neutral (%d):" % len(fallbacks), " ".join("%s (%s)" % kv for kv in sorted(fallbacks.items())))
print("missing scenes (%d):" % len(missing), " ".join(missing))
for p in probs:
    print("PROBLEM", p)
