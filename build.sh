#!/usr/bin/env bash
# Sklada aplikacje w jeden samowystarczalny plik HTML.
#   dist/ksef-uzgodnienia.html  -> wersja do rozdawania / uruchamiania z dysku
#   dist/artifact-body.html     -> fragment do publikacji jako Artifact
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p dist

# Znacznik wersji w stopce aplikacji - konczy zgadywanie, ktora wersja jest
# wgrana na hosting. Data i skrot commita, podmieniane w locie przy skladaniu.
WERSJA="$(date +%Y-%m-%d\ %H:%M) · $(git rev-parse --short HEAD 2>/dev/null || echo lokalna)"

FONTS='<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;600;700&family=Source+Sans+3:wght@400;600&family=IBM+Plex+Mono:wght@400;500&display=swap">'

# Wersja publikowana uzywa buildu "core": obsluguje te same formaty plikow, ale nie
# zawiera tablic stron kodowych (~123 tys. znakow spoza ASCII), ktore psuja publikacje.
# Skutek: stare pliki .xls zapisane w kodowaniu innym niz Latin moga miec przekrecone
# polskie znaki w nazwach. Plik rozdawany z dysku dostaje pelny build, wiec tam problemu nie ma.
{
  printf '<title>KSeF Uzgodnienia</title>\n'
  printf '%s\n' "$FONTS"
  printf '<style>\n'; cat src/app.css; printf '\n</style>\n'
  sed "s/__WERSJA__/$WERSJA/" src/app.body.html
  printf '<script>\n'; cat vendor/xlsx.core.min.js; printf '\n</script>\n'
  printf '<script>\n'; cat src/app.js; printf '\n</script>\n'
} > dist/artifact-body.html

{
  printf '<!doctype html>\n<html lang="pl">\n<head>\n<meta charset="utf-8">\n'
  printf '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
  printf '<meta name="description" content="Uzgodnienie eksportu z KSeF z rejestrem zakupu. Dziala offline, w przegladarce.">\n'
  printf '<title>KSeF Uzgodnienia</title>\n'
  printf '%s\n' "$FONTS"
  printf '<style>\n'; cat src/app.css; printf '\n</style>\n'
  printf '</head>\n<body>\n'
  sed "s/__WERSJA__/$WERSJA/" src/app.body.html
  printf '<script>\n'; cat vendor/xlsx.full.min.js; printf '\n</script>\n'
  printf '<script>\n'; cat src/app.js; printf '\n</script>\n'
  printf '</body>\n</html>\n'
} > dist/ksef-uzgodnienia.html

echo "dist/ksef-uzgodnienia.html  $(du -h dist/ksef-uzgodnienia.html | cut -f1)"
echo "dist/artifact-body.html     $(du -h dist/artifact-body.html | cut -f1)"

# ---- strony statyczne ----
# Fragment do publikacji jest zrodlem. Tu robimy z niego kompletny dokument
# z deklaracja kodowania: bez niej Firefox i Safari czytaja plik z dysku jako
# windows-1252, a serwer bez naglowka charset psuje polskie znaki u kazdego.
# Podzial jest jednoznaczny: wszystko do </style> nalezy do <head>, reszta do <body>.
standalone() {
  src="$1"; out="$2"; desc="$3"
  {
    printf '<!doctype html>\n<html lang="pl">\n<head>\n<meta charset="utf-8">\n'
    printf '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
    printf '<meta name="description" content="%s">\n' "$desc"
    awk '/^<meta charset=/ { next } { print } /<\/style>/ { exit }' "$src"
    printf '</head>\n<body>\n'
    awk 'f { print } /<\/style>/ { f = 1 }' "$src"
    printf '</body>\n</html>\n'
  } > "$out"
  echo "$out  $(du -h "$out" | cut -f1)"
}

standalone strona/index.html dist/strona.html \
  "Uzgodnienia KSeF, szkolenia obowiazkowe i arkusze na zamowienie. Narzedzia liczace lokalnie, bez serwera."
standalone sprzedaz/oferta.html dist/oferta.html \
  "Oferta narzedzia KSeF Uzgodnienia dla biur rachunkowych - cennik i zasady wspolpracy."
