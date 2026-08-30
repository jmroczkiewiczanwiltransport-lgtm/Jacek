#!/usr/bin/env python3
"""Analiza godzinowych danych o energii (eksport z eBOK Enei i podobnych).

Pokazuje nie „ile prądu", tylko „o której" — a przy fotowoltaice w net-billingu
to właśnie godzina decyduje o pieniądzach. Kilowatogodzina zużyta na miejscu
jest warta tyle, ile kosztuje kupiona; ta sama oddana do sieci — jakieś trzy do
czterech razy mniej. Optymalizacja polega więc na przesuwaniu poboru na godziny
własnej produkcji.

    python3 prad-enea.py dane-godzinowe.csv
    python3 prad-enea.py dane-godzinowe.xlsx --cena-kupna 1.10 --cena-sprzedazy 0.28

Plik rozpoznawany jest automatycznie — kolumny z datą, godziną, energią pobraną
i oddaną wyszukiwane są po nagłówkach, bo każdy operator nazywa je inaczej.
"""

import argparse
import csv
import io
import os
import re
import sys
import unicodedata
from collections import defaultdict
from datetime import datetime

# Ceny domyślne: rząd wielkości dla gospodarstwa domowego w 2026 roku.
# Podaj swoje z faktury — wynik będzie dokładniejszy.
CENA_KUPNA = 1.10          # zł/kWh z dystrybucją i podatkami
CENA_SPRZEDAZY = 0.28      # zł/kWh, średnia cena rynkowa w rozliczeniu prosumenta


def bez_ogonkow(tekst):
    rozlozone = unicodedata.normalize('NFD', str(tekst or ''))
    return ''.join(z for z in rozlozone if unicodedata.category(z) != 'Mn').lower().strip()


def liczba(wartosc):
    if isinstance(wartosc, (int, float)):
        return float(wartosc)
    tekst = str(wartosc or '').strip().replace(' ', '').replace(' ', '')
    if not tekst:
        return None
    # 124,080 to u nas 124,08 — przecinek dziesiętny, nie separator tysięcy
    tekst = tekst.replace(',', '.')
    if tekst.count('.') > 1:
        czesci = tekst.split('.')
        tekst = ''.join(czesci[:-1]) + '.' + czesci[-1]
    try:
        return float(tekst)
    except ValueError:
        return None


# ────────────────────────────── wczytywanie ──────────────────────────────

def wiersze_z_pliku(sciezka):
    """Zwraca listę wierszy jako listy komórek — z CSV albo z arkusza."""
    if sciezka.lower().endswith(('.xlsx', '.xlsm')):
        try:
            import openpyxl
        except ImportError:
            raise SystemExit('Do czytania arkuszy potrzebna jest biblioteka openpyxl:\n'
                             '   pip3 install openpyxl\n'
                             'Albo zapisz plik jako CSV i podaj jego nazwę.')
        arkusz = openpyxl.load_workbook(sciezka, data_only=True, read_only=True).active
        return [[k for k in wiersz] for wiersz in arkusz.values]

    with open(sciezka, encoding='utf-8-sig', errors='replace', newline='') as f:
        probka = f.read(8192)
        f.seek(0)
        try:
            dialekt = csv.Sniffer().sniff(probka, delimiters=';,\t')
        except csv.Error:
            dialekt = csv.excel
            dialekt.delimiter = ';'
        return [w for w in csv.reader(f, dialekt)]


TROPY = {
    'data': ('data', 'dzien', 'date', 'doba'),
    'godzina': ('godzina', 'godz', 'hour', 'od godziny', 'przedzial'),
    'pobrana': ('pobrana', 'pobor', 'pobrane', 'a+', 'zuzycie', 'consumption', 'import'),
    'oddana': ('oddana', 'oddane', 'a-', 'produkcja', 'wprowadzona', 'export'),
}


def znajdz_naglowek(wiersze):
    """Szuka wiersza nagłówka i przypisuje kolumnom znaczenie."""
    for numer, wiersz in enumerate(wiersze[:30]):
        podpisy = [bez_ogonkow(k) for k in wiersz]
        kolumny = {}
        for rola, tropy in TROPY.items():
            for i, podpis in enumerate(podpisy):
                if not podpis or i in kolumny.values():
                    continue
                if any(trop in podpis for trop in tropy):
                    kolumny[rola] = i
                    break
        if 'pobrana' in kolumny and 'oddana' in kolumny and ('data' in kolumny or 'godzina' in kolumny):
            return numer, kolumny
    raise SystemExit(
        'Nie rozpoznałem układu pliku — nie widzę kolumn z energią pobraną i oddaną.\n'
        'Otwórz plik i sprawdź nagłówki, albo prześlij mi pierwsze wiersze.')


def czas_z_wiersza(wiersz, kolumny, przesuniecie=0):
    """Składa datę i godzinę; obie bywają w jednej komórce albo w dwóch.

    Przesunięcie odpowiada konwencji numerowania godzin: jedni operatorzy liczą
    je od 0 do 23, inni od 1 do 24, gdzie „1" znaczy godzinę od północy."""
    surowa_data = wiersz[kolumny['data']] if 'data' in kolumny and kolumny['data'] < len(wiersz) else ''
    surowa_godz = wiersz[kolumny['godzina']] if 'godzina' in kolumny and kolumny['godzina'] < len(wiersz) else ''

    if isinstance(surowa_data, datetime):
        podstawa = surowa_data
    else:
        tekst = str(surowa_data or '').strip()
        podstawa = None
        for wzor in ('%Y-%m-%d %H:%M:%S', '%Y-%m-%d %H:%M', '%d.%m.%Y %H:%M',
                     '%Y-%m-%d', '%d.%m.%Y', '%d-%m-%Y'):
            try:
                podstawa = datetime.strptime(tekst[:len(datetime.now().strftime(wzor)) + 2].strip(), wzor)
                break
            except ValueError:
                continue
        if podstawa is None:
            return None

    godzina = None
    tekst_godz = str(surowa_godz or '').strip()
    if tekst_godz:
        # „14", „14:00", „13:00-14:00", „14-15"
        trafienie = re.search(r'(\d{1,2})', tekst_godz)
        if trafienie:
            godzina = int(trafienie.group(1)) - przesuniecie
    if godzina is None:
        godzina = podstawa.hour
    return podstawa.replace(hour=max(0, min(23, godzina)), minute=0, second=0, microsecond=0)


def przesuniecie_godzin(wiersze, kolumny):
    """Z całego pliku odczytuje, od której liczby zaczyna się doba."""
    if 'godzina' not in kolumny:
        return 0
    numery = set()
    for wiersz in wiersze:
        if kolumny['godzina'] >= len(wiersz):
            continue
        trafienie = re.search(r'(\d{1,2})', str(wiersz[kolumny['godzina']] or ''))
        if trafienie:
            numery.add(int(trafienie.group(1)))
    if not numery:
        return 0
    # 1–24 znaczy, że „1" to godzina od północy; 0–23 zostawiamy bez zmian
    return 1 if (min(numery) >= 1 and max(numery) >= 24) else 0


def wczytaj(sciezka):
    wiersze = wiersze_z_pliku(sciezka)
    numer, kolumny = znajdz_naglowek(wiersze)
    dane = wiersze[numer + 1:]
    przesuniecie = przesuniecie_godzin(dane, kolumny)
    odczyty = []
    pominiete = 0
    for wiersz in dane:
        if not wiersz or all(k in (None, '') for k in wiersz):
            continue
        czas = czas_z_wiersza(wiersz, kolumny, przesuniecie)
        pobrana = liczba(wiersz[kolumny['pobrana']]) if kolumny['pobrana'] < len(wiersz) else None
        oddana = liczba(wiersz[kolumny['oddana']]) if kolumny['oddana'] < len(wiersz) else None
        if czas is None or (pobrana is None and oddana is None):
            pominiete += 1
            continue
        odczyty.append((czas, pobrana or 0.0, oddana or 0.0))
    if not odczyty:
        raise SystemExit('Rozpoznałem nagłówek, ale nie wyciągnąłem żadnych danych.')
    return sorted(odczyty), kolumny, pominiete, przesuniecie


# ─────────────────────────────── zestawienia ───────────────────────────────

def miesiace(odczyty):
    wynik = defaultdict(lambda: [0.0, 0.0])
    for czas, pobrana, oddana in odczyty:
        klucz = f'{czas:%Y-%m}'
        wynik[klucz][0] += pobrana
        wynik[klucz][1] += oddana
    return dict(sorted(wynik.items()))


def profil_dobowy(odczyty):
    wynik = {g: [0.0, 0.0, 0] for g in range(24)}
    for czas, pobrana, oddana in odczyty:
        wynik[czas.hour][0] += pobrana
        wynik[czas.hour][1] += oddana
        wynik[czas.hour][2] += 1
    return wynik


def slupek(wartosc, maksimum, szerokosc=28):
    if maksimum <= 0:
        return ''
    return '█' * max(0, round(szerokosc * wartosc / maksimum))


def raport(odczyty, cena_kupna, cena_sprzedazy):
    pobrana_razem = sum(p for _, p, _ in odczyty)
    oddana_razem = sum(o for _, _, o in odczyty)
    od, do = odczyty[0][0], odczyty[-1][0]

    print(f'Okres: {od:%d.%m.%Y} – {do:%d.%m.%Y}   ({len(odczyty)} godzin)')
    print(f'Pobrane: {pobrana_razem:,.0f} kWh     Oddane: {oddana_razem:,.0f} kWh'
          .replace(',', ' '))

    print('\nMIESIĄCAMI')
    print(f'   {"miesiąc":<10}{"pobrane":>12}{"oddane":>12}{"bilans":>12}')
    for miesiac, (pobrana, oddana) in miesiace(odczyty).items():
        print(f'   {miesiac:<10}{pobrana:>9.0f} kWh{oddana:>9.0f} kWh{oddana - pobrana:>+9.0f} kWh')

    profil = profil_dobowy(odczyty)
    maksimum = max(max(p, o) for p, o, _ in profil.values()) or 1
    print('\nO KTÓREJ GODZINIE  (█ pobór z sieci, ░ oddawanie)')
    for godzina in range(24):
        pobrana, oddana, _ = profil[godzina]
        print(f'   {godzina:02d}:00 {pobrana:>7.0f} {slupek(pobrana, maksimum):<28}'
              f'{oddana:>7.0f} {"░" * len(slupek(oddana, maksimum))}')

    # Pobór w godzinach, w których słońce w ogóle pracuje, to ten, który da się
    # przesunąć na własną produkcję — resztę i tak trzeba kupić.
    dzien = sum(p for czas, p, _ in odczyty if 9 <= czas.hour < 16)
    noc = pobrana_razem - dzien
    print(f'\nPobór w godzinach 9–16: {dzien:.0f} kWh ({dzien / max(pobrana_razem, 1) * 100:.0f} %)')
    print(f'Pobór poza nimi:        {noc:.0f} kWh ({noc / max(pobrana_razem, 1) * 100:.0f} %)')

    # Czy zmiana taryfy z płaskiej na dwustrefową ma sens, zależy wyłącznie od
    # tego, ile poboru wypada w tanich godzinach — a to widać w danych.
    tanie_g12 = sum(p for czas, p, _ in odczyty
                    if czas.hour >= 22 or czas.hour < 6 or 13 <= czas.hour < 15)
    tanie_g12w = sum(p for czas, p, _ in odczyty
                     if czas.weekday() >= 5 or czas.hour >= 22 or czas.hour < 6
                     or 13 <= czas.hour < 15)
    print(f'\nGDYBY ZMIENIĆ TARYFĘ  (udział poboru w godzinach tańszej strefy)')
    print(f'   G12  (22–6 i 13–15):                 {tanie_g12 / max(pobrana_razem, 1) * 100:>5.0f} %')
    print(f'   G12w (jak wyżej plus całe weekendy): {tanie_g12w / max(pobrana_razem, 1) * 100:>5.0f} %')
    print('   Poniżej mniej więcej 55 % zmiana zwykle się nie opłaca — droższa strefa')
    print('   dzienna i wyższa opłata przesyłowa zjadają zysk z nocnej.')

    print('\nPIENIĄDZE  (przy cenach: kupno '
          f'{cena_kupna:.2f} zł/kWh, sprzedaż {cena_sprzedazy:.2f} zł/kWh)')
    koszt = pobrana_razem * cena_kupna
    depozyt = oddana_razem * cena_sprzedazy
    print(f'   koszt energii pobranej      {koszt:>10.0f} zł')
    print(f'   depozyt za energię oddaną   {depozyt:>10.0f} zł')
    print(f'   różnica                     {depozyt - koszt:>+10.0f} zł')

    strata = oddana_razem * (cena_kupna - cena_sprzedazy)
    print(f'\nGdyby cała oddana energia była zużyta na miejscu, byłaby warta '
          f'{strata:.0f} zł więcej.')
    print('To górna granica tego, co da się ugrać przesuwaniem poboru — nieosiągalna,')
    print('bo latem nie ma czym tej energii zużyć. Ale pokazuje, gdzie leżą pieniądze.')

    if dzien > 0:
        zysk = dzien * (cena_kupna - cena_sprzedazy)
        print(f'\nSam pobór z godzin 9–16 ({dzien:.0f} kWh) wart jest {zysk:.0f} zł różnicy —')
        print('tyle mniej więcej daje przesunięcie grzania CWU i bufora na południe,')
        print('o ile w tych godzinach jest jednocześnie nadwyżka z paneli.')


def main():
    parser = argparse.ArgumentParser(description='Analiza godzinowych danych o energii.')
    parser.add_argument('plik', help='eksport danych godzinowych (CSV albo XLSX)')
    parser.add_argument('--cena-kupna', type=float, default=CENA_KUPNA,
                        help='zł/kWh z dystrybucją — weź z faktury')
    parser.add_argument('--cena-sprzedazy', type=float, default=CENA_SPRZEDAZY,
                        help='zł/kWh w rozliczeniu prosumenta')
    argumenty = parser.parse_args()

    if not os.path.exists(argumenty.plik):
        raise SystemExit(f'Nie ma pliku {argumenty.plik}')
    odczyty, kolumny, pominiete, przesuniecie = wczytaj(argumenty.plik)
    if pominiete:
        print(f'(pominąłem {pominiete} wierszy bez danych)')
    if przesuniecie:
        print('(godziny numerowane od 1 do 24 — przeliczyłem na 0–23)')
    print()
    raport(odczyty, argumenty.cena_kupna, argumenty.cena_sprzedazy)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
    except BrokenPipeError:
        os._exit(0)
