#!/usr/bin/env python3
"""Sterowanie urządzeniami Tuya / SmartLife (MiBoxer i podobne).

Domyślnie po sieci lokalnej — komputer rozmawia ze sterownikami wprost, bez chmury.
Gdy urządzenie nie odpowiada w sieci, polecenie idzie przez chmurę Tuya (o ile jest
skonfigurowana). Warstwę protokołu obsługuje biblioteka tinytuya.

    python3 tuya.py pomoc
"""

import json
import math
import os
import random
import re
import socket
import sys
import threading
import time
import unicodedata
from datetime import datetime, timedelta
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

KATALOG = os.path.dirname(os.path.abspath(__file__))
PLIK_URZADZEN = os.environ.get('TUYA_URZADZENIA', os.path.join(KATALOG, 'urzadzenia.json'))
PLIK_AUTOMATYKI = os.path.join(KATALOG, 'automatyka.json')
PLIK_PRZYKLADOWEJ_AUTOMATYKI = os.path.join(KATALOG, 'automatyka.przyklad.json')

try:
    import tinytuya
except ImportError:                                             # pragma: no cover
    tinytuya = None


def wymagaj_tinytuya():
    if tinytuya is None:
        raise SystemExit('Brakuje biblioteki tinytuya. Zainstaluj: pip3 install tinytuya')


# ─────────────────────────── profile urządzeń ───────────────────────────
# Tuya numeruje funkcje („DP"). Sterowniki światła używają dwóch układów
# numeracji zależnie od wieku firmware'u; przełączniki mają własny.

PROFILE = {
    'swiatlo-cct': {
        'dp': {'wlacznik': 20, 'tryb': 21, 'jasnosc': 22, 'barwa': 23},
        'kody': {'wlacznik': 'switch_led', 'tryb': 'work_mode',
                 'jasnosc': 'bright_value_v2', 'barwa': 'temp_value_v2'},
        'zakres': {'jasnosc': [10, 1000], 'barwa': [0, 1000]},
    },
    'swiatlo-cct-stare': {
        'dp': {'wlacznik': 1, 'tryb': 2, 'jasnosc': 3, 'barwa': 4},
        'kody': {'wlacznik': 'switch_led', 'tryb': 'work_mode',
                 'jasnosc': 'bright_value', 'barwa': 'temp_value'},
        'zakres': {'jasnosc': [25, 255], 'barwa': [0, 255]},
    },
    'swiatlo': {
        'dp': {'wlacznik': 20, 'jasnosc': 22},
        'kody': {'wlacznik': 'switch_led', 'jasnosc': 'bright_value_v2'},
        'zakres': {'jasnosc': [10, 1000]},
    },
    'przelacznik': {
        'dp': {'wlacznik': 1},
        'kody': {'wlacznik': 'switch_1'},
        'zakres': {},
    },
}

# kategorie z chmury Tuya → nasz profil
KATEGORIE = {'dj': 'swiatlo-cct', 'dd': 'swiatlo', 'dc': 'swiatlo', 'xdd': 'swiatlo-cct',
             'kg': 'przelacznik', 'cz': 'przelacznik', 'pc': 'przelacznik', 'tdq': 'przelacznik'}


def bez_ogonkow(tekst):
    rozlozone = unicodedata.normalize('NFD', str(tekst or ''))
    return ''.join(z for z in rozlozone if unicodedata.category(z) != 'Mn').lower().strip()


def pasuje(a, b):
    return bez_ogonkow(a) == bez_ogonkow(b)


# ─────────────────────────────── urządzenie ───────────────────────────────

class Urzadzenie:
    """Jedno urządzenie: sterowanie lokalne, a gdy zawiedzie — przez chmurę."""

    def __init__(self, opis, chmura=None):
        self.nazwa = opis['nazwa']
        self.id = opis['id']
        self.klucz = opis.get('klucz', '')
        self.ip = opis.get('ip')
        self.wersja = float(opis.get('wersja', 3.3))
        self.rodzaj = opis.get('rodzaj', 'swiatlo-cct')
        profil = PROFILE.get(self.rodzaj, PROFILE['swiatlo-cct'])
        self.dp = {**profil['dp'], **opis.get('dp', {})}
        self.kody = {**profil['kody'], **opis.get('kody', {})}
        self.zakres = {**profil['zakres'], **opis.get('zakres', {})}
        self.grupy = opis.get('grupy', [])
        self.chmura = chmura
        self.blokada = threading.RLock()
        self.stan = {}                  # ostatnio odczytane DP
        self.blad = None
        self.zrodlo = None              # 'lokalnie' albo 'chmura'
        self.sprawdzone = 0
        self._polaczenie = None

    # ── warstwa transportu ──

    def _lokalne(self):
        if self._polaczenie is None:
            wymagaj_tinytuya()
            urzadzenie = tinytuya.Device(dev_id=self.id, address=self.ip,
                                         local_key=self.klucz, version=self.wersja)
            urzadzenie.set_socketTimeout(3)
            urzadzenie.set_socketRetryLimit(1)
            self._polaczenie = urzadzenie
        return self._polaczenie

    def _odpowiedz_lokalna(self, odpowiedz):
        if isinstance(odpowiedz, dict) and 'Error' in odpowiedz:
            raise OSError(f"{odpowiedz.get('Error')} ({odpowiedz.get('Err')})")
        return odpowiedz

    def odczytaj(self):
        """Pobiera stan; najpierw lokalnie, w razie czego z chmury."""
        with self.blokada:
            if self.ip:
                try:
                    odpowiedz = self._odpowiedz_lokalna(self._lokalne().status())
                    self.stan = odpowiedz.get('dps', {}) or {}
                    self.zrodlo, self.blad, self.sprawdzone = 'lokalnie', None, time.time()
                    return self.stan
                except Exception as powod:                       # noqa: BLE001
                    self.blad = str(powod)
                    self._polaczenie = None
            if self.chmura:
                try:
                    self.stan = self._z_chmury(self.chmura.stan(self.id))
                    self.zrodlo, self.blad, self.sprawdzone = 'chmura', None, time.time()
                    return self.stan
                except Exception as powod:                       # noqa: BLE001
                    self.blad = str(powod)
            self.zrodlo = None
            self.sprawdzone = time.time()
            return self.stan

    def wyslij(self, wartosci):
        """wartosci: {'wlacznik': True, 'jasnosc': 640} — klucze funkcji, nie numery DP."""
        if not wartosci:
            return
        with self.blokada:
            if self.ip:
                try:
                    dps = {self.dp[k]: w for k, w in wartosci.items() if k in self.dp}
                    self._odpowiedz_lokalna(self._lokalne().set_multiple_values(dps))
                    self.stan.update({str(dp): w for dp, w in dps.items()})
                    self.zrodlo, self.blad = 'lokalnie', None
                    return
                except Exception as powod:                       # noqa: BLE001
                    self.blad = str(powod)
                    self._polaczenie = None
            if self.chmura:
                polecenia = [{'code': self.kody[k], 'value': w}
                             for k, w in wartosci.items() if k in self.kody]
                self.chmura.polecenie(self.id, polecenia)
                self.stan.update({str(self.dp[k]): w for k, w in wartosci.items() if k in self.dp})
                self.zrodlo, self.blad = 'chmura', None
                return
            raise OSError(f'brak łączności ({self.blad or "nie znam adresu IP"})')

    def _z_chmury(self, wg_kodow):
        """Chmura mówi kodami ('switch_led'), lokalnie chodzą numery DP ('20')."""
        kod_na_funkcje = {kod: funkcja for funkcja, kod in self.kody.items()}
        stan = {}
        for kod, wartosc in wg_kodow.items():
            funkcja = kod_na_funkcje.get(kod)
            stan[str(self.dp[funkcja]) if funkcja in self.dp else kod] = wartosc
        return stan

    # ── odczyt stanu w ludzkich jednostkach ──

    def wartosc(self, funkcja):
        return self.stan.get(str(self.dp.get(funkcja)))

    @property
    def wlaczone(self):
        return bool(self.wartosc('wlacznik'))

    def procent(self, funkcja):
        """Procent liczony tak samo jak w aplikacji SmartLife — wprost od maksimum,
        żeby liczby na ekranie telefonu i tutaj się zgadzały."""
        surowa = self.wartosc(funkcja)
        if surowa is None or funkcja not in self.zakres or not isinstance(surowa, (int, float)):
            return None
        najwiecej = self.zakres[funkcja][1]
        if not najwiecej:
            return None
        return max(0, min(100, round(surowa * 100 / najwiecej)))

    def surowa(self, funkcja, procent):
        najmniej, najwiecej = self.zakres.get(funkcja, [0, 100])
        procent = max(0, min(100, procent))
        wartosc = int(round(najwiecej * procent / 100))
        return max(najmniej, wartosc)

    def opis(self):
        return {
            'nazwa': self.nazwa, 'id': self.id, 'ip': self.ip, 'wersja': self.wersja,
            'rodzaj': self.rodzaj, 'grupy': self.grupy,
            'wlaczone': self.wlaczone, 'zrodlo': self.zrodlo, 'blad': self.blad,
            'jasnosc': self.procent('jasnosc'), 'barwa': self.procent('barwa'),
            'reguluje': [k for k in ('jasnosc', 'barwa') if k in self.dp and k in self.zakres],
            'dps': self.stan,
        }


class Chmura:
    """Zapas na wypadek, gdy urządzenia nie ma w sieci lokalnej."""

    def __init__(self, ustawienia):
        wymagaj_tinytuya()
        self.polaczenie = tinytuya.Cloud(
            apiRegion=ustawienia.get('region', 'eu'),
            apiKey=ustawienia['klucz_api'],
            apiSecret=ustawienia['sekret_api'],
            apiDeviceID=ustawienia.get('id_urzadzenia', ''))

    def stan(self, id_urzadzenia):
        odpowiedz = self.polaczenie.getstatus(id_urzadzenia)
        if not odpowiedz or not odpowiedz.get('success'):
            raise OSError((odpowiedz or {}).get('msg', 'chmura nie odpowiada'))
        return {pozycja['code']: pozycja['value'] for pozycja in odpowiedz.get('result', [])}

    def polecenie(self, id_urzadzenia, polecenia):
        odpowiedz = self.polaczenie.sendcommand(id_urzadzenia, {'commands': polecenia})
        if not odpowiedz or not odpowiedz.get('success'):
            raise OSError((odpowiedz or {}).get('msg', 'chmura odrzuciła polecenie'))


# ─────────────────────────────── magazyn ───────────────────────────────

class Dom:
    def __init__(self, plik=PLIK_URZADZEN):
        if not os.path.exists(plik):
            raise SystemExit(
                f'Brak pliku {plik}.\n'
                'Najpierw pobierz klucze urządzeń: python3 tuya.py klucze\n'
                '(instrukcja krok po kroku jest w README.md).')
        with open(plik, encoding='utf-8') as f:
            dane = json.load(f)
        self.plik = plik
        ustawienia_chmury = dane.get('chmura')
        self.chmura = None
        if ustawienia_chmury and ustawienia_chmury.get('klucz_api'):
            try:
                self.chmura = Chmura(ustawienia_chmury)
            except Exception as powod:                           # noqa: BLE001
                print(f'Chmura niedostępna ({powod}) — zostaje sterowanie lokalne.', file=sys.stderr)
        self.urzadzenia = [Urzadzenie(o, self.chmura) for o in dane['urzadzenia']]

    def znajdz(self, cel):
        """Cel: 'wszystko', 'grupa:elewacja' albo nazwa urządzenia."""
        tekst = str(cel or '').strip()
        if not tekst or pasuje(tekst, 'wszystko'):
            return list(self.urzadzenia)
        if ':' in tekst:
            przedrostek, nazwa = tekst.split(':', 1)
            if bez_ogonkow(przedrostek) in ('grupa', 'grupy'):
                trafione = [u for u in self.urzadzenia if any(pasuje(g, nazwa) for g in u.grupy)]
                if not trafione:
                    raise SystemExit(f'Nie ma grupy „{nazwa}". Zobacz: python3 tuya.py lista')
                return trafione
            tekst = nazwa
        trafione = [u for u in self.urzadzenia if pasuje(u.nazwa, tekst)]
        if trafione:
            return trafione
        czesciowe = [u for u in self.urzadzenia if bez_ogonkow(tekst) in bez_ogonkow(u.nazwa)]
        if czesciowe:
            return czesciowe
        grupa = [u for u in self.urzadzenia if any(pasuje(g, tekst) for g in u.grupy)]
        if grupa:
            return grupa
        raise SystemExit(f'Nie znam celu „{cel}". Zobacz: python3 tuya.py lista')

    def odswiez(self, rownolegle=True):
        if not rownolegle:
            for u in self.urzadzenia:
                u.odczytaj()
            return
        watki = [threading.Thread(target=u.odczytaj, daemon=True) for u in self.urzadzenia]
        for w in watki:
            w.start()
        for w in watki:
            w.join(timeout=12)

    @property
    def grupy(self):
        wynik = {}
        for u in self.urzadzenia:
            for g in u.grupy:
                wynik.setdefault(g, []).append(u)
        return wynik


# ──────────────────────────────── akcje ────────────────────────────────

def wartosci_akcji(urzadzenie, akcja):
    """Akcja opisana po polsku → wartości DP dla tego konkretnego urządzenia."""
    wartosci = {}
    if akcja.get('przelacz'):
        wartosci['wlacznik'] = not urzadzenie.wlaczone
    elif 'wlacz' in akcja:
        wartosci['wlacznik'] = bool(akcja['wlacz'])
    for funkcja in ('jasnosc', 'barwa'):
        if akcja.get(funkcja) is None:
            continue
        if funkcja not in urzadzenie.dp or funkcja not in urzadzenie.zakres:
            continue                                   # np. przełącznik garażu
        wartosci[funkcja] = urzadzenie.surowa(funkcja, float(akcja[funkcja]))
        if funkcja == 'jasnosc' and float(akcja[funkcja]) > 0:
            wartosci.setdefault('wlacznik', True)
    if akcja.get('jasnosc') == 0:
        wartosci['wlacznik'] = False
    return wartosci


def wykonaj(dom, cel, akcja, automatyka=None, log=print):
    """Wykonuje akcję na celu. Zwraca listę opisów tego, co się udało."""
    if akcja.get('scena'):
        return uruchom_scene(dom, akcja['scena'], automatyka, log)

    urzadzenia = dom.znajdz(cel)
    przejscie = float(akcja.get('przejscie') or 0)
    zrobione = []

    def dla(urzadzenie):
        try:
            if przejscie > 0 and akcja.get('jasnosc') is not None and 'jasnosc' in urzadzenie.dp:
                sciemniaj(urzadzenie, akcja, przejscie)
            else:
                urzadzenie.wyslij(wartosci_akcji(urzadzenie, akcja))
            zrobione.append(urzadzenie.nazwa)
        except Exception as powod:                               # noqa: BLE001
            log(f'  {urzadzenie.nazwa}: {powod}')

    watki = [threading.Thread(target=dla, args=(u,), daemon=True) for u in urzadzenia]
    for w in watki:
        w.start()
    for w in watki:
        w.join(timeout=przejscie + 20)
    return zrobione


def sciemniaj(urzadzenie, akcja, sekundy):
    """Płynna zmiana jasności — urządzenia Tuya nie mają tego same z siebie,
    więc rozkładamy ją na kroki po stronie komputera."""
    urzadzenie.odczytaj()
    od = urzadzenie.procent('jasnosc')
    do = float(akcja['jasnosc'])
    if od is None:
        od = 0 if not urzadzenie.wlaczone else do
    if not urzadzenie.wlaczone and do > 0:
        urzadzenie.wyslij({'wlacznik': True, 'jasnosc': urzadzenie.surowa('jasnosc', max(od, 1))})
    krokow = max(1, min(40, int(sekundy / 0.6)))
    for i in range(1, krokow + 1):
        wartosci = {'jasnosc': urzadzenie.surowa('jasnosc', od + (do - od) * i / krokow)}
        if i == krokow:
            pozostale = {k: w for k, w in wartosci_akcji(urzadzenie, akcja).items() if k != 'jasnosc'}
            wartosci.update(pozostale)
        urzadzenie.wyslij(wartosci)
        if i < krokow:
            time.sleep(sekundy / krokow)
    if do == 0:
        urzadzenie.wyslij({'wlacznik': False})


def uruchom_scene(dom, nazwa_sceny, automatyka, log=print):
    sceny = (automatyka or {}).get('sceny', {})
    klucz = next((k for k in sceny if pasuje(k, nazwa_sceny)), None)
    if klucz is None:
        raise SystemExit(f'Nie ma sceny „{nazwa_sceny}". Sceny są w {PLIK_AUTOMATYKI}.')
    zrobione = []
    for krok in sceny[klucz]:
        zrobione += wykonaj(dom, krok.get('cel', 'wszystko'), krok.get('akcja', {}), automatyka, log)
    return zrobione


# ──────────────────────── wschód i zachód słońca ────────────────────────

def pory_slonca(dzien, szerokosc, dlugosc):
    """Zwraca (wschód, zachód) jako datetime w czasie lokalnym; None przy dniu
    albo nocy polarnej. Dokładność ok. 2 minut."""
    poludnie = dzien.replace(hour=12, minute=0, second=0, microsecond=0)
    dzien_julianski = poludnie.timestamp() / 86400.0 + 2440587.5
    n = round(dzien_julianski - 2451545.0 + 0.0008)
    przyblizenie = n + 0.0009 - dlugosc / 360.0
    M = (357.5291 + 0.98560028 * przyblizenie) % 360
    C = (1.9148 * math.sin(math.radians(M)) + 0.02 * math.sin(math.radians(2 * M))
         + 0.0003 * math.sin(math.radians(3 * M)))
    lam = (M + C + 180 + 102.9372) % 360
    tranzyt = (2451545.0 + przyblizenie + 0.0053 * math.sin(math.radians(M))
               - 0.0069 * math.sin(math.radians(2 * lam)))
    sin_deklinacji = math.sin(math.radians(lam)) * math.sin(math.radians(23.4397))
    deklinacja = math.asin(sin_deklinacji)
    licznik = math.sin(math.radians(-0.833)) - math.sin(math.radians(szerokosc)) * sin_deklinacji
    mianownik = math.cos(math.radians(szerokosc)) * math.cos(deklinacja)
    cos_kata = licznik / mianownik
    if abs(cos_kata) > 1:
        return None, None
    kat = math.degrees(math.acos(cos_kata))
    na_date = lambda jd: datetime.fromtimestamp((jd - 2440587.5) * 86400.0)
    return na_date(tranzyt - kat / 360.0), na_date(tranzyt + kat / 360.0)


def pora_na_dzien(zapis, dzien, polozenie=None):
    """'06:30' | 'wschod' | 'zachod-00:30' | 'wschod+01:00' → datetime tego dnia."""
    tekst = bez_ogonkow(zapis)
    proste = re.fullmatch(r'(\d{1,2}):(\d{2})', tekst)
    if proste:
        return dzien.replace(hour=int(proste[1]), minute=int(proste[2]), second=0, microsecond=0)
    wzgledne = re.fullmatch(r'(wschod|zachod)\s*(?:([+-])\s*(\d{1,2}):(\d{2}))?', tekst)
    if not wzgledne:
        raise ValueError(f'Nie rozumiem godziny „{zapis}". Użyj 06:30, wschod, zachod-00:30.')
    if not polozenie:
        raise ValueError('Godziny względem słońca wymagają pola "polozenie" w pliku automatyki.')
    wschod, zachod = pory_slonca(dzien, polozenie['szerokosc'], polozenie['dlugosc'])
    baza = wschod if wzgledne[1] == 'wschod' else zachod
    if baza is None:
        return None
    if wzgledne[2]:
        minuty = int(wzgledne[3]) * 60 + int(wzgledne[4])
        baza += timedelta(minutes=minuty if wzgledne[2] == '+' else -minuty)
    return baza


DNI = {'nd': 6, 'pn': 0, 'wt': 1, 'sr': 2, 'cz': 3, 'pt': 4, 'sb': 5}


def dzisiaj_pasuje(dni, data):
    if not dni:
        return True
    return any(DNI.get(bez_ogonkow(d)) == data.weekday() for d in dni)


def w_przedziale(teraz, od, do):
    if not od or not do:
        return True
    minuty = teraz.hour * 60 + teraz.minute
    a = int(od.split(':')[0]) * 60 + int(od.split(':')[1])
    b = int(do.split(':')[0]) * 60 + int(do.split(':')[1])
    return a <= minuty < b if a <= b else (minuty >= a or minuty < b)


# ────────────────────────────── automatyka ──────────────────────────────

def wczytaj_automatyke(plik=None):
    sciezka = plik or (PLIK_AUTOMATYKI if os.path.exists(PLIK_AUTOMATYKI)
                       else PLIK_PRZYKLADOWEJ_AUTOMATYKI)
    if not os.path.exists(sciezka):
        return {}, sciezka
    with open(sciezka, encoding='utf-8') as f:
        return json.load(f), sciezka


def dziennik(*czesci):
    print(datetime.now().strftime('%H:%M:%S'), *czesci, flush=True)


def automat(dom, plik=None):
    cfg, sciezka = wczytaj_automatyke(plik)
    zmieniony = os.path.getmtime(sciezka)
    dziennik(f'Automatyka wystartowała ({os.path.basename(sciezka)}). '
             f'Reguł czasowych: {len(cfg.get("harmonogramy", []))}, '
             f'scen: {len(cfg.get("sceny", {}))}.')
    dom.odswiez()
    wykonane = set()
    nastepna_obecnosc = [0.0]

    def zrob(cel, akcja, powod):
        try:
            zrobione = wykonaj(dom, cel, akcja, cfg, dziennik)
            dziennik(f'{powod} → {", ".join(zrobione) if zrobione else "nic nie odpowiedziało"}')
        except Exception as powod_bledu:                         # noqa: BLE001
            dziennik(f'{powod} → błąd: {powod_bledu}')

    ostatnie_odswiezenie = [time.time()]
    while True:
        try:
            teraz = datetime.now()

            if os.path.getmtime(sciezka) != zmieniony:
                try:
                    cfg, _ = wczytaj_automatyke(sciezka)
                    zmieniony = os.path.getmtime(sciezka)
                    dziennik(f'Przeładowano {os.path.basename(sciezka)}')
                except Exception as powod:                       # noqa: BLE001
                    dziennik(f'Błąd w pliku automatyki: {powod}')

            for h in cfg.get('harmonogramy', []):
                if h.get('wylaczona') or not dzisiaj_pasuje(h.get('dni'), teraz):
                    continue
                try:
                    cel_czasu = pora_na_dzien(h['o'], teraz, cfg.get('polozenie'))
                except ValueError as powod:
                    dziennik(f'„{h.get("nazwa")}": {powod}')
                    continue
                if cel_czasu is None:
                    continue
                klucz = f'{h.get("nazwa")}|{teraz:%Y-%m-%d}'
                if klucz in wykonane:
                    continue
                if 0 <= (teraz - cel_czasu).total_seconds() < 60:
                    wykonane.add(klucz)
                    zrob(h.get('cel', 'wszystko'), h.get('akcja', {}), f'harmonogram „{h.get("nazwa")}"')

            obecnosc(dom, cfg, teraz, nastepna_obecnosc, zrob)

            if time.time() - ostatnie_odswiezenie[0] > 300:
                dom.odswiez()
                ostatnie_odswiezenie[0] = time.time()

            if len(wykonane) > 500:
                wykonane.clear()
            time.sleep(15)
        except KeyboardInterrupt:
            dziennik('Zatrzymuję automatykę.')
            return


def obecnosc(dom, cfg, teraz, nastepna, zrob):
    o = cfg.get('obecnosc') or {}
    if not o.get('wlaczona'):
        return
    try:
        od = pora_na_dzien(o.get('od', 'zachod'), teraz, cfg.get('polozenie'))
        do = pora_na_dzien(o.get('do', '23:00'), teraz, cfg.get('polozenie'))
    except ValueError:
        return
    if not od or not do or not (od <= teraz <= do) or time.time() < nastepna[0]:
        return
    najmniej, najwiecej = o.get('minPrzerwa', 15), o.get('maxPrzerwa', 45)
    nastepna[0] = time.time() + random.uniform(najmniej, najwiecej) * 60
    zapal = random.random() < 0.6
    zrob(o.get('cel', 'wszystko'),
         {'wlacz': True, 'jasnosc': o.get('jasnosc', 60)} if zapal else {'wlacz': False},
         'symulacja obecności')


# ───────────────────────────── serwer panelu ─────────────────────────────

def serwer_panelu(dom, port=8124):
    stan_dzielony = {'urzadzenia': [], 'czas': 0}

    def odswiezaj():
        while True:
            dom.odswiez()
            stan_dzielony['urzadzenia'] = [u.opis() for u in dom.urzadzenia]
            stan_dzielony['czas'] = time.time()
            time.sleep(10)

    threading.Thread(target=odswiezaj, daemon=True).start()

    class Obsluga(BaseHTTPRequestHandler):
        def log_message(self, *_):                              # cisza w konsoli
            pass

        def _odpowiedz(self, kod, dane, typ='application/json; charset=utf-8'):
            tresc = dane if isinstance(dane, bytes) else json.dumps(dane, ensure_ascii=False).encode()
            self.send_response(kod)
            self.send_header('Content-Type', typ)
            self.send_header('Content-Length', str(len(tresc)))
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(tresc)

        def _cialo(self):
            dlugosc = int(self.headers.get('Content-Length') or 0)
            return json.loads(self.rfile.read(dlugosc) or b'{}')

        def do_GET(self):
            if self.path in ('/', '/panel.html'):
                with open(os.path.join(KATALOG, 'panel.html'), 'rb') as f:
                    return self._odpowiedz(200, f.read(), 'text/html; charset=utf-8')
            if self.path == '/favicon.ico':
                return self._odpowiedz(204, b'', 'image/x-icon')
            if self.path == '/api/stan':
                if not stan_dzielony['czas']:
                    dom.odswiez()
                    stan_dzielony['urzadzenia'] = [u.opis() for u in dom.urzadzenia]
                    stan_dzielony['czas'] = time.time()
                return self._odpowiedz(200, {
                    'urzadzenia': stan_dzielony['urzadzenia'],
                    'grupy': sorted(dom.grupy.keys()),
                    'chmura': dom.chmura is not None,
                    'czas': stan_dzielony['czas'],
                })
            if self.path == '/api/automatyka':
                cfg, _ = wczytaj_automatyke()
                return self._odpowiedz(200, cfg)
            self._odpowiedz(404, {'blad': 'Nie ma takiej ścieżki.'})

        def do_POST(self):
            try:
                if self.path == '/api/ustaw':
                    zadanie = self._cialo()
                    cfg, _ = wczytaj_automatyke()
                    zrobione = wykonaj(dom, zadanie.get('cel', 'wszystko'), zadanie.get('akcja', {}), cfg)
                    stan_dzielony['urzadzenia'] = [u.opis() for u in dom.urzadzenia]
                    return self._odpowiedz(200, {'zrobione': zrobione,
                                                 'urzadzenia': stan_dzielony['urzadzenia']})
                if self.path == '/api/odswiez':
                    dom.odswiez()
                    stan_dzielony['urzadzenia'] = [u.opis() for u in dom.urzadzenia]
                    stan_dzielony['czas'] = time.time()
                    return self._odpowiedz(200, {'urzadzenia': stan_dzielony['urzadzenia']})
                self._odpowiedz(404, {'blad': 'Nie ma takiej ścieżki.'})
            except Exception as powod:                           # noqa: BLE001
                self._odpowiedz(500, {'blad': str(powod)})

        def do_PUT(self):
            if self.path == '/api/automatyka':
                try:
                    cfg = self._cialo()
                    with open(PLIK_AUTOMATYKI, 'w', encoding='utf-8') as f:
                        json.dump(cfg, f, ensure_ascii=False, indent=2)
                    return self._odpowiedz(200, {'zapisano': True})
                except Exception as powod:                       # noqa: BLE001
                    return self._odpowiedz(500, {'blad': str(powod)})
            self._odpowiedz(404, {'blad': 'Nie ma takiej ścieżki.'})

    serwer = ThreadingHTTPServer(('127.0.0.1', port), Obsluga)
    print(f'Panel: http://localhost:{port}\nZatrzymanie: Ctrl+C')
    try:
        serwer.serve_forever()
    except KeyboardInterrupt:
        print('\nZamykam panel.')


# ────────────────────────── pobieranie kluczy ──────────────────────────

def klucze():
    """Kreator tinytuya pobiera z konta Tuya listę urządzeń wraz z kluczami
    lokalnymi, po czym przepisujemy je do urzadzenia.json."""
    wymagaj_tinytuya()
    print('Uruchamiam kreator tinytuya. Potrzebne będą dane projektu z iot.tuya.com')
    print('(instrukcja krok po kroku: README.md, rozdział „Klucze”).\n')
    import tinytuya.wizard                                        # noqa: PLC0415
    tinytuya.wizard.wizard()
    importuj()


def importuj(plik_zrodlowy='devices.json'):
    if not os.path.exists(plik_zrodlowy):
        raise SystemExit(f'Nie widzę {plik_zrodlowy} — uruchom najpierw: python3 tuya.py klucze')
    with open(plik_zrodlowy, encoding='utf-8') as f:
        surowe = json.load(f)
    stare = {}
    if os.path.exists(PLIK_URZADZEN):
        with open(PLIK_URZADZEN, encoding='utf-8') as f:
            poprzednie = json.load(f)
        stare = {u['id']: u for u in poprzednie.get('urzadzenia', [])}
        chmura = poprzednie.get('chmura', {})
    else:
        chmura = {}

    if os.path.exists('tinytuya.json'):
        with open('tinytuya.json', encoding='utf-8') as f:
            k = json.load(f)
        chmura = {'region': k.get('apiRegion', 'eu'), 'klucz_api': k.get('apiKey', ''),
                  'sekret_api': k.get('apiSecret', ''), 'id_urzadzenia': k.get('apiDeviceID', '')}

    urzadzenia = []
    for d in surowe:
        poprzednie = stare.get(d['id'], {})
        rodzaj = poprzednie.get('rodzaj') or KATEGORIE.get(d.get('category'), 'swiatlo-cct')
        urzadzenia.append({
            'nazwa': poprzednie.get('nazwa') or d.get('name') or d['id'],
            'id': d['id'],
            'klucz': d.get('key', ''),
            'ip': d.get('ip') or poprzednie.get('ip'),
            'wersja': float(d.get('version') or poprzednie.get('wersja') or 3.3),
            'rodzaj': rodzaj,
            'grupy': poprzednie.get('grupy', []),
            **({'dp': poprzednie['dp']} if 'dp' in poprzednie else {}),
            **({'zakres': poprzednie['zakres']} if 'zakres' in poprzednie else {}),
        })
    with open(PLIK_URZADZEN, 'w', encoding='utf-8') as f:
        json.dump({'chmura': chmura, 'urzadzenia': urzadzenia}, f, ensure_ascii=False, indent=2)
    os.chmod(PLIK_URZADZEN, 0o600)
    print(f'Zapisano {PLIK_URZADZEN} — urządzeń: {len(urzadzenia)}.')
    print('Sprawdź w nim rodzaje i dopisz grupy (np. "grupy": ["elewacja"]).')


def skanuj():
    wymagaj_tinytuya()
    print('Szukam urządzeń Tuya w sieci lokalnej (ok. 20 s)…')
    znalezione = tinytuya.deviceScan(False, 20)
    if not znalezione:
        return print('Nic nie znalazłem. Urządzenia muszą być w tej samej sieci co komputer.')
    for ip, d in znalezione.items():
        print(f'{ip:<16} {d.get("gwId", "?"):<24} protokół {d.get("version", "?")}')
    if os.path.exists(PLIK_URZADZEN):
        with open(PLIK_URZADZEN, encoding='utf-8') as f:
            dane = json.load(f)
        wg_id = {d.get('gwId'): (ip, d) for ip, d in znalezione.items()}
        zmian = 0
        for u in dane['urzadzenia']:
            if u['id'] in wg_id:
                ip, d = wg_id[u['id']]
                if u.get('ip') != ip or float(u.get('wersja', 0)) != float(d.get('version', 3.3)):
                    u['ip'], u['wersja'] = ip, float(d.get('version', 3.3))
                    zmian += 1
        if zmian:
            with open(PLIK_URZADZEN, 'w', encoding='utf-8') as f:
                json.dump(dane, f, ensure_ascii=False, indent=2)
            print(f'\nUaktualniłem adresy w {os.path.basename(PLIK_URZADZEN)}: {zmian}.')


# ─────────────────────────────── wypisy ───────────────────────────────

def wypisz_liste(dom):
    dom.odswiez()
    grupy = dom.grupy
    for nazwa_grupy, urzadzenia in grupy.items():
        print(f'\nGRUPA: {nazwa_grupy}')
        for u in urzadzenia:
            print('   • ' + wiersz_urzadzenia(u))
    bez_grupy = [u for u in dom.urzadzenia if not u.grupy]
    if bez_grupy:
        print('\nPOZA GRUPAMI' if grupy else 'URZĄDZENIA')
        for u in bez_grupy:
            print('   • ' + wiersz_urzadzenia(u))
    cfg, _ = wczytaj_automatyke()
    if cfg.get('sceny'):
        print('\nSCENY: ' + ', '.join(cfg['sceny']))


def wiersz_urzadzenia(u):
    stan = 'włączone ' if u.wlaczone else 'wyłączone'
    if not u.zrodlo:
        stan = 'BRAK ŁĄCZNOŚCI'
    jasnosc = f'  jasność {u.procent("jasnosc"):>3}%' if u.procent('jasnosc') is not None else ''
    barwa = f'  barwa {u.procent("barwa"):>3}%' if u.procent('barwa') is not None else ''
    zrodlo = f'  ({u.zrodlo})' if u.zrodlo else ''
    return f'{u.nazwa:<22} {stan}{jasnosc}{barwa}{zrodlo}'


def wypisz_diagnostyke(dom):
    dom.odswiez()
    print(f'{"URZĄDZENIE":<22}{"ADRES":<17}{"PROTOKÓŁ":<10}{"ŁĄCZNOŚĆ":<14}RODZAJ')
    problemy = []
    for u in dom.urzadzenia:
        lacznosc = u.zrodlo or 'BRAK'
        print(f'{u.nazwa[:21]:<22}{str(u.ip or "—"):<17}{u.wersja:<10}{lacznosc:<14}{u.rodzaj}')
        if not u.zrodlo:
            problemy.append(f'{u.nazwa}: nie odpowiada ({u.blad or "brak adresu IP"})')
        elif u.zrodlo == 'chmura':
            problemy.append(f'{u.nazwa}: odpowiada tylko przez chmurę — sprawdź adres IP '
                            f'(python3 tuya.py skanuj)')
        elif not u.stan:
            problemy.append(f'{u.nazwa}: odpowiada, ale nie zwrócił żadnych parametrów')
    print()
    if problemy:
        print('DO SPRAWDZENIA:')
        for p in problemy:
            print('   ! ' + p)
    else:
        print('Wszystkie urządzenia odpowiadają lokalnie.')


def wypisz_dps(dom, cel):
    for u in dom.znajdz(cel):
        u.odczytaj()
        print(f'\n{u.nazwa}  ({u.rodzaj}, protokół {u.wersja}, {u.zrodlo or "brak łączności"})')
        if u.blad:
            print(f'   błąd: {u.blad}')
        for numer, wartosc in sorted(u.stan.items(), key=lambda x: str(x[0])):
            funkcja = next((f for f, dp in u.dp.items() if str(dp) == str(numer)), '')
            print(f'   DP {str(numer):<4} = {str(wartosc):<24} {funkcja}')


# ──────────────────────────────── CLI ────────────────────────────────

POMOC = """
Sterowanie urządzeniami Tuya / SmartLife.

  python3 tuya.py klucze                pobiera klucze urządzeń z konta Tuya
  python3 tuya.py importuj              przepisuje devices.json do urzadzenia.json
  python3 tuya.py skanuj                szuka urządzeń w sieci i uaktualnia adresy
  python3 tuya.py lista                 urządzenia, grupy, sceny
  python3 tuya.py diagnostyka           łączność, adresy, protokoły
  python3 tuya.py dps <cel>             surowe parametry urządzenia

  python3 tuya.py wlacz <cel>
  python3 tuya.py wylacz <cel>
  python3 tuya.py przelacz <cel>
  python3 tuya.py jasnosc <cel> <0-100>
  python3 tuya.py barwa <cel> <0-100>        0 = ciepła, 100 = zimna
  python3 tuya.py scena <nazwa>

  python3 tuya.py automat [plik.json]   uruchamia automatykę
  python3 tuya.py panel [port]          panel w przeglądarce (domyślnie 8124)

Cel: "wszystko", "grupa:elewacja" albo nazwa urządzenia (fragment nazwy wystarczy).
Jasność i barwę można zmieniać płynnie: --przejscie <sekundy>
"""


def main(argumenty):
    if not argumenty or argumenty[0] in ('pomoc', '-h', '--help'):
        return print(POMOC)
    polecenie, reszta = argumenty[0], argumenty[1:]

    przejscie = None
    if '--przejscie' in reszta:
        i = reszta.index('--przejscie')
        przejscie = float(reszta[i + 1])
        reszta = reszta[:i] + reszta[i + 2:]

    if polecenie == 'klucze':
        return klucze()
    if polecenie == 'importuj':
        return importuj(reszta[0] if reszta else 'devices.json')
    if polecenie == 'skanuj':
        return skanuj()

    dom = Dom()

    if polecenie == 'lista':
        return wypisz_liste(dom)
    if polecenie == 'diagnostyka':
        return wypisz_diagnostyke(dom)
    if polecenie == 'dps':
        return wypisz_dps(dom, reszta[0] if reszta else 'wszystko')
    if polecenie == 'panel':
        return serwer_panelu(dom, int(reszta[0]) if reszta else 8124)
    if polecenie == 'automat':
        return automat(dom, reszta[0] if reszta else None)

    akcje = {
        'wlacz': lambda: {'wlacz': True},
        'wylacz': lambda: {'wlacz': False},
        'przelacz': lambda: {'przelacz': True},
        'jasnosc': lambda: {'jasnosc': float(reszta[1])},
        'barwa': lambda: {'barwa': float(reszta[1])},
    }
    if polecenie == 'scena':
        cfg, _ = wczytaj_automatyke()
        zrobione = uruchom_scene(dom, ' '.join(reszta), cfg)
        return print('OK — ' + ', '.join(zrobione) if zrobione else 'Nic nie odpowiedziało.')
    if polecenie not in akcje:
        print(f'Nie znam polecenia „{polecenie}".')
        return print(POMOC)
    if not reszta:
        raise SystemExit(f'Brakuje celu, np.: python3 tuya.py {polecenie} "Ledy ogród"')

    dom.odswiez()
    akcja = akcje[polecenie]()
    if przejscie is not None:
        akcja['przejscie'] = przejscie
    cfg, _ = wczytaj_automatyke()
    zrobione = wykonaj(dom, reszta[0], akcja, cfg)
    print('OK — ' + ', '.join(zrobione) if zrobione else 'Nic nie odpowiedziało.')


if __name__ == '__main__':
    try:
        main(sys.argv[1:])
    except KeyboardInterrupt:
        pass
    except BrokenPipeError:                 # np. „| head"
        os._exit(0)
