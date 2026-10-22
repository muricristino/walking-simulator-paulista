#!/bin/sh
set -e
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$PROJ/prints/shot.png}"
mkdir -p "$PROJ/prints"
rm -f "$OUT"
open -W -n -j -g -a /Applications/Godot.app --stdout "$PROJ/prints/log.txt" --stderr "$PROJ/prints/err.txt" --args --path "$PROJ" --audio-driver Dummy --position 20000,20000 res://main.tscn -- --shot "$OUT"
if [ -n "$2" ]; then
	magick "$OUT" -filter point -resize 400% "$2"
fi
