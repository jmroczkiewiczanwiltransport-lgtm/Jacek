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
import struct
import sys
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET

KATALOG = os.path.dirname(os.path.abspath(__file__))

# Kody funkcji Modbus
CZYTAJ_HOLDING = 3
CZYTAJ_INPUT = 4
ZAPISZ_JEDEN = 6

BLEDY = {
    1: 'nieobsługiwana funkcja',
    2: 'nie ma takiego rejestru',
    3: 'zła wartość albo za duży zakres',
    4: 'awaria urządzenia',
    6: 'urządzenie zajęte',
}


class Modbus:
    """Klient Modbus TCP — tyle, ile potrzeba do odczytu i zapisu rejestrów."""

    def __init__(self, host, port=502, jednostka=1, limit=5.0):
        self.host, self.port, self.jednostka, self.limit = host, port, jednostka, limit
        self.gniazdo = None
        self.transakcja = 0

    def __enter__(self):
        self.gniazdo = socket.create_connection((self.host, self.port), timeout=self.limit)
        self.gniazdo.settimeout(self.limit)
        return self

    def __exit__(self, *_):
        if self.gniazdo:
            self.gniazdo.close()

    def _rozmowa(self, pdu):
        self.transakcja = (self.transakcja + 1) % 0x10000
        naglowek = struct.pack('>HHHB', self.transakcja, 0, len(pdu) + 1, self.jednostka)
        self.gniazdo.sendall(naglowek + pdu)

        odpowiedz = self._odbierz(8)
        transakcja, protokol, dlugosc, jednostka, funkcja = struct.unpack('>HHHBB', odpowiedz)
        if protokol != 0:
            raise OSError('to nie jest Modbus TCP — inny protokół w odpowiedzi')
        reszta = self._odbierz(dlugosc - 2)
        if funkcja & 0x80:
            kod = reszta[0]
            raise OSError(f'urządzenie odmówiło: {BLEDY.get(kod, f"kod {kod}")}')
        return reszta

    def _odbierz(self, ile):
        bufor = b''
        while len(bufor) < ile:
            kawalek = self.gniazdo.recv(ile - len(bufor))
            if not kawalek:
                raise OSError('urządzenie zerwało połączenie')
            bufor += kawalek
        return bufor

    def czytaj(self, od, ile, funkcja=CZYTAJ_HOLDING):
        """Zwraca listę słów 16-bitowych. Modbus pozwala na 125 naraz."""
        wynik = []
        while ile > 0:
            porcja = min(ile, 125)
            odpowiedz = self._rozmowa(struct.pack('>BHH', funkcja, od + len(wynik), porcja))
            bajtow = odpowiedz[0]
            wynik += list(struct.unpack(f'>{bajtow // 2}H', odpowiedz[1:1 + bajtow]))
            ile -= porcja
        return wynik

    def zapisz(self, rejestr, wartosc):
        self._rozmowa(struct.pack('>BHH', ZAPISZ_JEDEN, rejestr, wartosc & 0xFFFF))


def ze_znakiem(slowo):
    return slowo - 0x10000 if slowo > 0x7FFF else slowo


def podpowiedz(slowo):
    """Zgaduje, czym może być wartość — po to, żeby dało się rozpoznać rejestry."""
    z = ze_znakiem(slowo)
    tropy = []
    if slowo in (0, 1):
        tropy.append('wyłącz./włącz.?')
    if -400 <= z <= 1500:
        tropy.append(f'{z / 10:.1f} °C?')
    if 0 < slowo <= 100:
        tropy.append(f'{slowo} %?')
    if 1000 <= slowo <= 30000:
        tropy.append(f'{slowo} W?')
    return '  '.join(tropy)


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
    czysta = ''.join(z for z in __import__('unicodedata').normalize('NFD', nazwa.lower())
                     if __import__('unicodedata').category(z) != 'Mn').replace('ł', 'l')
    return re.sub(r'_+', '_', re.sub(r'[^a-z0-9]+', '_', czysta)).strip('_')


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
                        choices=['sprawdz', 'strona', 'skanuj', 'dopasuj', 'czytaj', 'obserwuj', 'yaml'])
    parser.add_argument('host', help='adres pompy (192.168.88.9) albo adres strony sterownika '
                                     '(http://192.168.88.9/PAGE115.XML)')
    parser.add_argument('--port', type=int, default=502)
    parser.add_argument('--jednostka', type=int, default=1, help='adres Modbus (slave id)')
    parser.add_argument('--od', type=int, default=0, help='pierwszy rejestr')
    parser.add_argument('--ile', type=int, default=100, help='ile rejestrów')
    parser.add_argument('--co', type=float, default=2.0, help='co ile sekund odczyt przy obserwacji')
    parser.add_argument('--input', action='store_true', help='rejestry input zamiast holding')
    parser.add_argument('--pokaz-zera', action='store_true')
    parser.add_argument('--opisy', help='plik z opisami rejestrów (do polecenia yaml)')
    parser.add_argument('--panel', help='plik z odczytami z panelu WWW (do polecenia dopasuj)')
    parser.add_argument('--uzytkownik', help='login do panelu sterownika, jeśli wymaga')
    parser.add_argument('--haslo', help='hasło do panelu sterownika')
    argumenty = parser.parse_args()

    # Adres z „http" znaczy: czytamy stronę sterownika, a nie rejestry Modbusa.
    przez_strone = str(argumenty.host).lower().startswith('http')
    if argumenty.polecenie == 'strona' and not przez_strone:
        raise SystemExit('Polecenie „strona" potrzebuje adresu strony, np.\n'
                         '   python3 pompa-acond.py strona http://192.168.88.9/PAGE115.XML')

    przez_www = {'strona': strona, 'dopasuj': lambda a: dopasuj_strone(a, wczytaj_panel(a)),
                 'obserwuj': obserwuj_strone, 'yaml': yaml_strony}
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
