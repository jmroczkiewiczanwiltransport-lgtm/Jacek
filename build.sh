#!/usr/bin/env bash
# Sklada aplikacje w jeden samowystarczalny plik HTML.
#   dist/ksef-uzgodnienia.html  -> wersja do rozdawania / uruchamiania z dysku
#   dist/artifact-body.html     -> fragment do publikacji jako Artifact
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p dist

FONTS='<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;600;700&family=Source+Sans+3:wght@400;600&family=IBM+Plex+Mono:wght@400;500&display=swap">'

# Wersja publikowana uzywa buildu "core": obsluguje te same formaty plikow, ale nie
# zawiera tablic stron kodowych (~123 tys. znakow spoza ASCII), ktore psuja publikacje.
# Skutek: stare pliki .xls zapisane w kodowaniu innym niz Latin moga miec przekrecone
# polskie znaki w nazwach. Plik rozdawany z dysku dostaje pelny build, wiec tam problemu nie ma.
{
  printf '<title>KSeF Uzgodnienia</title>\n'
  printf '%s\n' "$FONTS"
  printf '<style>\n'; cat src/app.css; printf '\n</style>\n'
  cat src/app.body.html
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
  cat src/app.body.html
  printf '<script>\n'; cat vendor/xlsx.full.min.js; printf '\n</script>\n'
  printf '<script>\n'; cat src/app.js; printf '\n</script>\n'
  printf '</body>\n</html>\n'
} > dist/ksef-uzgodnienia.html

echo "dist/ksef-uzgodnienia.html  $(du -h dist/ksef-uzgodnienia.html | cut -f1)"
echo "dist/artifact-body.html     $(du -h dist/artifact-body.html | cut -f1)"
