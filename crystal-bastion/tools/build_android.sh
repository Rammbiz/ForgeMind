#!/usr/bin/env bash
# Builds a Crystal Bastion Android APK with Godot's prebuilt export templates
# (no Gradle, no Android Studio needed).
#
# Usage:
#   crystal-bastion/tools/build_android.sh [debug|release] [output.apk]
#
# Defaults: "debug", output crystal-bastion/build/crystal-bastion-<mode>.apk
#
# Requirements / environment:
#   GODOT              Godot 4.7.x editor binary (default: `godot` on PATH). The matching
#                      export templates must be installed (Editor > Manage Export Templates,
#                      or unpack the .tpz into ~/.local/share/godot/export_templates/<ver>/).
#   ANDROID_SDK_ROOT   Android SDK with platform-tools/adb and build-tools/<ver>/apksigner
#                      (ANDROID_HOME or ANDROID_SDK are accepted too).
#   JAVA_HOME          JDK 17+ (optional; otherwise derived from `java` on PATH).
#   Signing - read by Godot itself, never stored in export_presets.cfg:
#     GODOT_ANDROID_KEYSTORE_DEBUG_PATH / _DEBUG_USER / _DEBUG_PASSWORD
#         Optional. When unset, ~/.android/debug.keystore (alias androiddebugkey,
#         password android) is used and created with keytool if missing.
#     GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _RELEASE_USER / _RELEASE_PASSWORD
#         Required for "release".
#
# The script points Godot's editor settings (export/android/android_sdk_path and
# java_sdk_path in editor_settings-<major>.<minor>.tres) at the SDK/JDK above, runs a
# headless import, exports the "Android" preset and prints the APK path on the last line.
set -euo pipefail

MODE="${1:-debug}"
case "$MODE" in
	debug|release) ;;
	*) echo "usage: $0 [debug|release] [output.apk]" >&2; exit 2 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT="${2:-$PROJECT_DIR/build/crystal-bastion-$MODE.apk}"
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac
GODOT="${GODOT:-godot}"
PRESET="Android"

die() { echo "error: $*" >&2; exit 1; }
log() { echo "==> $*"; }

command -v "$GODOT" >/dev/null 2>&1 || die "Godot binary '$GODOT' not found (set GODOT=/path/to/godot)"

# --- Godot version + export templates ------------------------------------------------
GODOT_VERSION="$("$GODOT" --version 2>/dev/null | tail -n 1)"     # e.g. 4.7.2.stable.official.ed1daf0bf
TEMPLATE_VERSION="$(echo "$GODOT_VERSION" | cut -d. -f1-4)"      # e.g. 4.7.2.stable
MAJOR_MINOR="$(echo "$GODOT_VERSION" | cut -d. -f1-2)"            # e.g. 4.7
[[ "$MAJOR_MINOR" == "4.7" ]] || echo "warning: project targets Godot 4.7, found $GODOT_VERSION" >&2
TEMPLATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$TEMPLATE_VERSION"
for t in android_debug.apk android_release.apk; do
	[[ -f "$TEMPLATE_DIR/$t" ]] || die "missing export template $TEMPLATE_DIR/$t"
done

# --- Android SDK + JDK -----------------------------------------------------------------
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-${ANDROID_SDK:-}}}"
[[ -n "$SDK" ]] || die "set ANDROID_SDK_ROOT (or ANDROID_HOME) to your Android SDK"
SDK="$(cd "$SDK" && pwd)"
[[ -x "$SDK/platform-tools/adb" ]] || die "$SDK/platform-tools/adb not found"
compgen -G "$SDK/build-tools/*/apksigner" >/dev/null || die "no build-tools/<ver>/apksigner in $SDK"

if [[ -z "${JAVA_HOME:-}" ]]; then
	command -v java >/dev/null 2>&1 || die "no JDK: set JAVA_HOME or put java on PATH"
	JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
fi
[[ -x "$JAVA_HOME/bin/java" ]] || die "JAVA_HOME=$JAVA_HOME has no bin/java"
export JAVA_HOME

# --- Editor settings ---------------------------------------------------------------------
SETTINGS="${GODOT_EDITOR_SETTINGS:-${XDG_CONFIG_HOME:-$HOME/.config}/godot/editor_settings-$MAJOR_MINOR.tres}"
mkdir -p "$(dirname "$SETTINGS")"
if [[ ! -f "$SETTINGS" ]]; then
	printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > "$SETTINGS"
fi
set_editor_setting() {   # key value  (value written as a quoted string)
	local key="$1" value="$2" tmp
	tmp="$(mktemp)"
	grep -v -F "$key = " "$SETTINGS" > "$tmp" || true
	awk -v line="$key = \"$value\"" '{ print } /^\[resource\]$/ && !done { print line; done = 1 }' "$tmp" > "$SETTINGS"
	rm -f "$tmp"
}
set_editor_setting "export/android/android_sdk_path" "$SDK"
set_editor_setting "export/android/java_sdk_path" "$JAVA_HOME"
log "Editor settings: $SETTINGS (android_sdk_path=$SDK, java_sdk_path=$JAVA_HOME)"

# --- Signing -------------------------------------------------------------------------------
if [[ "$MODE" == "debug" ]]; then
	if [[ -z "${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-}" ]]; then
		export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$HOME/.android/debug.keystore"
		export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
		export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"
		if [[ ! -f "$GODOT_ANDROID_KEYSTORE_DEBUG_PATH" ]]; then
			log "Creating debug keystore $GODOT_ANDROID_KEYSTORE_DEBUG_PATH"
			mkdir -p "$(dirname "$GODOT_ANDROID_KEYSTORE_DEBUG_PATH")"
			"$JAVA_HOME/bin/keytool" -genkeypair -keystore "$GODOT_ANDROID_KEYSTORE_DEBUG_PATH" \
				-storepass android -keypass android -alias androiddebugkey -keyalg RSA -keysize 2048 \
				-validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
		fi
	fi
	[[ -f "$GODOT_ANDROID_KEYSTORE_DEBUG_PATH" ]] || die "debug keystore $GODOT_ANDROID_KEYSTORE_DEBUG_PATH not found"
	: "${GODOT_ANDROID_KEYSTORE_DEBUG_USER:?set GODOT_ANDROID_KEYSTORE_DEBUG_USER}"
	: "${GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD:?set GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD}"
else
	: "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:?set GODOT_ANDROID_KEYSTORE_RELEASE_PATH for release builds}"
	: "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:?set GODOT_ANDROID_KEYSTORE_RELEASE_USER (key alias)}"
	: "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:?set GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD}"
	[[ -f "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" ]] || die "release keystore $GODOT_ANDROID_KEYSTORE_RELEASE_PATH not found"
fi

# --- Import + export -------------------------------------------------------------------------
mkdir -p "$PROJECT_DIR/build" "$(dirname "$OUT")"
touch "$PROJECT_DIR/build/.gdignore"   # keep build outputs out of the Godot filesystem scan
rm -f "$OUT" "$OUT.idsig"

log "Importing project ($GODOT_VERSION)"
"$GODOT" --headless --path "$PROJECT_DIR" --import

log "Exporting $MODE APK -> $OUT"
"$GODOT" --headless --path "$PROJECT_DIR" "--export-$MODE" "$PRESET" "$OUT"
[[ -s "$OUT" ]] || die "export failed: $OUT was not created"
rm -f "$OUT.idsig"   # APK Signature Scheme v4 side file, only needed for incremental adb installs

APKSIGNER="$(find "$SDK/build-tools" -mindepth 2 -maxdepth 2 -name apksigner | sort -V | tail -n 1)"
log "Verifying signature"
"$APKSIGNER" verify --print-certs "$OUT" | grep -E "^Signer #1 certificate (DN|SHA-256)" || true
"$APKSIGNER" verify "$OUT" >/dev/null || die "apksigner could not verify $OUT"

log "Done ($(du -h "$OUT" | cut -f1))"
echo "$OUT"
