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

command -v "$GODOT" >/dev/null || { echo "Godot not found: set GODOT=/path/to/godot" >&2; exit 1; }
mkdir -p "$DIR"
python3 "$ROOT/tools/rig_hero.py" "$SRC" "$ROOT/tools/hero_rigs/$HERO.json" "$DIR/$HERO.glb"
# Godot's exit code after --import is not a reliable signal; check the files it writes.
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
for role in albedo normal; do
	if ! ls "$DIR/${HERO}_$role."*.import >/dev/null 2>&1; then
		echo "Godot did not extract ${HERO}_$role from $HERO.glb (run the import in the editor to see why)" >&2
		exit 1
	fi
done

shopt -s nullglob
for imp in "$DIR/${HERO}_"*.import; do
	sed -i -e 's|^compress/mode=.*|compress/mode=2|' "$imp"
	if [[ "$imp" == *_normal.* ]]; then
		sed -i -e 's|^compress/normal_map=.*|compress/normal_map=1|' "$imp"
	fi
	echo "VRAM compression: $(basename "${imp%.import}")"
done
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
