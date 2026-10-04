#!/usr/bin/env bash
# Rigs a prepared hero GLB and puts it into the project.
#
#   tools/import_hero.sh <hero id> <prepared.glb>
#
# 1. tools/rig_hero.py adds the skeleton described by tools/hero_rigs/<hero>.json
# 2. the result goes to assets/models/heroes/<hero>.glb
# 3. a headless import extracts the embedded textures next to the GLB; they are switched
#    to VRAM compression (ETC2/ASTC on phones), the normal map with the normal-map flag,
#    and imported again
set -euo pipefail

HERO="$1"
SRC="$2"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/assets/models/heroes"
GODOT="${GODOT:-godot}"

mkdir -p "$DIR"
python3 "$ROOT/tools/rig_hero.py" "$SRC" "$ROOT/tools/hero_rigs/$HERO.json" "$DIR/$HERO.glb"
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true

shopt -s nullglob
for imp in "$DIR/${HERO}_"*.import; do
	sed -i -e 's|^compress/mode=.*|compress/mode=2|' "$imp"
	if [[ "$imp" == *_normal.* ]]; then
		sed -i -e 's|^compress/normal_map=.*|compress/normal_map=1|' "$imp"
	fi
	echo "VRAM compression: $(basename "${imp%.import}")"
done
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
