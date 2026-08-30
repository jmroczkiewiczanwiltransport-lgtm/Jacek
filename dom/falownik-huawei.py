#!/usr/bin/env python3
"""Odczyt falownika Huawei SUN2000 przez Modbus TCP — lokalnie, bez chmury.

    python3 falownik-huawei.py 192.168.88.20
    python3 falownik-huawei.py 192.168.88.20 --zapisuj --co 300

Falownik musi mieć włączony Modbus TCP: aplikacja FusionSolar → Uruchomienie
urządzenia (połączenie z siecią WiFi falownika) → Ustawienia → Konfiguracja
komunikacji → Modbus TCP → „Włącz (bez ograniczeń)".

Uwaga: SUN2000 obsługuje **jednego klienta Modbus naraz**. Gdy podłączy się
Home Assistant, ten skrypt przestanie dostawać odpowiedzi i odwrotnie.
"""

import argparse
import os
import sys
import time
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from falownik import REJESTRY, zlacz, odczytaj   # noqa: E402


def wypisz(wynik):
    print(f'{datetime.now():%Y-%m-%d %H:%M:%S}')
    for nazwa, (wartosc, jednostka) in wynik.items():
        if wartosc is None:
            print(f'   {nazwa:<40} — {jednostka}')
        else:
            print(f'   {nazwa:<40} {wartosc:>12,.2f} {jednostka}'.replace(',', ' '))
    print('\nPorównaj z aplikacją FusionSolar. Jeśli któraś wartość nie ma sensu,')
    print('ten model numeruje ją inaczej — daj znać, poprawimy mapę rejestrów.')


def zapisuj(argumenty):
    plik = argumenty.plik or os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                          'dane-falownika.csv')
    kolumny = [nazwa for _, _, _, _, nazwa, _ in REJESTRY]
    if not os.path.exists(plik):
        with open(plik, 'w', encoding='utf-8') as f:
            f.write(';'.join(['czas'] + kolumny) + '\n')
        print(f'Zakładam {plik}')
    else:
        print(f'Dopisuję do {plik}')
    print(f'Zapisuję co {argumenty.co:.0f} s. Ctrl+C kończy.')

    zapisanych, bledow = 0, 0
    try:
        while True:
            try:
                wynik = odczytaj(argumenty.host, argumenty.port, argumenty.jednostka)
                wiersz = [datetime.now().strftime('%Y-%m-%d %H:%M:%S')]
                wiersz += ['' if wynik[k][0] is None else f'{wynik[k][0]:.2f}' for k in kolumny]
                with open(plik, 'a', encoding='utf-8') as f:
                    f.write(';'.join(wiersz) + '\n')
                zapisanych += 1
                if zapisanych % 12 == 1:
                    moc = wynik.get('Moc oddawana (AC)', (None, ''))[0]
                    print(f'{datetime.now():%H:%M:%S}  odczytów: {zapisanych}'
                          + (f', teraz {moc:.0f} W' if moc is not None else ''))
            except OSError as powod:
                bledow += 1
                print(f'{datetime.now():%H:%M:%S}  brak odczytu ({powod})')
                print('   Jeśli to się powtarza: sprawdź, czy Modbus nie jest zajęty przez')
                print('   Home Assistanta albo aplikację — falownik obsługuje jednego naraz.')
            time.sleep(argumenty.co)
    except KeyboardInterrupt:
        print(f'\nKoniec. Odczytów: {zapisanych}, nieudanych: {bledow}.')


def main():
    parser = argparse.ArgumentParser(description='Odczyt falownika Huawei SUN2000.')
    parser.add_argument('host', help='adres falownika w sieci domowej')
    parser.add_argument('--port', type=int, default=502)
    parser.add_argument('--jednostka', type=int, default=1, help='adres Modbus, zwykle 1 albo 0')
    parser.add_argument('--zapisuj', action='store_true', help='zapisuj odczyty do CSV')
    parser.add_argument('--co', type=float, default=300, help='co ile sekund przy zapisie')
    parser.add_argument('--plik', help='plik CSV z zapisem')
    argumenty = parser.parse_args()

    try:
        if argumenty.zapisuj:
            return zapisuj(argumenty)
        wypisz(odczytaj(argumenty.host, argumenty.port, argumenty.jednostka))
    except OSError as powod:
        print(f'\nNie udało się: {powod}\n')
        print('Co sprawdzić:')
        print('  • czy Modbus TCP jest włączony w falowniku — FusionSolar → Uruchomienie')
        print('    urządzenia → Ustawienia → Konfiguracja komunikacji → Modbus TCP,')
        print('  • czy adres jest właściwy (falownik w sieci domowej, nie jego własne WiFi),')
        print('  • czy nie odpytuje go już coś innego — obsługuje jednego klienta naraz,')
        print('  • spróbuj --jednostka 0, niektóre modele odpowiadają pod zerem.')
        sys.exit(1)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
    except BrokenPipeError:
        os._exit(0)
