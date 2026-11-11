#!/bin/bash
# Buduje wersję przeglądarkową i składa paczkę dla hostingów z limitem wielkości pliku
# (silnik .wasm ma ok. 38 MB, więc jest dzielony na części po 13 MB; stronę startową
# web/kurs-na-czas-3d.html składa je z powrotem w przeglądarce).
#
# Użycie:  tools/paczka_web.sh [ścieżka do godot] [katalog wyjściowy]
# Wymaga zainstalowanych szablonów eksportu Godot 4.6.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:-godot}"
OUT="${2:-build/paczka-web}"
rm -rf build/web "$OUT"
mkdir -p build/web "$OUT"
"$GODOT" --headless --path . --export-release "Web" build/web/index.html >/dev/null 2>&1 || true
[ -f build/web/index.wasm ] || { echo "Eksport nie powstał: sprawdź szablony eksportu." >&2; exit 1; }
cp build/web/index.js build/web/index.audio.worklet.js build/web/index.audio.position.worklet.js "$OUT"/
split -b 13000000 -d -a 1 build/web/index.wasm "$OUT/silnik-"
for f in "$OUT"/silnik-?; do mv "$f" "$f.wasm"; done
python3 - "$OUT" <<'PY'
import base64, glob, os, re, sys
out = sys.argv[1]
pck = open('build/web/index.pck', 'rb').read()
open(os.path.join(out, 'gra.pck.js'), 'w').write('window.KNC_PCK_B64="' + base64.b64encode(pck).decode() + '";\n')
wasm = os.path.getsize('build/web/index.wasm')
parts = sorted(os.path.basename(p) for p in glob.glob(os.path.join(out, 'silnik-?.wasm')))
html = open('web/kurs-na-czas-3d.html', encoding='utf-8').read()
html = re.sub(r"const PARTS=\[[^\]]*\], TOTAL=\d+;", "const PARTS=[" + ",".join("'" + p + "'" for p in parts) + "], TOTAL=" + str(wasm) + ";", html)
html = re.sub(r'"fileSizes":\{"index\.pck":\d+,"index\.wasm":\d+\}', '"fileSizes":{"index.pck":%d,"index.wasm":%d}' % (len(pck), wasm), html)
open(os.path.join(out, 'kurs-na-czas-3d.html'), 'w', encoding='utf-8').write(html)
print("paczka: %s (%d części silnika, %.1f MB)" % (out, len(parts), wasm / 1e6))
PY
