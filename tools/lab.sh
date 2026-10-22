#!/bin/sh
set -e
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
SCENE="$1"
OUT="$2"
shift 2
mkdir -p "$PROJ/prints"
rm -f "$OUT" "$PROJ/prints/lab_log.txt" "$PROJ/prints/lab_err.txt"
open -W -n -j -g -a /Applications/Godot.app --stdout "$PROJ/prints/lab_log.txt" --stderr "$PROJ/prints/lab_err.txt" --args --path "$PROJ" --audio-driver Dummy --position 20000,20000 "res://$SCENE.tscn" -- --shot "$OUT" "$@"
