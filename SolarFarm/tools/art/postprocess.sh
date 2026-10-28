#!/bin/sh
# Post-processing after render.js: soft depth-of-field background for the puzzle.
set -e
ROOT="$1"
convert "$ROOT/assets/bg/puzzle.png" -blur 0x9 -modulate 104,112 "$ROOT/assets/bg/puzzle.png"
