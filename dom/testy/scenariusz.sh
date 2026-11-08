#!/bin/bash
# Prawdziwy panel na atrapie sterownika, z zegarem przyspieszonym 20 razy
# (minuta testu = 20 minut pracy panelu).
#
#   dom/testy/scenariusz.sh KATALOG PORT_ATRAPY PORT_PANELU SEKUND [--slonecznie]
#
# Wypisuje KATALOG i wraca od razu; atrapa i panel chodza w tle. Stan atrapy
# (liczba rozmow, impulsy, najwiecej rozmow naraz, nastawa) daje
#   curl localhost:PORT_ATRAPY/_stan
# a "czlowieka przy sterowniku" udaje
#   curl "localhost:PORT_ATRAPY/_ustaw?n=19.0"
# Porownanie ze starsza wersja: WERSJA=<rewizja gita> dom/testy/scenariusz.sh ...
#
# Bez --slonecznie pogoda pada z bledem DNS, jak u Jacka 8.11 po restarcie.
TU=$(cd "$(dirname "$0")" && pwd); DOM=$(dirname "$TU")
K=$1; PA=$2; PP=$3; ILE=$4; SLONCE=$5
rm -rf "${K:?}"; mkdir -p "$K"
cp "$DOM"/*.py "$DOM/panel-pompy.html" "$K/"
cp "$DOM/opisy-panelu.przyklad.json" "$K/opisy-panelu.json"
if [ -n "$WERSJA" ]; then git -C "$DOM" show "$WERSJA:dom/pompa-acond.py" > "$K/pompa-acond.py"; fi
printf 'http://127.0.0.1:%s/PAGE115.XML\n' "$PA" > "$K/adres-pompy.txt"
# Okno na cala dobe, zeby automat dzialal o kazdej porze testu.
echo '{"wlaczone": true, "okno": [0, 23.9], "prog_kwh": 1.2, "nastawa_slonce": 21.5, "nastawa_baza": 20.0}' > "$K/slonce.json"
# Wyjscie atrapy odciete od terminala - inaczej $(...) czeka na nia bez konca.
python3 "$TU/atrapa_sterownika.py" "$PA" > /dev/null 2>&1 &
sleep 0.5
timeout "$ILE" python3 "$TU/panel_testowy.py" "$K" 20 panel "http://127.0.0.1:$PA/PAGE115.XML" \
    --port-panelu "$PP" --bez-szukania --tylko-lokalnie $SLONCE > "$K/panel.log" 2>&1 &
echo "$K"
