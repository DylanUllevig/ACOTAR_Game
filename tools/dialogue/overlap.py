#!/usr/bin/env python3
"""Find story lines that repeat the book's own sentences.

    python3 -I tools/dialogue/overlap.py <book.epub> [N] [file ...]

Story text in this game is written in our own words (see the content rules):
following the plot is fine, copying the prose is not. This lists every line
of tools/dialogue/src/*.txt (or the files named) that shares a run of N or
more words in a row with the book (default 9), longest run first, with the
shared words. Run it on new chapters before they ship; anything it lists
gets rewritten. Runs of 7 or 8 words are usually stock phrases ("from the
other end of the table"); look at them, but they are not automatically a
problem. Lore entries in data/book1/lore.json are checked too.

The book is read from the user's own EPUB, which is never committed.
"""
import html
import json
import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "tools", "dialogue", "src")


def words(s):
    s = s.replace("’", "'").replace("‘", "'")
    return re.findall(r"[a-z']+", s.lower())


def book_words(path):
    parts = []
    if os.path.isdir(path):
        for f in sorted(os.listdir(path)):
            if f.endswith((".html", ".xhtml", ".htm")):
                parts.append(open(os.path.join(path, f), encoding="utf-8", errors="ignore").read())
    else:
        with zipfile.ZipFile(path) as z:
            for n in sorted(z.namelist()):
                if n.endswith((".html", ".xhtml", ".htm")):
                    parts.append(z.read(n).decode("utf-8", errors="ignore"))
    text = html.unescape(re.sub(r"<[^>]+>", " ", " ".join(parts)))
    return words(text)


def longest_run(w, grams, n):
    best, run, start, best_at = 0, 0, 0, 0
    for i in range(len(w) - n + 1):
        if tuple(w[i:i + n]) in grams:
            if run == 0:
                start = i
            run += 1
            if run > best:
                best, best_at = run, start
        else:
            run = 0
    if best == 0:
        return 0, ""
    return best + n - 1, " ".join(w[best_at:best_at + best + n - 1])


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    n = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 9
    names = [a for a in sys.argv[2:] if not a.isdigit()]
    bw = book_words(sys.argv[1])
    grams = set(tuple(bw[i:i + n]) for i in range(len(bw) - n + 1))
    hits = []
    files = names or sorted(f for f in os.listdir(SRC) if f.endswith(".txt"))
    for fn in files:
        p = fn if os.path.isabs(fn) else os.path.join(SRC, fn)
        for ln, line in enumerate(open(p, encoding="utf-8"), 1):
            if line.startswith(("#", "==", ">", "*")):
                continue
            k, run = longest_run(words(line), grams, n)
            if k:
                hits.append((k, "%s:%d" % (os.path.basename(p), ln), run))
    lore = json.load(open(os.path.join(ROOT, "data", "book1", "lore.json"), encoding="utf-8"))
    for lid, e in lore.get("entries", {}).items():
        k, run = longest_run(words(e.get("text", "")), grams, n)
        if k:
            hits.append((k, "lore.json:" + lid, run))
    hits.sort(key=lambda h: -h[0])
    for k, where, run in hits:
        print("%3d  %-22s %s" % (k, where, run))
    print("%d line(s) share %d or more words in a row with the book" % (len(hits), n))
    sys.exit(1 if hits else 0)


if __name__ == "__main__":
    main()
