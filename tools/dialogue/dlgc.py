#!/usr/bin/env python3
"""Compiles the compact scene script (*.txt) into the game's dialogue JSON.

    python3 tools/dialogue/dlgc.py data/book1/dialogue tools/dialogue/src/ch22.txt [...]
    python3 tools/dialogue/check.py

Chapters 6 on and the Spring Court's ambient lines are written here, in
tools/dialogue/src; chapters 1 to 5 are kept directly in their JSON files.

== scene_id                      starts a scene
N text                           narration          {"n"}
H text                           a tip              {"hint"}
@who/expr text                   a spoken line      {"s","e","t"}
> action args                    an action; consecutive ones (same condition) share one {"do"}
* text -> target | act | act     a choice; consecutive ones share one {"choices"}
-> target                        jump to a scene    {"goto"}
[f:x !f:x i:x !i:x c:N] prefix   conditions on a line (or, after '*', on a choice)
"""
import json, re, shlex, sys, os

POS = {
    "chapter_card": ["n"], "journal": ["id"], "place": ["id"], "set_flag": ["flag"], "item": ["id", "n"],
    "take_item": ["id", "n"], "coins": ["n"], "heal": ["amount"], "unlock_tier": ["tier"], "open_shop": ["shop"],
    "time": ["hour"], "shake": ["strength"], "sfx": ["name", "db"], "music": ["name", "fade"], "outfit": ["id"],
    "start_fight": ["id"], "goto": ["region", "spawn"], "game_over": ["title", "line", "tip"],
}
RAW = {"objective": "text", "fade_to_black": "text"}
COND = {"f": "if_flag", "!f": "if_not_flag", "i": "if_item", "!i": "if_not_item", "c": "if_chapter"}
NOTES = ("Line forms: {n} Feyre's narration, first person past tense, shown in italics; {s,e,t} a line spoken aloud "
         "(speaker, portrait expression, text); {hint} a game tip on its own card; {choices:[{t,goto,do}]}; {do:[actions]}; "
         "{goto}. Any line or choice may carry if_flag, if_not_flag, if_item, if_not_item or if_chapter. Wording is written "
         "for the game; the few short book lines kept are listed in quotes.json.")


def val(s):
    if re.fullmatch(r"-?\d+", s):
        return int(s)
    if re.fullmatch(r"-?\d+\.\d*", s):
        return float(s)
    if s in ("true", "false"):
        return s == "true"
    return s


def toks(s):
    lx = shlex.shlex(s, posix=True)
    lx.whitespace_split = True
    lx.quotes = '"'
    lx.escape = ''
    lx.commenters = ''
    return list(lx)


def action(s):
    s = s.strip()
    name, _, rest = s.partition(" ")
    if name in RAW:
        return {"type": name, RAW[name]: rest.strip()}
    a = {"type": name}
    pos = []
    for t in toks(rest):
        if "=" in t and re.match(r"^[a-z_]+=", t):
            k, _, v = t.partition("=")
            a[k] = val(v)
        else:
            pos.append(val(t))
    if name == "region_call":
        a["method"] = pos[0]
        if len(pos) > 1:
            a["args"] = pos[1:]
    else:
        keys = POS.get(name, [])
        if len(pos) > len(keys):
            raise ValueError("too many args for %s: %s" % (name, s))
        for k, v in zip(keys, pos):
            a[k] = v
    return a


def conds(s):
    d = {}
    m = re.match(r"^\[([^\]]*)\]\s*", s)
    if not m:
        return d, s
    for t in m.group(1).split():
        k, _, v = t.partition(":")
        d[COND[k]] = int(v) if k == "c" else v
    return d, s[m.end():]


def compile_file(path):
    scenes = {}
    cur = None
    for ln, raw in enumerate(open(path, encoding="utf-8"), 1):
        line = raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        try:
            if line.startswith("== "):
                sid = line[3:].strip()
                if sid in scenes:
                    raise ValueError("duplicate scene " + sid)
                cur = scenes[sid] = {"lines": []}
                continue
            c, body = conds(line.strip())
            L = cur["lines"]
            if body.startswith("> "):
                a = action(body[2:])
                if L and set(L[-1].keys()) - set(COND.values()) == {"do"} and {k: v for k, v in L[-1].items() if k != "do"} == c:
                    L[-1]["do"].append(a)
                else:
                    L.append({"do": [a], **c})
            elif body.startswith("* "):
                cc, rest = conds(body[2:].strip())
                parts = [p.strip() for p in rest.split(" | ")]
                head = parts[0]
                ch = {}
                if " -> " in head:
                    head, _, tgt = head.rpartition(" -> ")
                    ch["goto"] = tgt.strip()
                ch = {"t": head.strip(), **({"goto": ch["goto"]} if "goto" in ch else {})}
                if len(parts) > 1:
                    ch["do"] = [action(p) for p in parts[1:]]
                ch.update(cc)
                if L and L[-1].get("_open") and {k: v for k, v in L[-1].items() if k not in ("choices", "_open")} == c:
                    L[-1]["choices"].append(ch)
                else:
                    L.append({"choices": [ch], **c, "_open": True})
                continue
            elif body.startswith("-> "):
                L.append({"goto": body[3:].strip(), **c})
            elif body.startswith("N "):
                L.append({"n": body[2:].strip(), **c})
            elif body.startswith("H "):
                L.append({"hint": body[2:].strip(), **c})
            elif body.startswith("@"):
                who, _, text = body[1:].partition(" ")
                s, _, e = who.partition("/")
                L.append({"s": s, "e": e or "neutral", "t": text.strip(), **c})
            else:
                raise ValueError("can't read line")
            # anything but a choice closes an open choice block
            for x in L[:-1]:
                x.pop("_open", None)
        except Exception as ex:
            sys.exit("%s:%d: %s\n  %s" % (path, ln, ex, line))
    for s in scenes.values():
        for x in s["lines"]:
            x.pop("_open", None)
    return scenes


if __name__ == "__main__":
    out_dir = sys.argv[1]
    for p in sys.argv[2:]:
        sc = compile_file(p)
        name = os.path.splitext(os.path.basename(p))[0]
        with open(os.path.join(out_dir, name + ".json"), "w", encoding="utf-8") as f:
            json.dump({"schema": 2, "notes": NOTES, "scenes": sc}, f, indent=1, ensure_ascii=False)
            f.write("\n")
        print("%s: %d scenes, %d lines" % (name, len(sc), sum(len(s["lines"]) for s in sc.values())))
