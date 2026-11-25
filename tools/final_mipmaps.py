#!/usr/bin/env python3
"""Turn on mipmaps for final props and actors.

    godot --headless --import --path .      # creates the .import files
    python3 tools/final_mipmaps.py          # flips mipmaps on
    godot --headless --import --path .      # reimports with mipmaps

Final sprites are painted at twice their layout size (see tools/fit_art.py)
and drawn smaller, so without mipmaps fine detail such as snow on branches
shimmers when the camera moves. Art.lit draws them with a mipmapped filter.
Only touches .import files whose image is listed in assets/final/density.json.
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FINAL = os.path.join(ROOT, "assets", "final")


def main():
    with open(os.path.join(FINAL, "density.json"), encoding="utf-8") as f:
        listed = json.load(f)
    changed = missing = 0
    for rel in listed:
        for name in (rel, rel[:-4] + "_n.png"):
            if not os.path.exists(os.path.join(FINAL, name)):
                continue          # not every image has a normal map (icons)
            imp = os.path.join(FINAL, name + ".import")
            if not os.path.exists(imp):
                missing += 1
                continue
            with open(imp, encoding="utf-8") as f:
                s = f.read()
            t = re.sub(r"^mipmaps/generate=false$", "mipmaps/generate=true", s, flags=re.M)
            if t != s:
                with open(imp, "w", encoding="utf-8") as f:
                    f.write(t)
                changed += 1
    print("mipmaps on for %d files; %d not imported yet" % (changed, missing))


if __name__ == "__main__":
    main()
