#!/bin/sh
set -e
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
REF="$1"
OUT="$2"
PANEL="$3"
FIRST="${4:-1}"
LAST="${5:-15}"
VISTA="${VISTA:-frente}"
shift 5 || true
mkdir -p "$OUT"
LIST=""
for n in $(seq "$FIRST" "$LAST"); do
	nn=$(printf "%02d" "$n")
	ref=$(ls "$REF"/${nn}_*_${VISTA}.png)
	m=$(basename "$ref" | cut -d_ -f2)
	"$PROJ/tools/lab.sh" lab/rio_claro "$OUT/g_${VISTA}_${nn}.png" --foto "$n" --vista "$VISTA" --dia "$@"
	magick "$ref" -gravity center -crop 1067x800+0+0 +repage -resize 640x480! "$OUT/r_${VISTA}_${nn}.png"
	magick "$OUT/g_${VISTA}_${nn}.png" -filter point -resize 200% -resize 640x480! "$OUT/g2_${VISTA}_${nn}.png"
	LIST="$LIST -label ${nn}_${m}_${VISTA}_foto $OUT/r_${VISTA}_${nn}.png -label ${nn}_${m}_${VISTA}_jogo $OUT/g2_${VISTA}_${nn}.png"
done
magick montage $LIST -tile 2x -geometry 640x480+4+4 -pointsize 18 -background '#222' -fill white "$PANEL"
echo "$PANEL"
