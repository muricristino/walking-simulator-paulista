#!/bin/sh
set -e
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$1"
shift
mkdir -p "$PROJ/prints"
rm -f "$OUT" "$PROJ/prints/cars_log.txt" "$PROJ/prints/cars_err.txt"
open -W -n -j -g -a /Applications/Godot.app --stdout "$PROJ/prints/cars_log.txt" --stderr "$PROJ/prints/cars_err.txt" --args --path "$PROJ" --audio-driver Dummy --position 20000,20000 res://lab/cars.tscn -- --shot "$OUT" "$@"
