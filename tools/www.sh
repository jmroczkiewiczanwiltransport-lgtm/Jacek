#!/usr/bin/env bash
# Sklada folder www/ do wystawienia w internecie oraz paczke zip do przeciagniecia.
# Zaklada, ze ./build.sh zostal juz uruchomiony.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f dist/strona.html ] || { echo "Brak dist/strona.html - uruchom najpierw ./build.sh"; exit 1; }
[ -f dist/ksef-uzgodnienia.html ] || { echo "Brak dist/ksef-uzgodnienia.html - uruchom najpierw ./build.sh"; exit 1; }

cp dist/strona.html www/index.html
cp dist/ksef-uzgodnienia.html www/ksef.html

# Odsylacz do dema musi wskazywac na plik obok, a nie na artefakt w Claude - inaczej
# link zepsuje sie przy zmianie konta, juz po rozeslaniu go klientom.
python3 - <<'PY'
import io, re
p = 'www/index.html'
s = io.open(p, encoding='utf-8').read()
s = re.sub(r'href="https://claude\.ai/code/artifact/[0-9a-f-]+"', 'href="ksef.html"', s)
if 'claude.ai/code/artifact' in s:
    raise SystemExit('BLAD: w www/index.html zostal odsylacz do artefaktu Claude')
io.open(p, 'w', encoding='utf-8').write(s)
PY

rm -f dist/mbs-strona.zip
( cd www && zip -qr ../dist/mbs-strona.zip . -x README.md )
echo "www/index.html   $(du -h www/index.html | cut -f1)"
echo "www/ksef.html    $(du -h www/ksef.html | cut -f1)"
echo "dist/mbs-strona.zip  $(du -h dist/mbs-strona.zip | cut -f1)  <- to przeciagasz na hosting"
