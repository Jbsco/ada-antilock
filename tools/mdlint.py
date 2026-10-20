#!/usr/bin/env python3
"""Okular markdown lint, using the real renderer as the oracle.

Okular renders via discount (libmarkdown). Anything discount emits as a raw tag that
is NOT a tag discount itself produces was swallowed markdown: an HTML consumer treats
it as an unknown element and drops it from the display. That is the defect class this
catches, with no guessing about parser internals.

Also flags accidental setext headings (---/=== under a non-blank line), which turn a
paragraph line into a heading.

Fenced code (```) is banned outright: under default discount flags a fence degrades
into an inline-code paragraph, and under Okular's flag set (fencedcode enabled) a
table directly after a fenced block is swallowed into the paragraph -- measured on
discount 3.0.1.3, GAME-STATE.md field table. Indented (4-space) code blocks render
correctly under every flag set; use those. As a backstop for adjacency quirks beyond
fences, the file is rendered under BOTH flag sets and any table present in one but
lost in the other is reported.
"""
import re, subprocess, sys

# Tags discount legitimately emits.
OK = {
    "p","br","hr","h1","h2","h3","h4","h5","h6","ul","ol","li","dl","dt","dd",
    "table","thead","tbody","tfoot","tr","th","td","code","pre","em","strong","b","i",
    "blockquote","a","img","del","ins","sup","sub","span","div","center","style",
    "figure","figcaption","caption","colgroup","col",
    "details","summary",
}

def render(path, flags=None):
    cmd = ["markdown"] + (["-f", flags] if flags else []) + [path]
    try:
        return subprocess.run(cmd, capture_output=True, text=True,
                              timeout=60).stdout
    except Exception as e:
        print(f"{path}: RENDER FAILED: {e}")
        return ""

def fences(path):
    """``` lines: banned (see module docstring)."""
    out = []
    for i, l in enumerate(open(path, encoding="utf-8").read().split("\n")):
        if l.lstrip().startswith("```"):
            out.append((i + 1, l.strip()[:40]))
    return out

def tables_lost(path):
    """Tables present under one discount flag set but not the other."""
    plain = render(path).count("<table>")
    okular = render(path, "fencedcode").count("<table>")
    return (plain, okular) if plain != okular else None

def swallowed(path):
    html = render(path)
    bad = {}
    for m in re.finditer(r'<\s*/?\s*([A-Za-z_][\w:.-]*)([^>]*)>', html):
        name = m.group(1).lower()
        if name in OK:
            continue
        bad[m.group(0)] = bad.get(m.group(0), 0) + 1
    return bad

def setext(path):
    out = []
    lines = open(path, encoding="utf-8").read().split("\n")
    fence = False
    for i, l in enumerate(lines):
        if l.lstrip().startswith("```"):
            fence = not fence
            continue
        if fence:
            continue
        if re.match(r'^(-{3,}|={3,})\s*$', l) and i and lines[i-1].strip():
            out.append((i + 1, lines[i-1][:60]))
    return out

total = 0
for p in sys.argv[1:]:
    for tag, n in sorted(swallowed(p).items()):
        print(f"{p}: SWALLOWED {tag}  x{n}")
        total += n
    for ln, ctx in setext(p):
        print(f"{p}:{ln}: SETEXT-ACCIDENT after <{ctx}>")
        total += 1
    for ln, ctx in fences(p):
        print(f"{p}:{ln}: FENCED-CODE {ctx}  (use a 4-space indented block)")
        total += 1
    lost = tables_lost(p)
    if lost:
        print(f"{p}: TABLE-LOST plain={lost[0]} okular-flags={lost[1]}")
        total += 1
print(f"--- {total} rendering defect(s) across {len(sys.argv)-1} file(s)")
sys.exit(1 if total else 0)
