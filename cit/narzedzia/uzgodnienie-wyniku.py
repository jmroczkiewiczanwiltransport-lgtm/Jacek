#!/usr/bin/env python3
"""Wynik księgowy, korekty podatkowe i kwota podatku — liczone z dziennika.

To jest jądro generatora: z dziennika zapisów za rok i ze znaczników przy
kontach wyprowadza wynik księgowy, pozycje K_1–K_8 węzła RPD, dochód
i podatek. Prototyp w Pythonie — służy do sprawdzania na prawdziwych księgach,
zanim te same reguły trafią do narzędzia w przeglądarce.

Wejście:
  dziennik.csv    kolumny: CPTGE (konto), LICOFD (nazwa), ORIGIN, DTECR8, MTLIG
                  (kwota ze znakiem: dodatnia = Wn, ujemna = Ma)
  plan_kont.xlsx  numer konta + nazwa (dla nazw w pliku JPK i dla reguł)
  wzorzec.json    opcjonalnie: liczby księgowej do porównania

Uruchomienie:
  python3 uzgodnienie-wyniku.py dziennik.csv plan_kont.xlsx [wzorzec.json]
"""
import collections
import csv
import json
import os
import re
import sys
from decimal import Decimal

BAZA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "slowniki")
ZERO = Decimal("0")
NAPRAWA_ZNAKOW = {"¡": "Ś", "£": "Ą", "©": "Ż", "¬": "Ł", "Ê": "Ę", "ù": "Ń"}

# Pozycje RPD, do których sumują się znaczniki podatkowe kont.
PD_DO_RPD = {
    "PD1": "K_1", "PD1_1": "K_1", "PD1_2": "K_1", "PD1_3": "K_1",
    "PD2": "K_2", "PD3_PB": "K_3",
    "PD4": "K_4", "PD4_1": "K_4", "PD4_2": "K_4", "PD4_3": "K_4",
    "PD5": "K_5", "PD6_PB": "K_6",
}
# Konto wyłączone z podatku koryguje dochód o tyle, ile wniosło do wyniku
# księgowego, ze znakiem przeciwnym. Wynik księgowy = minus suma sald kont
# wynikowych, więc korekta konta = jego saldo ze znakiem, bez żadnych
# przypadków szczególnych: przychód zwolniony (saldo Ma, ujemne) dochód
# zmniejsza, koszt NKUP (saldo Wn, dodatnie) zwiększa, a odwrócenie kosztu
# NKUP z lat ubiegłych (saldo Ma na koncie kosztowym) znowu zmniejsza.
# Wartości bezwzględne pojawiają się dopiero w polach K_ pliku JPK.


def napraw(s):
    return "".join(NAPRAWA_ZNAKOW.get(c, c) for c in str(s or ""))


def wczytaj_reguly():
    return json.load(open(os.path.join(BAZA, "reguly-mapowania.json"), encoding="utf-8"))


def wczytaj_dziennik(sciezka):
    rows = list(csv.DictReader(open(sciezka, encoding="utf-8")))
    for r in rows:
        r["kwota"] = Decimal(r["MTLIG"]) if r["MTLIG"] else ZERO
    return rows


def wczytaj_plan(sciezka):
    import openpyxl
    ws = openpyxl.load_workbook(sciezka, data_only=True).active
    plan = {}
    for w in ws.iter_rows(values_only=True):
        if not w or not w[0]:
            continue
        kod = str(w[0]).strip()
        if not kod[:1].isdigit():
            continue
        plan[kod] = napraw(w[1] if len(w) > 1 else "")
    return plan


def znaczniki_pd(konta, reguly, profil):
    """Znacznik podatkowy dla konta — z reguł, po nazwie.

    Nazwę bierzemy z planu kont i z dziennika: eksporty bywają w innym języku
    niż plan kont (u pierwszego klienta plan po polsku, dziennik po angielsku),
    a reguła może pasować tylko do jednej z wersji.
    """
    out = {}
    for kod, nazwy in konta.items():
        grupa = profil["zespoly"].get(kod[:1], "")
        kontekst = grupa if grupa in ("koszty", "przychody") else ""
        for r in reguly["reguly_pd"]:
            if r.get("kontekst") and r["kontekst"] != kontekst:
                continue
            if any(n and re.search(r["nazwa_regex"], n, re.I) for n in nazwy):
                out[kod] = (r["znacznik"], r["dlaczego"])
                break
    return out


def main():
    dziennik = wczytaj_dziennik(sys.argv[1])
    plan = wczytaj_plan(sys.argv[2])
    wzorzec = json.load(open(sys.argv[3], encoding="utf-8")) if len(sys.argv) > 3 else {}
    reguly = wczytaj_reguly()
    profil = reguly["profile_planu_kont"]["erp_zagraniczny_a"]

    # nazwy kont z obu źródeł
    konta = collections.defaultdict(set)
    for kod, nazwa in plan.items():
        konta[kod].add(nazwa)
    for r in dziennik:
        konta[r["CPTGE"]].add(r["LICOFD"] or "")

    saldo = collections.defaultdict(lambda: ZERO)
    bo = collections.defaultdict(lambda: ZERO)
    for r in dziennik:
        saldo[r["CPTGE"]] += r["kwota"]
        if r["ORIGIN"] == "OUV":
            bo[r["CPTGE"]] += r["kwota"]

    tylko_dziennik = sorted(k for k in saldo if k not in plan)

    przychody = -sum(v for k, v in saldo.items() if k[:1] == "7")
    koszty = sum(v for k, v in saldo.items()
                 if k[:1] == "6" and not k.startswith(("695", "699")))
    podatek_ksiegowy = sum(v for k, v in saldo.items() if k.startswith(("695", "699")))
    wynik = przychody - koszty

    pd = znaczniki_pd(konta, reguly, profil)
    rpd = collections.defaultdict(lambda: ZERO)
    pozycje = collections.defaultdict(list)
    korekta = ZERO
    for kod, (znacznik, _) in pd.items():
        pole = PD_DO_RPD.get(znacznik)
        if not pole:
            continue
        korekta_konta = saldo.get(kod, ZERO)
        if korekta_konta == 0:
            continue
        korekta += korekta_konta
        rpd[pole] += korekta_konta
        pozycje[pole].append((kod, sorted(konta[kod])[0], korekta_konta))

    dochod = wynik + korekta

    print("=" * 78)
    print("WYNIK KSIĘGOWY Z DZIENNIKA")
    print("  przychody (zespół 7)          %18s" % przychody)
    print("  koszty (zespół 6 bez podatku) %18s" % koszty)
    print("  wynik brutto                  %18s" % wynik)
    print("  podatek zaksięgowany (695/699)%18s" % podatek_ksiegowy)
    print("  wynik netto                   %18s" % (wynik - podatek_ksiegowy))
    print()
    print("KOREKTY PODATKOWE (węzeł RPD) — ze znaczników przy kontach")
    for pole in sorted(rpd):
        print("  %-4s %18s  (%d kont)" % (pole, rpd[pole], len(pozycje[pole])))
        for kod, nazwa, kwota in sorted(pozycje[pole], key=lambda x: -abs(x[2])):
            print("        %-8s %-34s %14s" % (kod, nazwa[:34], kwota))
    print()
    print("  razem korekta                 %18s" % korekta)
    print("  DOCHÓD                        %18s" % dochod)
    for stawka in ("19", "9"):
        p = (dochod * Decimal(stawka) / 100).quantize(Decimal("0.01"))
        print("  podatek %s%%                    %18s" % (stawka, p))

    if wzorzec:
        print()
        print("PORÓWNANIE ZE WZORCEM KSIĘGOWEJ")
        if "korekty" in wzorzec:
            w = Decimal(str(wzorzec["korekty"]))
            print("  %-14s wzorzec %16s  nasze %16s  różnica %s"
                  % ("korekty", w, korekta, korekta - w))
        for klucz, nasza in (("wynik_brutto", wynik), ("dochod", dochod)):
            if klucz in wzorzec:
                w = Decimal(str(wzorzec[klucz]))
                r = nasza - w
                print("  %-14s wzorzec %16s  nasze %16s  różnica %s  %s"
                      % (klucz, w, nasza, r, "ZGODNE" if abs(r) <= Decimal("0.01") else "ROZJAZD"))
    if tylko_dziennik:
        print()
        print("Konta w dzienniku, których nie ma w planie kont (%d):" % len(tylko_dziennik))
        for k in tylko_dziennik:
            print("   %-8s %-34s saldo %s" % (k, sorted(konta[k])[0][:34], saldo[k]))


if __name__ == "__main__":
    main()
