#!/usr/bin/env python3
"""Spis urządzeń w sieci domowej — bez wchodzenia do routera.

    python3 siec.py                    # sieć, w której jestem
    python3 siec.py 192.168.88.0/24    # wskazana sieć

Powstało, bo hasła do routera nie zawsze się ma, a lista dzierżaw DHCP jest
jedynym miejscem, gdzie normalnie widać, co siedzi pod jakim adresem. To samo
da się zobaczyć od strony sieci: pukamy do każdego adresu, a system przy okazji
zapamiętuje adresy MAC w tablicy ARP. MAC nie zmienia się nigdy, więc po nim
rozpoznaje się urządzenie, choćby dostało jutro inny numer.
"""

import argparse
import re
import socket
import subprocess
import sys
import threading

# Porty, po których poznaje się, czym jest urządzenie. Kamery i domofony
# wystawiają RTSP i własne porty sterujące, sterowniki — Modbusa.
PORTY = {
    80: 'WWW', 443: 'WWW (HTTPS)', 554: 'RTSP (obraz z kamery)',
    8000: 'kamera/rejestrator', 8080: 'WWW (zapasowy)', 8899: 'domofon/kamera',
    37777: 'Dahua', 34567: 'rejestrator', 502: 'Modbus', 22: 'SSH', 23: 'Telnet',
    1883: 'MQTT', 8123: 'panel Hue', 8125: 'panel pompy',
}

# Początki adresów MAC, które już rozpoznaliśmy w tym domu.
ZNANE = {
    'f8:dc:7a': 'pompa ciepła (Tecomat/ACOND)',
    '0c:ef:15': 'router TP-Link HX520',
    '5c:a6:e6': 'wzmacniacz TP-Link RE205',
    'ec:b5:fa': 'mostek Philips Hue',
    '00:17:88': 'mostek Philips Hue',
}


def odmiana(ile, jedno, kilka, wiele):
    """1 urządzenie, 2 urządzenia, 5 urządzeń — inaczej to kłuje w oczy."""
    if ile == 1:
        return jedno
    reszta_dziesiatek, reszta = ile % 100, ile % 10
    if 2 <= reszta <= 4 and not 12 <= reszta_dziesiatek <= 14:
        return kilka
    return wiele


def adres_lokalny():
    for cel in (('192.168.1.1', 1), ('192.168.88.1', 1), ('10.0.0.1', 1), ('8.8.8.8', 1)):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as g:
                g.connect(cel)
                adres = g.getsockname()[0]
            czesci = [int(x) for x in adres.split('.')]
            if czesci[0] == 10 or (czesci[0] == 172 and 16 <= czesci[1] <= 31) \
                    or (czesci[0] == 192 and czesci[1] == 168):
                return adres
        except (OSError, ValueError):
            continue
    return None


def tablica_arp():
    """{adres IP: MAC} z tablicy ARP systemu."""
    try:
        wynik = subprocess.run(['arp', '-a'], capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.SubprocessError):
        return {}
    wzor = re.compile(r'(\d{1,3}(?:\.\d{1,3}){3}).*?((?:[0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2})')
    mapa = {}
    for linia in wynik.stdout.splitlines():
        t = wzor.search(linia)
        if t:
            mapa[t.group(1)] = t.group(2).lower().replace('-', ':')
    return mapa


def otwarte_porty(adres, porty, limit):
    znalezione, zamek = [], threading.Lock()

    def sprawdz(port):
        with socket.socket() as g:
            g.settimeout(limit)
            if g.connect_ex((adres, port)) == 0:
                with zamek:
                    znalezione.append(port)

    watki = [threading.Thread(target=sprawdz, args=(p,)) for p in porty]
    for w in watki:
        w.start()
    for w in watki:
        w.join()
    return sorted(znalezione)


def zywe(poczatek, limit):
    """Adresy, które w ogóle odpowiadają — pukamy na kilka portów naraz."""
    trafione, zamek = [], threading.Lock()
    probne = (80, 443, 554, 8000, 8899)

    def puknij(numer):
        adres = f'{poczatek}.{numer}'
        for port in probne:
            with socket.socket() as g:
                g.settimeout(limit)
                if g.connect_ex((adres, port)) == 0:
                    with zamek:
                        trafione.append(adres)
                    return

    watki = [threading.Thread(target=puknij, args=(n,)) for n in range(1, 255)]
    for w in watki:
        w.start()
    for w in watki:
        w.join()
    return trafione


def main():
    parser = argparse.ArgumentParser(description='Spis urządzeń w sieci domowej.')
    parser.add_argument('siec', nargs='?', help='np. 192.168.88.0/24; domyślnie ta, w której jestem')
    parser.add_argument('--limit', type=float, default=0.6, help='ile sekund czekać na port')
    argumenty = parser.parse_args()

    if argumenty.siec:
        poczatek = argumenty.siec.split('/')[0].rsplit('.', 1)[0]
    else:
        moj = adres_lokalny()
        if not moj:
            raise SystemExit('Nie wiem, w jakiej jestem sieci — podaj ją, np. 192.168.88.0/24')
        poczatek = moj.rsplit('.', 1)[0]

    print(f'Przeczesuję {poczatek}.1–254 …', flush=True)
    trafione = zywe(poczatek, argumenty.limit)
    arp = tablica_arp()

    # Tablica ARP zna często więcej urządzeń niż odpowiedziało na porty —
    # kamera bez otwartego portu wciąż tam jest i warto o niej wiedzieć.
    wszystkie = sorted(set(trafione) | {a for a in arp if a.startswith(poczatek + '.')},
                       key=lambda a: int(a.rsplit('.', 1)[1]))
    if not wszystkie:
        raise SystemExit('Nic nie znalazłem. Czy komputer jest w tej samej sieci?')

    ile = len(wszystkie)
    print(f'\nZnalazłem {ile} {odmiana(ile, "urządzenie", "urządzenia", "urządzeń")}\n')
    print(f'{"Adres":<16}{"MAC":<20}{"Co nasłuchuje":<42}Domysł')
    print('─' * 104)
    for adres in wszystkie:
        mac = arp.get(adres, '—')
        porty = otwarte_porty(adres, PORTY, argumenty.limit) if adres in trafione else []
        opis = ', '.join(f'{p} {PORTY[p]}' for p in porty) or '(nic z listy)'
        domysl = ZNANE.get(mac[:8], '')
        if not domysl and 554 in porty:
            domysl = 'kamera albo domofon (ma obraz RTSP)'
        print(f'{adres:<16}{mac:<20}{opis[:41]:<42}{domysl}')

    print('\nMAC nie zmienia się nigdy — po nim poznasz urządzenie,')
    print('choćby jutro dostało inny adres.')


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
