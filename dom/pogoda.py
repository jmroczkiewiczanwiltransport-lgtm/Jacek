#!/usr/bin/env python3
"""Pogoda z Open-Meteo — temperatura odniesienia i prognoza nasłonecznienia.

Po co to pompie ciepła:

**Czujnik zewnętrzny stoi w słońcu.** 17.10.2026 pokazał 6,7 °C o 8:08 i
17,4 °C o 12:15. Sterownik dobiera po nim temperaturę wody, więc w pogodny
dzień odpuszcza grzanie dokładnie wtedy, gdy prąd jest najtańszy. Mając obok
odczyt modelu meteorologicznego widać, o ile obudowa zawyża.

**Nasłonecznienie mówi, czy podbicie w południe ma sens.** Harmonogram grzeje
w oknie 11:00–16:00 niezależnie od pogody. W dzień słoneczny to ciepło jest
z paneli i prawie darmowe; pod chmurami to zwykły prąd z sieci, i to zużyty
przy gorszej sprawności. Prognoza promieniowania pozwala to rozróżnić rano,
a nie trzy dni później z danych operatora.

Open-Meteo nie wymaga klucza ani rejestracji. Model **ICON-D2** (DWD) liczy
siatkę 2 km i obejmuje Polskę — dla pojedynczego domu to najlepsze, co jest
za darmo. Gdy go brakuje (prognoza dalej niż dwie doby), serwis sam schodzi
na model o grubszej siatce.
"""

import json
import os
import urllib.parse
import urllib.request
from datetime import datetime

USLUGA = 'https://api.open-meteo.com/v1/forecast'
KATALOG = os.path.dirname(os.path.abspath(__file__))
PLIK_USTAWIEN = os.path.join(KATALOG, 'pogoda.json')

# Próg, powyżej którego dzień uznajemy za wart podbicia grzania w południe.
# 2,0 kWh/m² w oknie 11–16 to w październiku dzień wyraźnie pogodny; przy
# 10 kWp daje to kilkanaście kilowatogodzin, czyli więcej, niż pompa zdoła zjeść.
PROG_SLONECZNY = 2.0
PROG_POCHMURNY = 0.9


def wczytaj_ustawienia(plik=None):
    """Współrzędne domu. Trzymane osobno, bo to dane Jacka, nie kod."""
    plik = plik or PLIK_USTAWIEN
    if not os.path.exists(plik):
        return None
    try:
        with open(plik, encoding='utf-8') as f:
            dane = json.load(f)
        return {'szerokosc': float(dane['szerokosc']),
                'dlugosc': float(dane['dlugosc']),
                'nazwa': dane.get('nazwa', '')}
    except (ValueError, KeyError, OSError):
        return None


def pobierz(szerokosc, dlugosc, limit=10, model='icon_d2'):
    """Surowa odpowiedź serwisu dla jednego punktu."""
    pytanie = {
        'latitude': f'{szerokosc:.4f}',
        'longitude': f'{dlugosc:.4f}',
        'current': 'temperature_2m,cloud_cover,shortwave_radiation',
        'hourly': 'temperature_2m,cloud_cover,shortwave_radiation',
        'forecast_days': '2',
        'timezone': 'Europe/Warsaw',
    }
    if model:
        pytanie['models'] = model
    adres = f'{USLUGA}?{urllib.parse.urlencode(pytanie)}'
    zadanie = urllib.request.Request(adres, headers={'User-Agent': 'panel-pompy'})
    with urllib.request.urlopen(zadanie, timeout=limit) as odp:
        return json.loads(odp.read().decode('utf-8'))


def _suma_kwh(godziny, wartosci, od_godziny, do_godziny, dzien):
    """Promieniowanie w W/m² to średnia z minionej godziny — suma w kWh/m²."""
    razem = 0.0
    for chwila, wat in zip(godziny, wartosci):
        if wat is None:
            continue
        try:
            kiedy = datetime.fromisoformat(chwila)
        except ValueError:
            continue
        if kiedy.date() != dzien:
            continue
        if od_godziny <= kiedy.hour < do_godziny:
            razem += wat / 1000.0
    return round(razem, 2)


def podsumuj(odpowiedz, okno=(11, 16), teraz=None):
    """Z surowej odpowiedzi robi to, co panel ma pokazać."""
    teraz = teraz or datetime.now()
    biezace = odpowiedz.get('current') or {}
    godzinowe = odpowiedz.get('hourly') or {}
    czasy = godzinowe.get('time') or []
    slonce = godzinowe.get('shortwave_radiation') or []

    dzis = teraz.date()
    suma_doby = _suma_kwh(czasy, slonce, 0, 24, dzis)
    suma_okna = _suma_kwh(czasy, slonce, okno[0], okno[1], dzis)

    if suma_okna >= PROG_SLONECZNY:
        ocena = 'sloneczny'
    elif suma_okna <= PROG_POCHMURNY:
        ocena = 'pochmurny'
    else:
        ocena = 'posredni'

    return {
        'temperatura': biezace.get('temperature_2m'),
        'zachmurzenie': biezace.get('cloud_cover'),
        'naslonecznienie': biezace.get('shortwave_radiation'),
        'suma_doby': suma_doby,
        'suma_okna': suma_okna,
        'okno': list(okno),
        'ocena': ocena,
        'o_ktorej': biezace.get('time'),
    }


def pogoda(ustawienia=None, okno=(11, 16), limit=10):
    """Całość w jednym kroku. Zwraca None, gdy nie ma ustawień albo łączności."""
    ustawienia = ustawienia or wczytaj_ustawienia()
    if not ustawienia:
        return None
    odpowiedz = pobierz(ustawienia['szerokosc'], ustawienia['dlugosc'], limit)
    wynik = podsumuj(odpowiedz, okno)
    wynik['nazwa'] = ustawienia.get('nazwa', '')
    return wynik


if __name__ == '__main__':
    import sys
    try:
        w = pogoda()
    except OSError as powod:
        print(f'Nie pobrałem pogody: {powod}')
        sys.exit(1)
    if not w:
        print(f'Brak {PLIK_USTAWIEN} — skopiuj pogoda.przyklad.json '
              f'i wpisz współrzędne domu.')
        sys.exit(1)
    print(f"{w['nazwa'] or 'dom'}  ({w['o_ktorej']})")
    print(f"  temperatura      {w['temperatura']} °C")
    print(f"  zachmurzenie     {w['zachmurzenie']} %")
    print(f"  słońce teraz     {w['naslonecznienie']} W/m²")
    print(f"  suma doby        {w['suma_doby']} kWh/m²")
    print(f"  w oknie {w['okno'][0]}–{w['okno'][1]}    {w['suma_okna']} kWh/m²  → {w['ocena']}")
