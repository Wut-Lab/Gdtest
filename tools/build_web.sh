#!/usr/bin/env bash
# Export the game for the web and package it for publishing as a claude.ai artifact.
#
#   tools/build_web.sh /path/to/godot  OUT_DIR
#
# Needs the "web_nothreads_release.zip" export template for the Godot version installed.
# Writes OUT_DIR/play.html (game only), OUT_DIR/editor.html (level editor + game) and the
# engine files. Artifacts only serve standard web types up to 15 MB, so the engine is stored
# gzipped + base64 as .txt and the pages decode it in the browser.
set -euo pipefail
GODOT="$1"
OUT="$2"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXPORT="$(mktemp -d)"

"$GODOT" --headless --path "$ROOT" --export-release "Web" "$EXPORT/index.html" >/dev/null 2>&1
test -s "$EXPORT/index.wasm" || { echo "Export failed" >&2; exit 1; }

mkdir -p "$OUT"
cp "$EXPORT/index.js" "$EXPORT/index.audio.worklet.js" "$EXPORT/index.audio.position.worklet.js" "$OUT/"
gzip -9 -c "$EXPORT/index.wasm" | base64 -w0 > "$OUT/index.wasm.gz.b64.txt"
base64 -w0 "$EXPORT/index.pck" > "$OUT/index.pck.b64.txt"

PCK_SIZE=$(stat -c %s "$EXPORT/index.pck")
WASM_SIZE=$(stat -c %s "$EXPORT/index.wasm")
python3 - "$ROOT" "$OUT" "$PCK_SIZE" "$WASM_SIZE" <<'EOF'
import json, sys
root, out, pck, wasm = sys.argv[1:]
level = json.dumps(open(f"{root}/levels/level_01.txt").read())
for page in ("play.html", "editor.html"):
    s = open(f"{root}/web/{page}").read()
    s = s.replace("/*PCK_SIZE*/0", pck).replace("/*WASM_SIZE*/0", wasm)
    s = s.replace('/*LEVEL_01*/""', level)
    open(f"{out}/{page}", "w").write(s)
EOF
rm -rf "$EXPORT"
echo "Built $OUT (pck $PCK_SIZE bytes, wasm $WASM_SIZE bytes)"
