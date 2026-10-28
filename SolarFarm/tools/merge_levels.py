#!/usr/bin/env python3
"""Merges generator outputs (JSON lists) into data/levels_generated.json.
Later files override earlier ones for the same level id (used to re-generate
single levels). Usage: merge_levels.py out.json part1.json part2.json ..."""
import json
import sys

levels = {}
for path in sys.argv[2:]:
    for lv in json.load(open(path)):
        levels[lv["id"]] = lv
out = [levels[k] for k in sorted(levels)]
with open(sys.argv[1], "w") as f:
    f.write("[\n" + ",\n".join(json.dumps(lv, ensure_ascii=False, separators=(",", ":")) for lv in out) + "\n]\n")
print(len(out), "levels ->", sys.argv[1])
