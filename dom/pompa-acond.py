#!/usr/bin/env python3
"""Rozpoznawanie i odczyt pompy ciepła ACOND przez Modbus TCP.

Sterowniki ACOND wystawiają Modbus TCP na porcie 502 po tym samym kablu, którym
pompa jest wpięta do sieci. Tablica rejestrów jest w dokumentacji producenta
(AC-Z010), ale nie trzeba jej mieć, żeby zacząć: te narzędzia odczytują rejestry
wprost z pompy i pomagają rozpoznać, co jest czym.

    python3 pompa-acond.py strona http://192.168.88.9/PAGE115.XML
    python3 pompa-acond.py dopasuj http://192.168.88.9/PAGE115.XML --panel panel-acond.json
    python3 pompa-acond.py yaml http://192.168.88.9/PAGE115.XML

Sterownik ACOND serwuje swoje ekrany jako XML z wartościami w środku, więc
odczyty można brać wprost stamtąd — bez Modbusa. Gdy strona nie wystarcza,
zostaje droga przez rejestry:

    python3 pompa-acond.py sprawdz 192.168.88.9
    python3 pompa-acond.py skanuj 192.168.88.9
    python3 pompa-acond.py dopasuj 192.168.88.9 --panel panel-acond.json
    python3 pompa-acond.py obserwuj 192.168.88.9 --od 0 --ile 60
    python3 pompa-acond.py czytaj 192.168.88.9 --od 10 --ile 4
    python3 pompa-acond.py yaml 192.168.88.9 --opisy opisy-pompy.json

Bez zależności zewnętrznych — Modbus TCP to na tyle prosty protokół, że własna
obsługa jest pewniejsza niż biblioteka zmieniająca API między wersjami.
"""

import argparse
import base64
import json
import os
import re
import socket
import sys
import time
import unicodedata
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime

KATALOG = os.path.dirname(os.path.abspath(__file__))

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from modbus import (CZYTAJ_HOLDING, CZYTAJ_INPUT, ZAPISZ_JEDEN, BLEDY, Modbus,   # noqa: E402
                    ze_znakiem, podpowiedz)

# ──────────────────── odczyt ze strony WWW sterownika ────────────────────
# Panel ACOND THERM serwuje strony XML, w których wartości siedzą wprost —
# każda jako <INPUT NAME="__T<skrót>_<typ>_<format>" VALUE="…" />. Nazwy są
# skrótami, ale stałymi: dopóki nie zmieni się program sterownika, ten sam
# skrót zawsze oznacza tę samą wielkość.

def pobierz_strone(url, uzytkownik=None, haslo=None, limit=15):
    zadanie = urllib.request.Request(url, headers={'User-Agent': 'pompa-acond'})
    if uzytkownik:
        poswiadczenie = base64.b64encode(f'{uzytkownik}:{haslo or ""}'.encode()).decode()
        zadanie.add_header('Authorization', 'Basic ' + poswiadczenie)
    try:
        with urllib.request.urlopen(zadanie, timeout=limit) as odpowiedz:
            surowe = odpowiedz.read()
    except urllib.error.HTTPError as powod:
        if powod.code in (401, 403):
            raise OSError(f'strona wymaga logowania ({powod.code}) — podaj --uzytkownik i --haslo')
        raise OSError(f'strona odpowiedziała {powod.code}')
    except urllib.error.URLError as powod:
        raise OSError(f'nie mogę pobrać strony: {powod.reason}')
    return czytaj_zmienne(surowe)


def czytaj_zmienne(surowe):
    """Z treści strony wyciąga {nazwa zmiennej: wartość jako tekst}."""
    try:
        korzen = ET.fromstring(surowe)
        zmienne = {w.get('NAME'): w.get('VALUE', '') for w in korzen.iter('INPUT') if w.get('NAME')}
        if zmienne:
            return zmienne
    except ET.ParseError:
        pass
    # gdyby XML był niedomknięty albo w innym kodowaniu — bierzemy po znaku
    tekst = surowe.decode('windows-1250', errors='replace') if isinstance(surowe, bytes) else surowe
    return dict(re.findall(r'<INPUT\s+NAME="([^"]+)"\s+VALUE="([^"]*)"', tekst))


def bez_ogonkow(tekst):
    rozlozone = unicodedata.normalize('NFD', str(tekst or ''))
    return ''.join(z for z in rozlozone if unicodedata.category(z) != 'Mn').lower().strip()


def liczba(tekst):
    try:
        return float(str(tekst).replace(',', '.'))
    except (TypeError, ValueError):
        return None


def rodzaj_zmiennej(nazwa):
    """Z nazwy zmiennej czyta jej typ: __T9E13248E_REAL_.1f → REAL."""
    trafienie = re.match(r'_*T[0-9A-Fa-f]+_([A-Z]+)', str(nazwa))
    return trafienie.group(1) if trafienie else '?'


def strona(argumenty):
    zmienne = pobierz_strone(argumenty.host, argumenty.uzytkownik, argumenty.haslo)
    print(f'Zmiennych na stronie: {len(zmienne)}\n')

    liczbowe = {n: w for n, w in zmienne.items() if rodzaj_zmiennej(n) in ('REAL', 'INT', 'UINT', 'USINT', 'DINT')}
    napisy = {n: w for n, w in zmienne.items() if rodzaj_zmiennej(n) == 'STRING' and w.strip()}
    logiczne = {n: w for n, w in zmienne.items() if rodzaj_zmiennej(n) == 'BOOL'}
    inne = {n: w for n, w in zmienne.items()
            if n not in liczbowe and n not in napisy and n not in logiczne}

    print('LICZBY  (to z nich robimy czujniki)')
    for n, w in sorted(liczbowe.items(), key=lambda x: -abs(liczba(x[1]) or 0)):
        print(f'   {n:<30} {w:>10}')
    if inne:
        print('\nDATY I GODZINY')
        for n, w in sorted(inne.items()):
            print(f'   {n:<30} {w:>10}')
    print('\nNAPISY  (podpisy z ekranu — pomagają rozpoznać, co jest czym)')
    for n, w in sorted(napisy.items()):
        print(f'   {n:<30} {w}')
    print(f'\nWARTOŚCI LOGICZNE: {len(logiczne)} (włączniki i sygnalizacja)')
    print('\nDalej: przepisz odczyty z ekranu do panel-acond.json i uruchom')
    print(f'   python3 pompa-acond.py dopasuj {argumenty.host} --panel panel-acond.json')


def dopasuj_strone(argumenty, panel):
    zmienne = pobierz_strone(argumenty.host, argumenty.uzytkownik, argumenty.haslo)
    liczbowe = {n: liczba(w) for n, w in zmienne.items() if liczba(w) is not None}
    print(f'Pobrałem {len(zmienne)} zmiennych, w tym {len(liczbowe)} liczbowych.\n')

    surowe = {n: w for n, w in zmienne.items() if liczba(w) is not None}
    rozpoznane, niepewne, przepadle = {}, [], []
    for nazwa, wartosc in panel.items():
        # Wartość podana jako tekst („0.00") musi zgodzić się co do znaku — a że
        # sterownik wyświetla każdą wielkość w swoim formacie, samo to potrafi
        # rozstrzygnąć, która zmienna jest którą.
        if isinstance(wartosc, str):
            kandydaci = [n for n, w in surowe.items() if w.strip() == wartosc.strip()]
            if not kandydaci:
                kandydaci = [n for n, w in liczbowe.items() if w == liczba(wartosc)]
        else:
            kandydaci = [n for n, w in liczbowe.items() if w == float(wartosc)]
        if not kandydaci:
            przepadle.append((nazwa, wartosc))
        elif len(kandydaci) == 1:
            rozpoznane[kandydaci[0]] = nazwa
            print(f'   {nazwa:<32} → {kandydaci[0]}')
        else:
            niepewne.append((nazwa, wartosc, kandydaci))

    for nazwa, wartosc, kandydaci in niepewne:
        print(f'   {nazwa:<32} → {len(kandydaci)} pasujących: {", ".join(kandydaci)}')
    for nazwa, wartosc in przepadle:
        print(f'   {nazwa:<32} → nie znalazłem wartości {wartosc}')

    if niepewne:
        print('\nKilka zmiennych ma tę samą wartość. Rozstrzygniesz je obserwacją:')
        print(f'   python3 pompa-acond.py obserwuj {argumenty.host}')
        print('Temperatury mierzone drgają same, nastawy stoją — to je rozdziela.')
    if przepadle:
        print('\nCzego nie znalazłem, to zwykle znaczy, że odczyt zdążył się zmienić.')
        print('Przepisz wartości jeszcze raz i uruchom od nowa.')

    if rozpoznane:
        plik = os.path.join(KATALOG, 'opisy-panelu.json')
        istniejace = {}
        if os.path.exists(plik):
            with open(plik, encoding='utf-8') as f:
                istniejace = json.load(f).get('zmienne', {})
        for zmienna, nazwa in rozpoznane.items():
            istniejace[zmienna] = [nazwa, jednostka_z_nazwy(nazwa)]
        with open(plik, 'w', encoding='utf-8') as f:
            json.dump({'_zrodlo': argumenty.host, 'zmienne': istniejace}, f, ensure_ascii=False, indent=2)
        print(f'\nZapisałem {plik} — {len(rozpoznane)} zmiennych.')
        print(f'Dalej:  python3 pompa-acond.py yaml {argumenty.host}')


def obserwuj_strone(argumenty):
    print(f'Obserwuję {argumenty.host}. Zmieniaj nastawy na panelu. Ctrl+C kończy.\n')
    poprzednie = None
    try:
        while True:
            zmienne = pobierz_strone(argumenty.host, argumenty.uzytkownik, argumenty.haslo)
            if poprzednie is None:
                print(f'{time.strftime("%H:%M:%S")}  pierwszy odczyt: {len(zmienne)} zmiennych')
            else:
                for nazwa, wartosc in zmienne.items():
                    stare = poprzednie.get(nazwa)
                    if stare is not None and stare != wartosc:
                        print(f'{time.strftime("%H:%M:%S")}  {nazwa:<30} {stare} → {wartosc}')
            poprzednie = zmienne
            time.sleep(argumenty.co)
    except KeyboardInterrupt:
        print('\nKoniec.')


def wczytaj_opisy_panelu():
    plik = os.path.join(KATALOG, 'opisy-panelu.json')
    if not os.path.exists(plik):
        return {}
    with open(plik, encoding='utf-8') as f:
        return json.load(f).get('zmienne', {})


def zapisuj(argumenty):
    """Zapisuje odczyty do pliku CSV — materiał do optymalizacji sezonu.

    Dane zbierane przed sezonem grzewczym są warte tyle, co te zbierane w jego
    trakcie: bez nich każda zmiana nastaw jest zgadywaniem."""
    plik = argumenty.plik or os.path.join(KATALOG, 'dane-pompy.csv')
    opisy = wczytaj_opisy_panelu()
    nazwa_kolumny = lambda zmienna: opisy.get(zmienna, [zmienna])[0]

    zmienne = pobierz_strone(argumenty.host, argumenty.uzytkownik, argumenty.haslo)
    kolumny = sorted((n for n, w in zmienne.items() if liczba(w) is not None),
                     key=lambda n: (nazwa_kolumny(n) == n, nazwa_kolumny(n)))

    istnieje = os.path.exists(plik)
    if istnieje:
        with open(plik, encoding='utf-8') as f:
            naglowek = f.readline().rstrip('\n').split(';')[1:]
        wg_nazwy = {nazwa_kolumny(n): n for n in kolumny}
        kolumny = [wg_nazwy.get(nazwa) for nazwa in naglowek]
        print(f'Dopisuję do {plik} ({len(naglowek)} kolumn z poprzedniego zapisu).')
    else:
        with open(plik, 'w', encoding='utf-8') as f:
            f.write(';'.join(['czas'] + [nazwa_kolumny(n) for n in kolumny]) + '\n')
        print(f'Zakładam {plik} — kolumn: {len(kolumny)}.')

    print(f'Zapisuję co {argumenty.co:.0f} s. Ctrl+C kończy. '
          f'Zostaw to uruchomione — im dłużej, tym więcej wiadomo.')
    zapisanych, bledow = 0, 0
    try:
        while True:
            try:
                zmienne = pobierz_strone(argumenty.host, argumenty.uzytkownik, argumenty.haslo)
                wiersz = [datetime.now().strftime('%Y-%m-%d %H:%M:%S')]
                wiersz += ['' if z is None else str(zmienne.get(z, '')).strip() for z in kolumny]
                with open(plik, 'a', encoding='utf-8') as f:
                    f.write(';'.join(wiersz) + '\n')
                zapisanych += 1
                if zapisanych % 12 == 1:
                    print(f'{datetime.now():%H:%M:%S}  zapisanych odczytów: {zapisanych}'
                          + (f', nieudanych: {bledow}' if bledow else ''))
            except OSError as powod:
                bledow += 1
                print(f'{datetime.now():%H:%M:%S}  nie udało się odczytać ({powod}) — próbuję dalej')
            time.sleep(argumenty.co)
    except KeyboardInterrupt:
        print(f'\nKoniec. Zapisanych odczytów: {zapisanych}, nieudanych: {bledow}.')
        print(f'Podsumowanie:  python3 pompa-acond.py podsumuj --plik {os.path.basename(plik)}')


def podsumuj(argumenty):
    """Dzień po dniu: ile prądu, przy jakiej pogodzie."""
    plik = argumenty.plik or os.path.join(KATALOG, 'dane-pompy.csv')
    if not os.path.exists(plik):
        raise SystemExit(f'Brak {plik} — najpierw uruchom „zapisuj".')
    with open(plik, encoding='utf-8') as f:
        naglowek = f.readline().rstrip('\n').split(';')
        wiersze = [w.rstrip('\n').split(';') for w in f if w.strip()]
    if not wiersze:
        raise SystemExit('Plik jest pusty — zapis jeszcze nic nie zebrał.')

    def kolumna(fragment):
        # przy kilku pasujących bierzemy najkrótszą nazwę: „Temperatura zewnętrzna"
        # a nie „Temperatura zewnętrzna średnia"
        trafienia = [(len(nazwa), i) for i, nazwa in enumerate(naglowek)
                     if fragment in bez_ogonkow(nazwa)]
        return min(trafienia)[1] if trafienia else None

    i_energia = kolumna('licznik energ')
    i_zewn = kolumna('zewnetrzna') 
    i_cwu = kolumna('cwu temper')
    i_moc = kolumna('wydajnosc')

    dni = {}
    for wiersz in wiersze:
        dzien = wiersz[0][:10]
        dni.setdefault(dzien, []).append(wiersz)

    print(f'{"DZIEŃ":<12}{"PRĄD":>10}{"ŚR. NA DWORZE":>16}{"NAJZIMNIEJ":>12}'
          f'{"ŚR. CWU":>10}{"ODCZYTÓW":>10}')
    poprzednia_energia = None
    for dzien, grupa in sorted(dni.items()):
        def wartosci(indeks):
            if indeks is None:
                return []
            return [liczba(w[indeks]) for w in grupa if indeks < len(w) and liczba(w[indeks]) is not None]

        energia = wartosci(i_energia)
        zuzycie = (max(energia) - min(energia)) if len(energia) > 1 else None
        zewn, cwu = wartosci(i_zewn), wartosci(i_cwu)
        print(f'{dzien:<12}'
              f'{(f"{zuzycie:.0f} kWh" if zuzycie is not None else "—"):>10}'
              f'{(f"{sum(zewn)/len(zewn):.1f} °C" if zewn else "—"):>16}'
              f'{(f"{min(zewn):.1f} °C" if zewn else "—"):>12}'
              f'{(f"{sum(cwu)/len(cwu):.1f} °C" if cwu else "—"):>10}'
              f'{len(grupa):>10}')

    wszystkie_zewn = [liczba(w[i_zewn]) for w in wiersze
                      if i_zewn is not None and i_zewn < len(w) and liczba(w[i_zewn]) is not None]
    wszystkie_energia = [liczba(w[i_energia]) for w in wiersze
                         if i_energia is not None and i_energia < len(w) and liczba(w[i_energia]) is not None]
    if len(wszystkie_energia) > 1 and wszystkie_zewn:
        razem = max(wszystkie_energia) - min(wszystkie_energia)
        srednia = sum(wszystkie_zewn) / len(wszystkie_zewn)
        # stopniodni: ile stopni brakowało do 20 °C, zsumowane po dniach —
        # dzieli zużycie przez surowość pogody, więc dni da się porównywać
        stopniodni = 0.0
        for dzien, grupa in dni.items():
            temperatury = [liczba(w[i_zewn]) for w in grupa
                           if i_zewn < len(w) and liczba(w[i_zewn]) is not None]
            if temperatury:
                stopniodni += max(0.0, 20 - sum(temperatury) / len(temperatury))
        print(f'\nRazem: {razem:.0f} kWh przy średniej {srednia:.1f} °C na dworze.')
        if stopniodni > 0.5:
            print(f'Na stopniodzień: {razem / stopniodni:.1f} kWh — tej liczby pilnuj '
                  f'przy zmianie nastaw, bo nie zależy od pogody.')
        else:
            print('Za ciepło na liczenie zużycia na stopniodzień — wróć do tego w sezonie.')


def yaml_strony(argumenty):
    plik_opisow = argumenty.opisy or os.path.join(KATALOG, 'opisy-panelu.json')
    if not os.path.exists(plik_opisow):
        raise SystemExit(f'Brak {plik_opisow} — uruchom najpierw „dopasuj".')
    with open(plik_opisow, encoding='utf-8') as f:
        zmienne = json.load(f).get('zmienne', {})
    if not zmienne:
        raise SystemExit(f'{plik_opisow} nie zawiera żadnych zmiennych.')

    linie = [
        '# Pompa ciepła ACOND — odczyty ze strony sterownika. Do configuration.yaml.',
        '# Home Assistant pobiera stronę tak samo jak przeglądarka i wyciąga z niej',
        '# wartości. Niczego w pompie nie zmienia — to wyłącznie odczyt.',
        '',
        'rest:',
        f'  - resource: {argumenty.host}',
        '    scan_interval: 60',
        '    timeout: 15',
    ]
    if argumenty.uzytkownik:
        linie += [f'    username: {argumenty.uzytkownik}',
                  '    password: !secret acond_haslo',
                  '    authentication: basic']
    linie.append('    sensor:')

    for zmienna, opis in sorted(zmienne.items(), key=lambda x: x[1][0]):
        nazwa, jednostka = (opis + [''])[:2]
        wzorzec = re.escape(zmienna) + '" VALUE="([^"]*)"'
        linie += [
            f'      - name: "Pompa {nazwa}"',
            f'        unique_id: acond_{identyfikator_ha(nazwa)}',
            '        value_template: >-',
            f"          {{{{ value | regex_findall_index('{wzorzec}') | float }}}}",
        ]
        if jednostka:
            linie.append(f'        unit_of_measurement: "{jednostka}"')
        klasa = {'°C': 'temperature', 'kW': 'power', 'kWh': 'energy', 'bar': 'pressure'}.get(jednostka)
        if klasa:
            linie.append(f'        device_class: {klasa}')
            linie.append('        state_class: ' +
                         ('total_increasing' if jednostka == 'kWh' else 'measurement'))
        linie.append('')

    plik = os.path.join(KATALOG, 'wyniki', 'pompa-acond-strona.yaml')
    os.makedirs(os.path.dirname(plik), exist_ok=True)
    with open(plik, 'w', encoding='utf-8') as f:
        f.write('\n'.join(linie))
    print(f'Zapisano {plik}  (czujników: {len(zmienne)})')
    print('Wklej do configuration.yaml, sprawdź konfigurację i przeładuj Home Assistanta.')


def identyfikator_ha(nazwa):
    return re.sub(r'_+', '_', re.sub(r'[^a-z0-9]+', '_', bez_ogonkow(nazwa).replace('ł', 'l'))).strip('_')


# ─────────────────────────────── polecenia ───────────────────────────────

def sprawdz(argumenty):
    """Sprawdza, co pompa w ogóle wystawia — zanim zacznie się szukać rejestrów."""
    print(f'Sprawdzam {argumenty.host}\n')
    porty = [(argumenty.port, 'Modbus TCP'), (80, 'panel WWW'), (443, 'panel WWW po HTTPS'),
             (502, 'Modbus TCP (domyślny)')]
    otwarte = {}
    for port, opis in dict.fromkeys(porty):
        if port in otwarte:
            continue
        gniazdo = socket.socket()
        gniazdo.settimeout(3)
        wynik = gniazdo.connect_ex((argumenty.host, port))
        gniazdo.close()
        otwarte[port] = wynik == 0
        stan = 'otwarty' if wynik == 0 else ('odrzucony' if wynik in (111,) else 'brak odpowiedzi')
        print(f'   port {port:<5} {opis:<26} {stan}')

    print()
    modbus = otwarte.get(argumenty.port) or otwarte.get(502)
    if not modbus:
        print('Modbus nie odpowiada. Najczęstsze powody:')
        print('  • komunikacja Modbus nie jest jeszcze odblokowana w pompie — włącza ją serwis ACOND-a,')
        print('  • to adres z sieci serwisowej (ETH1), a nie domowej (ETH2),')
        print('  • pompa dostała z DHCP inny adres — sprawdź na ekranie sterownika.')
        if any(otwarte.get(p) for p in (80, 443)):
            print('\nPanel WWW odpowiada, więc adres i sieć są dobre — brakuje samego Modbusa.')
        return

    print('Port Modbusa otwarty — sprawdzam, czy naprawdę mówi Modbusem…')
    for jednostka in (argumenty.jednostka, 1, 0, 2, 3):
        try:
            with Modbus(argumenty.host, argumenty.port, jednostka, limit=3) as m:
                slowa = m.czytaj(0, 4)
            print(f'   odpowiada jako jednostka {jednostka}: {slowa}')
            print(f'\nJest kontakt. Następny krok:')
            print(f'   python3 pompa-acond.py skanuj {argumenty.host}' +
                  (f' --jednostka {jednostka}' if jednostka != 1 else ''))
            return
        except OSError as powod:
            print(f'   jednostka {jednostka}: {powod}')
    print('\nPort jest otwarty, ale nic sensownego nie odpowiada. Spytaj serwisu ACOND-a,')
    print('czy Modbus jest odblokowany i pod jakim adresem jednostki (slave id) nasłuchuje.')


def jednostka_z_nazwy(nazwa):
    """Zgaduje jednostkę po nazwie z panelu — poprawisz ręcznie, jeśli spudłuje."""
    male = nazwa.lower()
    if any(s in male for s in ('wydajn', 'moc', 'kw')):
        return 'kW'
    if any(s in male for s in ('zuzycie', 'energia', 'kwh', 'licznik')):
        return 'kWh'
    if any(s in male for s in ('cisnien', 'bar')):
        return 'bar'
    if any(s in male for s in ('wilgot', 'procent', 'obcia')):
        return '%'
    if any(s in male for s in ('godzin', 'czas', 'motohodz')):
        return 'h'
    return '°C'


def wczytaj_panel(argumenty):
    sciezka = argumenty.panel or os.path.join(KATALOG, 'panel-acond.json')
    if not os.path.exists(sciezka):
        wzor = 'panel-acond.przyklad.json'
        raise SystemExit(f'Brak {sciezka}. Skopiuj wzór i wpisz swoje odczyty:\n'
                         f'   cp {wzor} {os.path.basename(sciezka)}')
    with open(sciezka, encoding='utf-8') as f:
        panel = {k: w for k, w in json.load(f).items() if not k.startswith('_')}
    if not panel:
        raise SystemExit(f'{sciezka} nie zawiera żadnych odczytów.')
    return panel


def dopasuj(argumenty):
    """Szuka rejestrów o wartościach odczytanych z panelu WWW pompy.

    Panel pokazuje „CWU 43,5 °C" — w rejestrze siedzi wtedy zwykle 435. Mając
    kilka takich par, tablicę rejestrów można złożyć bez dokumentacji."""
    panel = wczytaj_panel(argumenty)
    print(f'Czytam rejestry {argumenty.od}–{argumenty.od + argumenty.ile - 1} z {argumenty.host} …')
    surowe = {}
    for poczatek in range(argumenty.od, argumenty.od + argumenty.ile, 100):
        ile = min(100, argumenty.od + argumenty.ile - poczatek)
        try:
            with Modbus(argumenty.host, argumenty.port, argumenty.jednostka) as m:
                for i, slowo in enumerate(m.czytaj(poczatek, ile)):
                    surowe[poczatek + i] = slowo
        except OSError as powod:
            print(f'   {poczatek}–{poczatek + ile - 1}: {powod}')
    if not surowe:
        raise SystemExit('Nie udało się odczytać żadnego rejestru.')
    print(f'   odczytano {len(surowe)} rejestrów\n')

    rozpoznane, niepewne, przepadle = {}, [], []
    for nazwa, wartosc in panel.items():
        kandydaci = []
        for dzielnik in (10, 1, 100):
            szukane = round(float(wartosc) * dzielnik)
            for nr, slowo in surowe.items():
                if ze_znakiem(slowo) == szukane:
                    kandydaci.append((nr, dzielnik))
            if kandydaci:
                break                       # dziesiąte części to najczęstszy zapis
        if not kandydaci:
            przepadle.append((nazwa, wartosc))
        elif len(kandydaci) == 1:
            nr, dzielnik = kandydaci[0]
            rozpoznane[nr] = (nazwa, dzielnik)
            print(f'   {nazwa:<32} → rejestr {nr:<5} (÷{dzielnik})')
        else:
            niepewne.append((nazwa, wartosc, kandydaci))

    for nazwa, wartosc, kandydaci in niepewne:
        lista = ', '.join(f'{nr} (÷{d})' for nr, d in kandydaci[:8])
        print(f'   {nazwa:<32} → kilka pasujących: {lista}')
    for nazwa, wartosc in przepadle:
        print(f'   {nazwa:<32} → nie znalazłem wartości {wartosc}')

    if niepewne:
        print('\nKilka rejestrów ma tę samą wartość — to normalne. Rozstrzygnij je')
        print('poleceniem „obserwuj": zmień tę nastawę na panelu i zobacz, który drgnie.')
    if przepadle:
        print('\nCzego nie znalazłem, tego szukaj w innym zakresie (--od / --ile)')
        print('albo sprawdź, czy odczyt z panelu nie zdążył się zmienić.')

    if rozpoznane:
        plik = os.path.join(KATALOG, 'opisy-pompy.json')
        istniejace = {}
        if os.path.exists(plik):
            with open(plik, encoding='utf-8') as f:
                istniejace = json.load(f).get('sensory', {})
        for nr, (nazwa, dzielnik) in sorted(rozpoznane.items()):
            male = nazwa.lower()
            zapisywalny = any(s in male for s in ('wymagana', 'nastawa', 'zadanie', 'koniec sezonu'))
            istniejace[str(nr)] = [nazwa, jednostka_z_nazwy(nazwa), dzielnik, zapisywalny]
        with open(plik, 'w', encoding='utf-8') as f:
            json.dump({'_jak_uzywac': WZOR_OPISOW['_jak_uzywac'], 'sensory': istniejace},
                      f, ensure_ascii=False, indent=2)
        print(f'\nZapisałem {plik} — {len(rozpoznane)} rejestrów.')
        print('Sprawdź jednostki i to, które są nastawami, potem:')
        print(f'   python3 pompa-acond.py yaml {argumenty.host}')


def skanuj(argumenty):
    """Przechodzi rejestry blokami i pokazuje, gdzie pompa w ogóle odpowiada."""
    print(f'Pompa {argumenty.host}:{argumenty.port}, jednostka {argumenty.jednostka}\n')
    for funkcja, opis in ((CZYTAJ_HOLDING, 'holding (3)'), (CZYTAJ_INPUT, 'input (4)')):
        print(f'── rejestry {opis} ' + '─' * 40)
        znalezione = 0
        for poczatek in range(argumenty.od, argumenty.od + argumenty.ile, 16):
            try:
                with Modbus(argumenty.host, argumenty.port, argumenty.jednostka) as m:
                    slowa = m.czytaj(poczatek, min(16, argumenty.od + argumenty.ile - poczatek), funkcja)
            except OSError as powod:
                if znalezione == 0 and poczatek == argumenty.od:
                    print(f'   {poczatek:>5}: {powod}')
                continue
            for i, slowo in enumerate(slowa):
                if slowo == 0 and not argumenty.pokaz_zera:
                    continue
                znalezione += 1
                print(f'   {poczatek + i:>5}  {slowo:>6}  {podpowiedz(slowo)}')
        if not znalezione:
            print('   (nic albo same zera — spróbuj innego zakresu: --od / --ile)')
        print()
    print('Rejestry z sensownymi wartościami wypisz i porównaj z tym, co pokazuje')
    print('sterownik na ekranie — tak najszybciej rozpoznasz, co jest czym.')


def czytaj(argumenty):
    with Modbus(argumenty.host, argumenty.port, argumenty.jednostka) as m:
        slowa = m.czytaj(argumenty.od, argumenty.ile,
                         CZYTAJ_INPUT if argumenty.input else CZYTAJ_HOLDING)
    for i, slowo in enumerate(slowa):
        print(f'{argumenty.od + i:>5}  {slowo:>6}  {ze_znakiem(slowo):>7}  {podpowiedz(slowo)}')


def obserwuj(argumenty):
    """Pokazuje, które rejestry się zmieniają — najlepszy sposób na rozpoznanie
    nastawy: pokręć pokrętłem na sterowniku i patrz, co drgnie."""
    print(f'Obserwuję rejestry {argumenty.od}–{argumenty.od + argumenty.ile - 1}. '
          f'Zmieniaj nastawy na sterowniku. Ctrl+C kończy.\n')
    poprzednie = None
    funkcja = CZYTAJ_INPUT if argumenty.input else CZYTAJ_HOLDING
    try:
        while True:
            with Modbus(argumenty.host, argumenty.port, argumenty.jednostka) as m:
                slowa = m.czytaj(argumenty.od, argumenty.ile, funkcja)
            if poprzednie is None:
                print(f'{time.strftime("%H:%M:%S")}  pierwszy odczyt: '
                      f'{sum(1 for s in slowa if s)} rejestrów niezerowych')
            else:
                for i, (stare, nowe) in enumerate(zip(poprzednie, slowa)):
                    if stare != nowe:
                        print(f'{time.strftime("%H:%M:%S")}  rejestr {argumenty.od + i:>5}  '
                              f'{stare} → {nowe}   {podpowiedz(nowe)}')
            poprzednie = slowa
            time.sleep(argumenty.co)
    except KeyboardInterrupt:
        print('\nKoniec.')


# Wzór opisów: uzupełniasz nazwami rejestrów rozpoznanymi wyżej.
WZOR_OPISOW = {
    "_jak_uzywac": "rejestr: [nazwa, jednostka, dzielnik, zapisywalny]. "
                   "Jednostki: °C, %, W, kWh, '' dla stanu. Dzielnik 10 = wartość/10.",
    "sensory": {
        "10": ["Temperatura zewnętrzna", "°C", 10, False],
        "11": ["Temperatura wody w zbiorniku", "°C", 10, False],
        "12": ["Temperatura zadana", "°C", 10, True]
    }
}


def yaml_ha(argumenty):
    sciezka = argumenty.opisy or os.path.join(KATALOG, 'opisy-pompy.json')
    if not os.path.exists(sciezka):
        with open(sciezka, 'w', encoding='utf-8') as f:
            json.dump(WZOR_OPISOW, f, ensure_ascii=False, indent=2)
        print(f'Nie było pliku z opisami — założyłem wzór: {sciezka}')
        print('Uzupełnij go rejestrami rozpoznanymi przez „skanuj" i „obserwuj",\n'
              'potem uruchom to polecenie jeszcze raz.')
        return

    with open(sciezka, encoding='utf-8') as f:
        opisy = json.load(f)
    rejestry = [(int(nr), *dane) for nr, dane in opisy.get('sensory', {}).items()]
    rejestry.sort()
    if not rejestry:
        return print(f'W {sciezka} nie ma ani jednego rejestru.')

    linie = [
        '# Pompa ciepła ACOND przez Modbus TCP — do configuration.yaml',
        f'# Wygenerowane z {os.path.basename(sciezka)}. Same odczyty: nic nie ustawia w pompie.',
        '',
        'modbus:',
        '  - name: acond',
        '    type: tcp',
        f'    host: {argumenty.host}',
        f'    port: {argumenty.port}',
        '    delay: 5',
        '    timeout: 5',
        '    sensors:',
    ]
    for nr, nazwa, jednostka, dzielnik, _ in rejestry:
        linie += [
            f'      - name: "{nazwa}"',
            f'        address: {nr}',
            f'        slave: {argumenty.jednostka}',
            '        input_type: holding',
            '        data_type: int16',
            '        scan_interval: 30',
        ]
        if dzielnik and dzielnik != 1:
            linie += [f'        scale: {round(1 / dzielnik, 6)}', '        precision: 1']
        if jednostka:
            linie.append(f'        unit_of_measurement: "{jednostka}"')
        if jednostka == '°C':
            linie += ['        device_class: temperature', '        state_class: measurement']
        elif jednostka == 'W':
            linie += ['        device_class: power', '        state_class: measurement']
        elif jednostka == 'kWh':
            linie += ['        device_class: energy', '        state_class: total_increasing']
        linie.append('')

    # Sterowanie nastawą — świadomie zakomentowane. Zapis przez Modbus przełącza
    # pompę w tryb sterowania z zewnątrz; szczegóły w README.
    nastawa = next((r for r in rejestry if r[4] and r[2] == '°C'), None)
    # do nastawy dobieramy tę temperaturę mierzoną, która leży najbliżej niej
    # w numeracji — zwykle to ta sama sekcja rejestrów. Sprawdź to i popraw.
    mierzone = [r for r in rejestry if not r[4] and r[2] == '°C']
    biezaca = min(mierzone, key=lambda r: abs(r[0] - nastawa[0])) if (nastawa and mierzone) else None
    if nastawa and biezaca:
        linie += [
            '# ─────────────────────────────────────────────────────────────────',
            '# STEROWANIE — odkomentuj dopiero po przeczytaniu README (rozdział',
            '# „Pompa ciepła ACOND"). Zapis do rejestru przełącza pompę w tryb',
            '# sterowania z zewnątrz: jej własna regulacja zostaje wyłączona,',
            '# a gdy Home Assistant zamilknie, pompa wraca do trybu auto.',
            '#',
            '#    Sprawdź, czy „address" to na pewno ta temperatura, którą pompa ma',
            '#    doprowadzić do nastawy — dobrałem najbliższą w numeracji rejestrów.',
            '#',
            '#    climates:',
            f'#      - name: "Pompa ciepła"',
            f'#        address: {biezaca[0]}                  # {biezaca[1]}',
            f'#        target_temp_register: {nastawa[0]}     # {nastawa[1]}',
            f'#        slave: {argumenty.jednostka}',
            '#        input_type: holding',
            '#        data_type: int16',
            f'#        scale: {round(1 / (nastawa[3] or 1), 6)}',
            '#        precision: 1',
            '#        temperature_unit: C',
            '#        min_temp: 20',
            '#        max_temp: 60',
            '#        temp_step: 0.5',
            '',
        ]

    plik = os.path.join(KATALOG, 'wyniki', 'pompa-acond-modbus.yaml')
    os.makedirs(os.path.dirname(plik), exist_ok=True)
    with open(plik, 'w', encoding='utf-8') as f:
        f.write('\n'.join(linie))
    print(f'Zapisano {plik}')
    print(f'  odczytów: {len(rejestry)}' +
          ('  + zakomentowane sterowanie nastawą' if nastawa and biezaca else ''))


def main():
    parser = argparse.ArgumentParser(description='Pompa ciepła ACOND przez Modbus TCP.')
    parser.add_argument('polecenie',
                        choices=['sprawdz', 'strona', 'skanuj', 'dopasuj', 'czytaj',
                                 'obserwuj', 'zapisuj', 'podsumuj', 'yaml'])
    parser.add_argument('host', nargs='?', help='adres pompy (192.168.88.9) albo adres strony '
                                               'sterownika (http://192.168.88.9/PAGE115.XML); '
                                               'polecenie „podsumuj" go nie potrzebuje')
    parser.add_argument('--port', type=int, default=502)
    parser.add_argument('--jednostka', type=int, default=1, help='adres Modbus (slave id)')
    parser.add_argument('--od', type=int, default=0, help='pierwszy rejestr')
    parser.add_argument('--ile', type=int, default=100, help='ile rejestrów')
    parser.add_argument('--co', type=float, default=2.0, help='co ile sekund odczyt przy obserwacji')
    parser.add_argument('--input', action='store_true', help='rejestry input zamiast holding')
    parser.add_argument('--pokaz-zera', action='store_true')
    parser.add_argument('--opisy', help='plik z opisami rejestrów (do polecenia yaml)')
    parser.add_argument('--panel', help='plik z odczytami z panelu WWW (do polecenia dopasuj)')
    parser.add_argument('--plik', help='plik CSV z zapisem (do poleceń zapisuj i podsumuj)')
    parser.add_argument('--uzytkownik', help='login do panelu sterownika, jeśli wymaga')
    parser.add_argument('--haslo', help='hasło do panelu sterownika')
    argumenty = parser.parse_args()

    # Adres z „http" znaczy: czytamy stronę sterownika, a nie rejestry Modbusa.
    przez_strone = str(argumenty.host).lower().startswith('http')
    if argumenty.polecenie == 'podsumuj':
        return podsumuj(argumenty)
    if not argumenty.host:
        raise SystemExit(f'Polecenie „{argumenty.polecenie}" potrzebuje adresu, np.\n'
                         '   python3 pompa-acond.py strona http://192.168.88.9/PAGE115.XML')
    if argumenty.polecenie == 'strona' and not przez_strone:
        raise SystemExit('Polecenie „strona" potrzebuje adresu strony, np.\n'
                         '   python3 pompa-acond.py strona http://192.168.88.9/PAGE115.XML')

    przez_www = {'strona': strona, 'dopasuj': lambda a: dopasuj_strone(a, wczytaj_panel(a)),
                 'obserwuj': obserwuj_strone, 'zapisuj': zapisuj, 'yaml': yaml_strony}
    przez_modbus = {'sprawdz': sprawdz, 'skanuj': skanuj, 'dopasuj': dopasuj, 'czytaj': czytaj,
                    'obserwuj': obserwuj, 'yaml': yaml_ha}

    try:
        wykonanie = (przez_www if przez_strone else przez_modbus).get(argumenty.polecenie)
        if wykonanie is None:
            raise SystemExit(f'Polecenie „{argumenty.polecenie}" nie działa z tym rodzajem adresu.')
        wykonanie(argumenty)
    except OSError as powod:
        print(f'\nNie udało się: {powod}')
        print('\nCo sprawdzić:')
        print('  • czy Modbus jest odblokowany w pompie — robi to serwis ACOND-a,')
        print('  • czy to właściwy adres (ten z sieci domowej, nie serwisowej),')
        print('  • czy komputer jest w tej samej sieci co pompa.')
        sys.exit(1)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
    except BrokenPipeError:                 # np. „| head"
        os._exit(0)
