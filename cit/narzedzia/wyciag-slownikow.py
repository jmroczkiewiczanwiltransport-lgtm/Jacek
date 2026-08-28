#!/usr/bin/env python3
"""Wyciąga słowniki znaczników i typy pól z tekstu schematu JPK (PDF -> txt).

Wejście: plik .txt powstały z broszury/schematu MF (pypdf extract_text).
Wyjście: JSON ze słownikami znaczników per typ (TMapKonta*) + typy proste.

Uruchomienie:
  python3 wyciag-slownikow.py Schemat_JPK_KR_PD.txt > ../slowniki/znaczniki-KR_PD.json
"""
import json
import re
import sys


def wczytaj(sciezka):
    t = open(sciezka, encoding="utf-8").read()
    return re.sub(r"===== STRONA \d+ =====", "", t)


ENUM = re.compile(r'<xsd:enumeration value="([^"]+)">(.*?)</xsd:enumeration>', re.S)
DOC = re.compile(r"<xsd:documentation>(.*?)</xsd:documentation>", re.S)


def typy_proste(t):
    """Zwraca {nazwa_typu: surowe_zrodlo} dla kazdego xsd:simpleType."""
    out = {}
    for m in re.finditer(r'<xsd:simpleType name="([A-Za-z0-9_]+)">', t):
        nazwa = m.group(1)
        if nazwa in out:
            continue
        koniec = t.find("</xsd:simpleType>", m.end())
        out[nazwa] = t[m.start():koniec]
    return out


def znaczniki(zrodlo):
    """Kody znacznikow w kolejnosci ze schemy, z opisem MF."""
    lista = []
    widziane = set()
    for m in ENUM.finditer(zrodlo):
        kod = m.group(1)
        if kod in widziane:
            continue
        widziane.add(kod)
        d = DOC.search(m.group(2))
        opis = " ".join(d.group(1).split()) if d else ""
        lista.append({"kod": kod, "opis": opis})
    return lista


def main():
    t = wczytaj(sys.argv[1])
    typy = typy_proste(t)
    wynik = {"slowniki": {}, "typy": {}}
    for nazwa, zrodlo in sorted(typy.items()):
        z = znaczniki(zrodlo)
        if z:
            wynik["slowniki"][nazwa] = z
        else:
            restr = re.search(r'<xsd:restriction base="([^"]+)"', zrodlo)
            d = DOC.search(zrodlo)
            wynik["typy"][nazwa] = {
                "baza": restr.group(1) if restr else "",
                "opis": " ".join(d.group(1).split()) if d else "",
                "ograniczenia": re.findall(r'<xsd:(\w+) value="([^"]*)"/>', zrodlo),
            }
    json.dump(wynik, sys.stdout, ensure_ascii=False, indent=1)
    print()


if __name__ == "__main__":
    main()
