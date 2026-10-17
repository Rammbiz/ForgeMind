#!/usr/bin/env bash
# Puts a prepared GLB (tools/prepare_model.mjs) into the project with mobile texture settings.
#
#   tools/import_model.sh <prepared.glb> <res path inside the project, e.g. assets/worlds/space/road.glb>
#
# A headless import extracts the textures next to the GLB; they are switched to VRAM
# compression (ETC2/ASTC on phones), the normal map with the normal-map flag, and imported again.
set -euo pipefail

SRC="$1"
REL="$2"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
DEST="$ROOT/$REL"
NAME="$(basename "${DEST%.glb}")"
DIR="$(dirname "$DEST")"

command -v "$GODOT" >/dev/null || { echo "Godot not found: set GODOT=/path/to/godot" >&2; exit 1; }
mkdir -p "$DIR"
cp "$SRC" "$DEST"
# Godot's exit code after --import is not a reliable signal; check the files it writes.
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
shopt -s nullglob
imports=("$DIR/${NAME}_"*.import)
if [[ ${#imports[@]} -eq 0 ]]; then
	echo "Godot did not extract any texture from $NAME.glb" >&2
	exit 1
fi
for imp in "${imports[@]}"; do
	sed -i -e 's|^compress/mode=.*|compress/mode=2|' "$imp"
	if [[ "$imp" == *_normal.* ]]; then
		sed -i -e 's|^compress/normal_map=.*|compress/normal_map=1|' "$imp"
	fi
	echo "VRAM compression: $(basename "${imp%.import}")"
done
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
