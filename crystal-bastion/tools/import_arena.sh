#!/usr/bin/env bash
# Puts a prepared arena GLB into the project and fits it onto the level grid.
#
#   tools/import_arena.sh <level id> <prepared.glb> [fit_arena.py options...]
#
# 1. copies the GLB to assets/models/arenas/<level>.glb
# 2. runs a headless import (Godot extracts the embedded textures next to the GLB)
# 3. switches the extracted textures to VRAM compression (ETC2/ASTC on phones) with a
#    normal-map flag for the normal texture, then imports again
# 4. runs tools/fit_arena.py to write assets/models/arenas/<level>.json
set -euo pipefail

LEVEL="$1"
SRC="$2"
shift 2
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/assets/models/arenas"
GODOT="${GODOT:-godot}"

mkdir -p "$DIR"
cp "$SRC" "$DIR/$LEVEL.glb"
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true

shopt -s nullglob
for imp in "$DIR/${LEVEL}_"*.import; do
	sed -i -e 's|^compress/mode=.*|compress/mode=2|' "$imp"
	if [[ "$imp" == *normal* ]]; then
		sed -i -e 's|^compress/normal_map=.*|compress/normal_map=1|' "$imp"
	fi
	echo "VRAM compression: $(basename "${imp%.import}")"
done
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true

python3 "$ROOT/tools/fit_arena.py" "$LEVEL" "$@"
