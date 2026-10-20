#!/usr/bin/env python3
"""Generate the Antilock.Vehicle package from a vehicle YAML file.

Every field of Antilock.Parameters.Set and Antilock.Parameters.Thresholds is read from the
Ada specification with its range and default, so the YAML is checked against the ranges
the controller declares and no range is kept twice. The conditions between fields mirror
Antilock.Parameters.Valid and are listed in CROSS_CHECKS.
Usage: gen-vehicle.py <vehicle.yaml> <antilock-vehicle.ads> [--spec <antilock-parameters.ads>]
       gen-vehicle.py <vehicle.yaml> --check"""
import pathlib
import re
import sys

try:
    import yaml
except ImportError:
    sys.exit("gen-vehicle: PyYAML is required (python3-yaml)")

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = ROOT / "core" / "src" / "antilock-parameters.ads"
UNITS = ROOT / "core" / "src" / "antilock-units.ads"
MAP_COUNT = 11

# The conditions of Antilock.Parameters.Valid, as (description, predicate over the flat values).
CROSS_CHECKS = [
    ("loop_period_us <= release_pulse_us", lambda v: v["loop_period_us"] <= v["release_pulse_us"]),
    ("release_pulse_us <= release_budget_us", lambda v: v["release_pulse_us"] <= v["release_budget_us"]),
    ("release_budget_us <= release_window_us", lambda v: v["release_budget_us"] <= v["release_window_us"]),
    ("loop_period_us <= build_pulse_us", lambda v: v["loop_period_us"] <= v["build_pulse_us"]),
    ("loop_period_us <= build_pause_us", lambda v: v["loop_period_us"] <= v["build_pause_us"]),
    ("supply_min_mv < supply_max_mv", lambda v: v["supply_min_mv"] < v["supply_max_mv"]),
]


def number(text):
    return int(text.replace("_", ""))


def type_ranges(units_path):
    """The integer types of Antilock.Units: name -> (low, high)."""
    ranges = {}
    for m in re.finditer(r"type\s+(\w+)\s+is\s+range\s+(-?[\d_]+)\s*\.\.\s*(-?[\d_]+)\s*;", units_path.read_text()):
        ranges[m.group(1).lower()] = (number(m.group(2)), number(m.group(3)))
    return ranges


def record_fields(spec_text, record):
    """The fields of a record type: name -> dict(type, low, high, default), in declaration order."""
    body = re.search(r"type\s+" + record + r"\s+is\s+record(.*?)end\s+record;", spec_text, re.S).group(1)
    fields = {}
    pattern = re.compile(r"^\s*(\w+)\s*:\s*(\w+)(?:\s+range\s+(-?[\d_]+)\s*\.\.\s*(-?[\d_]+))?\s*:=\s*(.+?);\s*$", re.M)
    for m in pattern.finditer(body):
        name, kind, low, high, default = m.groups()
        fields[name] = {"ada": name, "type": kind,
                        "low": number(low) if low else None, "high": number(high) if high else None,
                        "default": default.strip()}
    return fields


def flatten(tree, out, path=""):
    for key, value in tree.items():
        if key == "maps" and not path:
            continue
        if isinstance(value, dict):
            flatten(value, out, f"{path}{key}.")
        else:
            out[str(key).lower()] = value
    return out


def check_value(name, field, value, ranges, errors):
    kind = field["type"].lower()
    if kind == "boolean":
        if not isinstance(value, bool):
            errors.append(f"{name}: expected true or false, got {value!r}")
        return "True" if value else "False"
    if isinstance(value, bool) or not isinstance(value, int):
        errors.append(f"{name}: expected an integer, got {value!r}")
        return None
    low, high = field["low"], field["high"]
    if low is None:
        low, high = ranges.get(kind, (None, None))
    if low is not None and not low <= value <= high:
        errors.append(f"{name}: {value} is outside {low} .. {high}")
    return str(value)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    spec = pathlib.Path(sys.argv[sys.argv.index("--spec") + 1]) if "--spec" in sys.argv else SPEC
    check_only = "--check" in sys.argv
    if len(args) < (1 if check_only else 2):
        sys.exit(__doc__)
    source = pathlib.Path(args[0])
    tree = yaml.safe_load(source.read_text()) or {}
    spec_text = spec.read_text()
    ranges = type_ranges(spec.parent / "antilock-units.ads" if spec != SPEC else UNITS)
    set_fields = record_fields(spec_text, "Set")
    threshold_fields = record_fields(spec_text, "Thresholds")
    flat = flatten(tree, {})
    errors = []

    values = {}
    for name, field in set_fields.items():
        key = name.lower()
        if key == "maps":
            continue
        if key in flat:
            text = check_value(key, field, flat.pop(key), ranges, errors)
        else:
            text = field["default"]
        values[key] = text
    for key in flat:
        errors.append(f"{key}: not a field of Antilock.Parameters.Set")

    maps_tree = tree.get("maps") or {}
    default_map = {k.lower(): v for k, v in (maps_tree.get("default") or {}).items()}
    maps = []
    for index in range(1, MAP_COUNT + 1):
        override = {k.lower(): v for k, v in (maps_tree.get(index) or {}).items()}
        entry = {}
        for name, field in threshold_fields.items():
            key = name.lower()
            if key in override:
                entry[key] = check_value(f"maps.{index}.{key}", field, override[key], ranges, errors)
            elif key in default_map:
                entry[key] = check_value(f"maps.default.{key}", field, default_map[key], ranges, errors)
            else:
                entry[key] = field["default"]
        for key in set(override) - set(entry):
            errors.append(f"maps.{index}.{key}: not a field of Antilock.Parameters.Thresholds")
        if int(entry["slip_recover"]) >= int(entry["slip_release"]):
            errors.append(f"maps.{index}: slip_recover must be below slip_release")
        maps.append(entry)
    for key in set(default_map) - set(k.lower() for k in threshold_fields):
        errors.append(f"maps.default.{key}: not a field of Antilock.Parameters.Thresholds")
    for key in maps_tree:
        if key != "default" and not (isinstance(key, int) and 1 <= key <= MAP_COUNT):
            errors.append(f"maps.{key}: expected default or a position 1 .. {MAP_COUNT}")

    numeric = {k: int(v) for k, v in values.items() if v not in ("True", "False")}
    for text, predicate in CROSS_CHECKS:
        try:
            if not predicate(numeric):
                errors.append(f"{text} does not hold")
        except KeyError as missing:
            errors.append(f"{text}: {missing} missing")

    if errors:
        for e in errors:
            print(f"gen-vehicle: {source}: {e}", file=sys.stderr)
        sys.exit(1)
    if check_only:
        print(f"gen-vehicle: {source}: valid")
        return

    lines = [f"--  Generated by tools/gen-vehicle.py from {source.name}. Edit the vehicle file, not this one.",
             "with Antilock.Parameters; use Antilock.Parameters;",
             "",
             "package Antilock.Vehicle with SPARK_Mode is",
             "",
             "   Params : constant Set :="]
    assoc = []
    for name in set_fields:
        key = name.lower()
        if key == "maps":
            continue
        assoc.append(f"{name} => {values[key]}")
    map_lines = []
    names = list(threshold_fields)
    for index, entry in enumerate(maps, start=1):
        first = ", ".join(f"{name} => {entry[name.lower()]}" for name in names[:2])
        second = ", ".join(f"{name} => {entry[name.lower()]}" for name in names[2:])
        map_lines.append(f"{index} => ({first},\n                     {second})")
    assoc.append("Maps => (" + ",\n               ".join(map_lines) + ")")
    lines.append("     (" + ",\n      ".join(assoc) + ");")
    lines += ["",
              "   --  The conditions between fields, checked by the generator and again here.",
              "   pragma Assert (Valid (Params));",
              "",
              "end Antilock.Vehicle;",
              ""]
    pathlib.Path(args[1]).write_text("\n".join(lines))
    print(f"gen-vehicle: wrote {args[1]} from {source}")


if __name__ == "__main__":
    main()
