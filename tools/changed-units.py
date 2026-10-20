#!/usr/bin/env python3
"""Print the core units a pull request has to prove: every unit whose specification or
body changed against the base, a generic unit through its instantiations, since GNATprove
analyzes a generic only there. With --all, every unit of the core the same way, for the
nightly run; with --shard k/n, the k-th of n groups of about equal source, counting a
generic's source for its instantiation.
Usage: changed-units.py <base-ref> | --all [--shard k/n]."""
import pathlib
import re
import subprocess
import sys

base = sys.argv[1] if len(sys.argv) > 1 else "origin/main"
shard = sys.argv[3] if len(sys.argv) > 3 and sys.argv[2] == "--shard" else None
src = pathlib.Path("core/src")


def code(path):
    """The Ada text of a file without its comments."""
    return re.sub(r"--[^\n]*", "", path.read_text())


def is_generic(name):
    """Whether a unit is a generic unit, not one declaring a generic inside it."""
    spec = src / (name + ".ads")
    context = r"\s*(((private|limited)\s+)*with\s[^;]*;|use\s[^;]*;|pragma\s[^;]*;)"
    return spec.exists() and re.match(r"(" + context + r")*\s*generic\b", code(spec), re.IGNORECASE) is not None


def instantiations(name):
    """The units instantiating a generic unit, by its Ada name."""
    unit = re.escape(name.replace("-", "."))
    pattern = re.compile(r"\bis\s+new\s+" + unit + r"\b", re.IGNORECASE)
    return {spec.stem for spec in src.glob("*.ads") if pattern.search(code(spec))}


if base == "--all":
    changed = [str(p) for p in src.glob("*.ad[sb]")]
else:
    changed = subprocess.run(["git", "diff", "--name-only", f"{base}...HEAD"],
                             check=True, capture_output=True, text=True).stdout.split()
selected = {pathlib.Path(c).stem for c in changed
            if c.startswith("core/src/") and c.endswith((".ads", ".adb"))}
for name in list(selected):
    if is_generic(name):
        selected.remove(name)
        selected |= instantiations(name)



def weight(name):
    """The bytes of source a unit's proof covers: its own, or its generic's for an instantiation."""
    spec, body = src / (name + ".ads"), src / (name + ".adb")
    if not body.exists() and spec.exists():
        generic = re.search(r"\bis\s+new\s+([\w.]+)", code(spec))
        if generic:
            name = generic.group(1).lower().replace(".", "-")
    return sum(f.stat().st_size for f in (src / (name + ".ads"), src / (name + ".adb")) if f.exists())


if shard:
    k, n = (int(v) for v in shard.split("/"))
    loads, groups = [0] * n, [set() for _ in range(n)]
    for name in sorted(selected, key=lambda u: (-weight(u), u)):
        i = loads.index(min(loads))
        groups[i].add(name)
        loads[i] += weight(name)
    selected = groups[k]

for name in sorted(selected):
    body = src / (name + ".adb")
    spec = src / (name + ".ads")
    if body.exists():
        print(body.name)
    elif spec.exists():
        print(spec.name)
